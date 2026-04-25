import Foundation
import SwiftData

@Model
final class AppSettings {
    var regionX: Double?
    var regionY: Double?
    var regionWidth: Double?
    var regionHeight: Double?
    var autoCopyToClipboard: Bool = true
    var wsPort: Int = 8765
    var wsServerEnabled: Bool = false

    init() {}

    var region: CGRect? {
        get {
            guard let x = regionX, let y = regionY,
                  let w = regionWidth, let h = regionHeight else { return nil }
            return CGRect(x: x, y: y, width: w, height: h)
        }
        set {
            if let r = newValue {
                regionX = Double(r.origin.x)
                regionY = Double(r.origin.y)
                regionWidth = Double(r.size.width)
                regionHeight = Double(r.size.height)
            } else {
                regionX = nil
                regionY = nil
                regionWidth = nil
                regionHeight = nil
            }
        }
    }

    var wsPortUInt16: UInt16 {
        get { UInt16(clamping: wsPort) }
        set { wsPort = Int(newValue) }
    }
}
