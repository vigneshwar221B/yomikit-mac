import Foundation
import Vision
import CoreImage

/// Performs OCR on CGImages using Apple's Vision framework.
/// Supports Japanese, English, Simplified Chinese, and Traditional Chinese.
actor TextRecognizer {

    private let ciContext = CIContext()

    /// Recognizes text in the given CGImage.
    /// Returns the concatenated recognized strings (one per text observation, joined by newlines).
    func recognize(image: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ja", "en", "zh-Hans", "zh-Hant"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Converts an IOSurface to a CGImage using CoreImage (safe independent copy).
    func cgImage(from surface: IOSurface) -> CGImage? {
        let ciImage = CIImage(ioSurface: surface)
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }
}
