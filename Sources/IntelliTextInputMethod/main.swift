import AppKit
import InputMethodKit
import IntelliTextCore

final class InputController: IMKInputController {
    private let provider: InferenceProvider = MockInferenceProvider()

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
        let sentenceRange = context.currentSentenceRange
        guard !sentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        Task { [provider] in
            guard let response = try? await provider.correct(CorrectionRequest(sentence: sentence)),
                  response.confidence >= 0.9,
                  response.replacement != response.original else { return }
            let transaction = ReplacementTransaction(
                range: sentenceRange,
                original: response.original,
                replacement: response.replacement
            )
            await MainActor.run {
                client.insertText(transaction.replacement, replacementRange: transaction.range)
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
        menu.addItem(item)
        return menu
    }

    @objc private func polishCurrentSentence(_ sender: Any?) {
        guard let info = sender as? [AnyHashable: Any],
              let client = info[kIMKCommandClientName] as? IMKTextInput else { return }
        correctCurrentSentence(client: client)
    }
}

final class ServerDelegate: NSObject, NSApplicationDelegate {
    private var server: IMKServer!

    func applicationDidFinishLaunching(_ notification: Notification) {
        server = IMKServer(name: "IntelliText_Connection", bundleIdentifier: Bundle.main.bundleIdentifier ?? "com.theo.IntelliTextMacOS.InputMethod")
    }
}

let app = NSApplication.shared
let delegate = ServerDelegate()
app.delegate = delegate
app.run()
