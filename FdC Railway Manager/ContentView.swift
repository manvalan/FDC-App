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
    @StateObject var railroadService = RailroadService.shared
    
    // Navigation State
    @State var highlightedConflictLocation: String? = nil
    @State var isExporting = false
    @State var showCredits = false
    
    @Namespace var tabNameSpace

    var body: some View {
        ZStack {
            // 1. BACKGROUND: THE MAP / CONTENT (Full Screen)
            detailContent
            
            // 2. OVERLAYS: MODES & NAVIGATION
            if appState.activePanel == .modeBar {
                ModeBarOverlay()
            }
            
            if appState.activePanel == .sidebar {
                SidebarOverlay()
            }
            
            if appState.isWidePanelVisible && appState.activePanel == .inspector {
                WidePanelOverlay()
            }
            
            if appState.activePanel == .inspector {
                InspectorOverlay()
            }
            
            if appState.currentMode == .live {
                SimulationControlsOverlay()
            }
            
            // 3. EDGE GESTURE DETECTORS
            EdgeGestureDetectors()
        }
        .environmentObject(network)
        .background {
            Button("") { railroad.undo() }
                .keyboardShortcut("z", modifiers: .command)
                .opacity(0)
        }
        .alert("Ottimizzazione completata", isPresented: $railroadService.showOptimizationResultAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Applica", role: .destructive) {
                railroadService.applyOptimization(to: lines)
            }
        } message: {
            Text("L'algoritmo ha ridotto i conflitti da \(railroadService.optimizationConflictDelta.before) a \(railroadService.optimizationConflictDelta.after).\nVuoi applicare \(railroadService.pendingOptimizedTrains.count) orari ottimizzati?")
        }
    }
}

// Placeholder for Live Simulation controls shelf
struct LiveSimulationShelf: View {
    @EnvironmentObject var appState: AppState
    var body: some View {
        HStack(spacing: 15) {
            Button(action: { appState.liveSim.toggle() }) {
                Image(systemName: appState.liveSim.isRunning ? "pause.fill" : "play.fill")
                    .font(.title2)
            }
            Divider().frame(height: 20)
            Text(appState.liveSim.currentSimTime, style: .time)
                .font(.system(.body, design: .monospaced))
                .bold()
            Divider().frame(height: 20)
            Menu {
                Button("1x") { appState.liveSim.timeMultiplier = 1 }
                Button("5x") { appState.liveSim.timeMultiplier = 5 }
                Button("10x") { appState.liveSim.timeMultiplier = 10 }
                Button("30x") { appState.liveSim.timeMultiplier = 30 }
            } label: {
                Text("\(Int(appState.liveSim.timeMultiplier))x")
                    .font(.caption).bold()
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(30)
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
    }
}
