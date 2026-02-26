import SwiftUI

struct RouteSectionView: View {
    let route: TrainRoute
    @ObservedObject var manager: LinesManager
    @Binding var selectedTrains: Set<UUID>
    let onShowSchedule: (TrainRoute) -> Void
    let onAddTrain: (TrainRoute, ScheduleMode) -> Void
    
    @State private var isExpanded: Bool = false
    
    var body: some View {
        Section(header: LineHeader(
            line: route,
            onAddTrain: { onAddTrain(route, .single) },
            onAddTrainCadenced: { onAddTrain(route, .cadenced) },
            onShowSchedule: { onShowSchedule(route) }
        )) {
            DisclosureGroup(isExpanded: $isExpanded) {
                let lineTrains = manager.trains.filter { $0.routeId == route.id }
                
                if lineTrains.isEmpty {
                    Text("no_trains_assigned".localized).font(.caption).foregroundColor(.secondary)
                }
                
                ForEach(lineTrains) { train in
                    TrainRow(
                        train: train,
                        selectedIds: selectedTrains,
                        onSelectTrain: { t in selectedTrains = [t.id] },
                        onToggleSelection: { t in
                            if selectedTrains.contains(t.id) { selectedTrains.remove(t.id) }
                            else { selectedTrains.insert(t.id) }
                        }
                    )
                }
                .onDelete { idx in
                    let toDel = idx.map { lineTrains[$0] }
                    manager.trains.removeAll { t in toDel.contains(where: { t.id == $0.id }) }
                }
            } label: {
                Text("trains_count_fmt".localizedFormat(manager.trains.filter { $0.routeId == route.id }.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
