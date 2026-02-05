import SwiftUI
import AppKit

@main
struct NotchChatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView() // No main window here
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var hoverWindow: HoverWindow!
    var setupWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check if this is first launch or Ollama needs setup
        if needsOllamaSetup() {
            showOllamaSetup()
        } else {
            showMainWindow()
        }
    }

    private func needsOllamaSetup() -> Bool {
        // Check if we've completed setup before
        let hasCompletedSetup = UserDefaults.standard.bool(forKey: "ollamaSetupCompleted")
        if hasCompletedSetup {
            return false
        }

        // Quick check if Ollama is running and has models
        return !isOllamaReady()
    }

    private func isOllamaReady() -> Bool {
        // Synchronous check - if this fails, we need setup
        guard let url = URL(string: "http://localhost:11434/api/tags") else { return false }

        var request = URLRequest(url: url)
        request.timeoutInterval = 2

        let semaphore = DispatchSemaphore(value: 0)
        var isReady = false

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]],
               !models.isEmpty {
                isReady = true
            }
            semaphore.signal()
        }.resume()

        semaphore.wait()
        return isReady
    }

    private func showOllamaSetup() {
        let setupView = OllamaSetupView(isPresented: .constant(true))
        let hostingController = NSHostingController(rootView: setupView)

        setupWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        setupWindow?.center()
        setupWindow?.contentView = hostingController.view
        setupWindow?.title = "Ollama Setup"
        setupWindow?.isReleasedWhenClosed = false
        setupWindow?.level = .floating
        setupWindow?.makeKeyAndOrderFront(nil)

        // Observe when setup is complete
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(setupCompleted),
            name: NSNotification.Name("OllamaSetupCompleted"),
            object: nil
        )
    }

    private func showMainWindow() {
        hoverWindow = HoverWindow()
        hoverWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func setupCompleted() {
        // Mark setup as completed
        UserDefaults.standard.set(true, forKey: "ollamaSetupCompleted")

        // Close setup window and show main window
        setupWindow?.close()
        setupWindow = nil

        showMainWindow()

        // Remove observer
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("OllamaSetupCompleted"), object: nil)
    }
}
