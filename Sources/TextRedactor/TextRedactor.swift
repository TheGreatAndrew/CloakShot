import Foundation
import Vision
import CoreGraphics
import Shared

public struct DetectedText {
    public let text: String
    public let boundingBox: CGRect
    public let confidence: Float
}

public struct RedactionResult {
    public let image: CGImage
    public let piiFound: [PIIMatch]
    public let regionsRedacted: Int
}

public final class TextRedactor: @unchecked Sendable {
    private var config: CloakConfig

    public init(config: CloakConfig) {
        self.config = config
    }

    public func updateConfig(_ config: CloakConfig) {
        self.config = config
    }

    // MARK: - OCR

    public func extractText(from cgImage: CGImage) throws -> [DetectedText] {
        var results: [DetectedText] = []

        let request = VNRecognizeTextRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }

            for observation in observations {
                guard let candidate = observation.topCandidates(1).first else { continue }
                results.append(DetectedText(
                    text: candidate.string,
                    boundingBox: observation.boundingBox,
                    confidence: candidate.confidence
                ))
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])
        return results
    }

    // MARK: - Scanning

    public func scanImage(_ cgImage: CGImage) throws -> [PIIRegion] {
        let detectedTexts = try extractText(from: cgImage)
        var regions: [PIIRegion] = []

        for detected in detectedTexts {
            let patternMatches = PIIPatterns.scan(detected.text)
            let secretMatches = PIIPatterns.scanForSecrets(detected.text, secrets: config.secretStrings)
            let allMatches = patternMatches + secretMatches

            if !allMatches.isEmpty {
                regions.append(PIIRegion(
                    boundingBox: detected.boundingBox,
                    matches: allMatches,
                    originalText: detected.text
                ))
            }
        }

        return regions
    }

    public func scanText(_ text: String) -> [PIIMatch] {
        let patternMatches = PIIPatterns.scan(text)
        let secretMatches = PIIPatterns.scanForSecrets(text, secrets: config.secretStrings)
        return patternMatches + secretMatches
    }

    // MARK: - Redaction

    public func redactImage(_ cgImage: CGImage) throws -> RedactionResult {
        let regions = try scanImage(cgImage)

        if regions.isEmpty {
            return RedactionResult(image: cgImage, piiFound: [], regionsRedacted: 0)
        }

        let allMatches = regions.flatMap { $0.matches }
        let redacted = drawRedactionBoxes(on: cgImage, regions: regions)

        return RedactionResult(
            image: redacted,
            piiFound: allMatches,
            regionsRedacted: regions.count
        )
    }

    public func redactText(_ text: String) -> String {
        var result = text
        let matches = scanText(text).sorted { $0.range.lowerBound > $1.range.lowerBound }

        for match in matches {
            let replacement = "[\(match.type.rawValue.uppercased())]"
            result.replaceSubrange(match.range, with: replacement)
        }

        return result
    }

    // MARK: - Private

    private func drawRedactionBoxes(on image: CGImage, regions: [PIIRegion]) -> CGImage {
        let width = image.width
        let height = image.height

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }

        let fullRect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(image, in: fullRect)

        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))

        for region in regions {
            // Vision bounding boxes are normalized (0-1), origin at bottom-left
            let pixelRect = CGRect(
                x: region.boundingBox.origin.x * CGFloat(width),
                y: region.boundingBox.origin.y * CGFloat(height),
                width: region.boundingBox.width * CGFloat(width),
                height: region.boundingBox.height * CGFloat(height)
            )
            let padded = pixelRect.insetBy(dx: -4, dy: -4)
            context.fill(padded)
        }

        return context.makeImage() ?? image
    }
}

public struct PIIRegion {
    public let boundingBox: CGRect
    public let matches: [PIIMatch]
    public let originalText: String
}
