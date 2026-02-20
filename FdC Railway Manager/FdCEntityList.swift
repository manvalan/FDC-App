import SwiftUI

// MARK: - FdCEntityList
/// Lista generica riutilizzabile per qualsiasi entità Identifiable.
/// Fornisce: header con titolo/conteggio, ricerca, selezione, swipe-to-delete, long-press edit mode.
///
/// Uso:
/// ```
/// FdCEntityList(
///     title: "Stazioni",
///     items: network.sortedNodes,
///     selectedItemId: $selectedNodeId,
///     searchText: { $0.name },
///     rowContent: { node in StationRowContent(node: node) },
///     onSelect: { node in appState.selectedNodeId = node.id },
///     onAdd: { createStation() },
///     onDelete: { node in network.removeNode(node.id) }
/// )
/// ```
struct FdCEntityList<Item: Identifiable & Hashable, RowContent: View>: View {
    let title: String
    let items: [Item]
    var selectedItemId: Binding<String?>?
    
    // Row builder
    @ViewBuilder var rowContent: (Item) -> RowContent
    
    // Search: restituisce il testo cercabile per ogni item
    var searchText: ((Item) -> String)?
    
    // Actions
    var onSelect: ((Item) -> Void)?
    var onAdd: (() -> Void)?
    var onDelete: ((Item) -> Void)?
    var onDeleteAll: (() -> Void)?
    
    // State
    @State private var query = ""
    @State private var editMode: EditMode = .inactive
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header
            headerView
            
            // MARK: Search (solo se >10 items)
            if items.count > 10 {
                searchBar
            }
            
            // MARK: List
            if filteredItems.isEmpty {
                emptyState
            } else {
                listView
            }
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            // Badge count
            Text("\(items.count)")
                .font(.caption2.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.secondary.opacity(0.5)))
            
            Spacer()
            
            if let onAdd = onAdd {
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            
            if let onDeleteAll = onDeleteAll {
                Button(action: onDeleteAll) {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Cerca...", text: $query)
                .textFieldStyle(.plain)
            if !query.isEmpty {
                Button(action: { query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.5))
            Text(query.isEmpty ? "Nessun elemento" : "Nessun risultato")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
    
    // MARK: - List
    private var listView: some View {
        List {
            ForEach(filteredItems, id: \.id) { item in
                rowContent(item)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if editMode == .inactive {
                            // Update selectedItemId binding if available
                            if let idStr = idString(for: item) {
                                selectedItemId?.wrappedValue = idStr
                            }
                            onSelect?(item)
                        }
                    }
                    .onLongPressGesture(minimumDuration: 0.5) {
                        withAnimation {
                            editMode = (editMode == .active) ? .inactive : .active
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(isSelected(item) ? Color.accentColor.opacity(0.1) : Color.clear)
                    .listRowSeparator(.hidden)
            }
            .onDelete(perform: deleteItems)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, $editMode)
    }
    
    // MARK: - Helpers
    
    private var filteredItems: [Item] {
        guard !query.isEmpty else { return items }
        if let searchText = searchText {
            return items.filter { searchText($0).localizedCaseInsensitiveContains(query) }
        }
        return items.filter { "\($0)".localizedCaseInsensitiveContains(query) }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        guard let onDelete = onDelete else { return }
        for index in offsets {
            let item = filteredItems[index]
            onDelete(item)
        }
    }
    
    private func idString(for item: Item) -> String? {
        if let id = item.id as? String { return id }
        if let id = item.id as? UUID { return id.uuidString }
        return "\(item.id)"
    }
    
    private func isSelected(_ item: Item) -> Bool {
        guard let selectedId = selectedItemId?.wrappedValue else { return false }
        return idString(for: item) == selectedId
    }
}
