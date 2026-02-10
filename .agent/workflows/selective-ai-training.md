---
description: Guida all'ottimizzazione AI focalizzata su singola linea e treni di sfondo
---

# Guida all'Integrazione App: Ottimizzazione Selettiva

Questa guida spiega come adattare l'applicazione Swift per utilizzare la nuova funzionalità di "Ottimizzazione Focalizzata", che permette di ottimizzare una specifica linea ignorando il calcolo complesso per gli altri treni (trattati come ostacoli statici).

## 💡 Il Concetto
Invece di chiedere all'AI di ottimizzare 50 treni contemporaneamente (causando crash o lentezza), ora inviamo **tutti** i treni per dare il contesto dell'occupazione dei binari, ma specifichiamo quali sono gli `active_agent_ids` su cui l'AI deve effettivamente lavorare.

## 1. Modifica dei Modelli (Swift)
Assicurati che `AIRequestPayload` (o `RailwayAIRequest`) nel tuo codice includa il campo `active_agent_ids`:

```swift
struct RailwayAIRequest: Codable {
    let trains: [RailwayAITrainInfo]
    let tracks: [RailwayAITrackInfo]
    let stations: [RailwayAIStationInfo]
    let max_iterations: Int
    let ga_max_iterations: Int?
    let ga_population_size: Int?
    let active_agent_ids: [Int]? // Aggiungi questo
    
    enum CodingKeys: String, CodingKey {
        case trains, tracks, stations
        case max_iterations = "max_iterations"
        case ga_max_iterations = "ga_max_iterations"
        case ga_population_size = "ga_population_size"
        case active_agent_ids = "active_agent_ids"
    }
}
```

## 2. Selezione della Linea Interessata
Quando l'utente seleziona una linea o un treno nella tua View (es. `LineDetailView`), identifica gli ID dei treni che compongono quella linea:

```swift
// Esempio di logica nel ViewModel o nel Service
func optimizeCurrentLine(trains: [Train], network: RailwayNetwork) {
    let focusIds = trains.map { $0.id }
    
    // Il RailwayAIService ora gestisce internamente la mappatura degli UUID
    // agli ID numerici tramite createRequest(..., activeAgentIds: focusIds, ...)
}
```

## 3. Vantaggi per l'App
- **Stabilità**: Il server non va in crash per Out-Of-Memory perché calcola i gradienti solo per pochi agenti.
- **Realismo**: Gli altri treni NON spariscono; l'AI li vede e coordina le precedenze della linea target per evitare collisioni con loro.
- **Velocità**: Risposta dell'AI in pochi secondi invece di minuti.

## 4. Test Rapido (Python/Postman)
Se vuoi testare manualmente prima di toccare il codice Swift, invia un body così:
```json
{
  "trains": [
    {"id": 1, "current_track": 10, ...},
    {"id": 2, "current_track": 15, ...}
  ],
  "active_agent_ids": [1],
  "max_iterations": 100
}
```
*L'AI sposterà il treno 1 per evitare il treno 2, ma non cercherà di ottimizzare l'arrivo del treno 2.*
