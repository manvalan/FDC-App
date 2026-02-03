import SwiftUI
import UIKit

enum ExportFormat { case jpeg, pdf }

@MainActor
struct ExportUtils {
    static func shareItem(_ item: Any) {
        let av = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            av.popoverPresentationController?.sourceView = root.view
            av.popoverPresentationController?.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            root.present(av, animated: true, completion: nil)
        }
    }
    
    static func printImage(_ image: UIImage, jobName: String = "Stampa FdC") {
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = jobName
        
        let controller = UIPrintInteractionController.shared
        controller.printInfo = printInfo
        controller.printingItem = image
        controller.present(animated: true, completionHandler: nil)
    }
    
    static func exportViewAsPDF<V: View>(content: V, fileName: String) -> URL? {
        let renderer = ImageRenderer(content: content)
        let pdfUrl = FileManager.default.temporaryDirectory.appendingPathComponent("\(fileName).pdf")
        
        renderer.render { size, context in
            var box = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(url: pdfUrl as CFURL),
                  let pdfContext = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
            pdfContext.beginPDFPage(nil)
            context(pdfContext)
            pdfContext.endPDFPage()
            pdfContext.closePDF()
        }
        return pdfUrl
    }
    
    static func exportViewAsImage<V: View>(content: V) -> UIImage? {
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3.0
        return renderer.uiImage
    }
}
