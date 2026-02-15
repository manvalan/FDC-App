import SwiftUI

@MainActor
struct LinesListView: View {
    @ObservedObject var network: NetworkModel
    @ObservedObject var lines: LinesManager
    @Binding var selectedLine: RailwayLine?
    @State private var showCreate = false
    @State private var editingLineId: String? = nil
    
    var body: some View {
        GenericEntityListView(
            title: "lines".localized,
            items: lines.sortedLines,
            selectedItem: $selectedLine,
            onAdd: { showCreate = true },
            onEdit: { line in editingLineId = line.id },
            onDelete: { line in
                if let idx = lines.lines.firstIndex(where: { $0.id == line.id }) {
                    lines.lines.remove(at: idx)
                    if selectedLine?.id == line.id { selectedLine = nil }
                }
                lines.createCheckpoint()
            },
            onDeleteAll: {
                lines.lines.removeAll()
                lines.trains.removeAll()
                selectedLine = nil
                lines.createCheckpoint()
            }
        )
        .sheet(isPresented: $showCreate) {
            LineCreationView()
                .presentationDetents([.height(180), .medium, .large])
                .presentationBackgroundInteraction(.enabled)
        }
        .sheet(item: Binding(
            get: { editingLineId.map { IdentifiableString(id: $0) } },
            set: { editingLineId = $0?.id }
        )) { ident in
            LineEditView(lineId: ident.id)
        }
    }
}
