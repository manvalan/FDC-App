import SwiftUI

@MainActor
struct RoutesListView: View {
    @ObservedObject var network: NetworkModel
    @ObservedObject var lines: LinesManager
    @Binding var selectedRoute: TrainRoute?
    @State private var showCreate = false
    @State private var editingRouteId: String? = nil
    
    var body: some View {
        FdCEntityList(
            title: "lines".localized,
            items: lines.sortedRoutes,
            selectedItemId: Binding(
                get: { selectedRoute?.id },
                set: { _ in }
            ),
            rowContent: { route in
                HStack {
                    Circle()
                        .fill(Color(hex: route.color ?? "#007AFF") ?? .blue)
                        .frame(width: 10, height: 10)
                    Text(route.name)
                        .font(.subheadline)
                    Spacer()
                    Text("\(route.stationIds.count) fermate")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            },
            searchText: { $0.name },
            onSelect: { route in editingRouteId = route.id },
            onAdd: { showCreate = true },
            onDelete: { route in
                if let idx = lines.routes.firstIndex(where: { $0.id == route.id }) {
                    lines.routes.remove(at: idx)
                    if selectedRoute?.id == route.id { selectedRoute = nil }
                }
                lines.createCheckpoint()
            },
            onDeleteAll: {
                lines.routes.removeAll()
                lines.trains.removeAll()
                selectedRoute = nil
                lines.createCheckpoint()
            }
        )
        .sheet(isPresented: $showCreate) {
            RouteCreationView()
                .presentationDetents([.height(180), .medium, .large])
                .presentationBackgroundInteraction(.enabled)
        }
        .sheet(item: Binding(
            get: { editingRouteId.map { IdentifiableString(id: $0) } },
            set: { editingRouteId = $0?.id }
        )) { ident in
            RouteEditView(routeId: ident.id)
        }
    }
}
