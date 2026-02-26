import SwiftUI
import UIKit

struct LineScheduleSummaryView: View {
    let line: TrainRoute
    @EnvironmentObject var linesManager: LinesManager
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // AGGIUNTO: Tasto per entrare in modalità generazione/modifica orario
                Button(action: {
                    withAnimation {
                        appState.creationRouteId = line.id
                    }
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("GESTISCI ORARIO")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(appState.theme.accent)
                    .cornerRadius(12)
                    .shadow(color: appState.theme.accent.opacity(0.3), radius: 5, y: 3)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Prossime Corse").font(.headline).foregroundColor(appState.theme.dark)
                    let trains = linesManager.trains.filter { $0.routeId == line.id }.sorted(by: { $0.departureTime ?? Date() < $1.departureTime ?? Date() })
                    if trains.isEmpty {
                        Text("Non ci sono corse programmate.")
                            .font(.caption).foregroundColor(appState.theme.medium)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(appState.theme.light.opacity(0.1))
                            .cornerRadius(8)
                    } else {
                         LazyVStack(spacing: 8) {
                             ForEach(trains) { train in
                                 HStack {
                                     Text(train.departureTime ?? Date(), style: .time)
                                         .font(.system(.subheadline, design: .monospaced))
                                         .foregroundColor(appState.theme.medium)
                                     Text(train.name)
                                         .font(.subheadline.bold())
                                         .foregroundColor(appState.theme.dark)
                                     Spacer()
                                 }
                                 .padding(10)
                                 .background(appState.theme.light.opacity(0.3))
                                 .cornerRadius(8)
                             }
                         }
                    }
                }
            }
        }
    }
}
