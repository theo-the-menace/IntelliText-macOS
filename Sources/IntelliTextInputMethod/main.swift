import AppKit
import InputMethodKit
import IntelliTextCore
import ApplicationServices

final class TeacherHintPanel {
    static let shared = TeacherHintPanel()

    private let panel: NSPanel
    private let titleLabel: NSTextField
    private let detailLabel: NSTextField
    private var dismissWorkItem: DispatchWorkItem?

    private init() {
        titleLabel = NSTextField(labelWithString: "")
        detailLabel = NSTextField(labelWithString: "")
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.maximumNumberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        detailLabel.font = .systemFont(ofSize: 11)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.maximumNumberOfLines = 0
        detailLabel.lineBreakMode = .byWordWrapping

        let stack = NSStackView(views: [titleLabel, detailLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 44),
            styleMask: [.titled, .utilityWindow, .nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.blendingMode = .withinWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 8
        background.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = background
        background.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 7),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -7),
            stack.topAnchor.constraint(equalTo: background.topAnchor, constant: 5),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -5)
        ])
    }

    func show(original: String, replacement: String, note: String, anchor: NSRect? = nil) {
        dismissWorkItem?.cancel()
        titleLabel.stringValue = "Corrected: \(replacement)"
        let explanation = note.trimmingCharacters(in: .whitespacesAndNewlines)
        detailLabel.stringValue = explanation.isEmpty
            ? "Original: \(original)"
            : "Why: \(explanation)  ·  Original: \(original)"
        let contentWidth: CGFloat = 246
        titleLabel.preferredMaxLayoutWidth = contentWidth
        detailLabel.preferredMaxLayoutWidth = contentWidth
        let titleHeight = (titleLabel.stringValue as NSString).boundingRect(
            with: NSSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: titleLabel.font!]
        ).height
        let detailHeight = (detailLabel.stringValue as NSString).boundingRect(
            with: NSSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: detailLabel.font!]
        ).height
        panel.setContentSize(NSSize(width: 260, height: max(34, titleHeight + detailHeight + 12)))

        if let anchor {
            let screen = NSScreen.screens.first(where: { $0.frame.intersects(anchor) }) ?? NSScreen.main
            let frame = panel.frame
            let below = anchor.minY - frame.height - 10
            let above = anchor.maxY + 10
            let y = below >= (screen?.visibleFrame.minY ?? 0) ? below : above
            let x = min(max(anchor.minX, screen?.visibleFrame.minX ?? anchor.minX),
                        (screen?.visibleFrame.maxX ?? anchor.maxX) - frame.width)
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else if let screen = NSScreen.main {
            let frame = panel.frame
            let x = screen.visibleFrame.midX - frame.width / 2
            let y = screen.visibleFrame.maxY - frame.height - 54
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        panel.orderFrontRegardless()

        let workItem = DispatchWorkItem { [weak self] in
            self?.panel.orderOut(nil)
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5, execute: workItem)
    }
}

@objc(InputController)
final class InputController: IMKInputController {
    private let engine = CorrectionEngine(provider: HybridInferenceProvider())
    private weak var lastClient: AnyObject?
    private var lastTransaction: ReplacementTransaction?
    private var autoCheckWorkItem: DispatchWorkItem?
    private var lastAutoCheckedSentence: String?
    private var fallbackText = ""
    private var fallbackClientID: ObjectIdentifier?

    override func inputText(_ string: String!, client sender: Any!) -> Bool {
        guard let string else { return false }
        guard let client = sender as? IMKTextInput else { return false }
        NSLog("IntelliText: inputText received committed text (length=%d)", string.utf16.count)
        client.insertText(string, replacementRange: NSRange(location: NSNotFound, length: 0))
        updateFallback(with: string, client: client)
        scheduleAutomaticCheck(for: client)
        return true
    }

    /// Receive unpacked key events from InputMethodKit and commit them directly.
    func inputText(_ string: String!, key keyCode: Int, modifiers flags: UInt, client sender: Any!) -> Bool {
        guard let client = sender as? IMKTextInput else { return false }
        NSLog("IntelliText: unpacked key event (keyCode=%d, length=%d)", keyCode, string?.utf16.count ?? 0)
        let modifiers = NSEvent.ModifierFlags(rawValue: flags)
        if modifiers.contains(.command) || modifiers.contains(.control) {
            return false
        }

        // Backspace and forward-delete do not have useful `characters` values.
        if keyCode == 51 {
            let selection = client.selectedRange()
            let location = selection.location == NSNotFound ? 0 : selection.location
            let range = selection.length > 0
                ? selection
                : NSRange(location: max(0, location - 1), length: location > 0 ? 1 : 0)
            if range.length > 0 {
                client.insertText("", replacementRange: range)
                removeFallbackCharacters(count: range.length, client: client)
            }
            scheduleAutomaticCheck(for: client)
            return true
        }
        if keyCode == 117 {
            let selection = client.selectedRange()
            if selection.location != NSNotFound {
                let range = selection.length > 0 ? selection : NSRange(location: selection.location, length: 1)
                client.insertText("", replacementRange: range)
                removeFallbackCharacters(count: range.length, client: client)
            }
            scheduleAutomaticCheck(for: client)
            return true
        }

        guard let string, !string.isEmpty else { return false }
        client.insertText(string, replacementRange: NSRange(location: NSNotFound, length: 0))
        updateFallback(with: string, client: client)
        scheduleAutomaticCheck(for: client)
        return true
    }

    /// Receive raw key events when the Text Services Manager does not unpack them.
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, event.type == .keyDown else { return false }
        NSLog("IntelliText: raw key event (keyCode=%d)", Int(event.keyCode))
        return inputText(
            event.characters,
            key: Int(event.keyCode),
            modifiers: event.modifierFlags.rawValue,
            client: sender
        )
    }

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask.keyDown.rawValue)
    }

    override func activateServer(_ sender: Any!) {
        NSLog("IntelliText: input controller activated")
    }

    /// Debounced automatic correction. The input method receives committed text here,
    /// so the model only runs after the user pauses, rather than once per keystroke.
    private func scheduleAutomaticCheck(for client: IMKTextInput) {
        autoCheckWorkItem?.cancel()
        var workItem: DispatchWorkItem!
        workItem = DispatchWorkItem { [weak self, weak client] in
            guard let self, let client, !workItem.isCancelled else { return }
            self.correctCurrentSentence(client: client, automatic: true)
        }
        autoCheckWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: workItem)
    }

    private func updateFallback(with string: String, client: IMKTextInput) {
        resetFallbackIfNeeded(for: client)
        fallbackText.append(string)
    }

    private func removeFallbackCharacters(count: Int, client: IMKTextInput) {
        resetFallbackIfNeeded(for: client)
        fallbackText = String(fallbackText.dropLast(min(count, fallbackText.count)))
    }

    private func resetFallbackIfNeeded(for client: IMKTextInput) {
        let id = ObjectIdentifier(client as AnyObject)
        if fallbackClientID != id {
            fallbackClientID = id
            fallbackText = ""
            lastAutoCheckedSentence = nil
        }
    }

    func correctCurrentSentence(client: IMKTextInput, automatic: Bool = false) {
        let selection = client.selectedRange()
        let documentLength = client.length()
        guard selection.location != NSNotFound,
              documentLength != NSNotFound,
              selection.location <= documentLength else {
            NSLog("IntelliText: cannot inspect current text (selection=%@ length=%d)", NSStringFromRange(selection), documentLength)
            return
        }

        let documentRange = NSRange(location: 0, length: documentLength)
        let text: String
        let contextSelection: NSRange
        if let attributed = client.attributedSubstring(from: documentRange) {
            text = attributed.string
            contextSelection = selection
        } else {
            resetFallbackIfNeeded(for: client)
            text = fallbackText
            contextSelection = NSRange(location: text.utf16.count, length: 0)
            NSLog("IntelliText: using local input buffer fallback (length=%d)", text.utf16.count)
        }
        guard !text.isEmpty else { return }
        let context = TextContext(text: text, selectedRange: contextSelection)
        let sentence = context.currentSentence
        guard !sentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard sentence.split(whereSeparator: { $0.isWhitespace }).count >= 2 else {
            NSLog("IntelliText: waiting for a complete phrase")
            return
        }
        if automatic, sentence == lastAutoCheckedSentence { return }
        if automatic { lastAutoCheckedSentence = sentence }

        lastClient = client as AnyObject
        let style = WritingStyle(rawValue: UserDefaults.standard.string(forKey: "IntelliText.WritingStyle") ?? "professional") ?? .professional
        Task { [engine] in
            guard let result = try? await engine.suggest(for: context, style: style) else {
                NSLog("IntelliText: correction model returned no change or failed")
                return
            }
            let (_, transaction) = result
            await MainActor.run {
                if let current = client.attributedSubstring(from: transaction.range), current.string == transaction.original {
                    client.insertText(transaction.replacement, replacementRange: transaction.range)
                } else if self.fallbackText == transaction.original {
                    let replacementRange = NSRange(location: 0, length: transaction.original.utf16.count)
                    client.insertText(transaction.replacement, replacementRange: replacementRange)
                    self.fallbackText = transaction.replacement
                } else {
                    return
                }
                NSLog("IntelliText: applied automatic correction")
                self.lastTransaction = transaction
                if automatic {
                    TeacherHintPanel.shared.show(
                        original: transaction.original,
                        replacement: transaction.replacement,
                        note: result.0.shortNote,
                        anchor: self.focusedTextFrame()
                    )
                }
            }
        }
    }

    private func focusedTextFrame() -> NSRect? {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused else { return nil }
        let element = focused as! AXUIElement
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }
        let screen = NSScreen.screens.first(where: { $0.frame.contains(point) })
        return NSRect(x: point.x, y: (screen?.frame.maxY ?? 0) - point.y - size.height, width: size.width, height: size.height)
    }

    override func menu() -> NSMenu! {
        let menu = NSMenu(title: "IntelliText")
        let item = NSMenuItem(
            title: "Polish Current Sentence",
            action: #selector(polishCurrentSentence(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(item)
        let undo = NSMenuItem(title: "Undo IntelliText Correction", action: #selector(undoLastCorrection(_:)), keyEquivalent: "z")
        undo.keyEquivalentModifierMask = [.command, .option, .shift]
        undo.target = self
        menu.addItem(undo)
        menu.addItem(.separator())
        let styleItem = NSMenuItem(title: "Writing Style", action: nil, keyEquivalent: "")
        let styleMenu = NSMenu(title: "Writing Style")
        for style in WritingStyle.allCases {
            let option = NSMenuItem(title: style.displayName, action: #selector(selectWritingStyle(_:)), keyEquivalent: "")
            option.representedObject = style.rawValue
            option.target = self
            styleMenu.addItem(option)
        }
        styleItem.submenu = styleMenu
        menu.addItem(styleItem)
        return menu
    }

    @objc private func polishCurrentSentence(_ sender: Any?) {
        guard let info = sender as? [AnyHashable: Any],
              let client = info[kIMKCommandClientName] as? IMKTextInput else { return }
        correctCurrentSentence(client: client)
    }

    @objc private func undoLastCorrection(_ sender: Any?) {
        guard let client = lastClient as? IMKTextInput, let transaction = lastTransaction else { return }
        let replacementRange = NSRange(location: transaction.range.location, length: transaction.replacement.utf16.count)
        guard replacementRange.location + replacementRange.length <= client.length(),
              let current = client.attributedSubstring(from: replacementRange),
              current.string == transaction.replacement else { return }
        client.insertText(transaction.original, replacementRange: replacementRange)
        lastTransaction = nil
    }

    @objc private func selectWritingStyle(_ sender: NSMenuItem) {
        guard let style = sender.representedObject as? String else { return }
        UserDefaults.standard.set(style, forKey: "IntelliText.WritingStyle")
    }
}

private extension WritingStyle {
    var displayName: String {
        switch self {
        case .casual: return "Daily Conversation"
        case .businessEmail: return "Business Email"
        case .professional: return "Professional"
        case .academic: return "Academic"
        }
    }
}

@objc(ServerDelegate)
final class ServerDelegate: NSObject, NSApplicationDelegate {
    private var server: IMKServer!
    private let modelServer = LocalModelServer()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("IntelliText: server delegate launched")
        modelServer.startIfNeeded()
        server = IMKServer(name: "IntelliText_Connection", bundleIdentifier: Bundle.main.bundleIdentifier ?? "com.theo.inputmethod.IntelliText")
        NSLog("IntelliText: IMK server initialized")
    }

    func applicationWillTerminate(_ notification: Notification) {
        modelServer.stop()
    }
}

let app = NSApplication.shared
let delegate = ServerDelegate()
app.delegate = delegate
app.run()
