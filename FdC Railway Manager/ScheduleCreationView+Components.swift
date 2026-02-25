import SwiftUI

// MARK: - Componenti UI riutilizzabili per ScheduleCreationView

struct ScheduleMetricView: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundColor(.secondary).bold()
            Text(value).font(.subheadline.bold()).foregroundColor(.primary)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.white.opacity(0.05)).cornerRadius(8)
    }
}

struct StationSymbolView: View {
    let station: RailwayNode?
    let size: CGFloat
    
    init(station: RailwayNode?, size: CGFloat = 16) {
        self.station = station
        self.size = size
    }
    
    var body: some View {
        if let station = station {
            if station.type == .interchange {
                InterchangeSymbolView(size: size)
            } else {
                RegularStationSymbolView(station: station, size: size)
            }
        } else {
            Circle().fill(Color.gray).frame(width: size, height: size)
        }
    }
}

struct InterchangeSymbolView: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle().stroke(Color.red, lineWidth: 2).frame(width: size, height: size)
            Circle().stroke(Color.red, lineWidth: 2).frame(width: size * 0.6, height: size * 0.6)
        }
    }
}

struct RegularStationSymbolView: View {
    let station: RailwayNode
    let size: CGFloat
    
    var body: some View {
        let color = station.customColor.flatMap { Color(hex: $0) } ?? .blue
        switch station.visualType ?? .filledCircle {
        case .filledCircle:
            Circle().fill(color).frame(width: size, height: size)
        case .emptyCircle:
            Circle().stroke(color, lineWidth: 2).frame(width: size, height: size)
        case .filledSquare:
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: size, height: size)
        case .emptySquare:
            RoundedRectangle(cornerRadius: 3).stroke(color, lineWidth: 2).frame(width: size, height: size)
        case .filledStar:
            Image(systemName: "star.fill").foregroundColor(color).font(.system(size: size))
        }
    }
}
