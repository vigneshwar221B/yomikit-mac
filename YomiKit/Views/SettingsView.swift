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
            if #available(macOS 26.0, *) {
                GlassSelectRegionButton { manager.selectRegion() }
            } else {
                Button {
                    manager.selectRegion()
                } label: {
                    Label("Select Region", systemImage: "plus.rectangle.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
            }
            if let r = manager.selectedRegion {
                Text("\(Int(r.width)) x \(Int(r.height))")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            if #available(macOS 26.0, *) {
                GlassQuickScanButton(isScanning: manager.isScanning) {
                    Task { await manager.quickScan() }
                }
            } else {
                Button {
                    Task { await manager.quickScan() }
                } label: {
                    Label(manager.isScanning ? "Scanning…" : "Quick Scan",
                          systemImage: manager.isScanning ? "rays" : "viewfinder")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .disabled(manager.isScanning)
            }

            Divider()

            // Settings
            Toggle("Auto-copy to clipboard", isOn: $manager.autoCopyToClipboard)
                .toggleStyle(.switch)

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
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .modifier(PortBadgeStyle())
                        .onTapGesture {
                            if !manager.webSocketServer.isRunning {
                                portText = String(manager.webSocketServer.port)
                                editingPort = true
                            }
                        }
                }
            }
            if manager.webSocketServer.isRunning {
                HStack {
                    Circle()
                        .fill(Color(red: 0.2, green: 0.7, blue: 0.4))
                        .frame(width: 8, height: 8)
                    Text(":\(String(manager.webSocketServer.port))  \(String(manager.webSocketServer.clientCount)) client\(manager.webSocketServer.clientCount == 1 ? "" : "s")")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if #available(macOS 26.0, *) {
                GlassActionButtons(
                    isRunning: manager.isRunning,
                    wsRunning: manager.webSocketServer.isRunning,
                    onCaptureToggle: {
                        Task {
                            if manager.isRunning { await manager.stop() } else { await manager.start() }
                        }
                    },
                    onWSToggle: {
                        if manager.webSocketServer.isRunning { manager.webSocketServer.stop() } else { manager.webSocketServer.start() }
                    }
                )
            } else {
                Button {
                    Task {
                        if manager.isRunning { await manager.stop() } else { await manager.start() }
                    }
                } label: {
                    Label(manager.isRunning ? "Stop Capture" : "Start Capture",
                          systemImage: manager.isRunning ? "stop.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(manager.isRunning ? .red : Color(red: 0.2, green: 0.7, blue: 0.4))

                Button {
                    if manager.webSocketServer.isRunning { manager.webSocketServer.stop() } else { manager.webSocketServer.start() }
                } label: {
                    Label(manager.webSocketServer.isRunning ? "Stop Server" : "Start Server",
                          systemImage: manager.webSocketServer.isRunning ? "xmark.circle.fill" : "antenna.radiowaves.left.and.right")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(manager.webSocketServer.isRunning ? .red : Color(red: 0.2, green: 0.7, blue: 0.4))
            }
        }
        .padding()
        .background(MaterialView())
        .onTapGesture {
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
    }
}

// MARK: - macOS 26 Glass helpers

@available(macOS 26.0, *)
private struct GlassSelectRegionButton: View {
    let action: () -> Void
    var body: some View {
        GlassEffectContainer {
            Button { action() } label: {
                Label("Select Region", systemImage: "plus.rectangle.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glass)
        }
    }
}

@available(macOS 26.0, *)
private struct GlassQuickScanButton: View {
    let isScanning: Bool
    let action: () -> Void
    var body: some View {
        GlassEffectContainer {
            Button { action() } label: {
                Label(isScanning ? "Scanning…" : "Quick Scan",
                      systemImage: isScanning ? "rays" : "viewfinder")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glass)
            .disabled(isScanning)
        }
    }
}

@available(macOS 26.0, *)
private struct GlassActionButtons: View {
    let isRunning: Bool
    let wsRunning: Bool
    let onCaptureToggle: () -> Void
    let onWSToggle: () -> Void

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 8) {
                Button { onCaptureToggle() } label: {
                    Label(isRunning ? "Stop Capture" : "Start Capture",
                          systemImage: isRunning ? "stop.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.glassProminent)
                .tint(isRunning ? .red : Color(red: 0.2, green: 0.7, blue: 0.4))

                Button { onWSToggle() } label: {
                    Label(wsRunning ? "Stop Server" : "Start Server",
                          systemImage: wsRunning ? "xmark.circle.fill" : "antenna.radiowaves.left.and.right")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.glassProminent)
                .tint(wsRunning ? .red : Color(red: 0.2, green: 0.7, blue: 0.4))
            }
        }
    }
}

@available(macOS 26.0, *)
private struct GlassPortBadgeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.glassEffect(in: .rect(cornerRadius: 6))
    }
}

private struct PortBadgeStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.modifier(GlassPortBadgeModifier())
        } else {
            content.background(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
        }
    }
}

// MARK: - Section header

struct HeaderView: View {
    private let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.secondary)
    }
}
