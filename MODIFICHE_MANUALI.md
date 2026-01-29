# 🔧 Modifiche Manuali Necessarie

## 1. Rendere i binari selezionabili

**File**: `ContentView.swift`
**Linee**: 233-240

**Sostituisci**:
```swift
ForEach(network.edges) { edge in
    VStack(alignment: .leading) {
         Text("\(stationName(for: edge.from)) → \(stationName(for: edge.to))")
         Text("\(Int(edge.distance)) km - \(edge.trackType.rawValue)")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}
```

**Con**:
```swift
ForEach(network.edges) { edge in
    VStack(alignment: .leading) {
         Text("\(stationName(for: edge.from)) → \(stationName(for: edge.to))")
         Text("\(Int(edge.distance)) km - \(edge.trackType.rawValue)")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .contentShape(Rectangle())
    .onTapGesture {
        print("Selected edge: \(edge.id)")
    }
}
.onDelete { indexSet in
    network.edges.remove(atOffsets: indexSet)
}
```

---

## 2. Aggiungere funzione per applicare proposte selezionate

**File**: `ContentView.swift`
**Posizione**: Dopo la riga 1441 (dopo la funzione `applyProposal`)

**Aggiungi**:
```swift
private func applySelectedProposals(_ selectedProposals: [ProposedLine], createTrains: Bool) {
    for pline in selectedProposals {
        // 1. Create Line
        let lineId = UUID().uuidString
        let stops = pline.stationSequence.map { sid -> RelationStop in
            let node = network.nodes.first(where: { $0.id == sid })
            let dwell = (node?.type == .interchange) ? 5 : 3
            return RelationStop(stationId: sid, minDwellTime: dwell)
        }
        
        let newLine = RailwayLine(
            id: lineId,
            name: pline.name,
            color: pline.color ?? "#007AFF",
            originId: pline.stationSequence.first ?? "",
            destinationId: pline.stationSequence.last ?? "",
            stops: stops
        )
        network.lines.append(newLine)
        
        // 2. Create sample trains ONLY if requested
        if createTrains {
            let freq = pline.frequencyMinutes > 0 ? pline.frequencyMinutes : 60
            let startHour = 6
            let endHour = 22
            
            let calendar = Calendar.current
            let baseDate = calendar.startOfDay(for: Date())
            
            for hour in stride(from: startHour, to: endHour, by: 1) {
                for min in stride(from: 0, to: 60, by: freq) {
                    let departureTime = calendar.date(bySettingHour: hour, minute: min, second: 0, of: baseDate)
                    let trainNum = 1000 + network.lines.count * 100 + (hour * 10) + (min / 10)
                    
                    let newTrain = Train(
                        id: UUID(),
                        number: trainNum,
                        name: "\(pline.name) - \(trainNum)",
                        type: "Regionale",
                        maxSpeed: 120,
                        priority: 5,
                        lineId: lineId,
                        departureTime: departureTime,
                        stops: stops
                    )
                    trainManager.trains.append(newTrain)
                }
            }
        }
    }
    
    proposedLines = []
    let trainsMsg = createTrains ? " con treni di esempio" : ""
    aiResult = "Creazione completata: \(selectedProposals.count) linee aggiunte\(trainsMsg)."
    trainManager.validateSchedules(with: network)
}
```

---

## 3. Eliminare file temporaneo

Dopo aver completato le modifiche sopra, elimina:
- `TEMP_ADD_TO_CONTENTVIEW.swift`

---

## ✅ Cosa è già stato fatto automaticamente:

1. ✅ Rimossi treni fantasma dalla mappa
2. ✅ Rimossi treni fantasma dal grafico
3. ✅ Creata `LineProposalView.swift` con:
   - Checkbox per selezione singola linee
   - Nomi reali stazioni (non ID)
   - Toggle per creare/non creare treni
4. ✅ Aggiornato `ScheduleProposer.swift` con campo `stops`
5. ✅ Aggiornato callback in ContentView per passare parametro `createTrains`

---

## 🔍 Problema treni non visibili

I treni dovrebbero essere visibili nella tab "Treni" (TrainsListView alle righe 287-400 di ContentView.swift).
Se non compaiono, verifica:
1. Che `trainManager.trains` contenga effettivamente i treni
2. Che i treni abbiano un `lineId` valido
3. Controlla la console per eventuali errori di caricamento
