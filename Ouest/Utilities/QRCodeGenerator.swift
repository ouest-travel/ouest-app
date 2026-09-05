import UIKit
import CoreImage.CIFilterBuiltins

// MARK: - QR Code Generator

enum QRCodeGenerator {

    /// Generates a QR code UIImage from the given string.
    /// Returns nil if generation fails.
    static func generate(from string: String, size: CGFloat = 250) -> UIImage? {
        guard !string.isEmpty, let data = string.data(using: .utf8) else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"

        guard let ciImage = filter.outputImage else { return nil }

        // Scale up from the tiny CIImage to the requested pixel size
        let scale = size / ciImage.extent.width
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        // Render via CIContext for crisp, non-blurred output
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
