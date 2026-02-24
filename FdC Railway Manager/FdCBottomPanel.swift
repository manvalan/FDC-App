import SwiftUI

// MARK: - FdCBottomPanel
/// Pannello inferiore generalizzato che compare dal basso.
/// Altezza configurabile ma mai più di 1/3 della pagina.
///
/// Uso:
/// ```
/// FdCBottomPanel(
///     isPresented: $showProfile,
///     title: "Profilo Altimetrico",
///     preferredHeight: 280
/// ) {
///     AltimetricProfileView(...)
/// }
/// ```

struct FdCBottomPanel<Content: View>: View {
    @Binding var isPresented: Bool
    var title: String? = nil
    var preferredHeight: CGFloat = 250
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        if isPresented {
            GeometryReader { geo in
                let maxHeight = geo.size.height / 2
                let panelHeight = min(preferredHeight, maxHeight)
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    VStack(spacing: 0) {
                        // Handle + Header
                        headerView
                        
                        // Content
                        content()
                            .frame(maxWidth: .infinity)
                    }
                    .frame(height: panelHeight)
                    .background(Color.white)
                    .contentShape(Rectangle())
                    .cornerRadius(14, corners: [.topLeft, .topRight])
                    .shadow(color: .black.opacity(0.15), radius: 10, y: -5)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: 4) {
            // Handle bar (pillola)
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            if title != nil {
                HStack {
                    if let title = title {
                        Text(title)
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 4)
            }
            
            Divider()
        }
    }
}


