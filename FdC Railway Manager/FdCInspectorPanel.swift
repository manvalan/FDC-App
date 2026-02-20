import SwiftUI
import Combine

// MARK: - FdCInspectorPanel
/// Inspector laterale riutilizzabile con navigazione a stack.
/// Fornisce: header con back/titolo/chiudi, navigazione push/pop, corpo libero.
///
/// Uso:
/// ```
/// FdCInspectorPanel(title: "Stazioni", onClose: { appState.showPanel(.none) }) {
///     StationsList(...)
/// }
/// ```
///
/// Per navigazione a stack, usare l'environment object `InspectorNavigator`:
/// ```
/// @EnvironmentObject var navigator: InspectorNavigator
/// navigator.push(title: "Dettaglio") { StationDetail(...) }
/// ```

// MARK: - Navigator (stack di pagine)

class InspectorNavigator: ObservableObject {
    struct Page: Identifiable {
        let id = UUID()
        let title: String
        let content: AnyView
    }
    
    @Published var stack: [Page] = []
    
    var currentTitle: String? {
        stack.last?.title
    }
    
    var canGoBack: Bool {
        !stack.isEmpty
    }
    
    func push<V: View>(title: String, @ViewBuilder content: () -> V) {
        stack.append(Page(title: title, content: AnyView(content())))
    }
    
    func pop() {
        if !stack.isEmpty {
            stack.removeLast()
        }
    }
    
    func popToRoot() {
        stack.removeAll()
    }
}

// MARK: - Inspector Panel View

struct FdCInspectorPanel<Content: View>: View {
    let title: String
    let onClose: () -> Void
    var onBack: (() -> Void)?
    var showBackButton: Bool = false
    @ViewBuilder let content: () -> Content
    
    @StateObject private var navigator = InspectorNavigator()
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header
            header
            
            Divider()
                .padding(.horizontal, 16)
            
            // MARK: Content
            if let page = navigator.stack.last {
                // Navigated page
                page.content
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
            } else {
                // Root content
                content()
            }
        }
        .environmentObject(navigator)
    }
    
    // MARK: - Header
    private var header: some View {
        HStack(spacing: 12) {
            // Titolo
            VStack(alignment: .leading, spacing: 2) {
                Text(navigator.currentTitle ?? title)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Back button (←)
            if navigator.canGoBack || showBackButton {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        if navigator.canGoBack {
                            navigator.pop()
                        } else {
                            onBack?()
                        }
                    }
                }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Close button (×)
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }
}
