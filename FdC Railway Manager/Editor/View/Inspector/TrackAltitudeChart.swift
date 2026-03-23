import SwiftUI

/// Read-only line chart of an altimetric profile.
///
/// Accepts pre-computed profile points as `(distance, altitude)` tuples.
/// Distance is in km (cumulative from the start of the path).
/// Altitude is in metres above sea level.
struct TrackAltitudeChart: View {
    let profilePoints: [(distance: Double, altitude: Double)]

    var body: some View {
        GeometryReader { _ in
            Canvas { ctx, size in
                guard profilePoints.count >= 2 else { return }
                let alts    = profilePoints.map(\.altitude)
                let minAlt  = (alts.min() ?? 0) - 5
                let altRange = max((alts.max() ?? 0) + 5 - minAlt, 1)
                let maxDist  = max(profilePoints.last!.distance, 0.001) // JUSTIFY: guarded above (count >= 2)

                let screen: (Double, Double) -> CGPoint = { d, a in
                    CGPoint(x: (d / maxDist) * size.width,
                            y: size.height - ((a - minAlt) / altRange) * size.height)
                }

                var line = Path()
                line.move(to: screen(profilePoints[0].distance, profilePoints[0].altitude))
                for pt in profilePoints.dropFirst() {
                    line.addLine(to: screen(pt.distance, pt.altitude))
                }
                ctx.stroke(line, with: .color(.accentColor), lineWidth: 2)

                var fill = line
                fill.addLine(to: screen(profilePoints.last!.distance, minAlt))
                fill.addLine(to: screen(profilePoints[0].distance, minAlt))
                fill.closeSubpath()
                ctx.fill(fill, with: .color(.accentColor.opacity(0.12)))
            }
        }
    }
}
