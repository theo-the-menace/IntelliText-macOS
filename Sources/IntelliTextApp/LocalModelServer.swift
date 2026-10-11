import Foundation

@MainActor
final class LocalModelServer {
    private var process: Process?
    private let port = 11439
    private var healthURL: URL { URL(string: "http://127.0.0.1:\(port)/health")! }

    func startIfNeeded() {
        guard process == nil, !isHealthy else { return }
        let executable = ["/opt/homebrew/bin/llama-server", "/usr/local/bin/llama-server"].first {
            FileManager.default.isExecutableFile(atPath: $0)
        }
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let modelPath = projectRoot.appendingPathComponent("Models/Qwen3-8B-Q4_K_M.gguf").path
        guard let executable, FileManager.default.fileExists(atPath: modelPath) else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["--model", modelPath, "--host", "127.0.0.1", "--port", "\(port)", "--ctx-size", "4096", "--n-gpu-layers", "99", "--no-webui"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            self.process = process
        } catch {
            NSLog("IntelliText: could not start local model server: %@", error.localizedDescription)
        }
    }

    func stop() {
        guard let process, process.isRunning else { return }
        process.terminate()
        self.process = nil
    }

    private var isHealthy: Bool {
        guard let response = try? Data(contentsOf: healthURL),
              let object = try? JSONSerialization.jsonObject(with: response) as? [String: String] else { return false }
        return object["status"] == "ok"
    }
}
