import SwiftUI

struct ContentView: View { 

    @StateObject private var manager = CaptureManager()
    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            statusBar
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Main content: settings on left, text display on right
            HSplitView {
                SettingsView(manager: manager)
                    .frame(minWidth: 220, idealWidth: 240, maxWidth: 280)

                // Recognized text area
                textDisplay
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("YomiKit")
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
                Text("WS :\(manager.webSocketServer.port)  \(manager.webSocketServer.clientCount) client\(manager.webSocketServer.clientCount == 1 ? "" : "s")")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var textDisplay: some View {
        VStack(spacing: 0) {
            CapturePreviewView(region: manager.selectedRegion)
                .frame(maxWidth: .infinity, alignment: .leading)
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
                                }
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .id(block.id)

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
