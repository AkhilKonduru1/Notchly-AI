import SwiftUI
import AppKit

struct OllamaSetupView: View {
    @Binding var isPresented: Bool
    @State private var setupStep: SetupStep = .checkingOllama
    @State private var availableModels: [String] = []
    @State private var isOllamaInstalled = false
    @State private var isOllamaRunning = false
    @State private var isDownloadingModel = false
    @State private var downloadProgress = 0.0
    @State private var errorMessage: String?

    enum SetupStep {
        case checkingOllama
        case installOllama
        case startOllama
        case checkModels
        case downloadModel
        case complete
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Setting up Ollama")
                .font(.title)
                .fontWeight(.bold)

            switch setupStep {
            case .checkingOllama:
                checkingOllamaView
            case .installOllama:
                installOllamaView
            case .startOllama:
                startOllamaView
            case .checkModels:
                checkModelsView
            case .downloadModel:
                downloadModelView
            case .complete:
                completeView
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(width: 400, height: 300)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .onAppear {
            checkOllamaStatus()
        }
    }

    private var checkingOllamaView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Checking if Ollama is installed and running...")
                .multilineTextAlignment(.center)
        }
    }

    private var installOllamaView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            Text("Ollama is not installed")
                .font(.headline)
            Text("Ollama is required to run AI models locally on your Mac.")
                .multilineTextAlignment(.center)
            Button("Download Ollama") {
                openOllamaDownloadPage()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var startOllamaView: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.circle")
                .font(.system(size: 48))
                .foregroundColor(.green)
            Text("Ollama is installed but not running")
                .font(.headline)
            Text("Please start Ollama by opening Terminal and running:")
                .multilineTextAlignment(.center)
            Text("ollama serve")
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            Button("Open Terminal") {
                openTerminal()
            }
            .buttonStyle(.bordered)
            Button("Check Again") {
                checkOllamaStatus()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var checkModelsView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Checking available models...")
                .multilineTextAlignment(.center)
        }
    }

    private var downloadModelView: some View {
        VStack(spacing: 16) {
            if isDownloadingModel {
                ProgressView(value: downloadProgress)
                    .scaleEffect(1.5)
                Text("Downloading llama2 model...")
                    .multilineTextAlignment(.center)
                Text("\(Int(downloadProgress * 100))%")
                    .font(.caption)
            } else {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                Text("No suitable models found")
                    .font(.headline)
                Text("We'll download the lightweight llama2 model for you.")
                    .multilineTextAlignment(.center)
                Button("Download Model") {
                    downloadRecommendedModel()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var completeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.green)
            Text("Setup Complete!")
                .font(.headline)
            Text("Ollama is ready to use. You can now chat with AI models locally on your Mac.")
                .multilineTextAlignment(.center)
            Button("Start Chatting") {
                NotificationCenter.default.post(name: NSNotification.Name("OllamaSetupCompleted"), object: nil)
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func checkOllamaStatus() {
        setupStep = .checkingOllama
        errorMessage = nil

        Task {
            // Check if Ollama is installed
            let isInstalled = await checkOllamaInstalled()
            await MainActor.run {
                isOllamaInstalled = isInstalled
            }

            if !isInstalled {
                await MainActor.run {
                    setupStep = .installOllama
                }
                return
            }

            // Check if Ollama is running
            let isRunning = await checkOllamaRunning()
            await MainActor.run {
                isOllamaRunning = isRunning
            }

            if !isRunning {
                await MainActor.run {
                    setupStep = .startOllama
                }
                return
            }

            // Check available models
            await MainActor.run {
                setupStep = .checkModels
            }
            let models = await getAvailableModels()
            await MainActor.run {
                availableModels = models
            }

            // Check if we have a suitable model
            let hasSuitableModel = models.contains { model in
                model.contains("llama2") || model.contains("llama3") || model.contains("mistral")
            }

            if hasSuitableModel {
                await MainActor.run {
                    setupStep = .complete
                }
            } else {
                await MainActor.run {
                    setupStep = .downloadModel
                }
            }
        }
    }

    private func checkOllamaInstalled() async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ollama"]

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func checkOllamaRunning() async -> Bool {
        guard let url = URL(string: "http://localhost:11434/api/tags") else { return false }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    private func getAvailableModels() async -> [String] {
        guard let url = URL(string: "http://localhost:11434/api/tags") else { return [] }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                return models.compactMap { $0["name"] as? String }
            }
        } catch {
            print("Error fetching models: \(error)")
        }
        return []
    }

    private func openOllamaDownloadPage() {
        if let url = URL(string: "https://ollama.ai/download") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openTerminal() {
        let script = "tell application \"Terminal\" to activate"
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(nil)
        }
    }

    private func downloadRecommendedModel() {
        isDownloadingModel = true
        downloadProgress = 0.0

        Task {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["ollama", "pull", "llama2"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()

                // Monitor progress (simplified - Ollama doesn't provide detailed progress)
                for i in 0...100 {
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    await MainActor.run {
                        downloadProgress = Double(i) / 100.0
                    }
                    if process.isRunning == false {
                        break
                    }
                }

                process.waitUntilExit()

                await MainActor.run {
                    isDownloadingModel = false
                    if process.terminationStatus == 0 {
                        setupStep = .complete
                    } else {
                        errorMessage = "Failed to download model. Please try again."
                    }
                }
            } catch {
                await MainActor.run {
                    isDownloadingModel = false
                    errorMessage = "Error downloading model: \(error.localizedDescription)"
                }
            }
        }
    }
}
