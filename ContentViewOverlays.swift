import SwiftUI

// MARK: - Overlay Components for ContentView
// Extracted to reduce cognitive load and improve testability

struct ModeBarOverlay: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            Color.black.opacity(0.001)
                .onTapGesture { appState.showPanel(.none) }
                .zIndex(ZIndex.modeDismiss)
            
            VStack {
                FloatingModeBar()
                    .padding(.top, Layout.leftEdgeWidth)
                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .zIndex(ZIndex.modeBar)
        }
    }
}

struct SidebarOverlay: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack {
            FloatingSideMenu()
                .transition(.move(edge: .leading))
            Spacer()
        }
        .background(Color.black.opacity(0.2).onTapGesture { appState.showPanel(.none) })
        .zIndex(ZIndex.sidebar)
    }
}

struct WidePanelOverlay: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            WidePanelView()
                .frame(width: Layout.widePanelWidth)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            Spacer()
                .frame(width: Layout.inspectorWidth)
        }
        .edgesIgnoringSafeArea(.all)
        .zIndex(ZIndex.widePanel)
    }
}

struct InspectorOverlay: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack {
            Spacer()
            ContextualInspector()
        }
        .zIndex(ZIndex.inspector)
    }
}

struct SimulationControlsOverlay: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack {
            Spacer()
            LiveSimulationShelf()
                .padding(.bottom, Layout.standardPadding)
        }
        .zIndex(ZIndex.simulation)
    }
}

// MARK: - Edge Gesture Detectors
struct EdgeGestureDetectors: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            topEdgeGesture
            
            HStack(spacing: 0) {
                leftEdgeGesture
                Spacer()
                rightEdgeGesture
            }
            .frame(maxHeight: .infinity)
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    private var topEdgeGesture: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.fdcGreyMedium.opacity(0.3))
                .frame(width: Layout.dragHandleWidth, height: Layout.dragHandleHeight)
                .padding(.top, Layout.smallPadding)
            
            Color.clear
                .frame(height: Layout.topEdgeHeight)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    if value.translation.height > Layout.pullDownThreshold {
                        appState.showPanel(.modeBar)
                    }
                }
        )
    }
    
    private var leftEdgeGesture: some View {
        Color.clear
            .frame(width: Layout.leftEdgeWidth)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: Layout.minimumDragDistance)
                    .onEnded { value in
                        if value.translation.width > Layout.swipeThreshold {
                            appState.showPanel(.sidebar)
                        }
                    }
            )
    }
    
    private var rightEdgeGesture: some View {
        Color.clear
            .frame(width: Layout.rightEdgeWidth)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: Layout.minimumDragDistance)
                    .onEnded { value in
                        if value.translation.width < -Layout.swipeThreshold {
                            appState.showPanel(.inspector)
                        }
                    }
            )
    }
}
