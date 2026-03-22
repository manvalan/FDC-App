import SwiftUI

struct TrackGraphicView: View {
    let trackType: Edge.TrackType
    let color: Color
    var width: CGFloat = 4
    var isInteractive: Bool = false
    
    var body: some View {
        ZStack {
            if trackType == .highSpeed {
                // High Speed: Solid base color with a dashed white spine
                Rectangle()
                    .fill(color)
                    .frame(width: width)
                
                VerticalDashedLine()
                    .stroke(Color.white.opacity(0.7), style: StrokeStyle(lineWidth: width / 2, lineCap: .round, dash: [width, width]))
                    .frame(width: width)
                    
            } else if trackType == .double {
                HStack(spacing: width/4) {
                    Rectangle().fill(color).frame(width: max(1, width / 2.5))
                    Rectangle().fill(color).frame(width: max(1, width / 2.5))
                }
            } else if trackType == .regional {
                Rectangle()
                    .fill(color)
                    .frame(width: width * 1.1)
            } else {
                Rectangle().fill(color).frame(width: width)
            }
        }
    }
}

struct VerticalDashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}
