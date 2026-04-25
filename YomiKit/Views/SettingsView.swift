import SwiftUI

/// Settings panel with region selection, start/stop, auto-copy toggle, and WebSocket status.
struct SettingsView: View {

    @ObservedObject var manager: CaptureManager
    @State private var portText = "8765"
    @State private var editingPort = false
    @FocusState private var portFocused: Bool

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
                .disabled(manager.isRunning)

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
                Text("Port")
                    .foregroundColor(.secondary)
                if editingPort && !manager.webSocketServer.isRunning {
                    TextField("Port", text: $portText, onCommit: {
                        if let p = UInt16(portText) {
                            manager.webSocketServer.port = p
                        }
                        editingPort = false
                    })
                    .frame(width: 70)
                    .textFieldStyle(.roundedBorder)
                    .focused($portFocused)
                    .onAppear { portFocused = true }
                    .onChange(of: portFocused) {
                        if !portFocused {
                            if let p = UInt16(portText) {
                                manager.webSocketServer.port = p
                            }
                            editingPort = false
                        }
                    }
                } else {
                    Text(String(manager.webSocketServer.port))
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
                        .onTapGesture {
                            if !manager.webSocketServer.isRunning {
                                portText = String(manager.webSocketServer.port)
                                editingPort = true
                            }
                        }
                }
            }
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
        .onTapGesture {
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
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
