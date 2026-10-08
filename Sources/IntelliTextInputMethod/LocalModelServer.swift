import Foundation

final class LocalModelServer {
    private var process: Process?

    func startIfNeeded() {
        guard !isHealthy(), process?.isRunning != true else { return }
        let sourceURL = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let configuredPath = ProcessInfo.processInfo.environment["INTELLITEXT_MODEL_PATH"]
        let model = configuredPath.map(URL.init(fileURLWithPath:))
            ?? projectRoot.appendingPathComponent("Models/Qwen3-8B-Q4_K_M.gguf")
        guard FileManager.default.fileExists(atPath: model.path),
              let executable = ["/opt/homebrew/bin/llama-server", "/usr/local/bin/llama-server"].first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { return }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = ["--model", model.path, "--host", "127.0.0.1", "--port", "11439", "--ctx-size", "4096", "--n-gpu-layers", "99", "--no-webui", "--log-disable"]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            process = task
            DispatchQueue.global(qos: .utility).async { [weak self, weak task] in
                for _ in 0..<120 {
                    if self?.isHealthy() == true || task?.isRunning == false { return }
                    Thread.sleep(forTimeInterval: 0.5)
                }
            }
        } catch {
            process = nil
        }
    }

    func stop() {
        guard let process, process.isRunning else { return }
        process.terminate()
        self.process = nil
    }

    private func isHealthy() -> Bool {
        guard let url = URL(string: "http://127.0.0.1:11439/health") else { return false }
        let semaphore = DispatchSemaphore(value: 0)
        var healthy = false
        URLSession.shared.dataTask(with: url) { _, response, _ in
            healthy = (response as? HTTPURLResponse)?.statusCode == 200
            semaphore.signal()
        }.resume()
        _ = semaphore.wait(timeout: .now() + 0.4)
        return healthy
    }
}
