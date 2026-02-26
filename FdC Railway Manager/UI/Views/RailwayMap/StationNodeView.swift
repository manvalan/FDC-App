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
    var bounds: SchematicRailwayView.MapBounds
    var onTap: () -> Void
    @Binding var isMoveModeEnabled: Bool
    var onDragStarted: (() -> Void)? = nil
    private let renderer = RailwayRenderer()
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        renderNodeIconWithInteraction
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .background(Circle().fill(Color.white).opacity(0.001))
            .overlay(selectionOverlay)
            .overlay(alignment: .top) { labelOverlay }
            .onLongPressGesture(minimumDuration: 0.5) { 
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    isMoveModeEnabled.toggle()
                }
                #if os(macOS)
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                #elseif canImport(UIKit)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
            }
            .onTapGesture { onTap() }
            .gesture(
                isMoveModeEnabled ?
                    DragGesture(minimumDistance: 1)
                        .onChanged { val in
                            if dragOffset == .zero { onDragStarted?() }
                            dragOffset = val.translation
                        }
                        .onEnded { val in
                            // Commit changes using the final drag offset
                            let drawWidth = max(canvasSize.width - 100, 1) 
                            let drawHeight = max(canvasSize.height - 100, 1)
                            
                            let dLon = (val.translation.width / drawWidth) * bounds.xRange
                            let dLat = -(val.translation.height / drawHeight) * bounds.yRange 
                            
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
                            
                            node = newNode 
                            dragOffset = .zero
                        }
                : nil
            )
            .offset(dragOffset)
    }

    @ViewBuilder
    private var renderNodeIconWithInteraction: some View {
        let style = NodeStyle(
            fillColor: Color(hex: node.customColor ?? node.defaultColor) ?? .black,
            strokeColor: .blue,
            strokeWidth: 2,
            size: node.type == .junction ? 10 : 24,
            showLabel: false,
            isHighlighted: false,
            isSelected: isSelected
        )
        
        renderer.renderNodeIcon(node, style: style)
    }

    @ViewBuilder
    private var selectionOverlay: some View {
        Group {
            if isSelected {
                Circle().stroke(Color.blue, lineWidth: 2).scaleEffect(1.4)
            }
            if isMoveModeEnabled {
                Circle().stroke(Color.blue.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4, 2])).scaleEffect(1.3)
            }
        }
    }

    @ViewBuilder
    private var labelOverlay: some View {
        // Don't show labels for junctions
        if node.type == .junction {
            EmptyView()
        }
        // For hub stations: only show label for the main station (parentHubId == nil)
        else if node.parentHubId != nil {
            // This is a secondary hub station, don't show label
            EmptyView()
        }
        // Show label for main stations, interchanges, and depots
        else {
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
