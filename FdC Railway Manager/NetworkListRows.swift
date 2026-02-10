import SwiftUI

struct StationRowView: View {
    let node: Node
    @Binding var selectedNode: Node?
    
    var body: some View {
        HStack {
            Text(node.name)
                .foregroundColor(node.id == selectedNode?.id ? .blue : .primary)
            Spacer()
            if node.type == .interchange {
                Image(systemName: "star.fill").foregroundColor(.yellow)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedNode = node
        }
        .listRowBackground(node.id == selectedNode?.id ? Color.accentColor.opacity(0.1) : Color.clear)
    }
}

struct EdgeRowView: View {
    let edge: Edge
    @Binding var selectedEdgeId: String?
    let fromName: String
    let toName: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("\(fromName) → \(toName)")
                    .fontWeight(selectedEdgeId == edge.id.uuidString ? .bold : .regular)
                    .foregroundColor(selectedEdgeId == edge.id.uuidString ? .blue : .primary)
                Text("\(Int(edge.distance)) km - \(edge.trackType.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if selectedEdgeId == edge.id.uuidString {
                Image(systemName: "checkmark").foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedEdgeId = edge.id.uuidString
        }
        .listRowBackground(selectedEdgeId == edge.id.uuidString ? Color.accentColor.opacity(0.1) : Color.clear)
    }
}
