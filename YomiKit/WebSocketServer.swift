import Foundation
import Network
import OSLog

/// A WebSocket server using Network.framework (NWListener).
/// Broadcasts UTF-8 text messages to all connected clients.
@MainActor
final class WebSocketServer: ObservableObject {

    @Published private(set) var isRunning = false
    @Published private(set) var clientCount = 0
    @Published var port: UInt16 = 8765

    private let logger = Logger()
    private var listener: NWListener?
    private var connections = [NWConnection]()

    func start() {
        stop()

        let wsOptions = NWProtocolWebSocket.Options()
        wsOptions.autoReplyPing = true

        let params = NWParameters(tls: nil)
        params.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

        do {
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            logger.error("Failed to create NWListener: \(error.localizedDescription)")
            return
        }

        listener?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                switch state {
                case .ready:
                    self.isRunning = true
                    self.logger.info("WebSocket server listening on port \(self.port)")
                case .failed(let error):
                    self.logger.error("Listener failed: \(error.localizedDescription)")
                    self.isRunning = false
                case .cancelled:
                    self.isRunning = false
                default:
                    break
                }
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in
                self?.handleNewConnection(connection)
            }
        }

        listener?.start(queue: .main)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        for conn in connections {
            conn.cancel()
        }
        connections.removeAll()
        isRunning = false
        clientCount = 0
    }

    /// Broadcasts a UTF-8 text message to all connected WebSocket clients.
    func broadcast(_ text: String) {
        guard !connections.isEmpty else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "textMessage",
                                                   metadata: [metadata])
        let data = Data(text.utf8)
        for conn in connections {
            conn.send(content: data, contentContext: context, isComplete: true,
                      completion: .contentProcessed { error in
                if let error {
                    Logger().error("Send error: \(error.localizedDescription)")
                }
            })
        }
    }

    // MARK: - Private

    private func handleNewConnection(_ connection: NWConnection) {
        connections.append(connection)
        clientCount = connections.count

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                switch state {
                case .cancelled, .failed:
                    self.connections.removeAll { $0 === connection }
                    self.clientCount = self.connections.count
                default:
                    break
                }
            }
        }

        // Start receiving (keeps connection alive and processes control frames).
        receiveLoop(connection)
        connection.start(queue: .main)
    }

    private nonisolated func receiveLoop(_ connection: NWConnection) {
        connection.receiveMessage { [weak self] _, _, _, error in
            if let error {
                Logger().error("Receive error: \(error.localizedDescription)")
                connection.cancel()
                return
            }
            // Continue receiving.
            self?.receiveLoop(connection)
        }
    }
}
