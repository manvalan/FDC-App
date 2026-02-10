import SwiftUI

@MainActor
struct LinesListView: View {
    @ObservedObject var network: NetworkModel
    @ObservedObject var lines: LinesManager
    @Binding var selectedLine: RailwayLine?
    @State private var showCreate = false
    @State private var editingLineId: String? = nil
    @State private var showDeleteAllConfirmation = false
    
    var body: some View {
        List {
            ForEach(lines.sortedLines) { line in
                HStack {
                    if let color = line.color {
                        Circle().fill(Color(hex: color) ?? .black).frame(width: 10, height: 10)
                    }
                    Text(line.name)
                        .fontWeight(selectedLine?.id == line.id ? .bold : .regular)
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedLine = line
                }
                .contextMenu {
                    Button(action: { editingLineId = line.id }) {
                        Label("edit_line".localized, systemImage: "pencil")
                    }
                    Button(role: .destructive, action: {
                        if let idx = lines.lines.firstIndex(where: { $0.id == line.id }) {
                            lines.lines.remove(at: idx)
                            if selectedLine?.id == line.id { selectedLine = nil }
                        }
                    }) {
                        Label("delete_line".localized, systemImage: "trash")
                    }
                }
                .listRowBackground(selectedLine?.id == line.id ? Color.accentColor.opacity(0.1) : Color.clear)
            }
            .onDelete { indexSet in
                let sorted = lines.sortedLines
                for index in indexSet {
                    let line = sorted[index]
                    if let idx = lines.lines.firstIndex(where: { $0.id == line.id }) {
                        lines.lines.remove(at: idx)
                        if selectedLine?.id == line.id { selectedLine = nil }
                    }
                }
            }
        }
        .navigationTitle("lines".localized)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    Button(action: { showCreate = true }) {
                        Image(systemName: "plus")
                    }
                    
                    Menu {
                        Button(role: .destructive, action: { showDeleteAllConfirmation = true }) {
                            Label("delete_all_lines".localized, systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .alert("delete_all_lines".localized, isPresented: $showDeleteAllConfirmation) {
            Button("cancel".localized, role: .cancel) { }
            Button("delete".localized, role: .destructive) {
                lines.lines.removeAll()
                lines.trains.removeAll() // Usually trains depend on lines
                selectedLine = nil
                lines.createCheckpoint()
            }
        } message: {
            Text("delete_all_lines_confirm".localized)
        }
        .sheet(isPresented: $showCreate) {
            LineCreationView()
        }
        .sheet(item: Binding(
            get: { editingLineId.map { IdentifiableString(id: $0) } },
            set: { editingLineId = $0?.id }
        )) { ident in
            LineEditView(lineId: ident.id)
        }
    }
}
