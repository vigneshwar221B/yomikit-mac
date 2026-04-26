import SwiftUI

/// Settings panel with region selection, start/stop, auto-copy toggle, and WebSocket status.
struct SettingsView: View {

    @ObservedObject var manager: CaptureManager
    @State private var portText = "8765"
    @State private var editingPort = false
    @FocusState private var portFocused: Bool
    @State private var showFiltersEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Region selection
            HeaderView("Region")
            if #available(macOS 26.0, *) {
                GlassSelectRegionButton(
                    hasRegion: manager.selectedRegion != nil,
                    regionSize: manager.selectedRegion.map { CGSize(width: $0.width, height: $0.height) }
                ) { manager.selectRegion() }
            } else {
                Button {
                    manager.selectRegion()
                } label: {
                    Label(
                        manager.selectedRegion != nil ? "Change Region" : "Select Region",
                        systemImage: manager.selectedRegion != nil
                            ? "rectangle.dashed.badge.record"
                            : "plus.rectangle.on.rectangle"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
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
            Toggle("Clipboard sync", isOn: $manager.autoCopyToClipboard)
                .toggleStyle(.switch)

            // Filters
            HeaderView("Content Filters")
            if #available(macOS 26.0, *) {
                GlassFiltersButton(
                    hasFilters: !manager.filters.isEmpty,
                    count: manager.filters.count
                ) { showFiltersEditor = true }
            } else {
                Button {
                    showFiltersEditor = true
                } label: {
                    Label(
                        manager.filters.isEmpty ? "Configure Filters" : "Filters Active (\(manager.filters.count))",
                        systemImage: manager.filters.isEmpty
                            ? "line.3.horizontal.decrease"
                            : "line.3.horizontal.decrease.circle.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
            }

            Divider()

            if #available(macOS 26.0, *) {
                GlassWebSocketStatus(
                    port: manager.webSocketServer.port,
                    isRunning: manager.webSocketServer.isRunning,
                    clientCount: manager.webSocketServer.clientCount
                ) { manager.webSocketServer.port = $0 }
            } else {
                HeaderView("WebSocket")
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.secondary)
                    Text("Port")
                        .foregroundColor(.secondary)
                    if editingPort && !manager.webSocketServer.isRunning {
                        TextField("Port", text: $portText, onCommit: {
                            if let p = UInt16(portText) { manager.webSocketServer.port = p }
                            editingPort = false
                        })
                        .frame(width: 70)
                        .textFieldStyle(.roundedBorder)
                        .focused($portFocused)
                        .onAppear { portFocused = true }
                        .onChange(of: portFocused) {
                            if !portFocused {
                                if let p = UInt16(portText) { manager.webSocketServer.port = p }
                                editingPort = false
                            }
                        }
                    } else {
                        Text(String(manager.webSocketServer.port))
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
                            .onTapGesture {
                                if !manager.webSocketServer.isRunning {
                                    portText = String(manager.webSocketServer.port)
                                    editingPort = true
                                }
                            }
                    }
                    Spacer()
                    if manager.webSocketServer.isRunning {
                        Circle().fill(Color(red: 0.2, green: 0.7, blue: 0.4)).frame(width: 8, height: 8)
                        Text("\(manager.webSocketServer.clientCount) client\(manager.webSocketServer.clientCount == 1 ? "" : "s")")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
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
        .sheet(isPresented: $showFiltersEditor) {
            FiltersEditorView(filters: $manager.filters)
        }
        .onTapGesture {
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
    }

}

// MARK: - macOS 26 Glass helpers

@available(macOS 26.0, *)
private struct GlassSelectRegionButton: View {
    let hasRegion: Bool
    let regionSize: CGSize?
    let action: () -> Void

    var body: some View {
        GlassEffectContainer {
            Button { action() } label: {
                HStack {
                    Label(
                        hasRegion ? "Change Region" : "Select Region",
                        systemImage: hasRegion
                            ? "rectangle.dashed.badge.record"
                            : "plus.rectangle.on.rectangle"
                    )
                    Spacer()
                    if let size = regionSize {
                        Text("\(Int(size.width))×\(Int(size.height))")
                            .font(.system(.caption2, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.white.opacity(0.25), in: .capsule)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.glass)
            .tint(hasRegion ? .accentColor : nil)
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
private struct GlassFiltersButton: View {
    let hasFilters: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        GlassEffectContainer {
            Button { action() } label: {
                HStack {
                    Label(
                        hasFilters ? "Filters Active" : "Configure Filters",
                        systemImage: hasFilters
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease"
                    )
                    Spacer()
                    if hasFilters {
                        Text("\(count)")
                            .font(.system(.caption2, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.white.opacity(0.25), in: .capsule)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
            }
            .buttonStyle(.glass)
            .tint(hasFilters ? .accentColor : nil)
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
private struct GlassWebSocketStatus: View {
    let port: UInt16
    let isRunning: Bool
    let clientCount: Int
    let onPortChange: (UInt16) -> Void

    @State private var editing = false
    @State private var portText = ""
    @State private var hoveringEdit = false
    @State private var hoveringCopy = false
    @State private var copied = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("WebSocket")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Spacer()

                if !editing {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("ws://localhost:\(port)", forType: .string)
                        copied = true
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            copied = false
                        }
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(.body))
                            .foregroundStyle(copied ? Color(red: 0.2, green: 0.7, blue: 0.4) : (hoveringCopy ? .primary : .secondary))
                            .scaleEffect(hoveringCopy ? 1.15 : 1.0)
                            .animation(.easeInOut(duration: 0.15), value: hoveringCopy)
                    }
                    .buttonStyle(.plain)
                    .help("Copy URL")
                    .onHover { hoveringCopy = $0 }

                    if !isRunning {
                        Button {
                            portText = String(port)
                            editing = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(.body))
                                .foregroundStyle(hoveringEdit ? .primary : .secondary)
                                .scaleEffect(hoveringEdit ? 1.15 : 1.0)
                                .animation(.easeInOut(duration: 0.15), value: hoveringEdit)
                        }
                        .buttonStyle(.plain)
                        .help("Edit port")
                        .onHover { hoveringEdit = $0 }
                    }
                }
            }

            GlassEffectContainer {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundStyle(isRunning ? Color(red: 0.2, green: 0.7, blue: 0.4) : .secondary)

                        if editing {
                            Text("Port")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                            TextField("", text: $portText)
                                .frame(width: 55)
                                .textFieldStyle(.plain)
                                .font(.system(.body, design: .monospaced))
                                .focused($focused)
                                .onAppear { focused = true }
                                .onSubmit { commit() }
                                .onChange(of: portText) { portText = portText.filter(\.isNumber) }
                                .onChange(of: focused) { if !focused { commit() } }
                                .onExitCommand { editing = false }
                        } else {
                            Text("ws://localhost:\(String(port))")
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                        }
                    }

                    if isRunning {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color(red: 0.2, green: 0.7, blue: 0.4))
                                .frame(width: 6, height: 6)
                            Text("\(clientCount) client\(clientCount == 1 ? "" : "s") connected")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
    }

    private func commit() {
        if let p = UInt16(portText) { onPortChange(p) }
        editing = false
    }
}

// MARK: - Filters editor

struct FiltersEditorView: View {
    @Binding var filters: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filters")
                .font(.headline)
            Text("One filter per line. Supports regex.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 340, minHeight: 200)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                Button("Save") {
                    filters = text
                        .components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .onAppear {
            text = filters.joined(separator: "\n")
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
