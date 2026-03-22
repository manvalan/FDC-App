import SwiftUI

struct TrainTrackParametersView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Form {
            Section(header: Text("default_train_params".localized)) {
                Text("new_train_params_desc".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 15) {
                    // Regionale
                    VStack(alignment: .leading) {
                        Text("regional_train".localized)
                            .font(.headline)
                        
                        HStack {
                            Text("max_speed_label".localized)
                            Spacer()
                            Text("\(Int(appState.regionalMaxSpeed)) km/h")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $appState.regionalMaxSpeed, in: 60...160, step: 10)
                        
                        HStack {
                            Text("acceleration_label".localized)
                            Spacer()
                            Text(String(format: "%.2f m/s²", appState.regionalAcceleration))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $appState.regionalAcceleration, in: 0.1...2.0, step: 0.1)
                        
                        HStack {
                            Text("deceleration_label".localized)
                            Spacer()
                            Text(String(format: "%.2f m/s²", appState.regionalDeceleration))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $appState.regionalDeceleration, in: 0.1...2.0, step: 0.1)
                        
                        HStack {
                            Text("priority_label".localized)
                            Spacer()
                            Text("\(Int(appState.regionalPriority))")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $appState.regionalPriority, in: 1...10, step: 1)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Intercity
                    VStack(alignment: .leading) {
                        Text("intercity_train".localized)
                            .font(.headline)
                        
                        HStack {
                            Text("max_speed_label".localized)
                            Spacer()
                            Text("\(Int(appState.intercityMaxSpeed)) km/h")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $appState.intercityMaxSpeed, in: 80...200, step: 10)
                        
                        HStack {
                            Text("acceleration_label".localized)
                            Spacer()
                            Text(String(format: "%.2f m/s²", appState.intercityAcceleration))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $appState.intercityAcceleration, in: 0.1...2.0, step: 0.1)
                        
                        HStack {
                            Text("deceleration_label".localized)
                            Spacer()
                            Text(String(format: "%.2f m/s²", appState.intercityDeceleration))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $appState.intercityDeceleration, in: 0.1...2.0, step: 0.1)
                        
                        HStack {
                            Text("priority_label".localized)
                            Spacer()
                            Text("\(Int(appState.intercityPriority))")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $appState.intercityPriority, in: 1...10, step: 1)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Alta Velocità
                    VStack(alignment: .leading) {
                        Text("highspeed_train".localized)
                            .font(.headline)
                        
                        HStack {
                            Text("max_speed_label".localized)
                            Spacer()
                            Text("\(Int(appState.highSpeedMaxSpeed)) km/h")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $appState.highSpeedMaxSpeed, in: 150...350, step: 10)
                        
                        HStack {
                            Text("acceleration_label".localized)
                            Spacer()
                            Text(String(format: "%.2f m/s²", appState.highSpeedAcceleration))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $appState.highSpeedAcceleration, in: 0.1...2.0, step: 0.1)
                        
                        HStack {
                            Text("deceleration_label".localized)
                            Spacer()
                            Text(String(format: "%.2f m/s²", appState.highSpeedDeceleration))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $appState.highSpeedDeceleration, in: 0.1...2.0, step: 0.1)
                        
                        HStack {
                            Text("priority_label".localized)
                            Spacer()
                            Text("\(Int(appState.highSpeedPriority))")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $appState.highSpeedPriority, in: 1...10, step: 1)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Button("reset_defaults".localized) {
                    // Regionale
                    appState.regionalMaxSpeed = 120
                    appState.regionalAcceleration = 0.5
                    appState.regionalDeceleration = 0.5
                    appState.regionalPriority = 3
                    
                    // Intercity
                    appState.intercityMaxSpeed = 160
                    appState.intercityAcceleration = 0.7
                    appState.intercityDeceleration = 0.7
                    appState.intercityPriority = 6
                    
                    // Alta Velocità
                    appState.highSpeedMaxSpeed = 300
                    appState.highSpeedAcceleration = 1.0
                    appState.highSpeedDeceleration = 1.0
                    appState.highSpeedPriority = 10
                }
                .foregroundColor(.orange)
            }
            
            Section(header: Text("track_speed_limits_section".localized)) {
                Text("track_speed_limits_desc".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("track_single".localized + ":")
                        Spacer()
                        Text("\(Int(appState.singleTrackMaxSpeed)) km/h")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $appState.singleTrackMaxSpeed, in: 60...160, step: 10)
                }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("track_double".localized + ":")
                        Spacer()
                        Text("\(Int(appState.doubleTrackMaxSpeed)) km/h")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $appState.doubleTrackMaxSpeed, in: 80...200, step: 10)
                }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("track_regional".localized + ":")
                        Spacer()
                        Text("\(Int(appState.regionalTrackMaxSpeed)) km/h")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $appState.regionalTrackMaxSpeed, in: 100...250, step: 10)
                }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("track_highspeed".localized + ":")
                        Spacer()
                        Text("\(Int(appState.highSpeedTrackMaxSpeed)) km/h")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $appState.highSpeedTrackMaxSpeed, in: 200...350, step: 10)
                }
                
                Button("reset_defaults".localized) {
                    appState.singleTrackMaxSpeed = 100
                    appState.doubleTrackMaxSpeed = 160
                    appState.regionalTrackMaxSpeed = 200
                    appState.highSpeedTrackMaxSpeed = 300
                }
                .foregroundColor(.orange)
            }
        }
        .navigationTitle("train_track_params_title".localized)

    }
}
