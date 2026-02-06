import SwiftUI
import AppKit

struct OllamaSetupView: View {
    @Binding var isPresented: Bool
    @State private var apiKey: String = ""
    @State private var isVerifying = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    var body: some View {
        VStack(spacing: 20) {
            if showSuccess {
                successView
            } else {
                apiKeyEntryView
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(width: 450, height: 300)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }

    private var apiKeyEntryView: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text("Enter Your Groq API Key")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Get your free API key from console.groq.com")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            SecureField("gsk_...", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 20)
            
            HStack(spacing: 12) {
                Button("Get API Key") {
                    openGroqConsole()
                }
                .buttonStyle(.bordered)
                
                Button(isVerifying ? "Verifying..." : "Save & Continue") {
                    saveApiKey()
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.isEmpty || isVerifying)
            }
        }
    }

    private var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("Setup Complete!")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Your Groq API key has been saved. You can now start chatting!")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button("Start Chatting") {
                NotificationCenter.default.post(name: NSNotification.Name("GroqApiKeySetupCompleted"), object: nil)
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func openGroqConsole() {
        if let url = URL(string: "https://console.groq.com/keys") {
            NSWorkspace.shared.open(url)
        }
    }

    private func saveApiKey() {
        errorMessage = nil
        isVerifying = true
        
        Task {
            let isValid = await verifyApiKey(apiKey)
            
            await MainActor.run {
                isVerifying = false
                
                if isValid {
                    UserDefaults.standard.set(apiKey, forKey: "groqApiKey")
                    withAnimation {
                        showSuccess = true
                    }
                } else {
                    errorMessage = "Invalid API key. Please check and try again."
                }
            }
        }
    }

    private func verifyApiKey(_ key: String) async -> Bool {
        guard let url = URL(string: "https://api.groq.com/openai/v1/models") else { return false }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
