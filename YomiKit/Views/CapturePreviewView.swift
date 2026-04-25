import SwiftUI

/// Displays information about the selected capture region.
struct CapturePreviewView: View {

    let region: CGRect?

    var body: some View {
        if let r = region {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.dashed")
                    .foregroundColor(.secondary)
                Text("Region: \(Int(r.origin.x)), \(Int(r.origin.y))  \(Int(r.width)) x \(Int(r.height))")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }
}
