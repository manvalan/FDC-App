import SwiftUI

// MARK: - Protocol for List Items

protocol EntityListItem: Identifiable where ID: Hashable {
    var displayBadgeText: String { get }      // Text shown in the colored badge (e.g., "AV", "S01")
    var displayTitle: String { get }          // Main title
    var displaySubtitle: String? { get }      // Subtitle (e.g., "Origin → Destination")
    var displayColor: Color { get }           // Badge background color
}

// MARK: - Generic Entity List View

struct GenericEntityListView<Item: EntityListItem>: View {
    let title: String
    let items: [Item]
    @Binding var selectedItem: Item?
    
    let onAdd: () -> Void
    let onEdit: (Item) -> Void
    let onDelete: (Item) -> Void
    let onDeleteAll: (() -> Void)?
    
    @State private var showDeleteAllConfirmation = false
    
    init(
        title: String,
        items: [Item],
        selectedItem: Binding<Item?>,
        onAdd: @escaping () -> Void,
        onEdit: @escaping (Item) -> Void,
        onDelete: @escaping (Item) -> Void,
        onDeleteAll: (() -> Void)? = nil
    ) {
        self.title = title
        self.items = items
        self._selectedItem = selectedItem
        self.onAdd = onAdd
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onDeleteAll = onDeleteAll
    }
    
    var body: some View {
        List {
            ForEach(items) { item in
                entityRow(for: item)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .onDelete(perform: deleteItems)
        }
        .listStyle(.plain)
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                    }
                    
                    if onDeleteAll != nil {
                        Menu {
                            Button(role: .destructive, action: { showDeleteAllConfirmation = true }) {
                                Label("delete_all".localized, systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .alert("delete_all_confirm_title".localized, isPresented: $showDeleteAllConfirmation) {
            Button("cancel".localized, role: .cancel) { }
            Button("delete".localized, role: .destructive) {
                onDeleteAll?()
            }
        } message: {
            Text("delete_all_confirm_message".localized)
        }
    }
    
    private func entityRow(for item: Item) -> some View {
        HStack(spacing: 12) {
            // Colored badge with text
            Text(item.displayBadgeText)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(item.displayColor)
                )
            
            // Title and subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                if let subtitle = item.displaySubtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(selectedItem?.id == item.id ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedItem = item
        }
        .contextMenu {
            Button(action: { onEdit(item) }) {
                Label("edit".localized, systemImage: "pencil")
            }
            Button(role: .destructive, action: { onDelete(item) }) {
                Label("delete".localized, systemImage: "trash")
            }
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = items[index]
            onDelete(item)
        }
    }
}

// MARK: - Entity Conformances

extension Node: EntityListItem {
    var displayBadgeText: String {
        // Use first 3 characters of ID or name
        String(id.prefix(3)).uppercased()
    }
    
    var displayTitle: String { name }
    
    var displaySubtitle: String? {
        let typeStr = type.localizedName
        if let platforms = platforms {
            return "\(typeStr) • \(platforms) " + "platforms".localized
        }
        return typeStr
    }
    
    var displayColor: Color {
        if let customColor = customColor, let color = Color(hex: customColor) {
            return color
        }
        switch type {
        case .station: return .blue
        case .interchange: return .orange
        case .depot: return .gray
        case .junction: return .green
        }
    }
}

extension Node.NodeType {
    var localizedName: String {
        switch self {
        case .station: return "station".localized
        case .interchange: return "interchange".localized
        case .depot: return "depot".localized
        case .junction: return "junction".localized
        }
    }
}

// Wrapper to provide network context for Edge display
struct EdgeWithNetwork: Identifiable, Hashable {
    let edge: Edge
    let network: NetworkModel
    
    var id: UUID { edge.id }
    
    static func == (lhs: EdgeWithNetwork, rhs: EdgeWithNetwork) -> Bool {
        lhs.edge.id == rhs.edge.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(edge.id)
    }
}

extension EdgeWithNetwork: EntityListItem {
    var displayBadgeText: String {
        // Show first letters of station names
        let fromName = network.nodes.first(where: { $0.id == edge.from })?.name ?? edge.from
        let toName = network.nodes.first(where: { $0.id == edge.to })?.name ?? edge.to
        let fromInitial = String(fromName.prefix(1)).uppercased()
        let toInitial = String(toName.prefix(1)).uppercased()
        return "\(fromInitial)→\(toInitial)"
    }
    
    var displayTitle: String {
        let fromName = network.nodes.first(where: { $0.id == edge.from })?.name ?? edge.from
        let toName = network.nodes.first(where: { $0.id == edge.to })?.name ?? edge.to
        return "\(fromName) ↔ \(toName)"
    }
    
    var displaySubtitle: String? {
        String(format: "%.1f km • %d km/h", edge.distance, edge.maxSpeed)
    }
    
    var displayColor: Color {
        edge.trackType.color
    }
}

extension Edge: EntityListItem {
    var displayBadgeText: String {
        trackType.displayName
    }
    
    var displayTitle: String {
        "\(from) ↔ \(to)"
    }
    
    var displaySubtitle: String? {
        String(format: "%.1f km • %d km/h", distance, maxSpeed)
    }
    
    var displayColor: Color {
        trackType.color
    }
}

extension Train: EntityListItem {
    var displayBadgeText: String {
        if let number = number {
            return String(number)
        }
        return String(name.prefix(4)).uppercased()
    }
    
    var displayTitle: String { name }
    
    var displaySubtitle: String? {
        if let lineId = lineId {
            return "line".localized + ": \(lineId)"
        }
        return type
    }
    
    var displayColor: Color {
        // Color based on train type
        if type.lowercased().contains("av") || type.lowercased().contains("alta") {
            return .red
        } else if type.lowercased().contains("ic") || type.lowercased().contains("intercity") {
            return .blue
        } else if type.lowercased().contains("reg") {
            return .green
        }
        return .gray
    }
}

extension Vehicle: EntityListItem {
    var displayBadgeText: String {
        String(model.prefix(3)).uppercased()
    }
    
    var displayTitle: String { name }
    
    var displaySubtitle: String? {
        String(format: "%@ • %.0fm • %d km/h", model, length, Int(maxSpeed))
    }
    
    var displayColor: Color {
        // Color based on model type
        if model.lowercased().contains("etr") || model.lowercased().contains("frecciarossa") {
            return .red
        } else if model.lowercased().contains("pop") || model.lowercased().contains("rock") {
            return .blue
        } else if model.lowercased().contains("minuetto") || model.lowercased().contains("atr") {
            return .green
        }
        return .cyan
    }
}

extension RailwayLine: EntityListItem {
    var displayBadgeText: String {
        if let prefix = codePrefix {
            return prefix
        }
        return String(name.prefix(3)).uppercased()
    }
    
    var displayTitle: String { name }
    
    var displaySubtitle: String? {
        // Get origin and destination names
        let originName = originId
        let destName = destinationId
        return "\(originName) → \(destName)"
    }
    
    var displayColor: Color {
        if let hexColor = color, let color = Color(hex: hexColor) {
            return color
        }
        return .blue
    }
}

// MARK: - Helper for Sheet Bindings

struct IdentifiableUUID: Identifiable {
    let id: UUID
}
