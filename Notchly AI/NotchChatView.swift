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
        // Check if Groq API key is set
        if needsGroqApiKeySetup() {
            showGroqApiKeySetup()
        } else {
            showMainWindow()
        }
    }

    private func needsGroqApiKeySetup() -> Bool {
        guard let apiKey = UserDefaults.standard.string(forKey: "groqApiKey") else { return true }
        return apiKey.isEmpty
    }

    private func showGroqApiKeySetup() {
        let setupView = OllamaSetupView(isPresented: .constant(true))
        let hostingController = NSHostingController(rootView: setupView)

        setupWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 300),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        setupWindow?.center()
        setupWindow?.contentView = hostingController.view
        setupWindow?.title = "Groq API Key Setup"
        setupWindow?.isReleasedWhenClosed = false
        setupWindow?.level = .floating
        setupWindow?.makeKeyAndOrderFront(nil)

        // Observe when setup is complete
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(setupCompleted),
            name: NSNotification.Name("GroqApiKeySetupCompleted"),
            object: nil
        )
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
            name: NSNotification.Name("GroqApiKeySetupCompleted"),
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
        // No need to set a boolean, just rely on API key presence

        // Close setup window and show main window
        setupWindow?.close()
        setupWindow = nil

        showMainWindow()

        // Remove observer
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("GroqApiKeySetupCompleted"), object: nil)
    }
}
