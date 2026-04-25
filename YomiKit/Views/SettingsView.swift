import SwiftUI

/// Settings panel with region selection, start/stop, auto-copy toggle, and WebSocket status.
struct SettingsView: View {

    @ObservedObject var manager: CaptureManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Region selection
            HeaderView("Region")
            HStack {
                Button("Select Region") {
                    manager.selectRegion()
                }
                if let r = manager.selectedRegion {
                    Text("\(Int(r.width)) x \(Int(r.height))")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Capture controls
            HeaderView("Capture")
            HStack(spacing: 12) {
                Button {
                    Task { await manager.start() }
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .disabled(manager.isRunning || manager.selectedRegion == nil)

                Button {
                    Task { await manager.stop() }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .disabled(!manager.isRunning)
            }

            Toggle("Auto-copy to clipboard", isOn: $manager.autoCopyToClipboard)

            Divider()

            // WebSocket
            HeaderView("WebSocket")
            HStack {
                Circle()
                    .fill(manager.webSocketServer.isRunning ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                if manager.webSocketServer.isRunning {
                    Text(":\(manager.webSocketServer.port)  \(manager.webSocketServer.clientCount) client\(manager.webSocketServer.clientCount == 1 ? "" : "s")")
                        .font(.system(.body, design: .monospaced))
                } else {
                    Text("Stopped")
                        .foregroundColor(.secondary)
                }
            }
            HStack(spacing: 12) {
                Button("Start Server") {
                    manager.webSocketServer.start()
                }
                .disabled(manager.webSocketServer.isRunning)

                Button("Stop Server") {
                    manager.webSocketServer.stop()
                }
                .disabled(!manager.webSocketServer.isRunning)
            }

            Spacer()
        }
        .padding()
        .background(MaterialView())
    }
}

/// A styled section header.
struct HeaderView: View {
    private let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.secondary)
    }
}
