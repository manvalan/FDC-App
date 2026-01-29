# 🔍 Debug: Treni Non Visibili

## Problema
I treni esistono nel file `last_state.json` ma non vengono visualizzati nella lista treni dell'app.

## Flusso di Caricamento Verificato

1. **App Start** (`FdC_Railway_ManagerApp.swift` riga 36)
   - Chiama `loader.performInitialLoad()`

2. **Caricamento Dati** (`AppLoaderService.swift` righe 26-48)
   - Legge `last_state.json`
   - Decodifica in `RailwayNetworkDTO`
   - Assegna `trainManager.trains = dto.trains ?? []` (riga 41)

3. **Visualizzazione** (`ContentView.swift` righe 287-400)
   - `TrainsListView` mostra i treni raggruppati per linea
   - Usa `manager.trains.filter { $0.lineId == line.id }` (riga 312)

## 🐛 Possibili Cause

### 1. Treni non caricati dal file
**Test**: Aggiungi logging in `AppLoaderService.swift` dopo riga 41:

```swift
trainManager.trains = dto.trains ?? []

print("✅ Caricato ultimo stato da: \(lastStateURL.lastPathComponent)")
print("📊 Statistiche caricamento:")
print("   - Stazioni: \(network.nodes.count)")
print("   - Binari: \(network.edges.count)")
print("   - Linee: \(network.lines.count)")
print("   - Treni: \(trainManager.trains.count)")
if !trainManager.trains.isEmpty {
    print("   - Primo treno: \(trainManager.trains[0].name)")
}
```

### 2. Treni hanno lineId non validi
**Test**: Aggiungi logging in `TrainsListView` (ContentView.swift riga 312):

```swift
let lineTrains = manager.trains.filter { $0.lineId == line.id }
print("🔍 Linea \(line.name): \(lineTrains.count) treni")
```

### 3. Treni senza lineId (non assegnati)
**Verifica**: Controlla la sezione "Treni Non Assegnati" (riga 336):

```swift
Section("Treni Non Assegnati") {
    let unassigned = manager.trains.filter { $0.lineId == nil }
    print("🔍 Treni non assegnati: \(unassigned.count)")
    // ...
}
```

### 4. File JSON corrotto
**Verifica**: Controlla il contenuto di `last_state.json`:

```bash
# Trova il file
find ~/Library/Containers -name "last_state.json" 2>/dev/null

# Visualizza il contenuto
cat [path_del_file] | jq '.trains | length'
```

## ✅ Soluzione Rapida

Se i treni esistono nel file ma non vengono visualizzati, potrebbe essere un problema di sincronizzazione.

**Aggiungi in `AppLoaderService.swift` dopo riga 48**:

```swift
// Force UI refresh
await MainActor.run {
    trainManager.objectWillChange.send()
}
```

## 🧪 Test Manuale

1. Apri l'app
2. Vai alla tab "Treni"
3. Controlla la console Xcode per i log
4. Se vedi "Treni: 0" ma il file contiene treni, c'è un problema di parsing
5. Se vedi "Treni: X" ma la lista è vuota, c'è un problema di UI

## 📝 Prossimi Passi

1. Aggiungi i log sopra
2. Ricompila e avvia l'app
3. Controlla la console
4. Riporta i risultati
