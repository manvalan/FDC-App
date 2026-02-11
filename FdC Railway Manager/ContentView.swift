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
        ZStack {
            // 1. BACKGROUND: THE MAP / CONTENT (Full Screen)
            detailContent
            
            // 2. OVERLAYS: MODES & NAVIGATION
            // Gestures handle visibility now
            
            // Top Mode Bar (Triggered by Swipe Down or Handle Tap)
            if appState.isModeBarVisible {
                Color.black.opacity(0.001) // Invisible tap region to close
                    .onTapGesture { withAnimation { appState.isModeBarVisible = false } }
                    .zIndex(99)
                
                VStack {
                    FloatingModeBar()
                        .padding(.top, 40)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
            }
            
            // Left Side Menu
            if appState.isSideMenuVisible {
                HStack {
                    FloatingSideMenu()
                        .transition(.move(edge: .leading))
                    Spacer()
                }
                .background(Color.black.opacity(0.2).onTapGesture { withAnimation { appState.isSideMenuVisible = false } })
                .zIndex(150)
            }
            
            // Right Inspector (Contextual)
            if appState.isInspectorVisible {
                HStack {
                    Spacer()
                    ContextualInspector()
                }
                .zIndex(90)
            }
            
            // Simulation Controls (Only in Live Mode)
            if appState.currentMode == .live {
                VStack {
                    Spacer()
                    LiveSimulationShelf()
                        .padding(.bottom, 20)
                }
                .zIndex(80)
            }
            
            
            // 3. EDGE GESTURE DETECTORS (Invisible strips on the edges)
            VStack(spacing: 0) {
                // Top edge strip (Mode Bar)
                Color.clear
                    .frame(height: 30)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onEnded { value in
                                if value.translation.height > 20 {
                                    withAnimation(.spring()) { appState.isModeBarVisible = true }
                                }
                            }
                    )
                
                HStack(spacing: 0) {
                    // Left edge strip (Side Menu)
                    Color.clear
                        .frame(width: 30)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 10)
                                .onEnded { value in
                                    if value.translation.width > 20 {
                                        withAnimation(.spring()) { appState.isSideMenuVisible = true }
                                    }
                                }
                        )
                    
                    Spacer()
                    
                    // Right edge strip (Inspector)
                    Color.clear
                        .frame(width: 40) // Wider for easier catch
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 10)
                                .onEnded { value in
                                    if value.translation.width < -20 {
                                        withAnimation(.spring()) { appState.isInspectorVisible = true }
                                    }
                                }
                        )
                }
                .frame(maxHeight: .infinity)
            }
            .edgesIgnoringSafeArea(.all)
        }
        .environmentObject(network)
        .background {
            Button("") { railroad.undo() }
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
