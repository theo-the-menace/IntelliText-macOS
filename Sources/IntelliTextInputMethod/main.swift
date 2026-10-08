import AppKit
import InputMethodKit
import IntelliTextCore

final class TeacherHintPanel {
    static let shared = TeacherHintPanel()

    private let panel: NSPanel
    private let titleLabel: NSTextField
    private let detailLabel: NSTextField
    private var dismissWorkItem: DispatchWorkItem?

    private init() {
        titleLabel = NSTextField(labelWithString: "")
        detailLabel = NSTextField(labelWithString: "")
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        detailLabel.font = .systemFont(ofSize: 12)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.maximumNumberOfLines = 2
        detailLabel.lineBreakMode = .byWordWrapping

        let stack = NSStackView(views: [titleLabel, detailLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 72),
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
        background.layer?.cornerRadius = 12
        background.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = background
        background.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: background.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -12)
        ])
    }

    func show(original: String, replacement: String, note: String) {
        dismissWorkItem?.cancel()
        titleLabel.stringValue = "Corrected: \(replacement)"
        let explanation = note.trimmingCharacters(in: .whitespacesAndNewlines)
        detailLabel.stringValue = explanation.isEmpty
            ? "Original: \(original)"
            : "Why: \(explanation)  ·  Original: \(original)"

        if let screen = NSScreen.main {
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

final class InputController: IMKInputController {
    private let engine = CorrectionEngine(provider: HybridInferenceProvider())
    private weak var lastClient: AnyObject?
    private var lastTransaction: ReplacementTransaction?
    private var autoCheckWorkItem: DispatchWorkItem?
    private var lastAutoCheckedSentence: String?

    override func inputText(_ string: String!, client sender: Any!) -> Bool {
        guard let string else { return false }
        guard let client = sender as? IMKTextInput else { return false }
        client.insertText(string, replacementRange: NSRange(location: NSNotFound, length: 0))
        scheduleAutomaticCheck(for: client)
        return true
    }

    /// Make IntelliText a usable English input source: pass ordinary key presses
    /// into the focused application while leaving app/system shortcuts untouched.
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, event.type == .keyDown,
              let client = sender as? IMKTextInput else { return false }
        let flags = event.modifierFlags
        if flags.contains(.command) || flags.contains(.control) {
            return false
        }

        // Backspace and forward-delete do not have useful `characters` values.
        if event.keyCode == 51 {
            let selection = client.selectedRange()
            let location = selection.location == NSNotFound ? 0 : selection.location
            let range = selection.length > 0
                ? selection
                : NSRange(location: max(0, location - 1), length: location > 0 ? 1 : 0)
            if range.length > 0 { client.insertText("", replacementRange: range) }
            scheduleAutomaticCheck(for: client)
            return true
        }
        if event.keyCode == 117 {
            let selection = client.selectedRange()
            if selection.location != NSNotFound {
                let range = selection.length > 0 ? selection : NSRange(location: selection.location, length: 1)
                client.insertText("", replacementRange: range)
            }
            scheduleAutomaticCheck(for: client)
            return true
        }

        guard let characters = event.characters, !characters.isEmpty else { return false }
        client.insertText(characters, replacementRange: NSRange(location: NSNotFound, length: 0))
        scheduleAutomaticCheck(for: client)
        return true
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

    func correctCurrentSentence(client: IMKTextInput, automatic: Bool = false) {
        let selection = client.selectedRange()
        let documentLength = client.length()
        guard selection.location != NSNotFound,
              documentLength != NSNotFound,
              selection.location <= documentLength else { return }

        let documentRange = NSRange(location: 0, length: documentLength)
        guard let attributed = client.attributedSubstring(from: documentRange) else { return }
        let context = TextContext(text: attributed.string, selectedRange: selection)
        let sentence = context.currentSentence
        guard !sentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard sentence.split(whereSeparator: { $0.isWhitespace }).count >= 2 else { return }
        if automatic, sentence == lastAutoCheckedSentence { return }
        if automatic { lastAutoCheckedSentence = sentence }

        lastClient = client as AnyObject
        let style = WritingStyle(rawValue: UserDefaults.standard.string(forKey: "IntelliText.WritingStyle") ?? "professional") ?? .professional
        Task { [engine] in
            guard let result = try? await engine.suggest(for: context, style: style) else { return }
            let (_, transaction) = result
            await MainActor.run {
                guard client.length() != NSNotFound,
                      transaction.range.location + transaction.range.length <= client.length(),
                      let current = client.attributedSubstring(from: transaction.range),
                      current.string == transaction.original else { return }
                client.insertText(transaction.replacement, replacementRange: transaction.range)
                self.lastTransaction = transaction
                if automatic {
                    TeacherHintPanel.shared.show(
                        original: transaction.original,
                        replacement: transaction.replacement,
                        note: result.0.shortNote
                    )
                }
            }
        }
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

final class ServerDelegate: NSObject, NSApplicationDelegate {
    private var server: IMKServer!
    private let modelServer = LocalModelServer()

    func applicationDidFinishLaunching(_ notification: Notification) {
        modelServer.startIfNeeded()
        server = IMKServer(name: "IntelliText_Connection", bundleIdentifier: Bundle.main.bundleIdentifier ?? "com.theo.IntelliTextMacOS.InputMethod")
    }

    func applicationWillTerminate(_ notification: Notification) {
        modelServer.stop()
    }
}

let app = NSApplication.shared
let delegate = ServerDelegate()
app.delegate = delegate
app.run()
