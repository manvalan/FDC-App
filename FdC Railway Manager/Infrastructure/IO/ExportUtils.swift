import SwiftUI
import UIKit

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum AppExportFormat { case jpeg, pdf }

@MainActor
struct ExportUtils {
    static func shareItem(_ item: Any) {
        #if os(iOS)
        let av = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            av.popoverPresentationController?.sourceView = root.view
            av.popoverPresentationController?.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            root.present(av, animated: true, completion: nil)
        }
        #elseif os(macOS)
        if let url = item as? URL {
            // Su Mac, per i file è meglio usare il SavePanel o il Finder
            let picker = NSSharingServicePicker(items: [url])
            if let window = NSApplication.shared.windows.first {
                picker.show(relativeTo: .zero, of: window.contentView ?? NSView(), preferredEdge: .minY)
            }
        } else if let image = item as? UIImage {
            let picker = NSSharingServicePicker(items: [image])
            if let window = NSApplication.shared.windows.first {
                picker.show(relativeTo: .zero, of: window.contentView ?? NSView(), preferredEdge: .minY)
            }
        }
        #endif
    }
    
    static func printImage(_ image: UIImage, jobName: String = "Stampa FdC") {
        #if os(iOS)
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = jobName
        
        let controller = UIPrintInteractionController.shared
        controller.printInfo = printInfo
        controller.printingItem = image
        controller.present(animated: true, completionHandler: nil)
        #elseif os(macOS)
        let printInfo = NSPrintInfo.shared
        let printOp = NSPrintOperation(view: NSImageView(image: image), printInfo: printInfo)
        printOp.run()
        #endif
    }
    
    static func exportViewAsPDF<V: View>(content: V, fileName: String) -> URL? {
        // TODO: Implement PDF export using proper ImageRenderer API or PDFKit
        return nil
    }
    
    static func exportViewAsImage<V: View>(content: V) -> UIImage? {
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3.0
        #if os(iOS)
        return renderer.uiImage
        #elseif os(macOS)
        return renderer.nsImage
        #endif
    }
}

// macOS compatibility aliases
#if os(macOS)
typealias UIImage = NSImage
#endif

