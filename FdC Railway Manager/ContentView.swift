import SwiftUI
import UniformTypeIdentifiers
import Foundation
import Combine

// MARK: - ContentView Unified UI
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    var railroad: RailroadNetwork { appState.railroad }
    var network: NetworkModel { railroad.network }
    var lines: LinesManager { railroad.lines }
    var trainManager: LinesManager { lines }
    
    @StateObject var aiService = RailwayAIService.shared
    
    // Navigation State
    @State var highlightedConflictLocation: String? = nil
    @State var isExporting = false
    @State var showCredits = false
    @State var inspectorVisible: Bool = false
    
    // Global Settings State
    @State var showGrid: Bool = false
    @State var isMoveModeEnabled: Bool = false
    
    // Infrastructure validation
    @State var missingTracks: [(from: String, to: String, type: Edge.TrackType)] = []
    @State var showInfrastructureAlert = false
    
    // Background Optimization State
    @StateObject var backgroundGA = GeneticOptimizer()
    @State var isOptimizingInBackground = false
    @State var showOptimizationResultAlert = false
    @State var pendingOptimizedTrains: [Train] = []
    @State var optimizationConflictDelta: (before: Int, after: Int) = (0, 0)
    @State var backgroundOptimizationTask: Task<Void, Never>? = nil
    
    @Namespace var tabNameSpace

    var body: some View {
        VStack(spacing: 0) {
            topNavigationBar
            
            HStack(spacing: 0) {
                // 1. MASTER LIST (Left)
                if appState.sidebarSelection != nil {
                    sidebarContent
                        .frame(width: 300)
                        .background(Color.secondary.opacity(0.05))
                        .background(.ultraThinMaterial)
                    
                    Divider()
                        .edgesIgnoringSafeArea(.all)
                }
                
                // 2. MAIN VIEW (Center Map)
                detailContent
                    .layoutPriority(1)
                
                // 3. PROPERTIES / DIAGRAM (Right)
                if isSomethingSelected {
                    Divider()
                        .edgesIgnoringSafeArea(.all)
                    
                    sidebarPropertiesContent
                        .frame(width: 350)
                        .background(Color.secondary.opacity(0.05))
                        .background(.ultraThinMaterial)
                        .transition(.move(edge: .trailing))
                }
            }
        }
        .animation(.spring(), value: appState.sidebarSelection)
        .animation(.spring(), value: isSomethingSelected)
        .environmentObject(network)
        .onChange(of: appState.sidebarSelection) { _ in
            appState.clearSelection()
        }
        .onChange(of: appState.jumpToTrainId) { trainId in
            if let tId = trainId {
                appState.sidebarSelection = .trains
                appState.selectTrain(tId)
                appState.jumpToTrainId = nil
            }
        }
        .background {
            Button("") { network.undo() }
                .keyboardShortcut("z", modifiers: .command)
                .opacity(0)
        }
        .alert("Ottimizzazione completata", isPresented: $showOptimizationResultAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Applica", role: .destructive) {
                lines.createCheckpoint()
                lines.trains = pendingOptimizedTrains
                lines.validateSchedules()
            }
        } message: {
            Text("L'algoritmo ha ridotto i conflitti da \(optimizationConflictDelta.before) a \(optimizationConflictDelta.after).\nVuoi applicare \(pendingOptimizedTrains.count) orari ottimizzati?")
        }
    }
}
