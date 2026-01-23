import SwiftUI
import MapKit

struct RailwayMapView: View {
    @ObservedObject var network: RailwayNetwork
    @EnvironmentObject var appState: AppState
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedNode: Node? = nil

    var body: some View {
        Map(selection: $selectedNode) {
            // Draw nodes
            ForEach(network.nodes) { node in
                if let coord = node.coordinate {
                    Annotation(node.name, coordinate: coord) {
                        Image(systemName: node.type == .station ? "train.side.front.car" : "square.split.diagonal.2x2")
                            .symbolVariant(.circle.fill)
                            .font(.title3)
                            .foregroundColor(node.type == .depot ? .orange : .blue)
                            .padding(4)
                            .background(.white)
                            .clipShape(Circle())
                            .onTapGesture {
                                selectedNode = node
                            }
                    }
                    .tag(node)
                }
            }
            
            // Draw edges (simplification: straight lines)
            ForEach(network.edges) { edge in
                if let from = network.nodes.first(where: { $0.id == edge.from })?.coordinate,
                   let to = network.nodes.first(where: { $0.id == edge.to })?.coordinate {
                    MapPolyline(coordinates: [from, to])
                        .stroke(edge.trackType == .highSpeed ? .red : .gray, lineWidth: edge.trackType == .single ? 2 : 4)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapScaleView()
            MapPitchButton()
        }
        .sheet(item: $selectedNode) { node in
            StationBoardView(station: node)
        }
        .navigationTitle("Mappa Rete")
    }
}
