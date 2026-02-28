import SwiftUI

struct EdgeGestureDetectors: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Top Detector (Solo al centro)
                topEdgeGesture
                    .frame(width: geo.size.width * 0.4, height: Layout.topEdgeHeight + 20)
                    .position(x: geo.size.width / 2, y: (Layout.topEdgeHeight + 20) / 2)
                
                // Left Detector (Solo al centro verticale)
                leftEdgeGesture
                    .frame(width: Layout.leftEdgeWidth, height: geo.size.height * 0.4)
                    .position(x: Layout.leftEdgeWidth / 2, y: geo.size.height / 2)
                
                // Right Detector (Solo al centro verticale)
                rightEdgeGesture
                    .frame(width: Layout.rightEdgeWidth, height: geo.size.height * 0.4)
                    .position(x: geo.size.width - Layout.rightEdgeWidth / 2, y: geo.size.height / 2)
            }
        }
        .allowsHitTesting(true)
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
