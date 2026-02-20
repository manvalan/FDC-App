import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - FdCToolbar
/// Toolbar orizzontale riutilizzabile con sezione custom + sezione fissa (undo/redo/export).
///
/// Uso:
/// ```
/// FdCToolbar(
///     items: [
///         .button(icon: "building.2.fill", label: "Stazione", action: createStation),
///         .toggle(icon: "tram.fill", label: "Binario", isActive: $isTrackMode, action: toggleTrack),
///         .divider,
///         .button(icon: "list.bullet.rectangle", label: "Ferrovie", action: showList),
///     ],
///     onUndo: { network.undo() },
///     onRedo: { network.redo() },
///     canUndo: network.canUndo,
///     canRedo: network.canRedo,
///     exportView: mapView
/// )
/// ```

// MARK: - Toolbar Item Model

enum FdCToolbarItem: Identifiable {
    case button(icon: String, label: String? = nil, action: () -> Void, isActive: Bool = false, isDestructive: Bool = false)
    case divider
    case custom(id: String, content: AnyView)
    
    var id: String {
        switch self {
        case .button(let icon, let label, _, _, _): return "btn-\(icon)-\(label ?? "")"
        case .divider: return "div-\(UUID().uuidString)"
        case .custom(let id, _): return id
        }
    }
}

// MARK: - Toolbar View

struct FdCToolbar: View {
    let items: [FdCToolbarItem]
    
    // Undo / Redo
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?
    var canUndo: Bool = false
    var canRedo: Bool = false
    
    // Export
    var exportView: UIView? = nil
    
    var body: some View {
        HStack(spacing: 14) {
            // MARK: Custom Items
            ForEach(items) { item in
                itemView(for: item)
            }
            
            // MARK: Fixed Section
            if onUndo != nil || onRedo != nil {
                fixedDivider
                
                // Undo
                Button(action: { onUndo?() }) {
                    Image(systemName: "arrow.uturn.backward")
                        .foregroundColor(canUndo ? .primary : .secondary.opacity(0.4))
                }
                .disabled(!canUndo)
                .help("Annulla")
                
                // Redo
                Button(action: { onRedo?() }) {
                    Image(systemName: "arrow.uturn.forward")
                        .foregroundColor(canRedo ? .primary : .secondary.opacity(0.4))
                }
                .disabled(!canRedo)
                .help("Ripristina")
            }
            
            if exportView != nil {
                fixedDivider
                exportButtons
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }
    
    // MARK: - Item View
    @ViewBuilder
    private func itemView(for item: FdCToolbarItem) -> some View {
        switch item {
        case .button(let icon, let label, let action, let isActive, let isDestructive):
            Button(action: action) {
                if let label = label {
                    Label(label, systemImage: icon)
                        .foregroundColor(isDestructive ? .red : (isActive ? .blue : .primary))
                } else {
                    Image(systemName: icon)
                        .foregroundColor(isDestructive ? .red : (isActive ? .blue : .primary))
                }
            }
            .help(label ?? "")
            
        case .divider:
            fixedDivider
            
        case .custom(_, let content):
            content
        }
    }
    
    // MARK: - Fixed Divider
    private var fixedDivider: some View {
        Divider().frame(height: 20)
    }
    
    // MARK: - Export Buttons
    private var exportButtons: some View {
        HStack(spacing: 14) {
            Button(action: exportJPG) {
                Image(systemName: "photo")
            }
            .help("Esporta JPG")
            
            Button(action: exportPDF) {
                Image(systemName: "doc.richtext")
            }
            .help("Esporta PDF")
            
            Button(action: printView) {
                Image(systemName: "printer")
            }
            .help("Stampa")
        }
    }
    
    // MARK: - Export Actions
    
    private func exportJPG() {
        #if canImport(UIKit)
        guard let view = exportView else { return }
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        let image = renderer.image { ctx in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        presentActivityVC(activityVC)
        #endif
    }
    
    private func exportPDF() {
        #if canImport(UIKit)
        guard let view = exportView else { return }
        let pdfData = NSMutableData()
        let bounds = view.bounds
        UIGraphicsBeginPDFContextToData(pdfData, bounds, nil)
        UIGraphicsBeginPDFPage()
        if let ctx = UIGraphicsGetCurrentContext() {
            view.layer.render(in: ctx)
        }
        UIGraphicsEndPDFContext()
        
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("export.pdf")
        pdfData.write(to: tmpURL, atomically: true)
        let activityVC = UIActivityViewController(activityItems: [tmpURL], applicationActivities: nil)
        presentActivityVC(activityVC)
        #endif
    }
    
    private func printView() {
        #if canImport(UIKit)
        guard let view = exportView else { return }
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        let image = renderer.image { ctx in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
        let printInfo = UIPrintInfo.printInfo()
        printInfo.outputType = .general
        let printController = UIPrintInteractionController.shared
        printController.printInfo = printInfo
        printController.printingItem = image
        printController.present(animated: true)
        #endif
    }
    
    #if canImport(UIKit)
    private func presentActivityVC(_ vc: UIActivityViewController) {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.keyWindow?.rootViewController {
            // For iPad: configure popover
            if let popover = vc.popoverPresentationController {
                popover.sourceView = root.view
                popover.sourceRect = CGRect(x: root.view.bounds.midX, y: 50, width: 0, height: 0)
            }
            root.present(vc, animated: true)
        }
    }
    #endif
}
