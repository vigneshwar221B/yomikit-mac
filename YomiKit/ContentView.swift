import SwiftUI
import SwiftData

struct ContentView: View {

    @StateObject private var manager = CaptureManager()
    @AppStorage("showStatusBar") private var showStatusBar = true
    @AppStorage("showSidebar") private var showSidebar = true
    @Environment(\.modelContext) private var modelContext
    @Query private var savedSettings: [AppSettings]

    private var settings: AppSettings {
        if let existing = savedSettings.first { return existing }
        let new = AppSettings()
        modelContext.insert(new)
        return new
    }

    var body: some View {
        VStack(spacing: 0) {
            if showStatusBar {
                statusBar
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor))

                Divider()
            }

            // Main content: settings on left, text display on right
            HStack(spacing: 0) {
                if showSidebar {
                    SettingsView(manager: manager)
                        .frame(width: 240)
                        .transition(.move(edge: .leading))

                    Divider()
                }

                textDisplay
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .animation(.easeInOut(duration: 0.2), value: showSidebar)
        }
        .focusedObject(manager)
        .navigationTitle("YomiKit")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSidebar.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                }
            }
        }
        .onAppear {
            manager.loadSettings(settings)
        }
        .onChange(of: manager.selectedRegion) {
            manager.saveSettings(to: settings)
        }
        .onChange(of: manager.autoCopyToClipboard) {
            manager.saveSettings(to: settings)
        }
        .onChange(of: manager.webSocketServer.port) {
            manager.saveSettings(to: settings)
        }
        .onChange(of: manager.webSocketServer.isRunning) {
            manager.saveSettings(to: settings)
        }
    }

    // MARK: - Sub-views

    private var statusBar: some View {
        HStack {
            Circle()
                .fill(manager.isRunning ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            Text(manager.statusMessage)
                .font(.system(.body, design: .monospaced))

            Spacer()

            if manager.webSocketServer.isRunning {
                Text("WS :\(String(manager.webSocketServer.port))  \(String(manager.webSocketServer.clientCount)) client\(manager.webSocketServer.clientCount == 1 ? "" : "s")")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var textDisplay: some View {
        VStack(spacing: 0) {
            HStack {
                CapturePreviewView(region: manager.selectedRegion)
                Spacer()
                if !manager.textBlocks.isEmpty {
                    Button("Clear") {
                        manager.textBlocks.removeAll()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 12)
                }
            }
            .padding(.top, 6)

            Divider()
                .padding(.vertical, 4)

            ScrollViewReader { proxy in
                ScrollView {
                    if manager.textBlocks.isEmpty {
                        Text("Recognized text will appear here...")
                            .font(.system(.body))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(12)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(manager.textBlocks) { block in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(block.timestamp, format: .dateTime.hour().minute().second())
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundColor(.secondary)
                                    Text(block.text)
                                        .font(.system(.body))
                                        .textSelection(.enabled)
                                        .contextMenu {
                                            Button {
                                                NSPasteboard.general.clearContents()
                                                NSPasteboard.general.setString(block.text, forType: .string)
                                            } label: {
                                                Label("Copy", systemImage: "doc.on.doc")
                                            }
                                        }
                                }
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                                .id(block.id)
                                .contextMenu {
                                    Button {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(block.text, forType: .string)
                                    } label: {
                                        Label("Copy", systemImage: "doc.on.doc")
                                    }
                                }

                                Divider()
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: manager.textBlocks.count) {
                    if let last = manager.textBlocks.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}
