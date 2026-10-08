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
        // Text extraction and replacement range wiring will use the IMKTextInput
        // protocol's documented selection APIs in the next input-method slice.
        _ = client
        _ = provider
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
