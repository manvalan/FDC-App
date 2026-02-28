import SwiftUI
import Combine
import MapKit
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

struct StationNodeView: View {
    @EnvironmentObject var appState: AppState
    @Binding var node: RailwayNode
    private var network: NetworkModel { appState.railroad.network }
    var canvasSize: CGSize
    var isSelected: Bool
    var snapToGrid: Bool
    var gridUnit: Double
    var bounds: MapBounds
    var nodePosition: CGPoint // Posizione centrale del nodo sul canvas
    var onTapAtLocation: (CGPoint) -> Void
    var onDragStarted: (() -> Void)? = nil
    private let renderer = RailwayRenderer()
    @State private var dragOffset: CGSize = .zero
    @State private var isInternalMoveEnabled: Bool = false
    var body: some View {
        ZStack {
            // 1. AREA DI INTERAZIONE (Ridotta per non bloccare i binari)
            Color.white.opacity(0.001)
                .frame(width: 44, height: 44) 
                .contentShape(Rectangle())
                .onTapGesture { localPos in
                    // Converti location locale in canvas-global
                    // Dato che siamo posizionati con .position(nodePosition),
                    // il top-left della nostra area 44x44 è nodePosition - (22, 22)
                    let globalX = nodePosition.x - 22 + localPos.x
                    let globalY = nodePosition.y - 22 + localPos.y
                    onTapAtLocation(CGPoint(x: globalX, y: globalY))
                }
            
            // 2. FEEDBACK VISIVO (Selezione / Trascinamento)
            if isSelected || isInternalMoveEnabled {
                Circle()
                    .stroke(Color.blue, lineWidth: 3)
                    .frame(width: isInternalMoveEnabled ? 90 : 66, height: isInternalMoveEnabled ? 90 : 66)
                    .scaleEffect(isInternalMoveEnabled ? 1.1 : 1.0)
                
                if isInternalMoveEnabled {
                    renderDraggingIcon
                        .transition(.scale.combined(with: .opacity))
                }
            }
            
            labelOverlay
        }
        .offset(dragOffset)
        // Usiamo un gesto sequenziale per il trascinamento
        .gesture(
            LongPressGesture(minimumDuration: 0.35)
                .onEnded { _ in
                    startDragging()
                }
                .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                .onChanged { value in
                    switch value {
                    case .second(true, let drag):
                        if let drag = drag {
                            withAnimation(.interactiveSpring()) {
                                dragOffset = drag.translation
                            }
                        }
                    default: break
                    }
                }
                .onEnded { value in
                    switch value {
                    case .second(true, let drag):
                        if let drag = drag {
                            finalizeDrag(translation: drag.translation)
                        } else {
                            cleanupDrag()
                        }
                    default:
                        cleanupDrag()
                    }
                }
        )
    }

    private func startDragging() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isInternalMoveEnabled = true
            appState.isDraggingNode = true
            appState.selectedNodeId = node.id
            if let network = appState.railroad.network as? NetworkModel {
                 network.createCheckpoint()
            }
        }
    }

    private func cleanupDrag() {
        withAnimation {
            dragOffset = .zero
            isInternalMoveEnabled = false
            appState.isDraggingNode = false
        }
    }

    private func finalizeDrag(translation: CGSize) {
        let drawWidth = max(canvasSize.width - 100, 1) 
        let drawHeight = max(canvasSize.height - 100, 1)
        
        let dLon = (translation.width / drawWidth) * bounds.xRange
        let dLat = -(translation.height / drawHeight) * bounds.yRange 
        
        var newNode = node
        let lat = (newNode.latitude ?? 0) + dLat
        let lon = (newNode.longitude ?? 0) + dLon
        
        if snapToGrid {
            let unit = gridUnit
            newNode.latitude = round(lat / unit) * unit
            newNode.longitude = round(lon / unit) * unit
        } else {
            newNode.latitude = lat
            newNode.longitude = lon
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            node = newNode 
            dragOffset = .zero
            isInternalMoveEnabled = false
            appState.isDraggingNode = false
        }
    }

    @ViewBuilder
    private var renderDraggingIcon: some View {
        let style = NodeStyle(
            fillColor: Color(hex: node.customColor ?? node.defaultColor) ?? .black,
            strokeColor: .blue,
            strokeWidth: 2,
            size: node.type == .junction ? 10 : 30, // Più grande mentre trascini
            showLabel: false,
            isHighlighted: false,
            isSelected: true
        )
        
        ZStack {
            renderer.renderNodeIcon(node, style: style)
            Circle()
                .stroke(Color.blue.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                .frame(width: 45, height: 45)
                .scaleEffect(1.2)
        }
    }

    @ViewBuilder
    private var selectionOverlay: some View {
        Group {
            if isSelected {
                Circle().stroke(Color.blue, lineWidth: 2).scaleEffect(1.4)
            }
            if isInternalMoveEnabled {
                Circle().stroke(Color.blue.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4, 2])).scaleEffect(1.3)
            }
        }
    }

    @ViewBuilder
    private var labelOverlay: some View {
        // Only show label if actively dragging (the real label is in the Canvas)
        if isInternalMoveEnabled && node.type != .junction && node.parentHubId == nil {
            Text(node.name)
                .font(.system(size: appState.globalFontSize, weight: .black))
                .fixedSize()
                .foregroundColor(.black)
                .shadow(color: .white, radius: 2)
                .offset(y: 28)
                .allowsHitTesting(false)
        }
    }
    
    @ViewBuilder
    func symbolView(type: RailwayNode.StationVisualType, color: Color) -> some View {
        switch type {
        case .filledSquare:
            Image(systemName: "square.fill").symbolRenderingMode(.palette).foregroundStyle(color)
        case .emptySquare:
            Image(systemName: "square").symbolRenderingMode(.palette).foregroundStyle(color).fontWeight(.bold)
        case .filledCircle:
            Image(systemName: "circle.fill").symbolRenderingMode(.palette).foregroundStyle(color)
        case .emptyCircle:
            Image(systemName: "circle").symbolRenderingMode(.palette).foregroundStyle(color).fontWeight(.bold)
        case .filledStar:
            Image(systemName: "star.fill").symbolRenderingMode(.palette).foregroundStyle(color)
        }
    }
}
