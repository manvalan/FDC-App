import SwiftUI

extension ContentView {
    
    var topNavigationBar: some View {
        HStack(spacing: 0) {
            Text("🚊 FdC Manager")
                .font(.system(size: 16, weight: .black))
                .padding(.horizontal, 20)
                .foregroundStyle(.primary)
            
            Divider()
                .frame(height: 24)
            
            HStack(spacing: 8) {
                ForEach(SidebarItem.allCases) { item in
                    tabButton(for: item)
                }
            }
            .padding(.horizontal, 12)
            
            Divider().frame(height: 24)
            
            HStack(spacing: 4) {
                Button(action: { railroad.undo() }) {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .foregroundStyle(railroad.canUndo ? Color.blue : Color.secondary.opacity(0.3))
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
                .disabled(!railroad.canUndo)
                .help("undo".localized)
                
                Button(action: { railroad.redo() }) {
                    Image(systemName: "arrow.uturn.forward.circle.fill")
                        .foregroundStyle(railroad.canRedo ? Color.blue : Color.secondary.opacity(0.3))
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
                .disabled(!railroad.canRedo)
                .help("redo".localized)
            }
            .padding(.horizontal, 12)
            
            if railroadService.isOptimizingInBackground {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Ottimizzazione in corso...").font(.caption).foregroundColor(.secondary)
                    
                    Button(action: { railroadService.cancelOptimization() }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .transition(.opacity)
            }
            
            Spacer()
            
            // Connection Status and global info
            HStack(spacing: 20) {
                if let selection = appState.sidebarSelection, selection == .ai {
                    connectionIndicator
                }
                
                Button(action: { showCredits = true }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .padding(8)
                        .background(Circle().fill(Color.primary.opacity(0.05)))
                }
            }
            .padding(.horizontal, 20)
        }
        .sheet(isPresented: $showCredits) {
            CreditsView()
        }
        .frame(height: 50)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
    
    func tabButton(for item: SidebarItem) -> some View {
        let isSelected = appState.sidebarSelection == item
        
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                appState.sidebarSelection = item
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                Text(item.title)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.15))
                        .matchedGeometryEffect(id: "tab_background", in: tabNameSpace)
                }
            }
            .foregroundColor(isSelected ? .accentColor : .primary.opacity(0.7))
        }
        .buttonStyle(.plain)
    }
    
    var connectionIndicator: some View {
        return Group {
            switch aiService.connectionStatus {
            case .connected:
                Circle().fill(Color.green).frame(width: 8, height: 8)
            case .connecting:
                ProgressView().scaleEffect(0.5).frame(width: 8, height: 8)
            case .unauthorized, .error:
                Circle().fill(Color.red).frame(width: 8, height: 8)
            case .disconnected:
                Circle().fill(Color.gray).frame(width: 8, height: 8)
            }
        }
    }
}
