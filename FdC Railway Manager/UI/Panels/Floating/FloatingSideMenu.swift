import SwiftUI
import UIKit

struct FloatingSideMenu: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var linesManager: LinesManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("MENU")
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(appState.theme.medium)
                    .tracking(2)
                Spacer()
                
                Button(action: { appState.showPanel(.none) }) {
                     Image(systemName: "xmark")
                         .font(.system(size: 14, weight: .bold))
                         .foregroundColor(appState.theme.medium)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 30)
            .padding(.bottom, 16)
            
            ScrollView {
                VStack(spacing: 8) {
                    
                    // GROUP 1: NETWORK & INFRASTRUCTURE
                    Group {
                        MenuRow(title: "Mappa", icon: "map.fill", isSelected: appState.currentMode == .design && appState.sidebarSelection == .stations) {
                            appState.sidebarSelection = .stations
                            appState.currentMode = .design
                            appState.showPanel(.none)
                        }
                        
                        MenuRow(title: "Rete", icon: "building.2.fill", isSelected: appState.sidebarSelection == .stations && appState.activePanel == .inspector) {
                            appState.sidebarSelection = .stations
                            appState.currentMode = .design
                            appState.clearSelection()
                            appState.showPanel(.inspector)
                        }
                        
                        MenuRow(title: "Linee", icon: "arrow.triangle.branch", isSelected: appState.sidebarSelection == .lines) {
                             appState.sidebarSelection = .lines
                             appState.currentMode = .design
                             appState.lineInspectorMode = .infrastructure
                             appState.clearSelection()
                             appState.showPanel(.inspector)
                        }
                        
                        MenuRow(title: "Materiale Rotabile", icon: "tram.fill", isSelected: appState.sidebarSelection == .vehicles) {
                            appState.sidebarSelection = .vehicles
                            appState.currentMode = .design
                            appState.clearSelection()
                            appState.showPanel(.inspector)
                        }
                    }
                    
                    Divider().padding(.vertical, 8).padding(.horizontal, 20)
                    
                    // GROUP 2: OPERATIONS
                    Group {
                        MenuRow(title: "Orari", icon: "calendar.badge.clock", isSelected: appState.currentMode == .schedule && appState.sidebarSelection == .trains) {
                            appState.currentMode = .schedule
                            appState.sidebarSelection = .trains
                            appState.clearSelection()
                            appState.showPanel(.inspector)
                        }
                    }
                    
                    Divider().padding(.vertical, 8).padding(.horizontal, 20)
                    
                    // GROUP 3: SYSTEM
                    Group {
                        MenuRow(title: "Impostazioni", icon: "gearshape.fill", isSelected: appState.sidebarSelection == .settings) {
                            appState.sidebarSelection = .settings
                            appState.showPanel(.inspector)
                        }
                        
                        MenuRow(title: "Import/Export", icon: "square.and.arrow.up", isSelected: appState.sidebarSelection == .io) {
                            appState.sidebarSelection = .io
                            appState.showPanel(.inspector)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .frame(width: Layout.sideMenuWidth)
        .background(appState.theme.surface)
        .cornerRadius(0)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 5, y: 0)
        .edgesIgnoringSafeArea(.vertical)
    }
}
