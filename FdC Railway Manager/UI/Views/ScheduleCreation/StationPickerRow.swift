import SwiftUI
import Combine

struct StationPickerRow: View {
    let title: String
    @Binding var selection: String
    let route: TrainRoute
    let network: NetworkModel
    let vm: ScheduleCreationViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            Picker(title, selection: $selection) {
                ForEach(route.stationIds, id: \.self) { stationId in
                    HStack(spacing: 8) {
                        StationSymbolView(station: network.nodes.first(where: { $0.id == stationId }), size: 14)
                        Text(vm.stationName(stationId))
                    }
                    .tag(stationId)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.15))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.3), lineWidth: 1))
        }
    }
}
