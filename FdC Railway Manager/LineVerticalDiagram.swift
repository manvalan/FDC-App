import SwiftUI

struct LineVerticalDiagram: View {
    @EnvironmentObject var network: RailwayNetwork
    let line: RailwayLine
    let orderedStations: [Node]
    @Binding var selectedStation: LineScheduleView.StationSelection?
    let onLineClick: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header: Line Name
            Button(action: onLineClick) {
                HStack {
                    if let c = line.color {
                        Circle().fill(Color(hex: c) ?? .black).frame(width: 8, height: 8)
                    }
                    Text(line.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(selectedStation == nil ? Color.blue.opacity(0.1) : Color.clear)
            }
            .buttonStyle(.plain)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(orderedStations.enumerated()), id: \.element.id) { index, station in
                        let isLast = index == orderedStations.count - 1
                        let nextId = isLast ? nil : orderedStations[index + 1].id
                        
                        VerticalDiagramStep(
                            stationId: station.id,
                            network: network,
                            isLast: isLast,
                            nextStationId: nextId,
                            lineColor: Color(hex: line.color ?? "") ?? .green,
                            isTransit: line.stops.first(where: { $0.stationId == station.id })?.minDwellTime == 0
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation {
                                selectedStation = LineScheduleView.StationSelection(id: station.id)
                            }
                        }
                        .overlay(alignment: .leading) {
                            if selectedStation?.id == station.id {
                                Rectangle()
                                    .fill(Color.blue)
                                    .frame(width: 4)
                                    .frame(height: 30)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color(red: 0.1, green: 0.1, blue: 0.12)) // Dark "Bywater" background
    }
}
