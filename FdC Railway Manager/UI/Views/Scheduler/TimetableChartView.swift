import SwiftUI
import Combine
import UniformTypeIdentifiers
import Foundation
import Charts

struct TimetableChartView: View {
    let schedulerResult: String
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack {
            Text("timetable_chart_title".localized)
                .font(.title2)
                .padding(.top)
            TimetableChart(data: TimetableChartData.parse(from: schedulerResult))
                .frame(height: 400)
                .padding()
            Button("close".localized) { dismiss() }
                .padding(.bottom)
        }
    }
}
