import Foundation
@preconcurrency import ScreenCaptureKit
import Combine
import OSLog
import SwiftUI
import AppKit

/// The main coordinator for YomiKit.
/// Manages region selection, screen capture, OCR, clipboard output, and WebSocket broadcast.
@MainActor
class CaptureManager: ObservableObject {

    private let logger = Logger()

    // MARK: - Published State

    @Published var isRunning = false
    @Published var recognizedText = ""
    @Published var statusMessage = "Idle"
    @Published var autoCopyToClipboard = true

    /// The selected capture region in NSScreen coordinates (bottom-left origin).
    @Published var selectedRegion: CGRect?

    // MARK: - Sub-components

    let webSocketServer = WebSocketServer()
    private let textRecognizer = TextRecognizer()
    private let captureEngine = CaptureEngine()

    // MARK: - Private State

    private var availableDisplays = [SCDisplay]()
    private var availableApps = [SCRunningApplication]()
    private var lastRecognizedText = ""
    private var captureTask: Task<Void, Never>?

    // MARK: - Permission

    var canRecord: Bool {
        get async {
            do {
                try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                return true
            } catch {
                return false
            }
        }
    }

    // MARK: - Region Selection

    /// Shows a fullscreen transparent overlay for the user to drag-select a region.
    func selectRegion() {
        guard let screen = NSScreen.main else { return }

        let overlay = OverlayWindow(screen: screen)
        let selectorView = RegionSelectorNSView()

        selectorView.onRegionSelected = { [weak self] rect in
            Task { @MainActor in
                self?.selectedRegion = rect
                overlay.close()
            }
        }
        selectorView.onCancelled = {
            overlay.close()
        }

        overlay.contentView = selectorView
        overlay.makeKeyAndOrderFront(nil)
        overlay.makeFirstResponder(selectorView)
    }

    // MARK: - Start / Stop

    func start() async {
        guard !isRunning else { return }
        guard let region = selectedRegion else {
            statusMessage = "Select a region first"
            return
        }
        guard let screen = NSScreen.main else { return }

        // Refresh available content.
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            availableDisplays = content.displays
            availableApps = content.applications
        } catch {
            logger.error("Failed to get shareable content: \(error.localizedDescription)")
            statusMessage = "Error: \(error.localizedDescription)"
            return
        }

        guard let display = availableDisplays.first else {
            statusMessage = "No display found"
            return
        }

        // Convert NSScreen coords (bottom-left origin) to SCK coords (top-left origin).
        let displayHeight = CGFloat(display.height)
        let sckRect = CGRect(x: region.origin.x,
                             y: displayHeight - region.origin.y - region.height,
                             width: region.width,
                             height: region.height)

        // Exclude our own app from the capture.
        let excludedApps = availableApps.filter { app in
            Bundle.main.bundleIdentifier == app.bundleIdentifier
        }

        let filter = SCContentFilter(display: display,
                                      excludingApplications: excludedApps,
                                      exceptingWindows: [])

        let scaleFactor = Int(screen.backingScaleFactor)
        let config = SCStreamConfiguration()
        config.width = Int(region.width) * scaleFactor
        config.height = Int(region.height) * scaleFactor
        config.minimumFrameInterval = CMTime(value: 1, timescale: 2) // 2 FPS
        config.queueDepth = 3
        config.showsCursor = false
        config.capturesAudio = false
        config.sourceRect = sckRect
        config.destinationRect = CGRect(origin: .zero,
                                         size: CGSize(width: Int(region.width) * scaleFactor,
                                                      height: Int(region.height) * scaleFactor))

        isRunning = true
        statusMessage = "Capturing..."
        lastRecognizedText = ""

        captureTask = Task {
            do {
                for try await frame in captureEngine.startCapture(configuration: config, filter: filter) {
                    await processFrame(frame)
                }
            } catch {
                logger.error("Capture error: \(error.localizedDescription)")
            }
            isRunning = false
            statusMessage = "Stopped"
        }
    }

    func stop() async {
        guard isRunning else { return }
        captureTask?.cancel()
        captureTask = nil
        await captureEngine.stopCapture()
        isRunning = false
        statusMessage = "Stopped"
    }

    // MARK: - Frame Processing

    private func processFrame(_ frame: CapturedFrame) async {
        guard let surface = frame.surface else { return }

        // Convert IOSurface → CGImage safely.
        guard let cgImage = await textRecognizer.cgImage(from: surface) else { return }

        // Run OCR.
        do {
            let text = try await textRecognizer.recognize(image: cgImage)
            guard !text.isEmpty, text != lastRecognizedText else { return }

            lastRecognizedText = text
            recognizedText = text

            // Auto-copy to clipboard.
            if autoCopyToClipboard {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }

            // Broadcast via WebSocket.
            if webSocketServer.isRunning {
                webSocketServer.broadcast(text)
            }
        } catch {
            logger.error("OCR error: \(error.localizedDescription)")
        }
    }
}
