import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit
import Vision

/// Reads a Sudoku grid from a photo, entirely on device:
/// find the grid, straighten it, then read each cell with text recognition.
/// Recognition is never perfect, so the result always goes to an editable review screen.
enum ScanService {
    struct Result: Sendable {
        /// 81 digits, 0 = empty.
        var digits: [Int]
        /// Cells that had ink but were read with low confidence (or not at all).
        var uncertain: Set<Int>
        /// False when no square grid was found and the photo was centre-cropped instead.
        var foundGrid: Bool
    }

    private static let gridSide = 900     // straightened grid is 900x900 px
    private static let cellSide = 100

    /// Runs the whole pipeline off the main thread. Takes raw image bytes (JPEG/PNG).
    static func scan(imageData: Data) async -> Result? {
        await Task.detached(priority: .userInitiated) { scanSync(imageData: imageData) }.value
    }

    // MARK: Pipeline

    private static func scanSync(imageData: Data) -> Result? {
        guard let image = UIImage(data: imageData), let cg = normalized(image) else { return nil }
        let context = CIContext()
        guard let (grid, found) = rectify(cg, context: context) else { return nil }

        var digits = [Int](repeating: 0, count: 81)
        var uncertain = Set<Int>()
        let inset = 16
        for r in 0..<9 {
            for c in 0..<9 {
                let i = r * 9 + c
                let rect = CGRect(
                    x: c * cellSide + inset, y: r * cellSide + inset,
                    width: cellSide - 2 * inset, height: cellSide - 2 * inset
                )
                guard let crop = grid.cropping(to: rect), hasInk(crop) else { continue }
                if let (digit, confidence) = recognizeDigit(crop) {
                    digits[i] = digit
                    if confidence < 0.45 { uncertain.insert(i) }
                } else {
                    uncertain.insert(i)   // something is printed there but we couldn't read it
                }
            }
        }
        return Result(digits: digits, uncertain: uncertain, foundGrid: found)
    }

    /// Redraws the photo upright and at most 1600 px on the long side.
    private static func normalized(_ image: UIImage, maxSide: CGFloat = 1600) -> CGImage? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxSide / longest)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format)
            .image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            .cgImage
    }

    // MARK: Finding and straightening the grid

    private static func distance(_ a: CGPoint, _ b: CGPoint, _ w: CGFloat, _ h: CGFloat) -> CGFloat {
        hypot((a.x - b.x) * w, (a.y - b.y) * h)
    }

    private static func rectify(_ cg: CGImage, context: CIContext) -> (CGImage, Bool)? {
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        var source = CIImage(cgImage: cg)
        var found = false

        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.5
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.25
        request.minimumConfidence = 0.4
        request.quadratureTolerance = 25
        request.maximumObservations = 10

        if (try? VNImageRequestHandler(cgImage: cg).perform([request])) != nil {
            // A Sudoku grid is square: ignore the (taller) page around it.
            let squarish = (request.results ?? []).filter { o in
                let top = distance(o.topLeft, o.topRight, w, h)
                let side = distance(o.topLeft, o.bottomLeft, w, h)
                guard side > 0 else { return false }
                let ratio = top / side
                return ratio > 0.8 && ratio < 1.25
            }
            if let best = squarish.max(by: { $0.boundingBox.width * $0.boundingBox.height
                                            < $1.boundingBox.width * $1.boundingBox.height }) {
                let filter = CIFilter.perspectiveCorrection()
                filter.inputImage = source
                filter.topLeft = CGPoint(x: best.topLeft.x * w, y: best.topLeft.y * h)
                filter.topRight = CGPoint(x: best.topRight.x * w, y: best.topRight.y * h)
                filter.bottomLeft = CGPoint(x: best.bottomLeft.x * w, y: best.bottomLeft.y * h)
                filter.bottomRight = CGPoint(x: best.bottomRight.x * w, y: best.bottomRight.y * h)
                if let out = filter.outputImage {
                    source = out
                    found = true
                }
            }
        }

        if !found {
            let side = min(w, h)
            source = source.cropped(to: CGRect(x: (w - side) / 2, y: (h - side) / 2, width: side, height: side))
        }

        // Normalise to a gridSide x gridSide square starting at the origin.
        let extent = source.extent
        guard extent.width > 1, extent.height > 1 else { return nil }
        let moved = source.transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
        let side = CGFloat(gridSide)
        let scaled = moved.transformed(by: CGAffineTransform(scaleX: side / extent.width, y: side / extent.height))
        guard let out = context.createCGImage(scaled, from: CGRect(x: 0, y: 0, width: side, height: side)) else {
            return nil
        }
        return (out, found)
    }

    // MARK: Reading cells

    /// True if the cell contains dark marks on a lighter background (i.e. a printed digit).
    private static func hasInk(_ crop: CGImage) -> Bool {
        let n = 32
        var pixels = [UInt8](repeating: 0, count: n * n)
        let drew: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let ctx = CGContext(
                data: buffer.baseAddress, width: n, height: n, bitsPerComponent: 8,
                bytesPerRow: n, space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(crop, in: CGRect(x: 0, y: 0, width: n, height: n))
            return true
        }
        guard drew else { return false }
        let sorted = pixels.sorted()
        let low = Int(sorted[n * n / 10]), high = Int(sorted[n * n * 9 / 10])
        guard high - low >= 45 else { return false }          // flat cell: no contrast
        let mid = (low + high) / 2
        let dark = pixels.filter { Int($0) < mid }.count
        return Double(dark) / Double(n * n) > 0.025
    }

    /// Upscales a cell onto a white canvas with a margin, which recognition prefers.
    private static func prepared(_ crop: CGImage) -> CGImage? {
        let side = 192, pad = 32
        guard let ctx = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
        ctx.interpolationQuality = .high
        ctx.draw(crop, in: CGRect(x: pad, y: pad, width: side - 2 * pad, height: side - 2 * pad))
        return ctx.makeImage()
    }

    private static func recognizeDigit(_ crop: CGImage) -> (Int, Float)? {
        guard let image = prepared(crop) else { return nil }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        guard (try? VNImageRequestHandler(cgImage: image).perform([request])) != nil else { return nil }
        for observation in request.results ?? [] {
            for candidate in observation.topCandidates(3) {
                if let d = digit(from: candidate.string) { return (d, candidate.confidence) }
            }
        }
        return nil
    }

    /// Maps recognised text to a single digit, forgiving common look-alikes.
    static func digit(from text: String) -> Int? {
        let map: [Character: Int] = [
            "1": 1, "l": 1, "I": 1, "|": 1, "!": 1, "i": 1,
            "2": 2, "Z": 2, "z": 2,
            "3": 3,
            "4": 4,
            "5": 5, "S": 5, "s": 5,
            "6": 6, "G": 6, "b": 6,
            "7": 7,
            "8": 8, "B": 8,
            "9": 9, "g": 9, "q": 9,
        ]
        let found = text.compactMap { map[$0] }
        return found.count == 1 ? found[0] : nil
    }
}

// MARK: - Self-test sample

/// A clean rendering of a puzzle, used by "Try with a sample" to check the pipeline on-device.
struct SamplePuzzleImage: View {
    let puzzle: [Int]

    var body: some View {
        let side: CGFloat = 810
        let cell = side / 9
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(0..<9, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<9, id: \.self) { c in
                            Text(puzzle[r * 9 + c] == 0 ? "" : "\(puzzle[r * 9 + c])")
                                .font(.system(size: 56, weight: .medium))
                                .foregroundStyle(.black)
                                .frame(width: cell, height: cell)
                        }
                    }
                }
            }
            GridLines(thick: false).stroke(Color.gray, lineWidth: 2)
            GridLines(thick: true).stroke(Color.black, lineWidth: 6)
        }
        .frame(width: side, height: side)
        .padding(60)
        .background(Color.white)
    }

    /// PNG bytes of the rendered sample. Must run on the main actor (SwiftUI rendering).
    @MainActor
    static func pngData(for puzzle: [Int]) -> Data? {
        let renderer = ImageRenderer(content: SamplePuzzleImage(puzzle: puzzle))
        renderer.scale = 1
        return renderer.uiImage?.pngData()
    }
}
