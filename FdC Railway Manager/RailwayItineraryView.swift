import SwiftUI

struct RailwayItineraryView: View {
    @EnvironmentObject var appState: AppState
    let stations: [String]
    let network: RailwayNetwork
    let trainStops: [RelationStop]? // Optional, if we want to show train-specific times
    let lineColor: Color? // NEW: Optional line color for visualization
    
    @State private var isExporting = false
    enum ExportFormat { case jpeg, pdf }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(stations.enumerated()), id: \.offset) { index, stationId in
                    ItineraryStepView(
                        index: index,
                        stationId: stationId,
                        stations: stations,
                        network: network,
                        trainStops: trainStops,
                        lineColor: lineColor ?? .green
                    )
                }
            }
            .padding()
        }
        .background(Color.black)
        .cornerRadius(12)
        .overlay(alignment: .topTrailing) {
            sideToolbar
                .padding()
        }
    }
    
    @ViewBuilder
    private var sideToolbar: some View {
        VStack(spacing: 8) {
            Button(action: { exportItinerary(as: .jpeg) }) {
                InteractionIcon(systemName: "photo", isActive: false, color: .white)
            }
            Button(action: { exportItinerary(as: .pdf) }) {
                InteractionIcon(systemName: "doc.text", isActive: false, color: .white)
            }
            Button(action: { printItinerary() }) {
                InteractionIcon(systemName: "printer", isActive: false, color: .white)
            }
        }
        .padding(6)
        .background(Color.gray.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    @MainActor
    private func exportItinerary(as format: ExportFormat) {
        let renderer = ImageRenderer(content: itinerarySnapshot.environmentObject(appState))
        renderer.scale = 3.0
        
        if format == .jpeg {
            if let image = renderer.uiImage {
                shareItem(image)
            }
        } else {
            let pdfUrl = FileManager.default.temporaryDirectory.appendingPathComponent("Itinerario.pdf")
            renderer.render { size, context in
                var box = CGRect(origin: .zero, size: size)
                guard let consumer = CGDataConsumer(url: pdfUrl as CFURL),
                      let pdfContext = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
                pdfContext.beginPDFPage(nil)
                context(pdfContext)
                pdfContext.endPDFPage()
                pdfContext.closePDF()
            }
            shareItem(pdfUrl)
        }
    }
    
    @MainActor
    private func printItinerary() {
        let renderer = ImageRenderer(content: itinerarySnapshot.environmentObject(appState))
        renderer.scale = 2.0
        if let image = renderer.uiImage {
             let printInfo = UIPrintInfo(dictionary: nil)
             printInfo.outputType = .general
             printInfo.jobName = "Itinerario"
             
             let controller = UIPrintInteractionController.shared
             controller.printInfo = printInfo
             controller.printingItem = image
             controller.present(animated: true, completionHandler: nil)
        }
    }
    
    private var itinerarySnapshot: some View {
        VStack(spacing: 0) {
            ForEach(Array(stations.enumerated()), id: \.offset) { index, stationId in
                ItineraryStepView(
                    index: index,
                    stationId: stationId,
                    stations: stations,
                    network: network,
                    trainStops: trainStops,
                    lineColor: lineColor ?? .green
                )
            }
        }
        .padding()
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    private func shareItem(_ item: Any) {
        let av = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            av.popoverPresentationController?.sourceView = root.view
            av.popoverPresentationController?.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            root.present(av, animated: true, completion: nil)
        }
    }
    
    struct ItineraryStepView: View {
        let index: Int
        let stationId: String
        let stations: [String]
        let network: RailwayNetwork
        let trainStops: [RelationStop]?
        let lineColor: Color

        var body: some View {
            let isLast = index == stations.count - 1
            let nextId = isLast ? nil : stations[index + 1]
            let stop = trainStops?.first(where: { $0.stationId == stationId })
            let isTransit = (index > 0 && !isLast) && (stop?.minDwellTime == 0)

            VerticalDiagramStep(
                stationId: stationId,
                network: network,
                isLast: isLast,
                nextStationId: nextId,
                lineColor: lineColor,
                isTransit: isTransit
            ) {
                StationTimesView(stop: stop, index: index, isLast: isLast)
            } segmentMetadata: {
                if !isLast, let nextId = nextId {
                    let nextStop = trainStops?.first(where: { $0.stationId == nextId })
                    let segmentDist = calculateSegmentDistance(from: stationId, to: nextId, network: network)
                    
                    TrainSegmentMetadataView(
                        arrivalTime: nextStop?.arrival,
                        departureTime: nextStop?.departure,
                        segmentDistance: segmentDist,
                        isOrigin: false, // index + 1 is never 0
                        isTerminus: (index + 1 == stations.count - 1)
                    )
                }
            }
        }
    }

    // Extracted sub-view to help compiler
    struct StationTimesView: View {
        let stop: RelationStop?
        let index: Int
        let isLast: Bool
        
        var body: some View {
            if let stop = stop {
                HStack(spacing: 8) {
                    let isOrigin = index == 0
                    let isTerminus = isLast
                    
                    if let arr = stop.arrival, !isOrigin {
                        Text(formatTime(arr))
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    if !isOrigin && !isTerminus {
                        Text("-").foregroundColor(.gray)
                    }
                    
                    if let dep = stop.departure, !isTerminus {
                        Text(formatTime(dep))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        
        private func formatTime(_ date: Date) -> String {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return f.string(from: date)
        }
    }
    
    // Static helper to avoid dependency on self
    private static func calculateSegmentDistance(from: String, to: String, network: RailwayNetwork) -> Double {
        if let edge = network.edges.first(where: { ($0.from == from && $0.to == to) || ($0.from == to && $0.to == from) }) {
            return edge.distance
        }
        return 0.0
    }
}
