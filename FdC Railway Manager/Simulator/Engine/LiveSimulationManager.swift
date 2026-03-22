import Foundation
import Combine
import SwiftUI

/// Gestisce la simulazione dinamica in tempo reale del traffico ferroviario.
/// Permette di controllare il tempo (pausa, play, accelerazione) e di monitorare
/// lo stato di avanzamento dei treni rispetto all'orario teorico.
@MainActor
final class LiveSimulationManager: ObservableObject {
    
    @Published var isRunning: Bool = false
    @Published var timeMultiplier: Double = 1.0 // 1x, 5x, 10x, 30x...
    @Published var currentSimTime: Date
    @Published var showLiveSimulation: Bool = false
    @Published var log = SimulationLogManager()
    
    private var timer: AnyCancellable?
    private var lastProcessedTime: Date?
    private let tickInterval: TimeInterval = 0.5 // Update 2 times per second
    
    init() {
        // Inizializza con l'orario attuale (normalizzato al giorno corrente)
        self.currentSimTime = Date().normalized()
    }
    
    func start() {
        isRunning = true
        setupTimer()
    }
    
    func pause() {
        isRunning = false
        timer?.cancel()
    }
    
    func stop() {
        pause()
        currentSimTime = Date().normalized()
    }
    
    func toggle() {
        if isRunning { pause() } else { start() }
    }
    
    func stepForward(seconds: TimeInterval) {
        currentSimTime = currentSimTime.addingTimeInterval(seconds)
    }
    
    private func setupTimer() {
        timer?.cancel()
        timer = Timer.publish(every: tickInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isRunning else { return }
                // Avanza il tempo in base al moltiplicatore
                let delta = self.tickInterval * self.timeMultiplier
                let oldTime = self.currentSimTime
                self.currentSimTime = self.currentSimTime.addingTimeInterval(delta)
                self.detectEvents(from: oldTime, to: self.currentSimTime)
            }
    }
    
    private func detectEvents(from start: Date, to end: Date) {
        // Accediamo agli schedule tramite AppState.shared (o passato nel costruttore)
        // Per semplicità qui assumiamo che il manager possa vedere i treni
        let schedules = AppState.shared.simulator.schedules
        
        for sch in schedules {
            for stop in sch.stops {
                // Rileva Arrivo
                if let arrival = stop.arrivalTime, arrival > start && arrival <= end {
                    log.addLog("Treno \(sch.trainName) arrivato a \(stop.stationName)", type: .success, timestamp: arrival)
                }
                // Rileva Partenza
                if let departure = stop.departureTime, departure > start && departure <= end {
                    log.addLog("Treno \(sch.trainName) partito da \(stop.stationName)", type: .info, timestamp: departure)
                }
            }
        }
    }
}

extension Date {
    /// Trasforma un orario in formato "HH:mm" in una Date normalizzata all'oggi.
    static func from(timeString: String) -> Date? {
        let parts = timeString.split(separator: ":")
        guard parts.count >= 2, 
              let hour = Int(parts[0]), 
              let minute = Int(parts[1]) else { return nil }
        
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour
        comps.minute = minute
        comps.second = parts.count > 2 ? Int(parts[2]) : 0
        return calendar.date(from: comps)
    }
}
