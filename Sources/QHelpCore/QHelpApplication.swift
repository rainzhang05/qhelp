import AppKit

public enum QHelpApplication {

    public static func run(with arguments: [String]) {
        let config = CLIParser.parse(arguments)

        guard let provider = ProviderRegistry.resolve(modelName: config.modelName) else {
            print("Error: Cannot route model '\(config.modelName)' to a provider.")
            print("\nUse an exact API model name with a recognized prefix:\n")
            print(ProviderCatalog.routingHelp)
            exit(1)
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let overlayManager = OverlayManager()
        let requestQueue = RequestQueue(provider: provider, overlayManager: overlayManager)
        let clipboardMonitor = ClipboardMonitor(queue: requestQueue)

        func shutdown() {
            print("\n\nShutting down...")
            clipboardMonitor.stop()
            Task {
                await requestQueue.cancelAll()
                await MainActor.run {
                    NSApp.terminate(nil)
                }
            }
        }

        let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        signal(SIGINT, SIG_IGN)
        sigintSource.setEventHandler { shutdown() }
        sigintSource.resume()

        let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        signal(SIGTERM, SIG_IGN)
        sigtermSource.setEventHandler { shutdown() }
        sigtermSource.resume()

        print("qhelp\n")
        print("Provider: \(provider.providerName)")
        print("Model: \(provider.displayName)\n")
        print("Watching clipboard...\n")
        print("Press Ctrl+C to quit.")

        clipboardMonitor.start()
        app.run()
    }
}
