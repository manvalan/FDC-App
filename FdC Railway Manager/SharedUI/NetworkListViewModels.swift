import SwiftUI

// MARK: - Station List ViewModel

@MainActor
struct StationListViewModel {
    let network: NetworkModel
    let appState: AppState
    @Binding var selectedNode: Node?

    var items: [Node] {
        network.sortedNodes
    }

    func searchText(for node: Node) -> String {
        node.name ?? node.id
    }

    func onSelect(_ node: Node) {
        selectedNode = node
        appState.showPanel(.inspector)
    }

    func onAdd() {
        let newStation = Node(
            id: UUID().uuidString,
            name: String(format: "station_default_name".localized, network.nodes.count + 1),
            type: .station,
            latitude: 42.0,
            longitude: 12.5,
            platforms: 2
        )
        network.nodes.append(newStation)
        selectedNode = newStation
        network.createCheckpoint()
        appState.showPanel(.inspector)
    }

    func onDelete(_ node: Node) {
        appState.railroad.removeNode(node.id)
        if selectedNode?.id == node.id {
            selectedNode = nil
        }
    }

    func onDeleteAll() {
        network.nodes.removeAll()
        network.edges.removeAll()
        selectedNode = nil
        network.createCheckpoint()
    }
}

// MARK: - Track List ViewModel

@MainActor
struct TrackListViewModel {
    let network: NetworkModel
    let appState: AppState
    @Binding var selectedEdgeId: String?

    var items: [Edge] {
        network.sortedEdges
    }

    func searchText(for edge: Edge) -> String {
        let fromName = network.nodes.first(where: { $0.id == edge.from })?.name ?? edge.from
        let toName = network.nodes.first(where: { $0.id == edge.to })?.name ?? edge.to
        return "\(fromName) \(toName)"
    }

    func onSelect(_ edge: Edge) {
        selectedEdgeId = edge.id.uuidString
        appState.showPanel(.inspector)
    }

    func onAdd() {
        appState.isCreatingTrack = true
        appState.showPanel(.inspector)
    }

    func onDelete(_ edge: Edge) {
        network.removeEdge(from: edge.from, to: edge.to)
        if appState.isEdgeSelected(edge.id.uuidString) {
            selectedEdgeId = nil
        }
        network.createCheckpoint()
    }

    func onDeleteAll() {
        network.edges.removeAll()
        selectedEdgeId = nil
        network.createCheckpoint()
    }
}

// MARK: - Ferrovia List ViewModel

@MainActor
struct FerroviaListViewModel {
    let network: NetworkModel
    let appState: AppState

    var items: [Ferrovia] {
        network.lines
    }

    func searchText(for ferrovia: Ferrovia) -> String {
        ferrovia.name
    }

    func onSelect(_ ferrovia: Ferrovia) {
        // Select ferrovia and highlight stations on map
        appState.selectedInfraLineId = ferrovia.id
        appState.selectedNodeIds = Set(ferrovia.nodeIds)
        appState.selectedNodeIdsOrder = ferrovia.nodeIds
        // Clear other selections
        appState.selectedNodeId = nil
        appState.selectedEdgeId = nil
        appState.selectedRouteId = nil
    }

    func onAdd() {
        // Ferrovia creation requires multi-selection - for now do nothing
        // TODO: Implement proper ferrovia creation flow
    }

    func onDelete(_ ferrovia: Ferrovia) {
        network.lines.removeAll { $0.id == ferrovia.id }
        if appState.selectedInfraLineId == ferrovia.id {
            appState.selectedInfraLineId = nil
        }
        network.createCheckpoint()
    }

    func onDeleteAll() {
        network.lines.removeAll()
        appState.selectedInfraLineId = nil
        network.createCheckpoint()
    }
}

// MARK: - Shared Symbol Views

struct NetworkSymbols {

    /// Station symbol view based on type and visualType
    @ViewBuilder
    static func stationSymbol(for node: Node, size: CGFloat = 12) -> some View {
        // Interchange stations use double red circle
        if node.type == .interchange {
            ZStack {
                Circle()
                    .stroke(Color.red, lineWidth: 2)
                    .frame(width: size, height: size)
                Circle()
                    .stroke(Color.red, lineWidth: 2)
                    .frame(width: size * 0.6, height: size * 0.6)
            }
        } else {
            let color = node.customColor.flatMap { Color(hex: $0) } ?? .blue

            switch node.visualType ?? .filledCircle {
            case .filledCircle:
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
            case .emptyCircle:
                Circle()
                    .stroke(color, lineWidth: 2)
                    .frame(width: size, height: size)
            case .filledSquare:
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: size, height: size)
            case .emptySquare:
                RoundedRectangle(cornerRadius: 2)
                    .stroke(color, lineWidth: 2)
                    .frame(width: size, height: size)
            case .filledStar:
                Image(systemName: "star.fill")
                    .foregroundColor(color)
                    .font(.system(size: size))
            }
        }
    }

    /// Track symbol view based on trackType
    @ViewBuilder
    static func trackSymbol(for trackType: Edge.TrackType, width: CGFloat = 24, height: CGFloat = 12) -> some View {
        switch trackType {
        case .single:
            // Single track - one line
            Rectangle()
                .fill(Color.gray)
                .frame(width: width, height: 2)
        case .regional:
            // Regional track - medium line with dots
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.orange)
                    .frame(width: width * 0.4, height: 2)
                Circle()
                    .fill(Color.orange)
                    .frame(width: 3, height: 3)
                Rectangle()
                    .fill(Color.orange)
                    .frame(width: width * 0.4, height: 2)
            }
            .frame(width: width, height: height)
        case .highSpeed:
            // High speed - thick red line
            Rectangle()
                .fill(Color.red)
                .frame(width: width, height: 3)
        }
    }

    /// Ferrovia color indicator
    @ViewBuilder
    static func ferroviaSymbol(color: String?, size: CGFloat = 12) -> some View {
        if let colorHex = color, let swiftColor = Color(hex: colorHex) {
            RoundedRectangle(cornerRadius: 3)
                .fill(swiftColor)
                .frame(width: size, height: size)
        } else {
            Circle()
                .fill(Color.red)
                .frame(width: size, height: size)
        }
    }
}
