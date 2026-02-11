import SwiftUI

struct VisualizationSettingsView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showGrid: Bool
    
    var body: some View {
        Form {
            Section(header: Text("general_options".localized)) {
                Toggle("show_grid".localized, isOn: $showGrid)
                Toggle("use_cloud_ai".localized, isOn: $appState.useCloudAI)
            }
            
            Section(header: Text("Tema Progetto (Monocromatico Gray)")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Palette ufficiale FdC Railway Manager").font(.caption).foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        colorSwatch(color: .fdcGreyBackground, name: "BG")
                        colorSwatch(color: .fdcGreySurface, name: "SURF")
                        colorSwatch(color: .fdcGreyLight, name: "LGT")
                        colorSwatch(color: .fdcGreyMedium, name: "MED")
                        colorSwatch(color: .fdcGreyDark, name: "DRK")
                        colorSwatch(color: .fdcGreyLine, name: "LINE")
                    }
                    
                    Text("Questo tema è ora lo standard per tutta l'interfaccia.")
                        .font(.caption2)
                        .italic()
                        .foregroundColor(.fdcGreyMedium)
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("sizes".localized)) {
                VStack(alignment: .leading) {
                    Text(String(format: "line_width_px".localized, Int(appState.globalLineWidth)))
                    Slider(value: $appState.globalLineWidth, in: 2...15, step: 0.5)
                }
                
                VStack(alignment: .leading) {
                    Text(String(format: "font_size_pt".localized, Int(appState.globalFontSize)))
                    Slider(value: $appState.globalFontSize, in: 8...24, step: 1)
                }
            }
            
            Section(header: Text("track_widths_map".localized)) {
                VStack(alignment: .leading) {
                    Text(String(format: "track_single_px".localized, appState.trackWidthSingle))
                    Slider(value: $appState.trackWidthSingle, in: 0.5...5.0, step: 0.1)
                }
                
                VStack(alignment: .leading) {
                    Text(String(format: "track_double_px".localized, appState.trackWidthDouble))
                    Slider(value: $appState.trackWidthDouble, in: 1.0...8.0, step: 0.1)
                }
                
                VStack(alignment: .leading) {
                    Text(String(format: "track_regional_px".localized, appState.trackWidthRegional))
                    Slider(value: $appState.trackWidthRegional, in: 0.5...6.0, step: 0.1)
                }
                
                VStack(alignment: .leading) {
                    Text(String(format: "track_highspeed_px".localized, appState.trackWidthHighSpeed))
                    Slider(value: $appState.trackWidthHighSpeed, in: 1.0...8.0, step: 0.1)
                }
                
                Button("reset_defaults".localized) {
                    appState.trackWidthSingle = 1.0
                    appState.trackWidthDouble = 3.0
                    appState.trackWidthRegional = 1.8
                    appState.trackWidthHighSpeed = 2.5
                }
                .foregroundColor(.orange)
            }
            
            Section(header: Text("map_preview".localized)) {
                VStack(spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("example_station".localized)
                                .font(.system(size: appState.globalFontSize, weight: .black))
                            Text("regional_line".localized)
                                .font(.system(size: appState.globalFontSize * 0.8))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Circle()
                            .stroke(Color.black, lineWidth: 2)
                            .background(Circle().fill(Color.white))
                            .frame(width: 20, height: 20)
                    }
                    
                    // Line Example
                    HStack {
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: 100, height: appState.globalLineWidth)
                            .cornerRadius(appState.globalLineWidth / 2)
                        
                        Text("edge_representation".localized)
                            .font(.system(size: appState.globalFontSize * 0.9))
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .navigationTitle("visualization".localized)

    }
    
    private func colorSwatch(color: Color, name: String) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 6)
                .fill(color)
                .frame(width: 45, height: 45)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.fdcGreyLine.opacity(0.1), lineWidth: 0.5))
            Text(name)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.fdcGreyMedium)
        }
    }
}
