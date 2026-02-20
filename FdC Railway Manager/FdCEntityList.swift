import SwiftUI

struct FdCEntityList<Item: Identifiable & Hashable>: View {
    let title: String
    let items: [Item]
    @Binding var selectedItem: Item?
    @State private var searchText = ""
    
    // Actions
    var onAdd: (() -> Void)?
    var onEdit: ((Item) -> Void)?
    var onDelete: ((Item) -> Void)?
    var onDeleteAll: (() -> Void)?
    
    @EnvironmentObject var network: NetworkModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                
                if let onAdd = onAdd {
                    Button(action: onAdd) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("add_new".localized)
                }
                
                if let onDeleteAll = onDeleteAll {
                    Button(action: onDeleteAll) {
                        Image(systemName: "trash")
                            .font(.body)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("delete_all".localized)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            
            // Search Bar (Simple)
            if items.count > 10 {
                TextField("cerca...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            
            // List
            List {
                ForEach(filteredItems, id: \.id) { item in
                    makeRow(for: item)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedItem = item
                            onEdit?(item)
                        }
                        .listRowBackground(
                            (selectedItem?.id == item.id) ? Color.accentColor.opacity(0.1) : Color.clear
                        )
                        .contextMenu {
                            if let onDelete = onDelete {
                                Button("elimina", role: .destructive) {
                                    onDelete(item)
                                }
                            }
                        }
                }
            }
            .listStyle(.plain)
        }
    }
    
    var filteredItems: [Item] {
        if searchText.isEmpty { return items }
        return items.filter { "\($0)".localizedCaseInsensitiveContains(searchText) }
    }
    
    @ViewBuilder
    private func makeRow(for item: Item) -> some View {
        if let node = item as? Node {
            StationRowView(
                node: node, 
                selectedNode: Binding(
                    get: { selectedItem as? Node },
                    set: { if let n = $0 as? Item { selectedItem = n } }
                )
            )
        } else if let edge = item as? Edge {
            if let n1 = network.nodes.first(where: { $0.id == edge.from }),
               let n2 = network.nodes.first(where: { $0.id == edge.to }) {
                EdgeRowView(
                    edge: edge,
                    selectedEdgeId: Binding(
                        get: { (selectedItem as? Edge)?.id.uuidString },
                        set: { _ in }
                    ),
                    fromName: n1.name,
                    toName: n2.name
                )
            } else {
                Text("Tratta sconosciuta (\(edge.id))")
            }
        } else if let line = item as? RailwayLine {
            HStack {
                Circle()
                    .fill(Color(hex: line.color ?? "#000000") ?? .black)
                    .frame(width: 10, height: 10)
                Text(line.name)
                    .fontWeight((selectedItem as? RailwayLine)?.id == line.id ? .bold : .regular)
                Spacer()
            }
            .padding(.vertical, 4)
        } else {
            Text("\(String(describing: item))")
        }
    }
}
