import SwiftUI
import AppKit

// MARK: - OverlayWindow

/// A transparent, borderless, full-screen window used for region selection.
class OverlayWindow: NSWindow {

    convenience init(screen: NSScreen) {
        self.init(contentRect: screen.frame,
                  styleMask: .borderless,
                  backing: .buffered,
                  defer: false)
        self.setFrame(screen.frame, display: true)
        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
}

// MARK: - Region Selector NSView

/// An NSView that handles mouse drag to select a rectangular region.
/// Draws a darkened overlay with a clear cutout for the selected area.
class RegionSelectorNSView: NSView {

    var onRegionSelected: ((CGRect) -> Void)?
    var onCancelled: (() -> Void)?

    private var dragStart: NSPoint?
    private var currentRect: CGRect?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func mouseMoved(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = convert(event.locationInWindow, from: nil)
        currentRect = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        let current = convert(event.locationInWindow, from: nil)
        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let w = abs(current.x - start.x)
        let h = abs(current.y - start.y)
        currentRect = CGRect(x: x, y: y, width: w, height: h)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if let rect = currentRect, rect.width > 10, rect.height > 10 {
            onRegionSelected?(rect)
        } else {
            onCancelled?()
        }
        dragStart = nil
    }

    override func keyDown(with event: NSEvent) {
        // Escape cancels
        if event.keyCode == 53 {
            onCancelled?()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        // Semi-transparent dark overlay
        NSColor(white: 0, alpha: 0.35).setFill()
        bounds.fill()

        // Clear cutout for selected region
        if let rect = currentRect {
            NSColor.clear.setFill()
            rect.fill(using: .copy)

            // Draw border around selected region
            NSColor.systemBlue.setStroke()
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 2
            path.stroke()

            // Draw dimensions label
            let label = "\(Int(rect.width)) x \(Int(rect.height))"
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.white,
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .medium),
                .backgroundColor: NSColor(white: 0, alpha: 0.7)
            ]
            let labelSize = (label as NSString).size(withAttributes: attrs)
            let labelPoint = NSPoint(x: rect.midX - labelSize.width / 2,
                                     y: rect.maxY + 6)
            (label as NSString).draw(at: labelPoint, withAttributes: attrs)
        }
    }
}

// MARK: - SwiftUI Wrapper

/// SwiftUI view that wraps the region selector NSView.
struct RegionSelectorView: NSViewRepresentable {
    var onRegionSelected: (CGRect) -> Void
    var onCancelled: () -> Void

    func makeNSView(context: Context) -> RegionSelectorNSView {
        let view = RegionSelectorNSView()
        view.onRegionSelected = onRegionSelected
        view.onCancelled = onCancelled
        return view
    }

    func updateNSView(_ nsView: RegionSelectorNSView, context: Context) {}
}
