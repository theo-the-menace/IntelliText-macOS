import AppKit
import InputMethodKit
import IntelliTextCore

final class InputController: IMKInputController {
    private let engine = CorrectionEngine(provider: HybridInferenceProvider())
    private weak var lastClient: AnyObject?
    private var lastTransaction: ReplacementTransaction?

    override func inputText(_ string: String!, client sender: Any!) -> Bool {
        guard let string else { return false }
        (sender as? IMKTextInput)?.insertText(string, replacementRange: NSRange(location: NSNotFound, length: 0))
        return true
    }

    func correctCurrentSentence(client: IMKTextInput) {
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
