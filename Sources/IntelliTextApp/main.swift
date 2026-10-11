import AppKit
import Combine
import SwiftUI
import IntelliTextCore

@MainActor
final class IntelliTextAppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NSPanel!
    private let modelServer = LocalModelServer()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        modelServer.startIfNeeded()

        let state = WritingAssistantModel()
        let hosting = NSHostingView(rootView: FloatingInputView(model: state))
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 340),
            styleMask: [.titled, .closable, .miniaturizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "IntelliText"
        panel.contentView = hosting
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: 360, height: 280)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        modelServer.stop()
    }
}

@MainActor
final class WritingAssistantModel: ObservableObject {
    @Published var text = "" {
        didSet { scheduleSuggestion() }
    }
    @Published var style: WritingStyle = .professional {
        didSet { scheduleSuggestion() }
    }
    @Published var suggestion: CorrectionResponse?
    @Published var isChecking = false
    @Published var status = "Type or paste English text. Suggestions never rewrite automatically."

    private let engine = CorrectionEngine(provider: HybridInferenceProvider())
    private var pendingCheck: Task<Void, Never>?
    private var revision = 0

    func checkNow() {
        scheduleSuggestion(delay: .zero)
    }

    func applySuggestion() {
        guard let suggestion else { return }
        let nsText = text as NSString
        let context = TextContext(text: text, selectedRange: NSRange(location: nsText.length, length: 0))
        let range = context.currentSentenceRange
        guard nsText.substring(with: range) == suggestion.original else {
            status = "Text changed. Check again to refresh the suggestion."
            return
        }
        text = nsText.replacingCharacters(in: range, with: suggestion.replacement)
        self.suggestion = nil
        status = "Suggestion applied."
    }

    private func scheduleSuggestion(delay: Duration = .milliseconds(900)) {
        revision += 1
        let currentRevision = revision
        pendingCheck?.cancel()
        suggestion = nil
        let snapshot = text
        let selectedStyle = style
        guard !snapshot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            isChecking = false
            status = "Type or paste English here. Suggestions never change your text automatically."
            return
        }
        isChecking = true
        status = "Checking the current sentence…"
        pendingCheck = Task { [weak self, engine] in
            do {
                try await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
                let nsSnapshot = snapshot as NSString
                let context = TextContext(text: snapshot, selectedRange: NSRange(location: nsSnapshot.length, length: 0))
                let result = try await engine.suggest(for: context, style: selectedStyle)
                guard !Task.isCancelled, let self, self.revision == currentRevision else { return }
                self.suggestion = result?.0
                self.isChecking = false
                self.status = result == nil ? "Looks good. Keep writing." : "Suggestion ready. Your text has not changed."
            } catch {
                guard let self, self.revision == currentRevision else { return }
                self.isChecking = false
                self.status = "Local model unavailable. Check that llama-server is installed."
            }
        }
    }
}

struct FloatingInputView: View {
    @ObservedObject var model: WritingAssistantModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("IntelliText").font(.headline)
                Spacer()
                Picker("Style", selection: $model.style) {
                    Text("Professional").tag(WritingStyle.professional)
                    Text("Daily conversation").tag(WritingStyle.casual)
                    Text("Business email").tag(WritingStyle.businessEmail)
                    Text("Academic").tag(WritingStyle.academic)
                }
                .labelsHidden()
                .frame(width: 155)
            }

            TextEditor(text: $model.text)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.75), in: RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .topLeading) {
                    if model.text.isEmpty {
                        Text("Write or paste English here…")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 14)
                            .allowsHitTesting(false)
                    }
                }

            if let suggestion = model.suggestion {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Try: \(suggestion.replacement)")
                        .font(.system(size: 13, weight: .semibold))
                        .textSelection(.enabled)
                    Text("Why: \(suggestion.shortNote)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    HStack {
                        Spacer()
                        Button("Apply suggestion") { model.applySuggestion() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding(10)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            }

            HStack(spacing: 8) {
                if model.isChecking { ProgressView().controlSize(.small) }
                Text(model.status).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                Spacer(minLength: 2)
                Button("Check") { model.checkNow() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
        .padding(14)
        .frame(minWidth: 360, minHeight: 280)
    }
}

@MainActor
private func runIntelliText() {
    let application = NSApplication.shared
    let applicationDelegate = IntelliTextAppDelegate()
    application.delegate = applicationDelegate
    application.run()
}

MainActor.assumeIsolated {
    runIntelliText()
}
