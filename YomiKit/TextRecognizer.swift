import Foundation
import VisionKit
import CoreImage

/// Performs OCR on CGImages using VisionKit's ImageAnalyzer.
/// Supports vertical and horizontal Japanese, English, Korean, Simplified Chinese, and Traditional Chinese.
actor TextRecognizer {

    private let ciContext = CIContext()
    private let analyzer = ImageAnalyzer()

    func recognize(image: CGImage) async throws -> String {
        var config = ImageAnalyzer.Configuration([.text])
        config.locales = ["ja", "en", "ko", "zh-Hans", "zh-Hant"]
        let analysis = try await analyzer.analyze(image, orientation: .up, configuration: config)
        return analysis.transcript
    }

    /// Converts an IOSurface to a CGImage using CoreImage (safe independent copy).
    func cgImage(from surface: IOSurface) -> CGImage? {
        let ciImage = CIImage(ioSurface: surface)
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }
}
