import SwiftUI
import Combine
import UniformTypeIdentifiers
import Foundation
import Charts

struct TimetableChart: View {
    @EnvironmentObject var appState: AppState
    private var lines: LinesManager { appState.railroad.lines }
    let data: [TimetableChartData] // Fallback for remote results
    
    var body: some View {
        Chart {
            // Only show simulator data if there are actual trains
            if !appState.simulator.schedules.isEmpty && !lines.trains.isEmpty {
                // Professional view from simulator data
                ForEach(appState.simulator.schedules) { schedule in
                    ForEach(schedule.stops) { stop in
                        if let arr = stop.arrivalTime {
                            PointMark(
                                x: .value("Tempo", arr),
                                y: .value("Stazione", stop.stationName)
                            )
                            .foregroundStyle(by: .value("Treno", schedule.trainName))
                            .symbolSize(20)
                        }
                        
                        if let dep = stop.departureTime {
                            PointMark(
                                x: .value("Tempo", dep),
                                y: .value("Stazione", stop.stationName)
                            )
                            .foregroundStyle(by: .value("Treno", schedule.trainName))
                            .symbolSize(20)
                        }
                        
                        // Line segment within the station (Dwelling)
                        if let arr = stop.arrivalTime, let dep = stop.departureTime {
                            LineMark(
                                x: .value("Tempo", arr),
                                y: .value("Stazione", stop.stationName)
                            )
                            .foregroundStyle(by: .value("Treno", schedule.trainName))
                            .lineStyle(StrokeStyle(lineWidth: 4))
                            
                            LineMark(
                                x: .value("Tempo", dep),
                                y: .value("Stazione", stop.stationName)
                            )
                            .foregroundStyle(by: .value("Treno", schedule.trainName))
                            .lineStyle(StrokeStyle(lineWidth: 4))
                        }
                    }
                    
                    // Connecting lines between stations
                    if schedule.stops.count > 1 {
                        ForEach(0..<schedule.stops.count-1, id: \.self) { i in
                            let start = schedule.stops[i]
                            let end = schedule.stops[i+1]
                            if let t1 = start.departureTime ?? start.arrivalTime,
                               let t2 = end.arrivalTime ?? end.departureTime {
                                LineMark(x: .value("T", t1), y: .value("S", start.stationName))
                                    .foregroundStyle(by: .value("Treno", schedule.trainName))
                                LineMark(x: .value("T", t2), y: .value("S", end.stationName))
                                    .foregroundStyle(by: .value("Treno", schedule.trainName))
                            }
                        }
                    }
                }
                
                // Conflict annotations
                ForEach(appState.simulator.activeConflicts) { conflict in
                    RuleMark(x: .value("Conflitto", conflict.startTime))
                        .foregroundStyle(.red.opacity(0.3))
                        .annotation(position: .top) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                }
            } else {
                // Fallback for legacy text results
                ForEach(data) { item in
                    LineMark(
                        x: .value("Orario", item.date),
                        y: .value("Stazione", item.station)
                    )
                    .foregroundStyle(by: .value("Treno", item.train))
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .chartYAxisLabel("stations_label".localized)
        .chartLegend(position: .bottom)
        .padding()
    }
}
