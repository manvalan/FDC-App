import Foundation
import CoreGraphics

/// Regole pure per hub AV/classico: accoppiamento nodi, endpoint binari, offset canvas.
public struct HubTopology: Sendable {
    public enum HubVisualRole: Sendable {
        case none
        case classicCenter
        case avSatellite
    }

    public let nodes: [Node]

    public init(nodes: [Node]) {
        self.nodes = nodes
    }

    public func findNode(id: String) -> Node? {
        nodes.first { $0.id == id }
    }

    /// Satellite AV collegato al parent hub (al massimo uno per parent).
    public func avSatellite(for hubParentId: String) -> Node? {
        nodes.first { $0.parentHubId == hubParentId }
    }

    public func isAVSatellite(_ node: Node) -> Bool {
        node.parentHubId != nil
    }

    public func isHubParent(_ node: Node) -> Bool {
        avSatellite(for: node.id) != nil
    }

    public func isHubMember(_ node: Node) -> Bool {
        isAVSatellite(node) || isHubParent(node)
    }

    public func hubParent(for node: Node) -> Node? {
        guard let parentId = node.parentHubId else { return nil }
        return findNode(id: parentId)
    }

    public func hubVisualRole(for node: Node) -> HubVisualRole {
        if node.parentHubId != nil { return .avSatellite }
        if avSatellite(for: node.id) != nil { return .classicCenter }
        return .none
    }

    /// Parent hub id per un membro del gruppo; per un parent restituisce il proprio id.
    public func hubGroupId(for node: Node) -> String? {
        if let parentId = node.parentHubId { return parentId }
        if avSatellite(for: node.id) != nil { return node.id }
        return nil
    }

    /// Nodo fisico da usare come endpoint di un binario, in base al tipo traccia.
    /// - Binari classici (regional/single) → stazione al centro.
    /// - Binari AV (highSpeed) → satellite AV offset.
    public func endpointNodeId(for nodeId: String, trackType: Edge.TrackType) -> String {
        guard let node = findNode(id: nodeId) else { return nodeId }
        switch trackType {
        case .highSpeed:
            if node.parentHubId != nil { return nodeId }
            return avSatellite(for: nodeId)?.id ?? nodeId
        case .regional, .single:
            if let parentId = node.parentHubId { return parentId }
            return nodeId
        }
    }

    /// Risolve entrambi gli endpoint per la creazione di un binario.
    public func resolvedEndpoints(
        from fromId: String,
        to toId: String,
        trackType: Edge.TrackType
    ) -> (from: String, to: String) {
        (
            endpointNodeId(for: fromId, trackType: trackType),
            endpointNodeId(for: toId, trackType: trackType)
        )
    }

    /// Proposta di satellite AV per un parent hub.
    public func makeAVSatellite(
        for parent: Node,
        direction: Node.HubOffsetDirection = .bottomRight,
        id: String? = nil
    ) -> Node {
        let satelliteId = id ?? "\(parent.id)_av"
        return Node(
            id: satelliteId,
            name: "\(parent.name) AV",
            type: .station,
            visualType: .filledCircle,
            customColor: "#FF3B30",
            latitude: parent.latitude,
            longitude: parent.longitude,
            parentHubId: parent.id,
            hubOffsetDirection: direction
        )
    }

    /// Offset canvas rispetto al centro hub (quadrato 8 posizioni).
    public static func canvasOffset(
        for direction: Node.HubOffsetDirection,
        magnitude: CGFloat = 25
    ) -> CGPoint {
        switch direction {
        case .topLeft: return CGPoint(x: -magnitude, y: -magnitude)
        case .topRight: return CGPoint(x: magnitude, y: -magnitude)
        case .bottomLeft: return CGPoint(x: -magnitude, y: magnitude)
        case .bottomRight: return CGPoint(x: magnitude, y: magnitude)
        case .top: return CGPoint(x: 0, y: -magnitude)
        case .bottom: return CGPoint(x: 0, y: magnitude)
        case .left: return CGPoint(x: -magnitude, y: 0)
        case .right: return CGPoint(x: magnitude, y: 0)
        }
    }
}
