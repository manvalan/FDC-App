# RailwayScheduleOptimizer - Manuale Tecnico

Questo documento descrive in dettaglio il funzionamento del motore di ottimizzazione `RailwayScheduleOptimizer.swift`.
L'architettura segue una pipeline a **7 Step** progettata per risolvere progressivamente i conflitti ferroviari, partendo da eurische locali (Greedy) fino ad algoritmi globali (AI) e raffinamenti stocastici (Genetici).

---

## Architecture Overview

La classe `RailwayScheduleOptimizer` è un attore (`actor`) singleton che coordina l'intero processo.
Il metodo principale è `executePipeline(...)`, che orchestra le chiamate alle sotto-funzioni in sequenza.

```swift
func executePipeline(newTrains, existingTrains, network, useAI) -> [Train]
```

---

## 1. Funzione: `optimizeDepartureTimes` (Step 1)

### Scopo
Risolvere i conflitti "macro" spostando l'orario di partenza dei nuovi treni. È la prima linea di difesa.

### Codice
```swift
private func optimizeDepartureTimes(_ newTrains: [Train], existingTrains: [Train], network: RailwayNetwork) -> [Train] {
    var optimized: [Train] = []
    let tempManager = TrainManager()
    
    // Iteriamo su ogni nuovo treno in sequenza
    for (idx, train) in newTrains.enumerated() {
        var bestTrain = train
        var minConflicts = Int.max
        
        // Range di shift da testare: prima 0, poi piccoli, poi grandi
        let shifts = [0, 5, -5, 10, -10, 15, -15, 20, -20]
        
        for shift in shifts {
            // Crea candidato con orario spostato
            var candidate = train
            if let dep = train.departureTime {
                candidate.departureTime = Calendar.current.date(byAdding: .minute, value: shift, to: dep)
            }
            
            // Simulazione: Ricalcola orari fisici per l'intero scenario
            tempManager.trains = existingTrains + optimized + [candidate]
            tempManager.refreshSchedules(with: network)
            
            // Conta conflitti
            let count = conflictManager.calculateConflicts(network: network, trains: tempManager.trains).count
            
            // Se migliora, salva
            if count < minConflicts {
                minConflicts = count
                bestTrain = candidate
                if count == 0 { break } // Slot perfetto trovato
            }
        }
        // "Congela" il treno migliore per i prossimi cicli
        optimized.append(bestTrain)
    }
    return optimized
}
```

### Logica Dettagliata
1.  **Accumulo Incrementale**: I treni vengono ottimizzati uno alla volta. Il treno $T_n$ deve rispettare gli orari congelati di $T_0...T_{n-1}$ oltre ai treni esistenti.
2.  **Grid Search Locale**: Per ogni treno, si provano 9 varianti temporali (`shifts`).
3.  **Simulazione Fisica (`refreshSchedules`)**: Fondamentale. Non basta cambiare `departureTime`; bisogna ricalcolare quando il treno passerà effettivamente in ogni stazione successiva per rilevare i conflitti reali.
4.  **Criterio Greedy**: Appena si trova uno slot con 0 conflitti, si accetta e si passa al treno successivo. Se non si trova 0, si tiene il "meno peggio".

---

## 2. Funzione: `analyzeHotspots` (Step 3)

### Scopo
Identificare statisticamente DOVE avvengono i conflitti residui per capire quali stazioni o tratte sono sature. Indispensabile per decidere dove far aspettare i treni.

### Codice
```swift
private func analyzeHotspots(conflicts: [RailwayConflict]) -> [String: Int] {
    var heatmap: [String: Int] = [:]
    
    for conflict in conflicts {
        let location = conflict.locationId
        if location.starts(with: "LINE::") {
            // Se conflitto in linea (es. LINE::Roma-Napoli), segna entrambi i nodi
            let segment = location.replacingOccurrences(of: "LINE::", with: "")
            let nodes = segment.split(separator: "-").map(String.init)
            for node in nodes {
                heatmap[node, default: 0] += 1
            }
        } else {
            // Se conflitto in stazione, segna la stazione
            heatmap[location, default: 0] += 1
        }
    }
    return heatmap
}
```

### Logica Dettagliata
1.  **Input**: Una lista di oggetti `RailwayConflict` generati dal `ConflictManager`.
2.  **Parsing Location**: I conflitti possono avvenire in una stazione (ID semplice) o in una tratta (`LINE::A-B`).
3.  **Attribuzione**: Se il conflitto è in tratta, "incolpiamo" entrambe le stazioni agli estremi. Se in stazione, incolpiamo la stazione.
4.  **Output**: Una mappa `[StationID: Count]` che ci dice quante volte una stazione è coinvolta in un conflitto. Più alto è il numero, più è probabile che serva "rallentare" il traffico prima di arrivare lì.

---

## 3. Funzione: `findBestHubBefore` (Step 4 Helper)

### Scopo
Trovare una stazione precedente adatta (Hub) dove un treno possa attendere in sicurezza per evitare di entrare in un Hotspot saturo.

### Codice
```swift
private func findBestHubBefore(train: Train, targetIndex: Int, network: RailwayNetwork) -> Int? {
    // Scorriamo all'indietro dalla fermata precedente al target
    let searchRange = (0..<targetIndex).reversed()
    
    for idx in searchRange {
        let stationId = train.stops[idx].stationId
        if let node = network.nodes.first(where: { $0.id == stationId }) {
            // Definizione di Hub:
            // 1. Più di 2 binari (permette sorpassi/incroci)
            // 2. Oppure dichiarato esplicitamente come Interchange
            if (node.platforms ?? 1) > 2 || node.type == .interchange {
                return idx
            }
        }
    }
    return nil
}
```

### Logica Dettagliata
1.  **Ricerca Backwards**: Si parte dalla stazione problematica (Hotspot) e si torna indietro lungo il percorso del treno.
2.  **Criterio di Idoneità**: Non tutte le stazioni vanno bene per aspettare.
    *   Una stazioncina a binario singolo bloccherebbe l'intera linea se ci fermassimo lì.
    *   Serve una stazione con **binari di precedenza** (Platforms > 2) o un nodo di interscambio (`.interchange`).
3.  **Risultato**: Ritorna l'`index` nella lista `train.stops` dove inserire l'attesa.

---

## 4. Funzione: `applyHubWaits` (Step 5)

### Scopo
Applicare concretamente le "soste tattiche" (Wait Strategy) ai treni che attraversano Hotspot.

### Codice
```swift
private func applyHubWaits(...) -> [Train] {
    var processedTrains = trains
    // Identifichiamo i treni "colpevoli" (coinvolti nei conflitti)
    let conflictingTrainIds = Set(conflicts.flatMap { [$0.trainAId, $0.trainBId] })
    
    for i in processedTrains.indices {
        // Ottimizziamo solo i treni problematici
        if !conflictingTrainIds.contains(processedTrains[i].id) { continue }
        
        let train = processedTrains[i]
        
        // Per ogni fermata del treno...
        for (stopIndex, stop) in train.stops.enumerated() {
            // Se la fermata è un Hotspot (zona calda)...
            if hotspots[stop.stationId] != nil {
                // ...trova un Hub PRIMA di arrivarci
                if let hubIndex = findBestHubBefore(train: train, targetIndex: stopIndex, network: network) {
                    
                    // AZIONE: Aumenta il tempo di sosta minima (minDwellTime)
                    // Questo costringerà il treno a fermarsi (es. 7 min extra) e ripartire dopo.
                    processedTrains[i].stops[hubIndex].minDwellTime += 7
                    
                    break // Applicata una pezza, passiamo al prossimo treno
                }
            }
        }
    }
    return processedTrains
}
```

### Logica Dettagliata
1.  **Targeting Chirurgico**: Lavora solo sui treni che hanno effettivamente generato conflitti.
2.  **Logica Proattiva**: Invece di risolvere il conflitto *sul punto*, cerca di prevenirlo rallentando il treno *prima* che ci arrivi.
3.  **Modifica Dati**: Incrementa `minDwellTime`. Questo è il parametro che il motore fisico (`refreshSchedules`) usa per calcolare l'orario di ripartenza. Incrementandolo, spostiamo in avanti tutta la schedulazione successiva del treno.

---

## 5. Funzione: `performCloudOptimization` (Step 6)

### Scopo
Delegare i problemi complessi all'Intelligenza Artificiale sul server.

### Codice
```swift
private func performCloudOptimization(...) async -> [RailwayAIResolution] {
    // Preparazione Dati Puliti
    let tempManager = TrainManager()
    tempManager.trains = existingTrains + trains
    tempManager.refreshSchedules(with: network) // Assicura che l'AI veda lo stato "vero"
    
    // Calcolo Conflitti per il Payload
    let currentConflicts = conflictManager.calculateConflicts(...)
    
    // Se non ci sono conflitti, non disturbare l'AI
    if currentConflicts.isEmpty { return [] }
    
    // Creazione Request e Chiamata
    let req = aiService.createRequest(network: network, trains: tempManager.trains, conflicts: currentConflicts)
    
    // Esecuzione
    let response = try await aiService.optimize(request: req)
    return response.resolutions ?? []
}
```

### Logica Dettagliata
1.  **State Consistency**: Prima di chiamare l'AI, esegue un `refreshSchedules`. Questo garantisce che i tempi di arrivo/partenza inviati nel JSON siano fisicamente corretti e includano le modifiche fatte negli Step precedenti (Time Shift + Hub Waits).
2.  **Conditional Execution**: Chiama il server solo se persistono conflitti.
3.  **Error Handling**: Gestisce eventuali errori di rete o timeout restituendo una lista vuota (fallback graceful).

---

## 6. Funzione: `applyAIResolutions` (Step 6 Helper)

### Scopo
Integrare le soluzioni suggerite dall'AI (Time Adjustments + Dwell Delays) nei treni locali.

### Codice
```swift
private func applyAIResolutions(_ trains: [Train], resolutions: [RailwayAIResolution]) -> [Train] {
    var updated = trains
    for res in resolutions {
        // Mapping by UUID (Server ID -> Local UUID)
        if let idx = updated.firstIndex(where: { aiService.getTrainUUID(optimizerId: res.train_id) == $0.id }) {
            
            // 1. Applica Time Shift (modifica orario partenza base)
            if let dep = updated[idx].departureTime {
                updated[idx].departureTime = dep.addingTimeInterval(res.time_adjustment_min * 60)
            }
            
            // 2. Applica Dwell Delays (modifica soste intermedie)
            if let delays = res.dwell_delays {
                for (sIdx, delay) in delays.enumerated() where sIdx < updated[idx].stops.count {
                    if delay > 0 {
                        // Importante: Arrotondiamo per eccesso (ceil) e aggiungiamo al Min Dwell Time
                        updated[idx].stops[sIdx].minDwellTime += Int(ceil(delay))
                    }
                }
            }
        }
    }
    return updated
}
```

### Logica Dettagliata
1.  **Identificazione**: Usa `aiService.getTrainUUID` per tradurre l'ID numerico dell'AI (0, 1, 2...) nell'UUID Swift del treno.
2.  **Applicazione Precisa**:
    *   `time_adjustment_min`: Viene aggiunto aritmeticamente all'orario di partenza.
    *   `dwell_delays`: Vengono applicati alle fermate specifiche. Questo è potente perché permette all'AI di dire "fermati 5 minuti in più alla stazione 3".

---

## 7. Funzione: `refreshPhysicalSchedules` (Utility)

### Scopo
Sincronizzare la "Fisica" con la "Logica". Ogni volta che cambiamo un parametro (partenza o dwell), dobbiamo ricalcolare tutto il viaggio.

### Codice
```swift
private func refreshPhysicalSchedules(_ trains: [Train], existingTrains: [Train], network: RailwayNetwork) -> [Train] {
    let tempManager = TrainManager()
    tempManager.trains = existingTrains + trains
    
    // Engine Fisico
    tempManager.refreshSchedules(with: network)
    
    // Estrazione
    let updatedIds = Set(trains.map { $0.id })
    return tempManager.trains.filter { updatedIds.contains($0.id) }
}
```

### Logica Dettagliata
1.  **Contesto Globale**: Inserisce i nostri treni in un contesto completo (con i treni esistenti) per simulare eventuali interazioni di segnalamento (se supportate in futuro) o calcoli di velocità.
2.  **Calling Engine**: `refreshSchedules` (in `TrainManager`) scorre fermata per fermata, calcolando: `Arrivo = PartenzaPrecedente + (Distanza / Velocità)`.
3.  **Filtraggio**: Ritorna solo i treni che ci interessano, con i campi `arrival`/`departure` di ogni `stop` aggiornati.

---
**Autore:** Antigravity AI Assistant
**Data:** 31 Gennaio 2026
