import Foundation
import Capacitor
import VisionKit
import PDFKit
import UIKit

@objc(DocumentScannerIOS)
public class DocumentScannerIOS: CAPPlugin, CAPBridgedPlugin, VNDocumentCameraViewControllerDelegate {

    private var savedCall: CAPPluginCall?

    // Required by CAPBridgedPlugin (Capacitor 6/7)
    public let identifier = "DocumentScannerIOS"
    public let jsName = "DocumentScannerIOS"
    public let pluginMethods: [CAPPluginMethod] = [
      CAPPluginMethod(name: "scan", returnType: CAPPluginReturnPromise)
    ]


    // scan(options?: { resultFormats?: 'JPEG'|'PDF'|'JPEG_PDF', jpegQuality?: number (0..1), maxDimension?: number })
    @objc func scan(_ call: CAPPluginCall) {
        self.savedCall = call

        // Check support for document camera
        if #available(iOS 13.0, *) {
            guard VNDocumentCameraViewController.isSupported else {
                call.reject("UNAVAILABLE", "Document camera not supported on this device.")
                return
            }
        } else {
            call.reject("UNAVAILABLE", "Requires iOS 13+")
            return
        }

        // Read options
        let resultFormats = (call.getString("resultFormats") ?? "JPEG_PDF").uppercased() // JPEG | PDF | JPEG_PDF
        let jpegQuality = call.getFloat("jpegQuality") ?? 0.9
        let maxDimension = call.getFloat("maxDimension") // opcional: redimensionar para bajar peso

        DispatchQueue.main.async {
            let vc = VNDocumentCameraViewController()
            vc.delegate = self
            self.bridge?.viewController?.present(vc, animated: true)
        }
    }

    // MARK: - Delegates

    public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true)
        savedCall?.reject("CANCELLED", "User cancelled")
        savedCall = nil
    }

    public func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                             didFailWithError error: Error) {
        controller.dismiss(animated: true)
        savedCall?.reject("SCAN_FAILED", error.localizedDescription)
        savedCall = nil
    }

    public func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                             didFinishWith scan: VNDocumentCameraScan) {
        controller.dismiss(animated: true)

        guard let call = savedCall else { return }

        let resultFormats = (call.getString("resultFormats") ?? "JPEG_PDF").uppercased()
        let jpegQuality = call.getFloat("jpegQuality") ?? 0.9
        let maxDimension = call.getFloat("maxDimension") // opcional

        var imagesBase64: [String] = []
        var uiImages: [UIImage] = []

        // Capture and (optionally) resize + encode to base64
        for i in 0..<scan.pageCount {
            var img = scan.imageOfPage(at: i).fixedOrientation() ?? scan.imageOfPage(at: i)
            if let maxDim = maxDimension, maxDim > 0 {
                img = img.resizedKeepingAspect(maxDimension: CGFloat(maxDim)) ?? img
            }
            uiImages.append(img)
            if resultFormats == "JPEG" || resultFormats == "JPEG_PDF" {
                if let data = img.jpegData(compressionQuality: CGFloat(jpegQuality)) {
                    imagesBase64.append(data.base64EncodedString())
                }
            }
        }

        var pdfBase64: String? = nil
        if (resultFormats == "PDF" || resultFormats == "JPEG_PDF"), uiImages.count > 0 {
            do {
                let data = try Self.buildPDFData(from: uiImages)
                pdfBase64 = data.base64EncodedString()
            } catch {
                // if PDF generation fails but there are images, still return the images
            }
        }

        var payload: [String: Any] = [:]
        if (resultFormats == "JPEG" || resultFormats == "JPEG_PDF") && !imagesBase64.isEmpty {
            payload["imagesBase64"] = imagesBase64
        }
        if (resultFormats == "PDF" || resultFormats == "JPEG_PDF"), let pdf = pdfBase64 {
            payload["pdfBase64"] = pdf
        }

        call.resolve(payload)
        savedCall = nil
    }

    // MARK: - Helpers

    static func buildPDFData(from images: [UIImage]) throws -> Data {
        // Use the first image's size as the page (aspect-fit the rest)
        let firstSize = images.first?.size ?? CGSize(width: 1240, height: 1754) // fallback approx A4 @150dpi
        let pageRect = CGRect(origin: .zero, size: firstSize)
        let fmt = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: fmt)
        let data = renderer.pdfData { ctx in
            for img in images {
                ctx.beginPage()
                let rect = Self.aspectFitRect(img.size, in: pageRect)
                img.draw(in: rect)
            }
        }
        return data
    }

    static func aspectFitRect(_ imageSize: CGSize, in bounds: CGRect) -> CGRect {
        let sx = bounds.width / imageSize.width
        let sy = bounds.height / imageSize.height
        let scale = min(sx, sy)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        let x = (bounds.width - w) / 2.0
        let y = (bounds.height - h) / 2.0
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

// UIImage helpers
private extension UIImage {
    func fixedOrientation() -> UIImage? {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized
    }

    func resizedKeepingAspect(maxDimension: CGFloat) -> UIImage? {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return self }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized
    }
}
