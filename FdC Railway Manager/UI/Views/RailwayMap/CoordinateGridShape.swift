import SwiftUI
import Combine
import MapKit
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

struct CoordinateGridShape: Shape {
    var bounds: MapBounds
    var unit: Double
    var size: CGSize
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        func projectX(_ lon: Double) -> CGFloat {
            let x = (lon - bounds.minLon) / bounds.xRange * Double(size.width - 100) + 50.0
            return CGFloat(x)
        }
        func projectY(_ lat: Double) -> CGFloat {
            let y = (1.0 - (lat - bounds.minLat) / bounds.yRange) * Double(size.height - 100) + 50.0
            return CGFloat(y)
        }

        // Vertical lines (constant Longitude)
        let minL = floor(bounds.minLon / unit) * unit
        let maxL = ceil(bounds.maxLon / unit) * unit
        
        var currentLon = minL
        while currentLon <= maxL {
            let x = projectX(currentLon)
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            currentLon += unit
        }
        
        // Horizontal lines (constant Latitude)
        let minA = floor(bounds.minLat / unit) * unit
        let maxA = ceil(bounds.maxLat / unit) * unit
        
        var currentLat = minA
        while currentLat <= maxA {
            let y = projectY(currentLat)
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            currentLat += unit
        }
        
        return path
    }
}
