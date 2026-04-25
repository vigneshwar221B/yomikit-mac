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

            ScrollView {
                Text(manager.recognizedText.isEmpty ? "Recognized text will appear here..." : manager.recognizedText)
                    .font(.system(.body))
                    .foregroundColor(manager.recognizedText.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
