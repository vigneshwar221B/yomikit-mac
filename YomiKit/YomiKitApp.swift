import SwiftUI
import SwiftData

@main
struct YomiKitApp: App {
    @FocusedObject private var manager: CaptureManager?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 480, minHeight: 400)
        }
        .modelContainer(for: AppSettings.self)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Clear Text") {
                    manager?.textBlocks.removeAll()
                }
                .keyboardShortcut("k", modifiers: .command)
                .disabled(manager?.textBlocks.isEmpty ?? true)
            }

            CommandMenu("Capture") {
                Button("Select Region") {
                    manager?.selectRegion()
                }

                Divider()

                Button("Start") {
                    Task { await manager?.start() }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(manager?.isRunning ?? false)

                Button("Stop") {
                    Task { await manager?.stop() }
                }
                .keyboardShortcut(".", modifiers: .command)
                .disabled(!(manager?.isRunning ?? false))
            }

            CommandMenu("WebSocket") {
                Button("Start Server") {
                    manager?.webSocketServer.start()
                }
                .disabled(manager?.webSocketServer.isRunning ?? false)

                Button("Stop Server") {
                    manager?.webSocketServer.stop()
                }
                .disabled(!(manager?.webSocketServer.isRunning ?? false))
            }

            // Remove Edit menu
            CommandGroup(replacing: .undoRedo) { }
            CommandGroup(replacing: .pasteboard) { }
            CommandGroup(replacing: .textEditing) { }

            // Remove View menu
            CommandGroup(replacing: .toolbar) { }
            CommandGroup(replacing: .sidebar) { }
        }
    }
}
