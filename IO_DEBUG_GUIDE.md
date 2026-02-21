# 🔍 IO Debug Guide - Import Infrastructure & Open Project

## Overview

Questa guida spiega come debuggare le funzionalità "Importa Infrastruttura" e "Apri Progetto" usando i log dettagliati aggiunti al codice.

## Debug Logging Aggiunto

### File Modificato
- **IOManagementView.swift**

### Log Points Aggiunti

#### 1. Click sui Pulsanti
```
🔵 [IO DEBUG] 'Import Infrastructure' button clicked
🔵 [IO DEBUG] importMode set to .infrastructure, isImporting binding should now be true

🔵 [IO DEBUG] 'Open Project' button clicked
🔵 [IO DEBUG] importMode set to .project, isImporting binding should now be true
```

#### 2. File Picker
```
🔵 [IO DEBUG] File picker returned URL: file://...
✅ [IO DEBUG] Security scoped resource access granted
🔴 [IO DEBUG] Security scoped resource access FAILED
🔵 [IO DEBUG] File loaded: 12345 bytes, extension: json
🔴 [IO DEBUG] Import mode is nil!
```

#### 3. Import Infrastructure (.infrastructure mode)
```
🔵 [IO DEBUG] Mode: INFRASTRUCTURE
🔵 [IO DEBUG] Trying RailML parser...
✅ [IO DEBUG] RailML parsed successfully: 10 nodes, 15 edges
⚠️ [IO DEBUG] RailML parsing failed

🔵 [IO DEBUG] Trying JSON decode (InfrastructurePayload)...
✅ [IO DEBUG] InfrastructurePayload decoded: 10 nodes, 15 edges

🔵 [IO DEBUG] Trying JSON decode (RailwayNetworkDTO)...
✅ [IO DEBUG] RailwayNetworkDTO decoded: 10 nodes, 15 edges

🔵 [IO DEBUG] Trying JSON decode (RailFileContainer)...
✅ [IO DEBUG] RailFileContainer decoded: 10 nodes, 15 edges

🔴 [IO DEBUG] All JSON decode attempts failed!
✅ [IO DEBUG] Infrastructure import completed, switching to stations view
```

#### 4. Open Project (.project mode)
```
🔵 [IO DEBUG] Mode: PROJECT
🔵 [IO DEBUG] Trying JSON decode (RailFileContainer)...
✅ [IO DEBUG] RailFileContainer decoded successfully

🔵 [IO DEBUG] Trying JSON decode (RailwayNetworkDTO)...
✅ [IO DEBUG] RailwayNetworkDTO decoded successfully

🔵 [IO DEBUG] Trying RailML parser...
✅ [IO DEBUG] RailML parsed successfully, converting to DTO
⚠️ [IO DEBUG] RailML parsing failed

🔵 [IO DEBUG] Trying FDC parser (last resort)...
✅ [IO DEBUG] FDC import successful
🔴 [IO DEBUG] FDC import failed: <error message>
```

#### 5. Error Handling
```
🔴 [IO DEBUG] Import failed with error: <error message>
🔵 [IO DEBUG] Resetting import mode
```

## Come Usare i Log per Debug

### Scenario 1: File Picker Non Si Apre

**Sintomo**: Clicco su "Importa Infrastruttura" o "Apri Progetto" ma il file picker non appare.

**Log da Cercare**:
1. Verifica che appaia:
   ```
   🔵 [IO DEBUG] 'Import Infrastructure' button clicked
   🔵 [IO DEBUG] importMode set to .infrastructure
   ```
2. Se questi log appaiono ma il file picker non si apre, il problema è nel binding `isImporting` o nella presentazione del `.fileImporter`

**Possibili Cause**:
- Inspector overlay non ha accesso alla window per presentare il file picker
- SwiftUI state non si aggiorna correttamente
- Conflitto di z-index tra pannelli

### Scenario 2: File Picker Si Apre Ma Non Importa

**Sintomo**: Il file picker appare, seleziono un file, ma non succede nulla.

**Log da Cercare**:
1. Dopo aver selezionato il file, dovrebbe apparire:
   ```
   🔵 [IO DEBUG] File picker returned URL: file://...
   ```
2. Se questo log NON appare, il callback `.fileImporter` non viene chiamato

**Possibili Cause**:
- Cancellazione invece di selezione file
- File picker presentato da una view che viene distrutta prima del callback

### Scenario 3: Security Scoped Resource Failed

**Sintomo**: Il log mostra:
```
🔴 [IO DEBUG] Security scoped resource access FAILED
```

**Causa**: L'app non ha permesso di accedere al file selezionato.

**Soluzione**: 
- Verificare le capabilities dell'app
- Verificare sandbox settings
- Il file potrebbe essere in una location protetta

### Scenario 4: File Caricato Ma Decode Failed

**Sintomo**: I log mostrano:
```
🔵 [IO DEBUG] File loaded: 12345 bytes, extension: json
🔴 [IO DEBUG] All JSON decode attempts failed!
```

**Causa**: Il file non corrisponde a nessuno dei formati supportati.

**Soluzione**:
1. Verificare il contenuto del file
2. Controllare che il JSON sia valido
3. Verificare che la struttura corrisponda a uno dei DTO supportati

### Scenario 5: Import Mode è Nil

**Sintomo**: Il log mostra:
```
🔴 [IO DEBUG] Import mode is nil!
```

**Causa**: Il `importMode` state è stato resettato prima che il file picker callback venisse eseguito.

**Possibile Causa Root**:
- SwiftUI lifecycle issue
- View recreated between button click and file selection
- State management issue

## Formati Supportati

### Import Infrastructure (.infrastructure)

1. **RailML** (`.railml`)
   - Parser: `RailMLParser()`
   - Output: `InfrastructurePayload` con nodes e edges

2. **InfrastructurePayload JSON**
   ```json
   {
     "nodes": [...],
     "edges": [...]
   }
   ```

3. **RailwayNetworkDTO JSON**
   ```json
   {
     "name": "Network Name",
     "nodes": [...],
     "edges": [...],
     "ferrovie": [...],
     "lines": [...],
     "trains": [...]
   }
   ```

4. **RailFileContainer JSON** (`.rail`)
   ```json
   {
     "version": "1.0",
     "network": { ... }
   }
   ```

### Open Project (.project)

Prova in ordine:
1. **RailFileContainer** (formato nativo `.rail`)
2. **RailwayNetworkDTO** (JSON standard)
3. **RailML** (se extension è `.railml`)
4. **FDC Parser** (legacy formats: `.fdc`, topology, text)

## Test Plan

### Test 1: Import Infrastructure con JSON Valido
1. Aprire l'app in editor mode
2. Cliccare "Import/Export" nel sidebar
3. Cliccare "Importa Infrastruttura"
4. Selezionare un file JSON con `InfrastructurePayload`
5. Verificare nei log:
   ```
   🔵 [IO DEBUG] 'Import Infrastructure' button clicked
   🔵 [IO DEBUG] File picker returned URL: ...
   ✅ [IO DEBUG] Security scoped resource access granted
   🔵 [IO DEBUG] File loaded: ... bytes, extension: json
   🔵 [IO DEBUG] Mode: INFRASTRUCTURE
   ✅ [IO DEBUG] InfrastructurePayload decoded: X nodes, Y edges
   ✅ [IO DEBUG] Infrastructure import completed
   ```

### Test 2: Open Project con .rail File
1. Aprire l'app in editor mode
2. Cliccare "Import/Export" nel sidebar
3. Cliccare "Apri Progetto"
4. Selezionare un file `.rail`
5. Verificare nei log:
   ```
   🔵 [IO DEBUG] 'Open Project' button clicked
   🔵 [IO DEBUG] File picker returned URL: ...
   ✅ [IO DEBUG] Security scoped resource access granted
   🔵 [IO DEBUG] File loaded: ... bytes, extension: rail
   🔵 [IO DEBUG] Mode: PROJECT
   ✅ [IO DEBUG] RailFileContainer decoded successfully
   ```

### Test 3: Open Project con FDC Legacy
1. Aprire l'app in editor mode
2. Cliccare "Import/Export" nel sidebar
3. Cliccare "Apri Progetto"
4. Selezionare un file `.fdc` legacy
5. Verificare nei log:
   ```
   🔵 [IO DEBUG] 'Open Project' button clicked
   🔵 [IO DEBUG] File loaded: ... bytes, extension: fdc
   🔵 [IO DEBUG] Mode: PROJECT
   🔵 [IO DEBUG] Trying FDC parser (last resort)...
   ✅ [IO DEBUG] FDC import successful
   ```

### Test 4: File Picker Cancellato
1. Cliccare "Apri Progetto"
2. Cancellare il file picker senza selezionare
3. Verificare nei log:
   ```
   🔵 [IO DEBUG] 'Open Project' button clicked
   🔵 [IO DEBUG] Resetting import mode
   ```
   (Nessun log di "File picker returned URL")

### Test 5: File Non Valido
1. Cliccare "Importa Infrastruttura"
2. Selezionare un file di testo random
3. Verificare nei log:
   ```
   🔵 [IO DEBUG] File loaded: ... bytes, extension: txt
   🔵 [IO DEBUG] Mode: INFRASTRUCTURE
   🔴 [IO DEBUG] All JSON decode attempts failed!
   🔴 [IO DEBUG] Import failed with error: ...
   ```

## Watching Logs in Xcode

1. Aprire Xcode
2. Eseguire l'app
3. Aprire **Console** (View → Debug Area → Show Debug Area)
4. Filtrare per `[IO DEBUG]` nella search box
5. Eseguire le operazioni di import
6. Osservare il flusso dei log in tempo reale

## Emoji Legend

- 🔵 Blue Circle: Info / Step in process
- ✅ Green Check: Success / Operation completed
- ⚠️ Warning Sign: Non-fatal warning / Fallback triggered
- 🔴 Red Circle: Error / Failure / Problem detected

## Next Steps

Una volta raccolti i log, possiamo:
1. Identificare esattamente dove si ferma il flusso
2. Capire se il problema è nel file picker presentation
3. Verificare se il problema è nel parsing/decode
4. Determinare se c'è un issue di state management
5. Fixare il problema specifico identificato

## Rimozione Debug Logs (Opzionale)

Una volta risolto il problema, i log possono essere:
- **Opzione A**: Lasciati per future debugging sessions
- **Opzione B**: Wrappati in `#if DEBUG ... #endif`
- **Opzione C**: Rimossi completamente

Raccomandazione: **Lasciare i log** - sono utili per troubleshooting futuro e non impattano performance.
