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
            // Gestures handle visibility now
            
            // Top Mode Bar
            if appState.activePanel == .modeBar {
                Color.black.opacity(0.001)
                    .onTapGesture { appState.showPanel(.none) }
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
            if appState.activePanel == .sidebar {
                HStack {
                    FloatingSideMenu()
                        .transition(.move(edge: .leading))
                    Spacer()
                }
                .background(Color.black.opacity(0.2).onTapGesture { appState.showPanel(.none) })
                .zIndex(150)
            }
            
            // 2.5 WIDE OVERLAY (e.g. Schedule / Timetable)
            if appState.isWidePanelVisible && appState.activePanel == .inspector {
                HStack(spacing: 0) {
                    WidePanelView()
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    Spacer()
                        .frame(width: 360) // Width of the regular inspector
                }
                .edgesIgnoringSafeArea(.all)
                .zIndex(160)
            }
            
            // Right Inspector (Contextual)
            if appState.activePanel == .inspector {
                HStack {
                    Spacer()
                    ContextualInspector()
                }
                .zIndex(170)
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
            
            
            // 3. EDGE GESTURE DETECTORS (High Priority to prevent background scroll/pan)
            VStack(spacing: 0) {
                // Top edge strip (Mode Bar)
                VStack(spacing: 0) {
                    Capsule()
                        .fill(Color.fdcGreyMedium.opacity(0.3))
                        .frame(width: 40, height: 4)
                        .padding(.top, 8)
                    
                    Color.clear
                        .frame(height: 50) 
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .global)
                        .onChanged { value in
                            if value.translation.height > 20 { 
                                appState.showPanel(.modeBar)
                            }
                        }
                )
                
                HStack(spacing: 0) {
                    // Left edge strip (Side Menu)
                    Color.clear
                        .frame(width: 40)
                        .contentShape(Rectangle())
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 15)
                                .onEnded { value in
                                    if value.translation.width > 30 {
                                        appState.showPanel(.sidebar)
                                    }
                                }
                        )
                    
                    Spacer()
                    
                    // Right edge strip (Inspector)
                    Color.clear
                        .frame(width: 50)
                        .contentShape(Rectangle())
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 15)
                                .onEnded { value in
                                    if value.translation.width < -30 {
                                        appState.showPanel(.inspector)
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
