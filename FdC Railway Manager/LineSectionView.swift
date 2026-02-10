import SwiftUI

struct LineSectionView: View {
    let line: RailwayLine
    @ObservedObject var manager: LinesManager
    @Binding var selectedTrains: Set<UUID>
    let onShowSchedule: (RailwayLine) -> Void
    let onAddTrain: (RailwayLine, ScheduleCreationView.ScheduleMode) -> Void
    
    @State private var isExpanded: Bool = false
    
    var body: some View {
        Section(header: LineHeader(
            line: line,
            onAddTrain: { onAddTrain(line, .single) },
            onAddTrainCadenced: { onAddTrain(line, .cadenced) },
            onShowSchedule: { onShowSchedule(line) }
        )) {
            DisclosureGroup(isExpanded: $isExpanded) {
                let lineTrains = manager.trains.filter { $0.lineId == line.id }
                
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
                Text("trains_count_fmt".localizedFormat(manager.trains.filter { $0.lineId == line.id }.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
