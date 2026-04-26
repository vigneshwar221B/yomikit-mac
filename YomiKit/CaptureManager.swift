import Foundation
@preconcurrency import ScreenCaptureKit
import Combine
import OSLog
import SwiftUI
import AppKit
import SwiftData

struct TextBlock: Identifiable {
    let id: UUID
    let text: String
    let timestamp: Date

    init(id: UUID = UUID(), text: String, timestamp: Date) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
    }
}

/// The main coordinator for YomiKit.
/// Manages region selection, screen capture, OCR, clipboard output, and WebSocket broadcast.
@MainActor
class CaptureManager: ObservableObject {

    private let logger = Logger()

    // MARK: - Published State

    @Published var isRunning = false
    @Published var isScanning = false
    @Published var textBlocks: [TextBlock] = []
    @Published var statusMessage = "Idle"
    @Published var autoCopyToClipboard = true
    @Published var filters: [String] = []

    /// The selected capture region in NSScreen coordinates (bottom-left origin).
    @Published var selectedRegion: CGRect?
    /// The screen the region was selected on.
    private var selectedScreen: NSScreen?

    // MARK: - Sub-components

    var webSocketServer = WebSocketServer()
    private let textRecognizer = TextRecognizer()
    private let captureEngine = CaptureEngine()
    private var modelContext: ModelContext?

    // MARK: - Private State

    private var availableDisplays = [SCDisplay]()
    private var availableApps = [SCRunningApplication]()
    private var lastRecognizedText = ""
    private var regionOverlays = [OverlayWindow]()
    private var captureTask: Task<Void, Never>?
    private var wsCancellable: AnyCancellable?

    init() {
        // Forward WebSocketServer changes so SwiftUI updates.
        wsCancellable = webSocketServer.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

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

    /// Shows a fullscreen transparent overlay on every screen for the user to drag-select a region.
    func selectRegion() {
        closeRegionOverlays()

        for screen in NSScreen.screens {
            let overlay = OverlayWindow(screen: screen)
            let selectorView = RegionSelectorNSView()

            selectorView.onRegionSelected = { [weak self] rect in
                Task { @MainActor in
                    self?.selectedRegion = rect
                    self?.selectedScreen = screen
                    self?.closeRegionOverlays()
                }
            }
            selectorView.onCancelled = { [weak self] in
                Task { @MainActor in
                    self?.closeRegionOverlays()
                }
            }

            overlay.contentView = selectorView
            overlay.makeKeyAndOrderFront(nil)
            regionOverlays.append(overlay)
        }

        // Focus the overlay on the main screen.
        if let main = regionOverlays.first {
            main.makeKey()
            main.makeFirstResponder(main.contentView)
        }
    }

    private func closeRegionOverlays() {
        for w in regionOverlays { w.close() }
        regionOverlays.removeAll()
        NSCursor.arrow.set()
    }

    // MARK: - Start / Stop

    func start() async {
        guard !isRunning else { return }

        let screen = selectedScreen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }

        // Default to full screen if no region selected.
        // selectedRegion is in view-local coords (0-based); screen.frame has global origin.
        let region = selectedRegion ?? CGRect(origin: .zero, size: screen.frame.size)

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

        // Match the SCDisplay to the NSScreen by CGDirectDisplayID.
        let screenDisplayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        let display = availableDisplays.first(where: { $0.displayID == screenDisplayID })
                      ?? availableDisplays.first
        guard let display else {
            statusMessage = "No display found"
            return
        }

        // Region coords are already in view-local space (0-based).
        // Convert to SCK coords (top-left origin).
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
        config.minimumFrameInterval = CMTime(value: 2, timescale: 3) // 1.5 FPS
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

    // MARK: - Quick Scan

    func quickScan() async {
        guard !isScanning else { return }
        let screen = selectedScreen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }

        let region = selectedRegion ?? CGRect(origin: .zero, size: screen.frame.size)

        isScanning = true
        defer { isScanning = false }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let screenDisplayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            let display = content.displays.first(where: { $0.displayID == screenDisplayID }) ?? content.displays.first
            guard let display else { return }

            let sckRect = CGRect(x: region.origin.x,
                                 y: CGFloat(display.height) - region.origin.y - region.height,
                                 width: region.width,
                                 height: region.height)

            let excludedApps = content.applications.filter { Bundle.main.bundleIdentifier == $0.bundleIdentifier }
            let filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])

            let scaleFactor = Int(screen.backingScaleFactor)
            let config = SCStreamConfiguration()
            config.width = Int(region.width) * scaleFactor
            config.height = Int(region.height) * scaleFactor
            config.showsCursor = false
            config.capturesAudio = false
            config.sourceRect = sckRect
            config.destinationRect = CGRect(origin: .zero,
                                            size: CGSize(width: Int(region.width) * scaleFactor,
                                                         height: Int(region.height) * scaleFactor))

            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            let raw = try await textRecognizer.recognize(image: cgImage)
            let text = applyFilters(raw)
            guard !text.isEmpty else { return }

            let block = TextBlock(text: text, timestamp: Date())
            textBlocks.append(block)
            persist(block)

            if autoCopyToClipboard {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }

            if webSocketServer.isRunning {
                webSocketServer.broadcast(text)
            }
        } catch {
            logger.error("Quick scan error: \(error.localizedDescription)")
        }
    }

    // MARK: - Frame Processing

    private func processFrame(_ frame: CapturedFrame) async {
        guard let surface = frame.surface else { return }

        // Convert IOSurface → CGImage safely.
        guard let cgImage = await textRecognizer.cgImage(from: surface) else { return }

        // Run OCR.
        do {
            let raw = try await textRecognizer.recognize(image: cgImage)
            guard !raw.isEmpty, !textMatchesLast(raw) else { return }
            let text = applyFilters(raw)
            guard !text.isEmpty else { return }

            lastRecognizedText = raw
            let block = TextBlock(text: text, timestamp: Date())
            textBlocks.append(block)
            persist(block)

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

    // MARK: - Settings Persistence

    // MARK: - Persistence

    func setModelContext(_ context: ModelContext) {
        modelContext = context
        let descriptor = FetchDescriptor<TextBlockRecord>(sortBy: [SortDescriptor(\.timestamp)])
        if let records = try? context.fetch(descriptor) {
            textBlocks = records.map { TextBlock(id: $0.id, text: $0.text, timestamp: $0.timestamp) }
        }
    }

    func deleteTextBlock(id: UUID) {
        textBlocks.removeAll { $0.id == id }
        guard let ctx = modelContext else { return }
        let descriptor = FetchDescriptor<TextBlockRecord>(predicate: #Predicate { $0.id == id })
        if let record = try? ctx.fetch(descriptor).first {
            ctx.delete(record)
        }
    }

    func clearTextBlocks() {
        textBlocks.removeAll()
        guard let ctx = modelContext else { return }
        let descriptor = FetchDescriptor<TextBlockRecord>()
        if let records = try? ctx.fetch(descriptor) {
            records.forEach { ctx.delete($0) }
        }
    }

    private func persist(_ block: TextBlock) {
        guard let ctx = modelContext else { return }
        ctx.insert(TextBlockRecord(id: block.id, text: block.text, timestamp: block.timestamp))
    }

    func loadSettings(_ settings: AppSettings) {
        selectedRegion = settings.region
        autoCopyToClipboard = settings.autoCopyToClipboard
        filters = settings.filters
        webSocketServer.port = settings.wsPortUInt16
        if settings.wsServerEnabled {
            webSocketServer.start()
        }
    }

    func saveSettings(to settings: AppSettings) {
        settings.region = selectedRegion
        settings.autoCopyToClipboard = autoCopyToClipboard
        settings.filters = filters
        settings.wsPort = Int(webSocketServer.port)
        settings.wsServerEnabled = webSocketServer.isRunning
    }

    private func applyFilters(_ text: String) -> String {
        filters.filter { !$0.isEmpty }.reduce(text) { result, pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }
            let range = NSRange(result.startIndex..., in: result)
            return regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
    }

    /// Fuzzy match to avoid duplicates from OCR jitter (punctuation/whitespace variations).
    private func textMatchesLast(_ text: String) -> Bool {
        if lastRecognizedText.isEmpty { return false }
        return normalize(text) == normalize(lastRecognizedText)
    }

    private func normalize(_ text: String) -> String {
        text.unicodeScalars.filter { scalar in
            !CharacterSet.whitespacesAndNewlines.contains(scalar)
            && !CharacterSet.punctuationCharacters.contains(scalar)
            && !CharacterSet.symbols.contains(scalar)
        }.map { String($0) }.joined()
    }
}
