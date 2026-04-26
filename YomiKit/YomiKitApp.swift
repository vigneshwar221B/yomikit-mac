import SwiftUI
import SwiftData

@main
struct YomiKitApp: App {
    @FocusedObject private var manager: CaptureManager?
    @AppStorage("showStatusBar") private var showStatusBar = true

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 480, minHeight: 400)
        }
        .modelContainer(for: [AppSettings.self, TextBlockRecord.self])
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Clear Text") {
                    manager?.clearTextBlocks()
                }
                .keyboardShortcut("k", modifiers: .command)
                .disabled(manager?.textBlocks.isEmpty ?? true)
            }

            CommandMenu("Capture") {
                Button("Select Region") {
                    manager?.selectRegion()
                }

                Divider()

                Button("Quick Scan") {
                    Task { await manager?.quickScan() }
                }
                .keyboardShortcut("g", modifiers: .command)
                .disabled(manager?.isScanning ?? false)

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


            // View menu — just the status bar toggle
            CommandGroup(replacing: .toolbar) {
                Toggle("Status Bar", isOn: $showStatusBar)
                    .keyboardShortcut("/", modifiers: .command)
            }
            CommandGroup(replacing: .sidebar) { }
        }
    }
}
