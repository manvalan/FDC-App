import SwiftUI

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
