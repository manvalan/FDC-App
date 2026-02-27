import SwiftUI
import Combine
import MapKit
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

struct TrainOverlayCanvas: View {
    @EnvironmentObject var appState: AppState
    private var network: NetworkModel { appState.railroad.network }
    
    let bounds: MapBounds
    let canvasSize: CGSize
    let totalZoom: CGFloat
    
    private let renderer = RailwayRenderer()
    
    var body: some View {
        TimelineView(.animation) { timelineContext in
            Canvas { context, size in
                let now = appState.liveSim.currentSimTime
                for schedule in appState.simulator.schedules {
                    if let pos = MapGeometryEngine.currentSchematicTrainPos(for: schedule, in: size, now: now, bounds: bounds, network: network) {
                        let isSelected = appState.selectedTrainIds.contains(schedule.trainId)
                        renderer.drawTrain(
                            position: pos,
                            name: schedule.trainName,
                            color: .yellow,
                            isSelected: isSelected,
                            fontSize: totalZoom > 2.0 ? 10 : 0,
                            in: context
                        )
                    }
                }
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }
}
