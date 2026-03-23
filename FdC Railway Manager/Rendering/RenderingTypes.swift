import Foundation
import SwiftUI

// MARK: - Rendering Context

/// Context for rendering railway infrastructure
struct RenderingContext {
    let bounds: MapBounds
    let canvasSize: CGSize
    let zoomLevel: CGFloat
    let mode: RenderMode
    
    struct MapBounds {
        let minLat, maxLat, minLon, maxLon: Double
        let xRange, yRange: Double
    }
    
    enum RenderMode {
        case schematic          // Vista schematica semplificata
        case infrastructure     // Dettagli tecnici (segmenti, segnali)
        case altimetricProfile  // Profilo altimetrico
        case scheduler          // Vista scheduler con timing
    }
}

// MARK: - Node Styles

/// Base style for rendering nodes
struct NodeStyle {
    var fillColor: Color
    var strokeColor: Color
    var strokeWidth: CGFloat
    var size: CGFloat
    var showLabel: Bool
    var isHighlighted: Bool
    var isSelected: Bool
    
    static var `default`: NodeStyle {
        NodeStyle(
            fillColor: .white,
            strokeColor: .blue,
            strokeWidth: 2,
            size: 16,
            showLabel: true,
            isHighlighted: false,
            isSelected: false
        )
    }
}

/// Style for station nodes
struct StationStyle {
    var base: NodeStyle
    let shape: StationShape
    let showTracks: Bool
    
    enum StationShape {
        case circle, square, diamond
    }
    
    static var `default`: StationStyle {
        StationStyle(
            base: .default,
            shape: .circle,
            showTracks: false
        )
    }
    
    static func selected() -> StationStyle {
        var style = StationStyle.default
        style.base.isSelected = true
        style.base.fillColor = .yellow
        style.base.strokeColor = .orange
        return style
    }
    
    static func highlighted() -> StationStyle {
        var style = StationStyle.default
        style.base.isHighlighted = true
        style.base.strokeWidth = 3
        return style
    }
}

/// Style for junction nodes
struct JunctionStyle {
    var base: NodeStyle
    let showInProfile: Bool
    
    static var standard: JunctionStyle {
        JunctionStyle(
            base: NodeStyle(
                fillColor: .black,
                strokeColor: .gray,
                strokeWidth: 1,
                size: 8,
                showLabel: false,
                isHighlighted: false,
                isSelected: false
            ),
            showInProfile: true
        )
    }
    
    static func highlighted() -> JunctionStyle {
        var style = JunctionStyle.standard
        style.base.isHighlighted = true
        style.base.size = 10
        style.base.strokeWidth = 2
        return style
    }
}

/// Style for hub/interchange nodes
struct HubStyle {
    var base: NodeStyle
    let showConnectionLines: Bool
    
    static var `default`: HubStyle {
        HubStyle(
            base: NodeStyle(
                fillColor: .white,
                strokeColor: .purple,
                strokeWidth: 3,
                size: 20,
                showLabel: true,
                isHighlighted: false,
                isSelected: false
            ),
            showConnectionLines: true
        )
    }
}

// MARK: - Edge Styles

/// Style for rendering edges
struct EdgeStyle {
    var strokeColor: Color
    var strokeWidth: CGFloat
    var lineStyle: LineStyle
    var showDirection: Bool
    var showSegments: Bool
    var isHighlighted: Bool
    
    enum LineStyle {
        case solid, dashed, dotted
        
        var dashPattern: [CGFloat]? {
            switch self {
            case .solid: return nil
            case .dashed: return [10, 5]
            case .dotted: return [2, 3]
            }
        }
    }
    
    static var `default`: EdgeStyle {
        EdgeStyle(
            strokeColor: .gray,
            strokeWidth: 2,
            lineStyle: .solid,
            showDirection: false,
            showSegments: false,
            isHighlighted: false
        )
    }
    
    static func forTrackType(_ trackType: Edge.TrackType) -> EdgeStyle {
        let color: Color
        let width: CGFloat
        
        switch trackType {
        case .highSpeed:
            color = .red
            width = 4
        case .single, .regional:
            color = .gray
            width = 2
        }
        
        return EdgeStyle(
            strokeColor: color,
            strokeWidth: width,
            lineStyle: .solid,
            showDirection: false,
            showSegments: false,
            isHighlighted: false
        )
    }
    
    static func highlighted() -> EdgeStyle {
        var style = EdgeStyle.default
        return EdgeStyle(
            strokeColor: .orange,
            strokeWidth: style.strokeWidth + 2,
            lineStyle: style.lineStyle,
            showDirection: true,
            showSegments: style.showSegments,
            isHighlighted: true
        )
    }
}

// MARK: - Altitude Profile Styles

/// Style for altitude profile rendering
struct AltitudeProfileStyle {
    let backgroundColor: Color
    let gridColor: Color
    let lineColor: Color
    let lineWidth: CGFloat
    let showGrid: Bool
    let showSlopes: Bool
    let slopeColors: SlopeColors
    
    struct SlopeColors {
        let normal: Color      // 0-12‰
        let steep: Color       // 12-25‰
        let extreme: Color     // >25‰
        
        static var `default`: SlopeColors {
            SlopeColors(
                normal: .green,
                steep: .orange,
                extreme: .red
            )
        }
    }
    
    static var `default`: AltitudeProfileStyle {
        AltitudeProfileStyle(
            backgroundColor: .white,
            gridColor: Color.gray.opacity(0.3),
            lineColor: .blue,
            lineWidth: 2,
            showGrid: true,
            showSlopes: true,
            slopeColors: .default
        )
    }
}

// MARK: - Altitude Data
// AltitudePoint is now defined in InfrastructureTypes.swift
