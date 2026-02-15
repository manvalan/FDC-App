import SwiftUI

// MARK: - Layout Constants
// Centralized UI dimensions following "Code That Fits in Your Head" principles
struct Layout {
    // Panel Widths
    static let inspectorWidth: CGFloat = 360
    static let widePanelWidth: CGFloat = 800
    static let sideMenuWidth: CGFloat = 260
    
    // Edge Gesture Areas
    static let topEdgeHeight: CGFloat = 50
    static let leftEdgeWidth: CGFloat = 40
    static let rightEdgeWidth: CGFloat = 50
    
    // Drag Handle
    static let dragHandleWidth: CGFloat = 40
    static let dragHandleHeight: CGFloat = 4
    
    // Spacing
    static let standardPadding: CGFloat = 16
    static let largePadding: CGFloat = 24
    static let smallPadding: CGFloat = 8
    
    // Corner Radius
    static let cardCornerRadius: CGFloat = 12
    static let panelCornerRadius: CGFloat = 24
    static let buttonCornerRadius: CGFloat = 20
    
    // Gesture Thresholds
    static let minimumDragDistance: CGFloat = 15
    static let swipeThreshold: CGFloat = 30
    static let pullDownThreshold: CGFloat = 20
    
    // Animation
    static let springResponse: Double = 0.35
    static let springDamping: Double = 0.8
    
    // Shadows
    static let shadowRadius: CGFloat = 20
    static let shadowOpacity: Double = 0.06
    static let shadowY: CGFloat = 10
}

// MARK: - Z-Index Constants
struct ZIndex {
    static let background: Double = 0
    static let content: Double = 10
    static let simulation: Double = 80
    static let modeDismiss: Double = 99
    static let modeBar: Double = 100
    static let sidebar: Double = 150
    static let widePanel: Double = 160
    static let inspector: Double = 170
}
