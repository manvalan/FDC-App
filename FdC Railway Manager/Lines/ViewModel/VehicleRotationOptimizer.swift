//
//  VehicleRotationOptimizer.swift
//  FdC Railway Manager
//
//  Ottimizzatore per assegnare il minor numero di mezzi fisici per coprire tutte le corse.
//  Algoritmo: Trova la sequenza di treni che un singolo mezzo può coprire (A→B→A→B...)
//

import Foundation
import SwiftUI

/// Rappresenta un turno di lavoro per un mezzo fisico
struct VehicleRotation: Identifiable {
    let id = UUID()
    var vehicleId: UUID
    var trainIds: [UUID]  // Sequenza di treni che questo mezzo copre
    var startTime: Date?
    var endTime: Date?
    
    var duration: TimeInterval? {
        guard let start = startTime, let end = endTime else { return nil }
        return end.timeIntervalSince(start)
    }
}

class VehicleRotationOptimizer {
    
    /// Ottimizza l'assegnazione di mezzi a una lista di treni
    /// - Parameters:
    ///   - trains: Lista di treni da assegnare
    ///   - vehicles: Lista di mezzi disponibili
    ///   - minimumTurnaroundTime: Tempo minimo di giro macchina (in minuti)
    /// - Returns: Dizionario vehicleId -> [trainIds] che rappresenta l'assegnazione ottimale
    func optimizeVehicleAssignment(
        trains: [Train],
        vehicles: [Vehicle],
        minimumTurnaroundTime: Int = 15
    ) -> [UUID: [UUID]] {
        
        print("🔧 [VehicleRotation] Starting optimization")
        print("   Trains: \(trains.count)")
        print("   Vehicles: \(vehicles.count)")
        print("   Min turnaround: \(minimumTurnaroundTime)min")
        
        // 1. Filtra solo i treni con orario di partenza definito
        let scheduledTrains = trains.filter { $0.departureTime != nil }
            .sorted { ($0.departureTime ?? .distantPast) < ($1.departureTime ?? .distantPast) }
        
        print("   Scheduled trains: \(scheduledTrains.count)")
        
        // 2. Raggruppa per linea (direzione)
        var trainsByDirection: [String: [Train]] = [:]
        for train in scheduledTrains {
            let key = "\(train.stops.first?.stationId ?? "")->\(train.stops.last?.stationId ?? "")"
            trainsByDirection[key, default: []].append(train)
        }
        
        print("   Directions: \(trainsByDirection.count)")
        
        // 3. Crea catene di treni (rotazioni)
        var rotations: [VehicleRotation] = []
        var assignedTrains: Set<UUID> = []
        
        // Per ogni treno non ancora assegnato, prova a creare una catena
        for train in scheduledTrains where !assignedTrains.contains(train.id) {
            var rotation = createRotation(
                startingFrom: train,
                allTrains: scheduledTrains,
                assigned: &assignedTrains,
                trainsByDirection: trainsByDirection,
                minimumTurnaroundTime: minimumTurnaroundTime
            )
            
            if !rotation.trainIds.isEmpty {
                rotations.append(rotation)
            }
        }
        
        print("   Created rotations: \(rotations.count)")
        
        // 4. Assegna veicoli alle rotazioni
        var result: [UUID: [UUID]] = [:]
        
        // Se abbiamo abbastanza veicoli, assegna uno per rotazione
        if vehicles.count >= rotations.count {
            for (i, rotation) in rotations.enumerated() {
                let vehicle = vehicles[i]
                result[vehicle.id] = rotation.trainIds
                print("   Vehicle \(vehicle.name): \(rotation.trainIds.count) trains")
            }
        } else {
            // Se non abbiamo abbastanza veicoli, crea veicoli virtuali
            // (il sistema creerà automaticamente nuovi mezzi)
            for rotation in rotations {
                // Usa il primo veicolo disponibile come template
                let templateVehicle = vehicles.first ?? createDefaultVehicle()
                result[templateVehicle.id] = rotation.trainIds
            }
            print("   ⚠️ Not enough vehicles! Need \(rotations.count), have \(vehicles.count)")
        }
        
        return result
    }
    
    /// Crea una rotazione partendo da un treno iniziale
    private func createRotation(
        startingFrom initialTrain: Train,
        allTrains: [Train],
        assigned: inout Set<UUID>,
        trainsByDirection: [String: [Train]],
        minimumTurnaroundTime: Int
    ) -> VehicleRotation {
        
        var trainIds: [UUID] = [initialTrain.id]
        assigned.insert(initialTrain.id)
        
        var currentTrain = initialTrain
        var iterations = 0
        let maxIterations = 100 // Previeni loop infiniti
        
        // Continua ad aggiungere treni finché possibile
        while iterations < maxIterations {
            iterations += 1
            
            // Trova il prossimo treno compatibile
            guard let nextTrain = findNextCompatibleTrain(
                after: currentTrain,
                in: allTrains,
                assigned: assigned,
                trainsByDirection: trainsByDirection,
                minimumTurnaroundTime: minimumTurnaroundTime
            ) else {
                break
            }
            
            trainIds.append(nextTrain.id)
            assigned.insert(nextTrain.id)
            currentTrain = nextTrain
        }
        
        // Crea un nuovo veicolo per questa rotazione (verrà assegnato dopo)
        return VehicleRotation(
            vehicleId: UUID(),
            trainIds: trainIds,
            startTime: initialTrain.departureTime,
            endTime: currentTrain.stops.last?.arrival
        )
    }
    
    /// Trova il prossimo treno compatibile dopo quello corrente
    private func findNextCompatibleTrain(
        after currentTrain: Train,
        in allTrains: [Train],
        assigned: Set<UUID>,
        trainsByDirection: [String: [Train]],
        minimumTurnaroundTime: Int
    ) -> Train? {
        
        // Tempo di arrivo alla stazione finale
        guard let arrivalTime = currentTrain.stops.last?.arrival else { return nil }
        
        // Stazione finale del treno corrente
        let currentEndStation = currentTrain.stops.last?.stationId ?? ""
        
        // Tempo minimo per il prossimo treno
        let minimumNextDeparture = arrivalTime.addingTimeInterval(Double(minimumTurnaroundTime * 60))
        
        // Cerca treni che partono dalla stazione di arrivo
        let candidateTrains = allTrains.filter { train in
            guard !assigned.contains(train.id) else { return false }
            guard let trainDeparture = train.departureTime else { return false }
            
            // Deve partire dalla stazione dove è arrivato il treno corrente
            let trainStartStation = train.stops.first?.stationId ?? ""
            guard trainStartStation == currentEndStation else { return false }
            
            // Deve partire dopo il tempo minimo
            return trainDeparture >= minimumNextDeparture
        }
        
        // Prendi il primo disponibile (più vicino nel tempo)
        return candidateTrains.sorted { ($0.departureTime ?? .distantPast) < ($1.departureTime ?? .distantPast) }.first
    }
    
    /// Applica l'assegnazione ottimizzata ai treni
    func applyOptimizedAssignment(
        _ assignment: [UUID: [UUID]],
        to trains: inout [Train],
        manager: LinesManager
    ) {
        print("🚂 [VehicleRotation] Applying assignment to \(trains.count) trains")
        
        for (vehicleId, trainIds) in assignment {
            for trainId in trainIds {
                if let index = trains.firstIndex(where: { $0.id == trainId }) {
                    trains[index].vehicleId = vehicleId
                }
                
                // Aggiorna anche nel manager
                if let managerIndex = manager.trains.firstIndex(where: { $0.id == trainId }) {
                    manager.trains[managerIndex].vehicleId = vehicleId
                }
            }
        }
        
        print("✅ [VehicleRotation] Assignment completed")
    }
    
    /// Crea un veicolo di default per quando non ci sono veicoli disponibili
    private func createDefaultVehicle() -> Vehicle {
        Vehicle(
            name: "Mezzo Generico",
            model: "Standard",
            length: 200,
            maxSpeed: 160,
            acceleration: 0.5,
            deceleration: 0.4
        )
    }
    
    /// Suggerisce quanti mezzi fisici sono necessari per una lista di treni
    func suggestVehicleCount(
        for trains: [Train],
        minimumTurnaroundTime: Int = 15
    ) -> Int {
        // Crea un veicolo temporaneo per l'analisi
        let dummyVehicle = createDefaultVehicle()
        
        let assignment = optimizeVehicleAssignment(
            trains: trains,
            vehicles: [dummyVehicle],
            minimumTurnaroundTime: minimumTurnaroundTime
        )
        
        return assignment.count
    }
}
