import SwiftUI

@MainActor
struct LinesListView: View {
    @ObservedObject var network: NetworkModel
    @ObservedObject var lines: LinesManager
    @Binding var selectedLine: RailwayLine?
    @State private var showCreate = false
    @State private var editingLineId: String? = nil
    
    var body: some View {
        FdCEntityList(
            title: "lines".localized,
            items: lines.sortedLines,
            selectedItemId: Binding(
                get: { selectedLine?.id },
                set: { _ in }
            ),
            rowContent: { line in
                HStack {
                    Circle()
                        .fill(Color(hex: line.color ?? "#007AFF") ?? .blue)
                        .frame(width: 10, height: 10)
                    Text(line.name)
                        .font(.subheadline)
                    Spacer()
                    Text("\(line.stops.count) fermate")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            },
            searchText: { $0.name },
            onSelect: { line in editingLineId = line.id },
            onAdd: { showCreate = true },
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
