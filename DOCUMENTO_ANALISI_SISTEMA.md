# Analisi del Progetto FdC Railway Manager

## Sezione: DataManagement (Logica e Dati)

### File: `RailwayAILogger.swift`

#### Struct: `LogEntry`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = LogEntry()`
- **Variabili principali**: type, message, timestamp, id

**Metodi:**
  * **`log`**
    - **Parametri**: `_ message: String, type: LogType = .info`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `RailSchedulerCore.swift`

#### Struct: `OccupazioneTratta`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = OccupazioneTratta()`
- **Variabili principali**: resId, direzione, intervallo

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `VincoloSvizzero`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = VincoloSvizzero()`
- **Variabili principali**: stazioneId, finestraArrivo, finestraPartenza

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `SearchNode`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = SearchNode()`
- **Variabili principali**: resId, nodesExpanded, s2Id, fStops, exitTime, updatedStops, avgSpeed, tFine, sostaNode, prevStop, lastIdx, anchorStop, merged, maxNodes, newStop

**Metodi:**
  * **`addOccupancies`**
    - **Parametri**: `_ newOccs: [OccupazioneTratta]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`extractOccupancies`**
    - **Parametri**: `from trains: [Train], network: NetworkModel`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`extractSingleTrainOccupancy`**
    - **Parametri**: `train: Train, network: NetworkModel`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`isTrattaLibera`**
    - **Parametri**: `edge: Edge, tInizio: Date, tFine: Date, verso: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`isStazioneLibera`**
    - **Parametri**: `stazioneId: String, at time: Date`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`estimateDistanceBetween`**
    - **Parametri**: `fromId: String, toId: String, network: NetworkModel`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`h`**
    - **Parametri**: `_ id: String, goal: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `GeneticOptimizerTransformer.swift`

#### Struct: `ScheduleTransformer`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ScheduleTransformer()`
- **Variabili principali**: l, maxAllowedExtra, totalExtra, dep, transit, result, arr, extra, earliestDeparture, departure, stops, baseDwell, arrival, curr, minAllowedExtra

**Metodi:**
  * **`convertToLite`**
    - **Parametri**: `train: Train`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`reconstructTrains`**
    - **Parametri**: `lite: [LiteTrain], original: [Train]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`apply`**
    - **Parametri**: `chromosome: Chromosome, to trains: [LiteTrain]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `RailwayGraphManager.swift`

#### Struct: `AGStation`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = AGStation()`
- **Variabili principali**: lon, id, lat, name, num_platforms

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `AGTrack`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = AGTrack()`
- **Variabili principali**: max_speed, id, length_km, is_single_track, station_ids, capacity

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `AGTrain`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = AGTrain()`
- **Variabili principali**: destination_station, position_km, delay_minutes, origin_station, is_delayed, priority, min_dwell_minutes, velocity_kmh, scheduled_departure_time, current_track, planned_route, id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `AGAIRequest`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = AGAIRequest()`
- **Variabili principali**: edges, active_agent_ids, idx, trains, s2, trackId, firstEdge, request, s1, tracks, routeIds, key, from, depTime, max_iterations

**Metodi:**
  * **`loadNetwork`**
    - **Parametri**: `from network: RailwayNetwork`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`generateAIRequestDictionary`**
    - **Parametri**: `for trains: [Train], network: RailwayNetwork, focusAgentIds: [UUID]? = nil`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`generateAIRequestJSON`**
    - **Parametri**: `for trains: [Train], network: RailwayNetwork, focusAgentIds: [UUID]? = nil`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `the`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = the()`
- **Variabili principali**: edges, idx, s2, firstEdge, comps, encoder, request, s1, routeIds, key, from, depTime, date, edge, stations

**Metodi:**
  * **`normalize`**
    - **Parametri**: `_ date: Date?`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`getTrainUUID`**
    - **Parametri**: `fromId id: Int`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`getOriginalStationId`**
    - **Parametri**: `fromNumericId id: Int`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `GeneticOptimizerEvaluator.swift`

#### Struct: `ScheduleEvaluator`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ScheduleEvaluator()`
- **Variabili principali**: resId, penalty, travelTimePenalty, conflictCount, conflictingIds, constraintPenalty, isCandidate, depPrev, totalTime, cap, avgSpeed, exit, preferredTrackBonus, fitness, stop

**Metodi:**
  * **`collectOccupationsAndPenalties`**
    - **Parametri**: `allTrains: [LiteTrain], candidateCount: Int, context: inout EvaluationContext`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateDwellPenalty`**
    - **Parametri**: `stop: LiteStop`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`addStationOccupations`**
    - **Parametri**: `train: LiteTrain, stop: LiteStop, context: inout EvaluationContext`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`addSegmentOccupations`**
    - **Parametri**: `train: LiteTrain, stopIdx: Int, context: inout EvaluationContext`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateResourceConflicts`**
    - **Parametri**: `context: inout EvaluationContext`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`getResourceCapacity`**
    - **Parametri**: `resId: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`generateConflictEvents`**
    - **Parametri**: `occs: [(Double, Double, UUID`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateFitness`**
    - **Parametri**: `updatedSubset: [LiteTrain], candidateTrains: [LiteTrain], chromosome: Chromosome, context: EvaluationContext`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateTrackBonus`**
    - **Parametri**: `train: LiteTrain, candidates: LiteTrain`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateTrackDeviationPenalty`**
    - **Parametri**: `train: LiteTrain, gene: TrainGene, candidates: LiteTrain`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `DepartureTimeOptimizer.swift`

#### Struct: `Config`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = Config()`
- **Variabili principali**: mutationProbability, maxGenerations, tournamentSize, populationSize, timeResolutionMinutes, eliteCount

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `Individual`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = Individual()`
- **Variabili principali**: fitness, returnDepartureMinute, outboundDepartureMinute

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `OptimizationContext`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = OptimizationContext()`
- **Variabili principali**: returnRoundness, estimatedTravelTime, timeWindow, offspring2, returnStart, outbound, offspring1, waitingTime, parent1, route, departure, outboundRoundness, population, score, offset

**Metodi:**
  * **`optimize`**
    - **Parametri**: `context: OptimizationContext`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`generateInitialPopulation`**
    - **Parametri**: `context: OptimizationContext`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateFitness`**
    - **Parametri**: `individual: Individual, context: OptimizationContext`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateSingleConflictPenalty`**
    - **Parametri**: `departureTime: Int, context: OptimizationContext`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateConflictPenalty`**
    - **Parametri**: `outboundTime: Int, returnTime: Int, context: OptimizationContext`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`tournamentSelection`**
    - **Parametri**: `population: [Individual]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`singlePointCrossover`**
    - **Parametri**: `parent1: Individual, parent2: Individual`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`mutate`**
    - **Parametri**: `individual: Individual, context: OptimizationContext`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`clamp`**
    - **Parametri**: `_ value: Int, to range: ClosedRange<Int>`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`convertToAbsoluteTimes`**
    - **Parametri**: `individual: Individual`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `CadenceIndividual`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = CadenceIndividual()`
- **Variabili principali**: returnStartMinute, returnIntervalMinutes, startMinute, intervalMinutes, fitness

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `CadenceContext`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = CadenceContext()`
- **Variabili principali**: outboundTimes, estimatedTravelTime, scheduleReturn, useParent1Interval, newInterval, timeWindow, returnStart, idealReturn, offspring2, endTime, minutesSinceMidnight, currentReturn, returnTimes, components, interval2

**Metodi:**
  * **`optimizeCadence`**
    - **Parametri**: `context: CadenceContext`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`generateCadencePopulation`**
    - **Parametri**: `context: CadenceContext`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateCadenceFitness`**
    - **Parametri**: `individual: CadenceIndividual, context: CadenceContext`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`cadenceTournamentSelection`**
    - **Parametri**: `population: [CadenceIndividual]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`cadenceCrossover`**
    - **Parametri**: `parent1: CadenceIndividual, parent2: CadenceIndividual`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`cadenceMutate`**
    - **Parametri**: `individual: CadenceIndividual, context: CadenceContext`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`convertCadenceToTimes`**
    - **Parametri**: `individual: CadenceIndividual`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`minutesToTime`**
    - **Parametri**: `_ minutes: Int`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `AuthenticationManager.swift`

#### Struct: `TokenResponse`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TokenResponse()`
- **Variabili principali**: httpResponse, body, tokenObj, access_token, errStr, token_type, endpoint, request, token, data

**Metodi:**
  * **`generatePermanentKey`**
    - **Parametri**: `completion: @escaping (Result<String, AuthError>`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `KeyResponse`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = KeyResponse()`
- **Variabili principali**: httpResponse, body, api_key, rawString, key, finalKey, keyObj, endpoint, request, token

**Metodi:**
  * **`registerNewUser`**
    - **Parametri**: `username: String, password: String, completion: @escaping (Result<Bool, AuthError>`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`attachAuthHeaders`**
    - **Parametri**: `to request: inout URLRequest`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `RailFileContainer.swift`

#### Struct: `RailFileContainer`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RailFileContainer()`
- **Variabili principali**: network, qualifier, formatVersion, metadata

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `RailMetadata`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RailMetadata()`
- **Variabili principali**: lastModified, createdBy, description, createdAt

- *Nessun metodo rilevato in questa Struct.*

### File: `FDCModels.swift`

#### Struct: `FDCStation`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = FDCStation()`
- **Variabili principali**: latitude, longitude, capacity, platformCount, type, name, id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `FDCEdge`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = FDCEdge()`
- **Variabili principali**: bidirectional, trackType, from, distance, capacity, to, maxSpeed

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `FDCTrain`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = FDCTrain()`
- **Variabili principali**: id, acceleration, priority, type, deceleration, name, maxSpeed

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `FDCTimetableEntry`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = FDCTimetableEntry()`
- **Variabili principali**: stationId, trainId, time

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `FDCNetworkParsed`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = FDCNetworkParsed()`
- **Variabili principali**: edges, rawSchedules, trains, stations, lines, name

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `FDCFileRoot`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = FDCFileRoot()`
- **Variabili principali**: network, lines, schedules, trains

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `FDCNetworkData`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = FDCNetworkData()`
- **Variabili principali**: edges, nodes

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `FDCNodeData`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = FDCNodeData()`
- **Variabili principali**: platforms, latitude, longitude, capacity, type, platform_count, name, id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `FDCEdgeData`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = FDCEdgeData()`
- **Variabili principali**: bidirectional, max_speed, from_node, track_type, distance, to_node, capacity

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `FDCTrainData`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = FDCTrainData()`
- **Variabili principali**: max_speed, acceleration, priority, type, deceleration, name, id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `FDCLineData`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = FDCLineData()`
- **Variabili principali**: color, stations, name, id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `FDCScheduleData`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = FDCScheduleData()`
- **Variabili principali**: train_id, stops, schedule_id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `FDCStopData`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = FDCStopData()`
- **Variabili principali**: platform, departure, node_id, is_stop, arrival

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `FDCTopology`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = FDCTopology()`
- **Variabili principali**: nodes, links

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `FDCLinkData`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = FDCLinkData()`
- **Variabili principali**: target, max_speed, source, track_type, length

- *Nessun metodo rilevato in questa Struct.*

### File: `GeneticEngine.swift`

#### Struct: `GeneticEngine`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = GeneticEngine()`
- **Variabili principali**: isConflicting, trainId, mutationChance, contextTrains, targets, sIdx, i1, allowed, targetLoc, i2, sid, r, seg, j, others

**Metodi:**
  * **`selectParent`**
    - **Parametri**: `from population: [Chromosome]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`crossover`**
    - **Parametri**: `p1: Chromosome, p2: Chromosome`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`mutate`**
    - **Parametri**: `chromosome: inout Chromosome, rate: Double`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `RailwayAIService.swift`

#### Struct: `RouteAnalysis`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RouteAnalysis()`
- **Variabili principali**: maxFrequency, trainMapping, optimalOffsetAB, recommendation, minHeadwayMin, url, key, cleanEndpoint, baseServer, t, recommendedFrequency, crossingPointsCount, baseURL, optimalOffsetMin, apiKey

**Metodi:**
  * **`syncCredentials`**
    - **Parametri**: `endpoint: String, apiKey: String, token: String? = nil`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `TokenResponse`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TokenResponse()`
- **Variabili principali**: token_type, access_token

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `APIKeyResponse`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = APIKeyResponse()`
- **Variabili principali**: jsonData, httpResponse, requestURL, prompt, prettyEncoder, endpoints, prettyJson, encoder, request, relevantEdgeIds, rawString, path, loginURL, allowed, from

**Metodi:**
  * **`login`**
    - **Parametri**: `username: String, password: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`encode`**
    - **Parametri**: `_ s: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`verifyConnection`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`performCheck`**
    - **Parametri**: `at endpoints: [String]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`generateApiKey`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`optimize`**
    - **Parametri**: `request: RailwayAIRequest`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`analyzeRoute`**
    - **Parametri**: `name: String, stationIds: [String], nodes: [RailwayNode], edges: [RailwayEdge]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `AnalysisPayload`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = AnalysisPayload()`
- **Variabili principali**: jsonData, httpResponse, prompt, inJson, request, firstBrace, extracted, tracks, payloadStr, temporal_obstacles, error, cleanJson, decoder, firstTrack, responseString

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `usually`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = usually()`
- **Variabili principali**: httpResponse, message, byTrack, next, focusTrains, aiStations, s2, trackId, segmentToTrackId, wsMessages, encoder, finalRequest, request, s1, components

**Metodi:**
  * **`performAnalysisRequest`**
    - **Parametri**: `url: String, payload: Data`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`optimize`**
    - **Parametri**: `jsonString: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`optimizeWithScenario`**
    - **Parametri**: `scenarioPath: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`listUsers`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`addUser`**
    - **Parametri**: `username: String, password: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`removeUser`**
    - **Parametri**: `username: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`generateScenario`**
    - **Parametri**: `area: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`train`**
    - **Parametri**: `scenarioPath: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`connectMonitoring`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`disconnectMonitoring`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`receiveWSMessage`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`getMinutesFromMidnight`**
    - **Parametri**: `for date: Date`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`createRequest`**
    - **Parametri**: `nodes: [RailwayNode], edges: [RailwayEdge], trains: [RailwayTrain], fixedTrainIds: Set<UUID> = [], activeAgentIds: Set<UUID>? = nil, temporalObstacles: [TemporalObstacle]? = nil, conflicts: [ScheduleConflict]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`mapAIStations`**
    - **Parametri**: `nodes: [Node]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`mapAIUniqueTracks`**
    - **Parametri**: `edges: [Edge]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`createAITrackInfo`**
    - **Parametri**: `id: Int, s1: Int, s2: Int, edge: Edge`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`processTemporalObstacles`**
    - **Parametri**: `focusTrains: [Train], bgTrains: [Train], edges: [Edge], initialObstacles: [TemporalObstacle]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`identifyFocusTrackIds`**
    - **Parametri**: `focusTrains: [Train], edges: [Edge]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`createObstaclesForTrain`**
    - **Parametri**: `_ train: Train, edges: [Edge], focusTrackIds: Set<Int>`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`buildObstacle`**
    - **Parametri**: `trackId: Int, dep: Date, arr: Date, trainName: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`mapAITrains`**
    - **Parametri**: `focusTrains: [Train], nodes: [Node], edges: [Edge], fixedTrainIds: Set<UUID>, conflicts: [ScheduleConflict]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`createAITrainInfo`**
    - **Parametri**: `index: Int, train: Train, nodes: [Node], edges: [Edge], fixedTrainIds: Set<UUID>, conflicts: [ScheduleConflict], formatter: DateFormatter`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateRouteIds`**
    - **Parametri**: `for train: Train, edges: [Edge]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateVelocity`**
    - **Parametri**: `for train: Train, nodes: [Node], edges: [Edge]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`normalizeDate`**
    - **Parametri**: `_ date: Date?`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`saveRequestToFile`**
    - **Parametri**: `_ request: RailwayAIRequest`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`getTrainUUID`**
    - **Parametri**: `optimizerId: Int`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`mergeObstacles`**
    - **Parametri**: `_ obstacles: [TemporalObstacle]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`getTrainMapping`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `CadenceOptimizer.swift`

#### Struct: `CadenceChromosome`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = CadenceChromosome()`
- **Variabili principali**: offsetMinutes, p2, baseDate, trainName, localTrains, prevId, generations, fitness, stop, mutationStrength, nextGen, dwell, betterParent, dummyCache, mutationRate

**Metodi:**
  * **`proposeIdealWindow`**
    - **Parametri**: `for line: TrainRoute, frequency: Double, existingTrains: [Train], network: NetworkModel`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`tournamentSelect`**
    - **Parametri**: `from population: [CadenceChromosome], tournamentSize: Int`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`evaluateCadence`**
    - **Parametri**: `offset: Double, line: TrainRoute, frequency: Double, existingTrains: [Train], nodes: [RailwayNode], edges: [Edge]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`refreshSchedules`**
    - **Parametri**: `trains: inout [Train], nodes: [RailwayNode], edges: [Edge]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `Secrets.swift`

#### Struct: `Secrets`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = Secrets()`
- **Variabili principali**: railwayAiToken

- *Nessun metodo rilevato in questa Struct.*

### File: `ScheduleProposer.swift`

#### Struct: `ProposedRoute`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ProposedRoute()`
- **Variabili principali**: stationSequence, destination, color, digits, frequencyMinutes, graph, frequency, s2, sB, stops, firstDepartureMinute, sA, s1, origin, name

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `SchedulePreviewItem`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = SchedulePreviewItem()`
- **Variabili principali**: destination, departure, stops, line, origin

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `ProposalResponse`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ProposalResponse()`
- **Variabili principali**: proposedRoutes, schedulePreviewItems

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `ProposerResponseRoot`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ProposerResponseRoot()`
- **Variabili principali**: body, message, networkDict, shared, url, decoder, proposal, error, errorMessage, request, urlString, detail, root, success, baseURL

**Metodi:**
  * **`requestProposal`**
    - **Parametri**: `using graph: RailwayGraphManager, network: NetworkModel, targetRoutes: Int, completion: @escaping (Result<ProposalResponse, Error>`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `RailwayConstants.swift`

#### Struct: `RailwayConstants`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RailwayConstants()`
- **Variabili principali**: maxPathAlternativeLengthMultiplier, maxTimeStep, interchangeDwellTime, degreesToKm, defaultStationCapacity, defaultSegmentCapacity, minTimeStep, standardDwellTime, standardTrackGauge, freightDwellTime, maxRecursionDepth, defaultEarthRadius, gravity

- *Nessun metodo rilevato in questa Struct.*

### File: `GeneticOptimizerModels.swift`

#### Struct: `TrainGene`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrainGene()`
- **Variabili principali**: departureOffset, legTransitTimes, trainId, stopTracks, stopDwellOffsets

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `LiteStop`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = LiteStop()`
- **Variabili principali**: plannedArrival, plannedDeparture, stationId, minDwell, extraDwell, departure, isPreferredTrack, isSkipped, arrival, track, isManualTrack

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `LiteTrain`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = LiteTrain()`
- **Variabili principali**: routeId, maxSpeed, stops, acceleration, departureTime, deceleration, name, id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `Chromosome`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = Chromosome()`
- **Variabili principali**: conflictLocations, genes, fitness, conflictingTrainIds

- *Nessun metodo rilevato in questa Struct.*

### File: `FDC_Scheduler.swift`

#### Struct: `ScheduleStop`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ScheduleStop()`
- **Variabili principali**: stationName, platform, dwellsMinutes, stationId, trainName, arrivalTime, trainId, stops, totalDelayMinutes, departureTime, id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `Conflict`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = Conflict()`
- **Variabili principali**: stationName, edgeKey, involvedTrains, scheduleToDelay, effectiveMaxSpeed, s2, trainIds, endTime, stops, activeConflicts, stationUsage, toAlt, arrival, lowPriorityTrain, conflict

**Metodi:**
  * **`calculatePathTravelTime`**
    - **Parametri**: `edges: [Edge], train: RailwayTrain, nodes: [RailwayNode], isStarting: Bool = false, isStopping: Bool = false, startNodeId: String, endNodeId: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateTravelTimeBetweenNodes`**
    - **Parametri**: `from fromId: String, to toId: String, train: RailwayTrain, nodes: [RailwayNode], edges: [Edge], isStarting: Bool = false, isStopping: Bool = false`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`buildSchedule`**
    - **Parametri**: `train: RailwayTrain, network: RailwayNetwork, route: [String], startTime: Date`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`checkConflicts`**
    - **Parametri**: `schedules: [TrainSchedule], network: RailwayNetwork`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`resolveConflicts`**
    - **Parametri**: `trains: [RailwayTrain], network: RailwayNetwork`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`findStationBeforeTrack`**
    - **Parametri**: `schedule: TrainSchedule, edgeKey: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`applyDelay`**
    - **Parametri**: `to schedule: TrainSchedule, minutes: Int, startingFrom stationId: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `RailwayAIModels.swift`

#### Struct: `RailwayAIRequest`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RailwayAIRequest()`
- **Variabili principali**: active_agent_ids, tracks, trains, stations, max_iterations, temporal_obstacles, current_time_minutes, ga_population_size, ga_max_iterations

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `TemporalObstacle`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TemporalObstacle()`
- **Variabili principali**: reason, track_id, start_minute, end_minute

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `RailwayAIStationInfo`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RailwayAIStationInfo()`
- **Variabili principali**: num_platforms, name, id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `RailwayAITrackInfo`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RailwayAITrackInfo()`
- **Variabili principali**: max_speed_kmh, id, length_km, is_single_track, station_ids, capacity

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `RailwayAITrainInfo`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RailwayAITrainInfo()`
- **Variabili principali**: destination_station, position_km, delay_minutes, origin_station, is_delayed, priority, min_dwell_minutes, velocity_kmh, scheduled_departure_time, current_track, planned_route, id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `RailwayAIResponse`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RailwayAIResponse()`
- **Variabili principali**: total_impact_minutes, total_delay_minutes, inference_time_ms, resolutions, modifications, error_message, conflict_analysis, conflicts_resolved, total_travel_time_min, success, conflicts_detected, ml_confidence

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `RailwayAIResolution`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RailwayAIResolution()`
- **Variabili principali**: train_id, time_adjustment_min, confidence, track_assignment, dwell_delays

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `RailwayAIModification`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RailwayAIModification()`
- **Variabili principali**: train_id, section, reason, impact, parameters, modification_type, confidence, id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `RailwayAISection`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RailwayAISection()`
- **Variabili principali**: to_station, station, from_station

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `RailwayAIImpact`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RailwayAIImpact()`
- **Variabili principali**: passenger_impact_score, time_increase_seconds, affected_stations

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `RailwayAIConflictAnalysis`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RailwayAIConflictAnalysis()`
- **Variabili principali**: remaining_conflicts, resolved_conflicts, original_conflicts

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `AdminUser`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = AdminUser()`
- **Variabili principali**: is_active, username, id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `AddUserRequest`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = AddUserRequest()`
- **Variabili principali**: password, username

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `KeyInfoResponse`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = KeyInfoResponse()`
- **Variabili principali**: expires_at, remaining_days, privilege, key_prefix, username

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `ScenarioGenerateRequest`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ScenarioGenerateRequest()`
- **Variabili principali**: area

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `TrainRequest`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrainRequest()`
- **Variabili principali**: scenario_path

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `OptimizeRequestWithScenario`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = OptimizeRequestWithScenario()`
- **Variabili principali**: scenario_path

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `WSMessage`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = WSMessage()`
- **Variabili principali**: message, level, scenario_path, training_update, type, episode, conflicts, reward

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `TrainingUpdate`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrainingUpdate()`
- **Variabili principali**: episode, conflicts, reward

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `AnyCodable`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = AnyCodable()`
- **Variabili principali**: x, container, value

**Metodi:**
  * **`encode`**
    - **Parametri**: `to encoder: Encoder`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `GeneticOptimizer.swift`

#### Struct: `Config`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = Config()`
- **Variabili principali**: p2, genes, times, prev, res, prevId, stop, nextGen, paths, baseMutationRate, tracks, path, evaluator, capacities, allowed

**Metodi:**
  * **`optimize`**
    - **Parametri**: `newTrains: [RailwayTrain], existingTrains: [RailwayTrain], nodes: [RailwayNode], edges: [Edge], iterations: Int? = nil`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`prepareForOptimization`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`completeOptimization`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`updateUI`**
    - **Parametri**: `gen: Int, maxGen: Int, best: Chromosome`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`spatialFilter`**
    - **Parametri**: `newTrains: [RailwayTrain], existing: [RailwayTrain], edges: [Edge]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`precalculateAllowedTracks`**
    - **Parametri**: `allTrains: [RailwayTrain], nodes: [RailwayNode]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`precalculatePaths`**
    - **Parametri**: `allTrains: [RailwayTrain], edges: [Edge]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`precalculateTransitTimes`**
    - **Parametri**: `allTrains: [RailwayTrain], nodes: [RailwayNode], edges: [Edge], paths: [UUID: [[Edge]?]]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`initializePopulation`**
    - **Parametri**: `liteNew: [LiteTrain], transitTimes: [UUID: [Double]], allowedTracks: [UUID: [Set<String>]]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`evaluatePopulation`**
    - **Parametri**: `population: [Chromosome], liteNew: [LiteTrain], liteFixed: [LiteTrain], evaluator: ScheduleEvaluator`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`updateAdaptiveState`**
    - **Parametri**: `state: (lastBestConflictCount: Int, stagnationGens: Int, mutationRate: Double`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`evolvePopulation`**
    - **Parametri**: `population: [Chromosome], engine: GeneticEngine, mutationRate: Double`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`sanitizeTracks`**
    - **Parametri**: `lite: [LiteTrain], constraints: [UUID: [Set<String>]]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`getResourceKeys`**
    - **Parametri**: `edges: [Edge]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `RailwayOptimizerDTO.swift`

#### Struct: `OptimizerRequest`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = OptimizerRequest()`
- **Variabili principali**: tracks, trains, stations, max_iterations, ga_population_size, ga_max_iterations

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `OptimizerTrain`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = OptimizerTrain()`
- **Variabili principali**: destination_station, position_km, delay_minutes, origin_station, route, is_delayed, priority, min_dwell_minutes, velocity_kmh, scheduled_departure_time, current_track, id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `OptimizerTrack`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = OptimizerTrack()`
- **Variabili principali**: max_speed, id, length_km, is_single_track, station_ids, capacity

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `OptimizerStation`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = OptimizerStation()`
- **Variabili principali**: num_platforms, name, id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `OptimizerResponse`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = OptimizerResponse()`
- **Variabili principali**: total_delay_minutes, inference_time_ms, resolutions, conflicts_resolved, success, conflicts_detected, timestamp

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `OptimizerResolution`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = OptimizerResolution()`
- **Variabili principali**: dwellDelays, trackAssignment, trainId, confidence, timeAdjustmentMin

- *Nessun metodo rilevato in questa Struct.*

### File: `AppConfig.swift`

#### Struct: `AppConfig`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = AppConfig()`
- **Variabili principali**: currentEnvironment, proposeScheduleEndpoint, apiBaseURL

- *Nessun metodo rilevato in questa Struct.*

### File: `TaktEngine.swift`

#### Struct: `TaktDiagnosticEntry`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TaktDiagnosticEntry()`
- **Variabili principali**: takt, hubDeparture, status, depE, hubName, hubArrival, hubStop, arrMinute, trainName, mainTrainWindows, travelMinutes, comps, station, targetMinute, firstTakt

**Metodi:**
  * **`calculateAlignedStartTime`**
    - **Parametri**: `startTime: Date, stationSequence: [String], taktStationId: String, train: Train, isReturn: Bool`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`findFirstTaktStation`**
    - **Parametri**: `in sequence: [String]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateTaktSuggestions`**
    - **Parametri**: `stationSequence: [String]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`validateTaktPlacement`**
    - **Parametri**: `trains: [Train], taktStationId: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`formatTime`**
    - **Parametri**: `_ date: Date`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

## Sezione: UI (Interfaccia Utente)

### File: `AppState.swift`

#### Struct: `FdCTheme`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = FdCTheme()`
- **Variabili principali**: jumpToTrainId, selectedTrainIds, lastVehicleAssignmentRouteId, liveSim, backgroundSecondary, activePanel, cancellables, selectedNodeIds, simulator, lastVehicleLength, aiNetwork, creationRouteId, showAI, schedulePreviewMinTurnaroundTime, selectedNodeId

**Metodi:**
  * **`showPanel`**
    - **Parametri**: `_ panel: ActivePanel`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`togglePanel`**
    - **Parametri**: `_ panel: ActivePanel`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`toggleNodeSelection`**
    - **Parametri**: `_ id: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `OptimizedTimesPreviewData`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = OptimizedTimesPreviewData()`
- **Variabili principali**: selectedNode, uiSettings, currentReturnTime, regionalAcceleration, showGrid, globalLineWidth, params, title, regionalDeceleration, highSpeedDeceleration, trackSettings, intercityDeceleration, selectedLine, globalFontSize, trackWidthDouble

**Metodi:**
  * **`updateInspectorVisibilityForSelection`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`shouldShowInspectorForSelection`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`shouldHideInspectorForSelection`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`updateMapVisualizationMode`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`startTrainCreation`**
    - **Parametri**: `routeId: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`selectTrain`**
    - **Parametri**: `_ id: UUID`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`selectLine`**
    - **Parametri**: `_ route: TrainRoute`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`clearSelection`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`showSettings`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`initializeAIService`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`setupBindings`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`getPhysics`**
    - **Parametri**: `for category: TrainCategory`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `BatchTrainEditView.swift`

#### Struct: `BatchTrainEditView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = BatchTrainEditView()`
- **Variabili principali**: body, selectedIds, timeShiftMinutes, manager, network, selectedTrains, current, showingDeleteConfirmation

**Metodi:**
  * **`shiftTimes`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`deleteSelected`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `DiagnosticsSettingsView.swift`

#### Struct: `DiagnosticsSettingsView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = DiagnosticsSettingsView()`
- **Variabili principali**: jsonData, body, showCredits, network, trainManager, showLogs, jsonString, encoder, debugContent

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `DebugContent`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = DebugContent()`
- **Variabili principali**: title, json, id

- *Nessun metodo rilevato in questa Struct.*

### File: `RailwayScheduleOptimizer.swift`

#### Struct: `PlanningCursor`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = PlanningCursor()`
- **Variabili principali**: nextArrivalAtTarget, currentConflicts, reason, idx, actuallySkipped, isStoppingAtNext, forwardFinished, idPrev, dwell, depTime, trackOk, estArrAtHub, idCur, train, edge

**Metodi:**
  * **`expandCursorOneStep`**
    - **Parametri**: `_ cursor: inout PlanningCursor, direction: ExpansionDirection, core: RailSchedulerCore, network: NetworkModel`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`shiftForward`**
    - **Parametri**: `_ cursor: inout PlanningCursor, delta: TimeInterval`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`shiftBackward`**
    - **Parametri**: `_ cursor: inout PlanningCursor, delta: TimeInterval`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`formatTimeWithSeconds`**
    - **Parametri**: `_ date: Date`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`isIdJunction`**
    - **Parametri**: `_ id: String, nodes: [RailwayNode]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`roundToBusinessSeconds`**
    - **Parametri**: `_ date: Date`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`performCloudOptimization`**
    - **Parametri**: `_ trains: [RailwayTrain], existingTrains: [RailwayTrain], nodes: [RailwayNode], edges: [Edge], pathCache: inout [String: [Edge]], preferredHubId: String? = nil`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`applyAIResolutions`**
    - **Parametri**: `_ trains: [Train], resolutions: [RailwayAIResolution]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`refreshPhysicalSchedules`**
    - **Parametri**: `_ trains: [RailwayTrain], existingTrains: [RailwayTrain], nodes: [RailwayNode], edges: [Edge], pathCache: inout [String: [Edge]], preferredHubId: String? = nil`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`detectConflicts`**
    - **Parametri**: `_ trainSubset: [RailwayTrain], existingTrains: [RailwayTrain], nodes: [RailwayNode], edges: [Edge], pathCache: inout [String: [Edge]]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`refreshMultipleSchedules`**
    - **Parametri**: `_ trains: inout [RailwayTrain], nodes: [RailwayNode], edges: [Edge], pathCache: inout [String: [Edge]], preferredHubId: String? = nil`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`refreshSingleTrainSchedule`**
    - **Parametri**: `_ train: inout [RailwayTrain].Element, nodes: [RailwayNode], edges: [Edge], pathCache: inout [String: [Edge]], preferredHubId: String? = nil`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`findHubNode`**
    - **Parametri**: `in train: [RailwayTrain].Element, nodes: [RailwayNode], preferredId: String? = nil`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`refreshTaktSchedule`**
    - **Parametri**: `train: inout [RailwayTrain].Element, hIdx: Int, hNode: RailwayNode, nodes: [RailwayNode], edges: [Edge]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateHubTimes`**
    - **Parametri**: `for train: [RailwayTrain].Element, hIdx: Int, hNode: RailwayNode`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`propagateBackward`**
    - **Parametri**: `from hIdx: Int, arrival: Date, train: inout [RailwayTrain].Element, nodes: [RailwayNode], edges: [Edge]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`propagateForward`**
    - **Parametri**: `from hIdx: Int, departure: Date, train: inout [RailwayTrain].Element, nodes: [RailwayNode], edges: [Edge]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`refreshStandardSchedule`**
    - **Parametri**: `train: inout [RailwayTrain].Element, nodes: [RailwayNode], edges: [Edge]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`formatTime`**
    - **Parametri**: `_ date: Date`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`interleaveTrainsForAStar`**
    - **Parametri**: `_ trains: [Train]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`minutesDiff`**
    - **Parametri**: `_ t1: Train, _ t2: Train`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `LogViewerSheet.swift`

#### Struct: `LogViewerSheet`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = LogViewerSheet()`
- **Variabili principali**: body, dismiss, logger

**Metodi:**
  * **`typeString`**
    - **Parametri**: `_ type: RailwayAILogger.LogType`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`typeColor`**
    - **Parametri**: `_ type: RailwayAILogger.LogType`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `VehicleCreationSheet.swift`

#### Struct: `VehicleCreationSheet`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = VehicleCreationSheet()`
- **Variabili principali**: fallbackView, finalName, appState, selectedTemplateId, dismiss, nextNumber, parts, existing, imageName, newVehicle, num, components, baseName, selectedTemplate, _

**Metodi:**
  * **`recalculateNextNumber`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`createVehicle`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `TrainingCenterView.swift`

#### Struct: `TrainingCenterView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrainingCenterView()`
- **Variabili principali**: body, last, status, path, ep, area, cancellables, conf, trainingUpdates, errorMessage, update, error, msg, rew, statusColor

**Metodi:**
  * **`logRow`**
    - **Parametri**: `_ msg: WSMessage`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`levelColor`**
    - **Parametri**: `_ level: String?`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`setupWSHandlers`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`startScenarioGeneration`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`startTraining`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`startOptimization`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `MapArchitecture.swift`

#### Struct: `MapConstants`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = MapConstants()`
- **Variabili principali**: longPressDuration, canvasPadding, commercialLineSelectionMultiplier, zoomStep, minZoom, hitTestRadius, selectionOutlineWidth, defaultZoom, infrastructureLineWidth, lineOffsetBase, maxZoom, stationRadius, springDamping, nodeLabelOffset, isEditMode

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `MapRenderData`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = MapRenderData()`
- **Variabili principali**: size, bounds, hubGeometries, commercialLines, nodePositions, edgeGeometries

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `PrecomputedLine`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = PrecomputedLine()`
- **Variabili principali**: bundleSize, isSelected, line, color

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `SegmentKey`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = SegmentKey()`
- **Variabili principali**: from, to

- *Nessun metodo rilevato in questa Struct.*

### File: `WidePanelView.swift`

#### Struct: `WidePanelView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = WidePanelView()`
- **Variabili principali**: body, appState, linesManager, content, line, header

- *Nessun metodo rilevato in questa Struct.*

### File: `FdCBottomPanel.swift`

#### Struct: `FdCBottomPanel`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = FdCBottomPanel()`
- **Variabili principali**: body, headerView, title, preferredHeight, maxHeight, panelHeight, content, isPresented

- *Nessun metodo rilevato in questa Struct.*

### File: `LineScheduleView.swift`

#### Struct: `LineScheduleView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = LineScheduleView()`
- **Variabili principali**: stationDistances, id, network, manager, maxDistance, orderedStations, line, inspectorMode, mode

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `StationSelection`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = StationSelection()`
- **Variabili principali**: body, url, distInfo, edge, selection, appState, selectedStation, stationIds, mainContent, stations, pdfView, station, distances, firstId, prevId

**Metodi:**
  * **`exportPDF`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateLineGeometry`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `EditorFerrovieComponents.swift`

#### Struct: `InfraLinesListPopover`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = InfraLinesListPopover()`
- **Variabili principali**: body, onCreate, appState, onSelect, line

**Metodi:**
  * **`deleteInfraLine`**
    - **Parametri**: `at offsets: IndexSet`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `InfraLinesInspectorList`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = InfraLinesInspectorList()`
- **Variabili principali**: body, onSelect, appState

- *Nessun metodo rilevato in questa Struct.*

### File: `RoutesListView.swift`

#### Struct: `RoutesListView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RoutesListView()`
- **Variabili principali**: body, network, idx, editingRouteId, showCreate, selectedRoute, lines

- *Nessun metodo rilevato in questa Struct.*

### File: `ConflictManager.swift`

#### Struct: `ScheduleConflict`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ScheduleConflict()`
- **Variabili principali**: resId, typeStr, occupantsCount, nodesCopy, timeEnd, s2Id, slots, exitTime, bwdEdges, totalTime, timeStart, lastResourceCapacities, sortedNew, prevId, capBwd

**Metodi:**
  * **`getResourceCapacities`**
    - **Parametri**: `nodes: [Node], edges: [Edge]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`detectConflicts`**
    - **Parametri**: `nodes: [Node], edges: [Edge], trains: [Train], pathCache: [String: [Edge]]? = nil`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateConflictsWithCapacities`**
    - **Parametri**: `nodes: [RailwayNode], edges: [RailwayEdge], trains: [RailwayTrain], pathCache: inout [String: [RailwayEdge]]?`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateTrackConflicts`**
    - **Parametri**: `nodes: [RailwayNode], trains: [RailwayTrain]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateScheduleConflicts`**
    - **Parametri**: `nodes: [RailwayNode], edges: [RailwayEdge], trains: [RailwayTrain], pathCache: inout [String: [RailwayEdge]]?`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `ResourceOccupation`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ResourceOccupation()`
- **Variabili principali**: resId, fallbackTime, vehicleGroups, entry, events, defaultBuffer, trainName, bufferMinutes, trainId, missions, activeOccupants, vId, exit, physicalCount, vehicleId

**Metodi:**
  * **`effectiveExit`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`prepareVehicleMissions`**
    - **Parametri**: `trains: [RailwayTrain]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateEffectiveOccupationTimes`**
    - **Parametri**: `train: RailwayTrain, stop: RelationStop, vehicleMissions: [UUID: [(trainId: UUID, stationId: String, arrival: Date?, departure: Date?`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`detectOverlaps`**
    - **Parametri**: `occupations: [ResourceOccupation], capacity: Int, resId: String, nodes: [Node]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `OccupationEvent`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = OccupationEvent()`
- **Variabili principali**: incidentId, startOverlap, occA, overlapEnd, parts, trainName, trainA, candidates, trainId, prevId, vehicleId, name, stop, buffer, stopAIdx

**Metodi:**
  * **`generateSortedEvents`**
    - **Parametri**: `from occupations: [ResourceOccupation]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`countPhysicalOccupants`**
    - **Parametri**: `_ active: [UUID: (vehicleId: UUID?, name: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`parseLocationInfo`**
    - **Parametri**: `resId: String, nodes: [Node]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`groupConflictsByIncident`**
    - **Parametri**: `_ conflicts: [ScheduleConflict]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateSuggestion`**
    - **Parametri**: `for conflict: ScheduleConflict, network: NetworkModel, trains: [Train]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`isTrackFree`**
    - **Parametri**: `stationId: String, track: String, from: Date, to: Date, trains: [Train], excludingId: UUID`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `EditorInspectorContent.swift`

#### Struct: `EditorInspectorContent`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = EditorInspectorContent()`
- **Variabili principali**: index, routeId, idx, appState, alt1, l2, nextNode, alt2, currentSlope, distM, edgeId, route, sid, dist, l1

**Metodi:**
  * **`addStationToRoute`**
    - **Parametri**: `node: RailwayNode, route: TrainRoute`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`routeEditor`**
    - **Parametri**: `route: TrainRoute`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateSlope`**
    - **Parametri**: `from: RailwayNode, to: RailwayNode`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`getNodeName`**
    - **Parametri**: `_ id: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `TrackGraphicView.swift`

#### Struct: `TrackGraphicView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrackGraphicView()`
- **Variabili principali**: body, trackType, color, width, isInteractive

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `VerticalDashedLine`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = VerticalDashedLine()`
- **Variabili principali**: path

**Metodi:**
  * **`path`**
    - **Parametri**: `in rect: CGRect`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `RouteCreationInspectorView.swift`

#### Struct: `RouteCreationInspectorView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RouteCreationInspectorView()`
- **Variabili principali**: proposedOffset, maxDistance, appState, saturation, lastStation, newSaturation, baseColor, cadenceFrequency, emptyStateView, hasCommonOrigin, stationSelectionView, firstStation, lineName, newHue, mostSimilarRoute

**Metodi:**
  * **`stationRow`**
    - **Parametri**: `index: Int, stationId: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`stationName`**
    - **Parametri**: `for stationId: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`deleteStation`**
    - **Parametri**: `at offsets: IndexSet`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`suggestColorForRoute`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`generateSimilarColor`**
    - **Parametri**: `from baseColor: Color`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`generateDistinctColor`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`saveRoute`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `SettingsView.swift`

#### Struct: `SettingsView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = SettingsView()`
- **Variabili principali**: showCredits, network, showGrid, appState, showExporter, trainManager, showImporter, importError, showLogs, showDeleteConfirmation

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `DebugContent`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = DebugContent()`
- **Variabili principali**: jsonData, cancellables, title, lineManagementSection, encoder, dangerZoneSection, testResultMessage, languageSection, jsonString, testErrorMessage, debugContent, body, headerSection, appearanceSection, id

**Metodi:**
  * **`sectionHeader`**
    - **Parametri**: `icon: String, title: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`settingsNavigationRow`**
    - **Parametri**: `icon: String, title: String, destination: AnyView`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`assignColorsToAllLines`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `Ferrovia.swift`

#### Struct: `RailwayLine`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RailwayLine()`
- **Variabili principali**: color, displayColor, nodeIds, electrification, name, id

- *Nessun metodo rilevato in questa Struct.*

### File: `SimulationLogManager.swift`

#### Struct: `LogEntry`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = LogEntry()`
- **Variabili principali**: entries, message, entry, type, timestamp, id

**Metodi:**
  * **`addLog`**
    - **Parametri**: `_ message: String, type: LogEntry.LogType = .info, timestamp: Date = Date(`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`clear`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `TrainCreationView.swift`

#### Struct: `TrainCreationView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrainCreationView()`
- **Variabili principali**: repeatCount, retDepTime, list, nextHour, template, base, appState, frequencyMinutes, dismiss, selectedVehicleTemplateId, createdTrainsCount, stops, currentNumReturn, vehicleName, includeReturn

**Metodi:**
  * **`setupDefaults`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`nominalDuration`**
    - **Parametri**: `from startId: String, to endId: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`processCreation`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`buildTrain`**
    - **Parametri**: `number: Int, origin: String, dest: String, departure: Date`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`extractStops`**
    - **Parametri**: `from start: String, to end: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`stationName`**
    - **Parametri**: `for id: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `FloatingUIComponents.swift`

#### Struct: `FloatingModeBar`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = FloatingModeBar()`
- **Variabili principali**: body, appState

**Metodi:**
  * **`icon`**
    - **Parametri**: `for mode: AppMode`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `FloatingSideMenu`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = FloatingSideMenu()`
- **Variabili principali**: linesManager, body, appState

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `MenuRow`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = MenuRow()`
- **Variabili principali**: body, icon, appState, action, title, isSelected

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `ContextualInspector`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ContextualInspector()`
- **Variabili principali**: editingLine, isListEditMode, isCreatingVehicle, appState, showingDeleteAlert, linesManager, itemToDelete, ioTab, editingVehicle

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `AnyIdentifiable`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = AnyIdentifiable()`
- **Variabili principali**: p2, automationsSection, idx, trainId, vehiclesList, tabSelector, exportSection, tracksList, line, itemType, globalSidebarList, vehicle, from, stationsList, edgeId

**Metodi:**
  * **`selectedLineInspector`**
    - **Parametri**: `_ line: TrainRoute`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`performDelete`**
    - **Parametri**: `_ item: AnyIdentifiable`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`elementList`**
    - **Parametri**: `for type: RailElementType`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`rowView`**
    - **Parametri**: `title: String, icon: String, id: String, type: RailElementType`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`isItemSelected`**
    - **Parametri**: `_ id: String, type: RailElementType`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`nodeBackgroundColor`**
    - **Parametri**: `for nodeId: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `RuleRow`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RuleRow()`
- **Variabili principali**: edges, activityVC, body, tmpURL, icon, desktop, value, fileName, nodes, label, root, scene, data

**Metodi:**
  * **`exportNodesAndEdges`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `LineRow`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = LineRow()`
- **Variabili principali**: body, destination, allRoutes, sameTerminals, appState, origin, isUnique, linesManager, mid, line, midStops

**Metodi:**
  * **`findUniqueIntermediate`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `LineRowContent`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = LineRowContent()`
- **Variabili principali**: body, destination, allRoutes, sameTerminals, appState, origin, isUnique, linesManager, mid, line, midStops

**Metodi:**
  * **`findUniqueIntermediate`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `LineQuickStats`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = LineQuickStats()`
- **Variabili principali**: generator, body, longPressMode, idx, appState, linesManager, hex, current, line

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `LineVehiclesView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = LineVehiclesView()`
- **Variabili principali**: body, assignedTrains, vehicle, dep, cleaned, appState, groupedTrains, linesManager, brands, lineId, vehicleId

**Metodi:**
  * **`cleanModelName`**
    - **Parametri**: `_ name: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `LineScheduleSummaryView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = LineScheduleSummaryView()`
- **Variabili principali**: body, appState, trains, linesManager, line

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `StationQuickStats`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = StationQuickStats()`
- **Variabili principali**: body, appState, linesManager, hub, node, onEdit

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `StationRoutingConstraintsView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = StationRoutingConstraintsView()`
- **Variabili principali**: linesManager, body, appState, node

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `RoutingConstraintRow`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RoutingConstraintRow()`
- **Variabili principali**: body, appState, linesManager, line, constraint

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `TrackQuickStats`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrackQuickStats()`
- **Variabili principali**: toName, body, fromName, edge, appState, onEdit

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `CompactInfoRow`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = CompactInfoRow()`
- **Variabili principali**: appState, body, label, value

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `EdgeRowButton`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = EdgeRowButton()`
- **Variabili principali**: toName, body, fromName, edge, appState

**Metodi:**
  * **`cornerRadius`**
    - **Parametri**: `_ radius: CGFloat, corners: UIRectCorner`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `RoundedCorner`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RoundedCorner()`
- **Variabili principali**: corners, path, radius

**Metodi:**
  * **`path`**
    - **Parametri**: `in rect: CGRect`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `SidebarSubButton`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = SidebarSubButton()`
- **Variabili principali**: body, icon, appState, action, title, isSelected

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `SidebarButton`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = SidebarButton()`
- **Variabili principali**: isSpecial, body, icon, action, customIcon, appState, title, ci, si

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `SidebarSection`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = SidebarSection()`
- **Variabili principali**: title, body, appState, content

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `MetricView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = MetricView()`
- **Variabili principali**: body, label, value

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `StationInlineEditor`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = StationInlineEditor()`
- **Variabili principali**: longitudeText, latitudeText, isEditingCoordinates, availableHubs, body, lon, color, appState, value, localPlatforms, linesManager, hub, lat, colorHex, node

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `TrackInlineEditor`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrackInlineEditor()`
- **Variabili principali**: body, toStation, toLat, edge, fromNode, fromLat, midLat, appState, fromStation, points, fromLon, midLon, newPoint, toLon, toNode

**Metodi:**
  * **`updateTrackType`**
    - **Parametri**: `_ type: RailwayEdge.TrackType`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`updateCapacity`**
    - **Parametri**: `for type: RailwayEdge.TrackType`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`trackLabel`**
    - **Parametri**: `for type: RailwayEdge.TrackType`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`trackIcon`**
    - **Parametri**: `for type: RailwayEdge.TrackType`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`addGeometryPoint`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`removeGeometryPoint`**
    - **Parametri**: `at index: Int`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `StationRowContent`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = StationRowContent()`
- **Variabili principali**: body, platforms, customColor, typeStr, color, appState, nodeColor, node

**Metodi:**
  * **`stationSymbol`**
    - **Parametri**: `size: CGFloat = 28`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `InspectorWrapperView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = InspectorWrapperView()`
- **Variabili principali**: title, body, appState, content

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `TrackRowContent`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrackRowContent()`
- **Variabili principali**: toName, body, fromName, edge, network, appState, trackColor

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `FerroviaRowContent`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = FerroviaRowContent()`
- **Variabili principali**: body, appState, ferrovia

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `LineInfrastructureView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = LineInfrastructureView()`
- **Variabili principali**: body, idx, appState, linesManager, line

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `LinePropertyEditor`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = LinePropertyEditor()`
- **Variabili principali**: body, lineCodeBinding, currentLine, idx, appState, _, lineNameBinding, lineColorBinding, linesManager, hex, linePrefixBinding, line

- *Nessun metodo rilevato in questa Struct.*

### File: `StationEditView.swift`

#### Struct: `StationEditView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = StationEditView()`
- **Variabili principali**: allRoutesSorted, appState, dismiss, isRoutingSheetPresented, localPlatforms, station, nextIds, onDelete, showDeleteConfirmation, availableHubs, loader, route, railroad, initialStation, stopIndices

**Metodi:**
  * **`isRouteAtStation`**
    - **Parametri**: `_ routeId: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`possibleNextStations`**
    - **Parametri**: `for routeId: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `DirectionGroup`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = DirectionGroup()`
- **Variabili principali**: visualStyleSection, dirId, idx, coordinatesSection, routeName, directionGroups, hex, stationDataSection, name, newC, routes, neighborIds, route, groupRoutes, _

**Metodi:**
  * **`symbolImage`**
    - **Parametri**: `for type: RailwayNode.StationVisualType`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`isTerminus`**
    - **Parametri**: `routeId: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`updateTracks`**
    - **Parametri**: `routeId: String, directionId: String?, tracks: [String], type: TrackConfigType`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `RoutingLineRow`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RoutingLineRow()`
- **Variabili principali**: totalPlatforms, body, appState, route, transitTracks, stopTracks, allowedTracks, track, isSelected

**Metodi:**
  * **`trackSelector`**
    - **Parametri**: `for tracks: Binding<[String]>, color: Color`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `TrainTrackParametersView.swift`

#### Struct: `TrainTrackParametersView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrainTrackParametersView()`
- **Variabili principali**: body, appState

- *Nessun metodo rilevato in questa Struct.*

### File: `AISettingsView.swift`

#### Struct: `AISettingsView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = AISettingsView()`
- **Variabili principali**: body, url, isTestLoading, cancellables, result, appState, error, testErrorMessage, testResultMessage

**Metodi:**
  * **`testConnection`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `RailwaySharedVisualization.swift`

#### Struct: `RailwayInteractionIcon`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RailwayInteractionIcon()`
- **Variabili principali**: body, color, activeColor, systemName, isActive

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `StationNodeSymbol`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = StationNodeSymbol()`
- **Variabili principali**: size, body, color, isTransit, node, defaultColor

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `RouteTrackSegment`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RouteTrackSegment()`
- **Variabili principali**: body, appState, trackType, color

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `VerticalDiagramStep`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = VerticalDiagramStep()`
- **Variabili principali**: onStationTap, stationId, onInsert, onDelete, segmentMetadata, lineColor, nextStationId, onInsertAfter, extraInfo, onSegmentTap, body, network, isTransit, generator, onInsertBefore

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `LineSegmentMetadataView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = LineSegmentMetadataView()`
- **Variabili principali**: body, edge, network, from, trackTypeLabel, to

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `TrainSegmentMetadataView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrainSegmentMetadataView()`
- **Variabili principali**: isOrigin, body, f, dep, arr, arrivalTime, departureTime, segmentDistance, isTerminus

**Metodi:**
  * **`formatTime`**
    - **Parametri**: `_ date: Date`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `ConnectionLineView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ConnectionLineView()`
- **Variabili principali**: body, color, edge, network, from, to

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `DashedLine`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = DashedLine()`
- **Variabili principali**: path

**Metodi:**
  * **`path`**
    - **Parametri**: `in rect: CGRect`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `ExportUtils.swift`

#### Struct: `ExportUtils`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ExportUtils()`
- **Variabili principali**: printInfo, av, url, printOp, image, renderer, root, picker, window, windowScene, controller

**Metodi:**
  * **`shareItem`**
    - **Parametri**: `_ item: Any`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`printImage`**
    - **Parametri**: `_ image: UIImage, jobName: String = "Stampa FdC"`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `LineGraphView.swift`

#### Struct: `LineGraphView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = LineGraphView()`
- **Variabili principali**: found, graphWidth, p2, stationDistances, timeScale, idx, maxDistance, appState, lastScale, trains, trainId, l2, hour, arrival, bestTrain

**Metodi:**
  * **`graphContent`**
    - **Parametri**: `geometry: GeometryProxy, verticalProxy: ScrollViewProxy`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`findTrainAtLocation`**
    - **Parametri**: `_ location: CGPoint`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`timeToX`**
    - **Parametri**: `_ date: Date`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`checkSegments`**
    - **Parametri**: `_ points: [CGPoint], for train: RailwayTrain, at location: CGPoint, minDist: inout CGFloat, best: inout RailwayTrain?`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`distanceToSegment`**
    - **Parametri**: `p: CGPoint, a: CGPoint, b: CGPoint`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `GridLayer`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = GridLayer()`
- **Variabili principali**: body, stationDistances, km, height, path, timeScale, width, pixelsPerKm, appState, y, orderedStations, x

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `TrainLayer`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrainLayer()`
- **Variabili principali**: p2, stationDistances, timeScale, idx, appState, arrival, orderedStations, components, movedToStart, color, manager, departure, maxX, isSelected, body

**Metodi:**
  * **`timeToX`**
    - **Parametri**: `_ date: Date`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`drawTrainPath`**
    - **Parametri**: `_ points: [CGPoint], for train: RailwayTrain, in context: GraphicsContext`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`strokePath`**
    - **Parametri**: `_ path: Path, for train: RailwayTrain, in context: GraphicsContext`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `ConflictLayer`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ConflictLayer()`
- **Variabili principali**: resId, stationDistances, timeScale, idx, stationId, appState, parts, orderedStations, components, manager, idx2, rect, idx1, body, height

**Metodi:**
  * **`timeToX`**
    - **Parametri**: `_ date: Date`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`drawMarker`**
    - **Parametri**: `at point: CGPoint, icon: String, in context: GraphicsContext`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `StationLabelsView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = StationLabelsView()`
- **Variabili principali**: body, appState, selectedStation, pixelsPerKm, y, stations, station, distances, dist

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `StationScheduleViewWrapper`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = StationScheduleViewWrapper()`
- **Variabili principali**: body, network, stationId, manager, station, id

- *Nessun metodo rilevato in questa Struct.*

### File: `LineDetailView.swift`

#### Struct: `LineDetailView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = LineDetailView()`
- **Variabili principali**: selectedNode, showScheduleCreator, body, network, appState, selectedEdgeId, isMoveModeEnabled, showFleetManager, colorBinding, hex, line, unassignedTrains, id

**Metodi:**
  * **`stopName`**
    - **Parametri**: `_ id: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `LineFleetManagementView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = LineFleetManagementView()`
- **Variabili principali**: manager, body, line, dismiss

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `LineFleetManagementContent`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = LineFleetManagementContent()`
- **Variabili principali**: sortedModels, body, modelVehicles, manager, dep, idx, appState, trains, v, groupedVehicles, showingAddVehicle, vId, showUnassignedOnly, line

- *Nessun metodo rilevato in questa Struct.*

### File: `FdCInspectorNavigator.swift`

#### Struct: `Page`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = Page()`
- **Variabili principali**: id, title, canGoBack, content, currentTitle, stack

**Metodi:**
  * **`pop`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`popToRoot`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `StationBoardView.swift`

#### Struct: `StationBoardView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = StationBoardView()`
- **Variabili principali**: body, timeB, arrivals, dep, result, appState, arr, dismiss, timeA, plat, formatter, station, cap, stop

**Metodi:**
  * **`formatTime`**
    - **Parametri**: `_ date: Date`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `StationScheduleView.swift`

#### Struct: `StationScheduleView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = StationScheduleView()`
- **Variabili principali**: sortOrder, network, manager, station, selectedTrack

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `StationArrival`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = StationArrival()`
- **Variabili principali**: routeMap, list, filteredArrivals, idx, appState, trainName, trains, trainId, relationName, destId, vehicles, vehicleName, stop, binding, tracks

**Metodi:**
  * **`applyFilters`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateArrivals`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`getName`**
    - **Parametri**: `_ id: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`arrivalRow`**
    - **Parametri**: `for item: StationArrival`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `ScheduleCreationView+Components.swift`

#### Struct: `ScheduleMetricView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ScheduleMetricView()`
- **Variabili principali**: body, label, value

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `StationSymbolView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = StationSymbolView()`
- **Variabili principali**: size, body, station

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `InterchangeSymbolView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = InterchangeSymbolView()`
- **Variabili principali**: size, body

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `RegularStationSymbolView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RegularStationSymbolView()`
- **Variabili principali**: size, body, station, color

- *Nessun metodo rilevato in questa Struct.*

### File: `TrainsListView.swift`

#### Struct: `TrainsListView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrainsListView()`
- **Variabili principali**: suggestingForRoute, isAiLoading, network, manager, appState, selectedTrains, showScheduleForRoute, customTrainRoute, showAddTrain, aiSuggestion

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `ScheduleRequest`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ScheduleRequest()`
- **Variabili principali**: activeScheduleRequest, body, id, route, unassignedSection, toDel, unassigned, aiAlertBinding, toolbarContent, listContent, mode

**Metodi:**
  * **`scheduleCreationSheet`**
    - **Parametri**: `for req: ScheduleRequest`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`trainCreationSheet`**
    - **Parametri**: `for route: TrainRoute`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`scheduleViewCover`**
    - **Parametri**: `for route: TrainRoute`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `LineHeader`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = LineHeader()`
- **Variabili principali**: body, onShowSchedule, c, line, onAddTrainCadenced, onAddTrain

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `TrainRow`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrainRow()`
- **Variabili principali**: onSelectTrain, body, train, selectedIds, manager, dep, v, vId, f, onToggleSelection

**Metodi:**
  * **`formatTime`**
    - **Parametri**: `_ date: Date`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `ScheduleCreationView.swift`

#### Struct: `ScheduleCreationView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ScheduleCreationView()`
- **Variabili principali**: stationSelectSection, body, showModelSelector, network, manager, appState, vm, dismiss, route, bodyContent, showOptimizedTimesPreview, formScrollContent, headerSection, data

**Metodi:**
  * **`handleOptimizedTimesConfirmed`**
    - **Parametri**: `_ confirmed: Bool`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`handleStationChange`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`stationPickerRow`**
    - **Parametri**: `title: String, selection: Binding<String>`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `StationPickerRow`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = StationPickerRow()`
- **Variabili principali**: status, taktInfoMessage, emptyStopPatternMessage, grad, stopPatternHeader, geneticOptimizerToggle, title, trainTypePicker, cadenceSelectionSection, direttoButton, imageName, infrastructureCharacteristicsRow, localeButton, lc, taktfahrplanSection

**Metodi:**
  * **`infraBadge`**
    - **Parametri**: `icon: String, label: String, color: Color`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`gradientIcon`**
    - **Parametri**: `_ g: Double`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`gradientLabel`**
    - **Parametri**: `_ g: Double`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`gradientColor`**
    - **Parametri**: `_ g: Double`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`vehicleModelThumbnail`**
    - **Parametri**: `model: TrainModel`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`vehicleModelInfo`**
    - **Parametri**: `model: TrainModel`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`stopPatternRow`**
    - **Parametri**: `index: Int, stationId: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`stopIndicator`**
    - **Parametri**: `isSkipped: Bool`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`stopLabel`**
    - **Parametri**: `stationId: String, isFirst: Bool, isLast: Bool, isSkipped: Bool`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`skipToggleButton`**
    - **Parametri**: `stationId: String, isSkipped: Bool`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`taktStationPicker`**
    - **Parametri**: `stations: [String]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`taktTimeWindow`**
    - **Parametri**: `title: String, value: String, color: Color`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`optimizationProgressView`**
    - **Parametri**: `status: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`optimizationHeader`**
    - **Parametri**: `status: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`generateButton`**
    - **Parametri**: `isValid: Bool`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`infoLabel`**
    - **Parametri**: `title: String, value: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `ScheduleChangeModifiersA`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ScheduleChangeModifiersA()`
- **Variabili principali**: appState, handleOptimizedTimesConfirmed, vm, handleStationChange

**Metodi:**
  * **`body`**
    - **Parametri**: `content: Content`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `ScheduleChangeModifiersB`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ScheduleChangeModifiersB()`
- **Variabili principali**: appState, vm

**Metodi:**
  * **`body`**
    - **Parametri**: `content: Content`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `ScheduleChangeModifiersB1`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ScheduleChangeModifiersB1()`
- **Variabili principali**: vm

**Metodi:**
  * **`body`**
    - **Parametri**: `content: Content`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `ScheduleChangeModifiersB2`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ScheduleChangeModifiersB2()`
- **Variabili principali**: appState, vm

**Metodi:**
  * **`body`**
    - **Parametri**: `content: Content`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `IOManagementView.swift`

#### Struct: `IOManagementView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = IOManagementView()`
- **Variabili principali**: ext, message, trimmedName, sanitized, speed, appState, showExporter, isImporting, subtitle, snippets, lat, legacySection, trackImportMessage, stationJsonInput, singleSnippet

**Metodi:**
  * **`importDTO`**
    - **Parametri**: `_ dto: RailwayNetworkDTO`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`normalizedInfrastructureNodes`**
    - **Parametri**: `_ nodes: [RailwayNode]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`addStationsFromJson`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`processStationSnippets`**
    - **Parametri**: `_ snippets: [StationSnippet]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`addTracksFromJson`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`processTrackSnippets`**
    - **Parametri**: `_ snippets: [TrackSnippet]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`mapTrackType`**
    - **Parametri**: `_ rawType: String?`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`mapNodeType`**
    - **Parametri**: `_ rawType: String?`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`sanitizeJsonSnippet`**
    - **Parametri**: `_ input: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`lastValidCoordinate`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `RailwayNetworkDocument`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RailwayNetworkDocument()`
- **Variabili principali**: readableContentTypes, dto, encoder, decoder, container, data

**Metodi:**
  * **`fileWrapper`**
    - **Parametri**: `configuration: WriteConfiguration`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `InfrastructureDocument`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = InfrastructureDocument()`
- **Variabili principali**: edges, readableContentTypes, encoder, nodes

**Metodi:**
  * **`fileWrapper`**
    - **Parametri**: `configuration: WriteConfiguration`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `Payload`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = Payload()`
- **Variabili principali**: edges, nodes, payload, data

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `InfrastructurePayload`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = InfrastructurePayload()`
- **Variabili principali**: edges, nodes

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `StationSnippet`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = StationSnippet()`
- **Variabili principali**: latitude, longitude, type, name, id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `TrackSnippet`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrackSnippet()`
- **Variabili principali**: from, distance, type, to, maxSpeed

- *Nessun metodo rilevato in questa Struct.*

### File: `CommonInspectorView.swift`

#### Struct: `InspectorView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = InspectorView()`
- **Variabili principali**: body, icon, onClose, title, iconColor, content, onBack

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `InspectorHeader`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = InspectorHeader()`
- **Variabili principali**: body, icon, onClose, title, iconColor, onBack

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `InspectorSection`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = InspectorSection()`
- **Variabili principali**: body, icon, title, iconColor, content

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `InspectorTextField`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = InspectorTextField()`
- **Variabili principali**: text, body, label, placeholder

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `InspectorNumberField`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = InspectorNumberField()`
- **Variabili principali**: body, range, value, label, unit

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `InspectorPicker`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = InspectorPicker()`
- **Variabili principali**: body, selection, label, content

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `InspectorInfoBanner`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = InspectorInfoBanner()`
- **Variabili principali**: body, message, icon, color, title, type

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `InspectorDeleteButton`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = InspectorDeleteButton()`
- **Variabili principali**: onDelete, body, label, showConfirmation

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `EditingModeBanner`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = EditingModeBanner()`
- **Variabili principali**: body, isEditingEnabled

- *Nessun metodo rilevato in questa Struct.*

### File: `LineEditingSystem.swift`

#### Struct: `StationSequenceSection`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = StationSequenceSection()`
- **Variabili principali**: stationSequence, body, mapPickingType, network, activePicker, lineColor, node, suggestions

- *Nessun metodo rilevato in questa Struct.*

### File: `RailwayAISchedulerView.swift`

#### Struct: `RailwayAISchedulerView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RailwayAISchedulerView()`
- **Variabili principali**: cancellables, loadingOverlay, station, emptyStateView, request, showChart, service, saved, response, _, headerView, statusCard, error, showExport, body

**Metodi:**
  * **`summaryItem`**
    - **Parametri**: `icon: String, title: String, value: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`modificationsSection`**
    - **Parametri**: `response: RailwayAIResponse`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`modificationRow`**
    - **Parametri**: `mod: RailwayAIModification`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`analysisCard`**
    - **Parametri**: `response: RailwayAIResponse`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`analysisItem`**
    - **Parametri**: `title: String, value: String, color: Color`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`runOptimization`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`modificationColor`**
    - **Parametri**: `type: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`modificationIcon`**
    - **Parametri**: `type: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`modificationValue`**
    - **Parametri**: `mod: RailwayAIModification`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `Extensions.swift`

#### Struct: `IdentifiableString`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = IdentifiableString()`
- **Variabili principali**: id

- *Nessun metodo rilevato in questa Struct.*

### File: `AdminUserListView.swift`

#### Struct: `AdminUserListView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = AdminUserListView()`
- **Variabili principali**: addUserSheet, isAdding, body, showAuthError, showAddUser, cancellables, users, newUsername, errorMessage, error, newPassword, service, isLoading

**Metodi:**
  * **`loadUsers`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`performAddUser`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`deleteUser`**
    - **Parametri**: `_ username: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`resetAddForm`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `ConflictDashboardView.swift`

#### Struct: `ConflictDashboardView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ConflictDashboardView()`
- **Variabili principali**: idx, stationId, appState, overlapEnd, parts, trains, allConflictsList, candidates, trainA, station, prevId, stop, buffer, counts, track

**Metodi:**
  * **`analyzeHotspots`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateSuggestion`**
    - **Parametri**: `for conflict: ScheduleConflict`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`processTrain`**
    - **Parametri**: `_ train: Train`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`isTrackFree`**
    - **Parametri**: `stationId: String, track: String, from: Date, to: Date, excludingId: UUID`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`getPrevStation`**
    - **Parametri**: `for train: Train, currentStation: Node`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`getNextStation`**
    - **Parametri**: `for train: Train, currentStation: Node`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`findStation`**
    - **Parametri**: `for conflict: ScheduleConflict`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `HotspotInfo`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = HotspotInfo()`
- **Variabili principali**: count, id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `SuccessBanner`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = SuccessBanner()`
- **Variabili principali**: body, appState

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `ConflictHeader`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ConflictHeader()`
- **Variabili principali**: count, body, appState

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `HotspotCard`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = HotspotCard()`
- **Variabili principali**: body, network, appState, hotspot, name

- *Nessun metodo rilevato in questa Struct.*

### File: `RollingStockView.swift`

#### Struct: `RollingStockView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RollingStockView()`
- **Variabili principali**: isListEditMode, routeId, vehicleListByLine, appState, showingAddSheet, manufacturer, vehicle, m, manager, groupingMode, route, vehicleListByManufacturer, vehicleListByName, body, vehicleListByModel

**Metodi:**
  * **`getManufacturer`**
    - **Parametri**: `for model: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`deleteVehicles`**
    - **Parametri**: `at offsets: IndexSet`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `VehicleRowContent`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = VehicleRowContent()`
- **Variabili principali**: body, assignedTrains, vehicle, m, manager, modelColor, appState, _, imageName

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `VehicleRow`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = VehicleRow()`
- **Variabili principali**: body, vehicle, m, manager, modelColor, appState, sorted, trains, conflicts

- *Nessun metodo rilevato in questa Struct.*

### File: `VisualizationSettingsView.swift`

#### Struct: `VisualizationSettingsView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = VisualizationSettingsView()`
- **Variabili principali**: showGrid, body, appState

**Metodi:**
  * **`colorSwatch`**
    - **Parametri**: `color: Color, name: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `RouteSectionView.swift`

#### Struct: `RouteSectionView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RouteSectionView()`
- **Variabili principali**: body, manager, lineTrains, route, selectedTrains, toDel, onShowSchedule, isExpanded, onAddTrain

- *Nessun metodo rilevato in questa Struct.*

### File: `MapGeometryEngine.swift`

#### Struct: `MapGeometryEngine`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = MapGeometryEngine()`
- **Variabili principali**: offset, lon, direction, parent, y, candidates, cost, best, lat, parentId, x, pPos

**Metodi:**
  * **`schematicPoint`**
    - **Parametri**: `for node: RailwayNode, in size: CGSize, bounds: SchematicRailwayView.MapBounds`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`finalPosition`**
    - **Parametri**: `for node: RailwayNode, in size: CGSize, bounds: SchematicRailwayView.MapBounds, network: NetworkModel`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`generateSchematicPoints`**
    - **Parametri**: `from p1: CGPoint, to p2: CGPoint, avoidPoints: [CGPoint] = [], neighborsStart: [CGPoint] = [], neighborsEnd: [CGPoint] = []`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `SchematicCandidate`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = SchematicCandidate()`
- **Variabili principali**: nodeNeighbors, a2, dx, neighbors, firstEdge, geometries, offsetDistance, x, color, trackCount, elapsed, t, sx, offset, nPosStart

**Metodi:**
  * **`generateSchematicCandidates`**
    - **Parametri**: `from p1: CGPoint, to p2: CGPoint`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculatePathCost`**
    - **Parametri**: `path: [CGPoint], avoid: [CGPoint], neighborsStart: [CGPoint], neighborsEnd: [CGPoint]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`normalize`**
    - **Parametri**: `vector: CGPoint`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`distanceToSegment`**
    - **Parametri**: `_ p: CGPoint, _ v: CGPoint, _ w: CGPoint`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`currentSchematicTrainPos`**
    - **Parametri**: `for schedule: TrainSchedule, in size: CGSize, now: Date, bounds: SchematicRailwayView.MapBounds, network: NetworkModel`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateNodePositions`**
    - **Parametri**: `network: NetworkModel, size: CGSize, bounds: SchematicRailwayView.MapBounds`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`buildNodeNeighbors`**
    - **Parametri**: `network: NetworkModel`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`groupEdgesByPair`**
    - **Parametri**: `network: NetworkModel`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`toCanvasCoords`**
    - **Parametri**: `lat: Double, lon: Double, size: CGSize, bounds: SchematicRailwayView.MapBounds`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`applyOffsets`**
    - **Parametri**: `for edges: [RailwayEdge], basePoints: [CGPoint], results: inout [String: [CGPoint]]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`offsetPoints`**
    - **Parametri**: `_ points: [CGPoint], offset: CGFloat`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculatePerpendicularAt`**
    - **Parametri**: `_ i: Int, in points: [CGPoint]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`perpendicularBetween`**
    - **Parametri**: `_ p1: CGPoint, _ p2: CGPoint`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateHubGeometries`**
    - **Parametri**: `network: NetworkModel, nodePositions: [String: CGPoint]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `MapDrawing`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = MapDrawing()`
- **Variabili principali**: rect, textObj, sz, resolved

**Metodi:**
  * **`drawNodeLabel`**
    - **Parametri**: `context: GraphicsContext, text: String, at: CGPoint, color: Color, fontSize: CGFloat`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `StationInspectorView.swift`

#### Struct: `StationInspectorView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = StationInspectorView()`
- **Variabili principali**: visualStyleSection, isEditingEnabled, dirId, coordinatesSection, appState, isRoutingSheetPresented, station, hex, onDelete, lineName, availableHubs, taktfahrplanSection, loader, basicInfoSection, railroad

**Metodi:**
  * **`symbolImage`**
    - **Parametri**: `for type: RailwayNode.StationVisualType`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `DirectionGroup`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = DirectionGroup()`
- **Variabili principali**: newC, idx, stationLines, result, neighborIds, groupLines, directionGroups, groupsMap, lines, name, id

**Metodi:**
  * **`updateTracks`**
    - **Parametri**: `routeId: String, directionId: String?, tracks: [String], type: TrackConfigType`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `TrackInspectorView.swift`

#### Struct: `TrackInspectorView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrackInspectorView()`
- **Variabili principali**: isEditingEnabled, trackTypeIcon, appState, trackTitle, onDelete, trackTypeLabel, loader, from, fromStation, parametersWarning, body, edge, network, parametersSection, trackTypeSection

**Metodi:**
  * **`stationRow`**
    - **Parametri**: `station: RailwayNode?, label: String, icon: String, color: Color`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`updateParametersForTrackType`**
    - **Parametri**: `_ type: RailwayEdge.TrackType`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `SchedulerView.swift`

#### Struct: `SchedulerView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = SchedulerView()`
- **Variabili principali**: selectedSchedule, showManualEdit, appState, showChart, url, response, showPrint, error, schedulerResult, railroad, selectedTrain, showExport, body, network, selectedStation

**Metodi:**
  * **`simulateLocally`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `TimetableChartView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TimetableChartView()`
- **Variabili principali**: body, dismiss, schedulerResult

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `TimetableChart`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TimetableChart()`
- **Variabili principali**: t2, body, dep, t1, arr, appState, start, end, lines, data

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `TimetableChartData`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TimetableChartData()`
- **Variabili principali**: time, train, foundTimeToken, norm, date, parts, start, minutes, data, station, comps, tokens, timeStr, ft, tnorm

**Metodi:**
  * **`parse`**
    - **Parametri**: `from result: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `TrainsDetailView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrainsDetailView()`
- **Variabili principali**: body, newType, newName, manager, showAdd, newMaxSpeed

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `SchedulerResultDocument`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = SchedulerResultDocument()`
- **Variabili principali**: result, readableContentTypes, str, data

**Metodi:**
  * **`fileWrapper`**
    - **Parametri**: `configuration: WriteConfiguration`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `FDCFileDocument`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = FDCFileDocument()`
- **Variabili principali**: readableContentTypes, url, str, content, components, baseURL, data

**Metodi:**
  * **`fileWrapper`**
    - **Parametri**: `configuration: WriteConfiguration`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`sendToScheduler`**
    - **Parametri**: `dto: RailwayNetworkDTO, trains: [Train], completion: @escaping (Result<String, Error>`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `Payload`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = Payload()`
- **Variabili principali**: network, trains

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `SchedulerResponse`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = SchedulerResponse()`
- **Variabili principali**: task, payload, result, error, request, lines, decoded, conflicts, data

**Metodi:**
  * **`parseConflicts`**
    - **Parametri**: `from result: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `ManualEditView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ManualEditView()`
- **Variabili principali**: body, dismiss, schedulerResult, editedText

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `PrintView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = PrintView()`
- **Variabili principali**: printInfo, body, dismiss, formatter, printController, text, loadedNetwork

**Metodi:**
  * **`printText`**
    - **Parametri**: `_ text: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`loadRailwayNetwork`**
    - **Parametri**: `from url: URL`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`saveRailwayNetwork`**
    - **Parametri**: `to url: URL`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `TrainInspectorView.swift`

#### Struct: `TrainInspectorView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrainInspectorView()`
- **Variabili principali**: routeId, isEditingEnabled, appState, showVehicleSheet, vehicleDetailsButton, imageName, line, binding, url, vehicle, conflictBanner, manager, color, error, vId

**Metodi:**
  * **`content`**
    - **Parametri**: `train: Binding<RailwayTrain>`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`schedulingErrorBanner`**
    - **Parametri**: `_ error: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`identificationSection`**
    - **Parametri**: `train: Binding<RailwayTrain>`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`vehicleImage`**
    - **Parametri**: `train: RailwayTrain`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`vehicleAssignmentSection`**
    - **Parametri**: `train: Binding<RailwayTrain>`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`vehicleMenu`**
    - **Parametri**: `train: Binding<RailwayTrain>`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`vehicleMetrics`**
    - **Parametri**: `vehicle: RailwayVehicle`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`vehicleConflicts`**
    - **Parametri**: `train: Binding<RailwayTrain>, vehicleId: UUID`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`timetableSection`**
    - **Parametri**: `train: Binding<RailwayTrain>`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`lineInfo`**
    - **Parametri**: `line: TrainRoute`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`priorityStepper`**
    - **Parametri**: `train: Binding<RailwayTrain>`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`itineraryView`**
    - **Parametri**: `train: Binding<RailwayTrain>, line: TrainRoute`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`priorityColor`**
    - **Parametri**: `_ p: Int`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `RouteInspectorView.swift`

#### Struct: `RouteInspectorView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RouteInspectorView()`
- **Variabili principali**: body, network, idx, appState, route, lines

- *Nessun metodo rilevato in questa Struct.*

### File: `NetworkListRows.swift`

#### Struct: `StationRowView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = StationRowView()`
- **Variabili principali**: selectedNode, body, node

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `EdgeRowView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = EdgeRowView()`
- **Variabili principali**: toName, body, fromName, edge, selectedEdgeId

- *Nessun metodo rilevato in questa Struct.*

### File: `EntityCreationView.swift`

#### Struct: `EntityCreationConfig`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = EntityCreationConfig()`
- **Variabili principali**: icon, emptyStateTitle, emptyStateMessage, confirmButtonTitle, buildingStateTitle, saveButtonTitle, entityName

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `EntityCreationView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = EntityCreationView()`
- **Variabili principali**: body, showingDetails, buildingContent, config, detailsStateView, buildingStateView, onClose, detailsContent, emptyStateView, isEmpty

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `EntityCreationCoordinator`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = EntityCreationCoordinator()`
- **Variabili principali**: body, appState, entityType

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `StationCreationWizard`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = StationCreationWizard()`
- **Variabili principali**: stationName, platforms, body, newStation, network, detailsView, appState, latitude, hasPosition, longitude, buildingView, stationType, isPlacingOnMap

**Metodi:**
  * **`setupMapPicking`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`cleanupMapPicking`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`saveStation`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `TrackCreationWizard`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrackCreationWizard()`
- **Variabili principali**: body, network, appState, toStationId, fromStationId, hasSelection

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `TrackCreationBuildingView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrackCreationBuildingView()`
- **Variabili principali**: body, network, toStationId, fromStationId, station, id

**Metodi:**
  * **`stationSelectionCard`**
    - **Parametri**: `title: String, stationId: String?, icon: String, color: Color`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `TrackCreationDetailsView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrackCreationDetailsView()`
- **Variabili principali**: body, trackType, network, newEdge, appState, toStationId, fromStationId, distance, capacity, maxSpeed

**Metodi:**
  * **`calculateDistance`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`updateParametersForTrackType`**
    - **Parametri**: `_ type: Edge.TrackType`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`saveTrack`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `TrainCreationWizard`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrainCreationWizard()`
- **Variabili principali**: body

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `VehicleCreationWizard`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = VehicleCreationWizard()`
- **Variabili principali**: body

- *Nessun metodo rilevato in questa Struct.*

### File: `RouteProposalView.swift`

#### Struct: `RouteProposalView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RouteProposalView()`
- **Variabili principali**: body, network, selectedRouteIds, selectedProposals, dismiss, trainManager, createSampleTrains, proposals, onApply

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `ProposalRow`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ProposalRow()`
- **Variabili principali**: body, color, names, network, onToggle, proposal, isSelected

- *Nessun metodo rilevato in questa Struct.*

### File: `VehicleComponents.swift`

#### Struct: `VehicleEditSheet`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = VehicleEditSheet()`
- **Variabili principali**: template, idx, img, appState, selectedTemplateId, dismiss, technicalSpecsSection, existing, imageName, name, vehicle, manager, maxSpeed, body, newV

**Metodi:**
  * **`applyTemplate`**
    - **Parametri**: `_ template: VehicleTemplate`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`attachedTrainsSection`**
    - **Parametri**: `_ v: Vehicle`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`attachedTrainRow`**
    - **Parametri**: `_ train: Train`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`unassignTrain`**
    - **Parametri**: `_ train: Train`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`save`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `TrainSelectionPicker`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrainSelectionPicker()`
- **Variabili principali**: vehicleTrains, idx, newDep, appState, dismiss, destId, existing, conflict, matchesLine, vehicleId, emptyTrainsSection, newArr, originId, manager, route

**Metodi:**
  * **`smartFilterSection`**
    - **Parametri**: `_ lastPos: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`trainSelectionRow`**
    - **Parametri**: `_ train: Train`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`trainHeaderRow`**
    - **Parametri**: `_ train: Train`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`trainRouteRow`**
    - **Parametri**: `_ train: Train`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`conflictWarningRow`**
    - **Parametri**: `_ conflict: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`assignVehicleToTrain`**
    - **Parametri**: `_ train: Train`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`checkPotentialConflict`**
    - **Parametri**: `train: Train`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `VehicleInspectorView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = VehicleInspectorView()`
- **Variabili principali**: appState, imageName, vehicle, m, manager, modelColor, trainIconForModel, route, originName, vehicleImageHeader, body, technicalSpecsGrid, vehicleConflictsSection, dep, arr

**Metodi:**
  * **`specItem`**
    - **Parametri**: `label: String, value: String, icon: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`assignedTrainTimelineRow`**
    - **Parametri**: `_ train: Train`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`assignedTrainTimeInfo`**
    - **Parametri**: `_ train: Train`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `NetworkListView.swift`

#### Struct: `NetworkListView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = NetworkListView()`
- **Variabili principali**: selectedNode, appState, showDeleteAllConfirmation, stationsListView, selectedEdgeId, trackVM, ferroviaVM, localizedName, ferrovieListView, body, network, stationVM, id, toName, mode

- *Nessun metodo rilevato in questa Struct.*

### File: `StationOccupancyView.swift`

#### Struct: `StationOccupancyView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = StationOccupancyView()`
- **Variabili principali**: network, manager, station, timeScale

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `OccupationBlock`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = OccupationBlock()`
- **Variabili principali**: trainName, arrival, x, stop, tracks, path, h, m, departure, foundTracks, type, track, rowHeight, body, width

**Metodi:**
  * **`timeToX`**
    - **Parametri**: `_ date: Date`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`format`**
    - **Parametri**: `_ date: Date`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`drawTimeGrid`**
    - **Parametri**: `width: CGFloat, height: CGFloat`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateOccupancy`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `TrainDetailView.swift`

#### Struct: `TrainDetailView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrainDetailView()`
- **Variabili principali**: routeId, appState, showVehicleSheet, imageName, line, binding, url, vehicle, conflictBanner, manager, color, _, error, vId, wikiImageService

**Metodi:**
  * **`content`**
    - **Parametri**: `train: Binding<Train>`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`headerSection`**
    - **Parametri**: `train: Binding<Train>`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`schedulingErrorBanner`**
    - **Parametri**: `_ error: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`identificationSection`**
    - **Parametri**: `train: Binding<Train>`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`vehicleImage`**
    - **Parametri**: `train: Train`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`vehicleAssignmentSection`**
    - **Parametri**: `train: Binding<Train>`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`timetableSection`**
    - **Parametri**: `trainBinding: Binding<Train>`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`priorityColor`**
    - **Parametri**: `_ p: Int`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `RouteCreationView.swift`

#### Struct: `RouteCreationView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RouteCreationView()`
- **Variabili principali**: manualStationId, proposedOffset, stationId, appState, analysisTask, dismiss, activePicker, showDetailsSheet, cadenceFrequency, lineName, stationsHorizontalList, headerView, error, totalDistance, lineColor

**Metodi:**
  * **`stationChip`**
    - **Parametri**: `at index: Int`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`removeStation`**
    - **Parametri**: `at index: Int`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `StationChip`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = StationChip()`
- **Variabili principali**: index, stationName, stationId, appState, neighbors, lastId, detailsForm, suggestionsOverlay, newRoute, route, error, onRemove, suggestions, body, offset

**Metodi:**
  * **`setupMapPicking`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`cleanupMapPicking`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`finishSelection`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`cancelSelection`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`findIdealOffset`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`saveAndFinish`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`getSuggestions`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`triggerLineAnalysis`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`suggestionsHorizontalList`**
    - **Parametri**: `_ suggestions: [Node]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`suggestionButton`**
    - **Parametri**: `for node: Node`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `Models.swift`

#### Struct: `RailwayNetworkDTO`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RailwayNetworkDTO()`
- **Variabili principali**: edges, routes, trains, nodes, vehicles, lines, name

**Metodi:**
  * **`toDTO`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`apply`**
    - **Parametri**: `dto: RailwayNetworkDTO`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `AIScheduleSuggestion`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = AIScheduleSuggestion()`
- **Variabili principali**: newDepartureTime, trainId, stopAdjustments, id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `StopAdjustment`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = StopAdjustment()`
- **Variabili principali**: newMinDwellTime, stationId

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `RoutingConstraint`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RoutingConstraint()`
- **Variabili principali**: routeId, transitTracks, directionStationId, stopTracks, allowedTracks, id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `Node`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = Node()`
- **Variabili principali**: allTracks, routeId, max, routingConstraints, parentHubId, matchingConstraint, lat, name, hubOffsetDirection, customColor, visualType, lon, tNum, preferred, color

**Metodi:**
  * **`encode`**
    - **Parametri**: `to encoder: Encoder`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`isTrackAllowed`**
    - **Parametri**: `track: String?, routeId: String, prevStationId: String?, nextStationId: String?`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`getTracksByProvenance`**
    - **Parametri**: `from prevStationId: String?, nextStationId: String? = nil, forRoute routeId: String?`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `Edge`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = Edge()`
- **Variabili principali**: trackType, color, from, segments, geometryPoints, maxSpeed, canonicalKey, sorted, distance, capacity, electrification, displayName, to, id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `GeometryPoint`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = GeometryPoint()`
- **Variabili principali**: longitude, latitude, container, id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `TrackSegment`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrackSegment()`
- **Variabili principali**: signal, latitude, longitude, length, altitude, isOccupied, order, speedLimit, id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `Signal`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = Signal()`
- **Variabili principali**: positionAtEnd, aspect, name, id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `Switch`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = Switch()`
- **Variabili principali**: nodeId, connectedEdges, state, id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `RelationStop`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RelationStop()`
- **Variabili principali**: plannedArrival, customDwellSeconds, plannedDeparture, extraDwellTime, stationId, track, departure, isPreferredTrack, isSkipped, arrival, minDwellTime, isManualTrack, container, id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `Vehicle`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = Vehicle()`
- **Variabili principali**: container, power, notes, id, isElectric, length, acceleration, model, mass, imageName, deceleration, name, maxSpeed

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `VehicleConflict`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = VehicleConflict()`
- **Variabili principali**: departureB, trainB, description, arrivalA, trainA, id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `VehicleTemplate`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = VehicleTemplate()`
- **Variabili principali**: power, all, id, isElectric, length, acceleration, model, mass, imageName, deceleration, name, maxSpeed

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `Train`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = Train()`
- **Variabili principali**: routeId, schedulingError, targetRouteId, deceleration, stops, matchingConstraint, encoder, vehicleId, mass, name, preferred, finalList, isMainTrain, type, allPlatforms

**Metodi:**
  * **`encode`**
    - **Parametri**: `to encoder: Encoder`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`getPreferredTracks`**
    - **Parametri**: `at node: Node, prevStationId: String?, nextStationId: String?, for route: TrainRoute?, isSkipping: Bool = false`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`isTrackPreferred`**
    - **Parametri**: `_ track: String, at node: Node, prevStationId: String?, nextStationId: String?, for routeId: String?`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`exportStationsAndTracksJSON`**
    - **Parametri**: `nodes: [Node], edges: [Edge]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `Payload`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = Payload()`
- **Variabili principali**: edges, nodes, payload, data

**Metodi:**
  * **`exportString`**
    - **Parametri**: `nodes: [Node], edges: [Edge]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `RailwayItineraryView.swift`

#### Struct: `RailwayItineraryView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RailwayItineraryView()`
- **Variabili principali**: body, train, network, appState, isReadOnly, stations, editingTrackIndex, stopConflicts, lineColor, trainConflicts, editingStopIndex

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `ItineraryStepView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ItineraryStepView()`
- **Variabili principali**: index, isOrigin, body, train, network, appState, isReadOnly, onTimeTap, isLast, node, onTrackTap, lineColor, hasConflict, stop

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `StationTimesView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = StationTimesView()`
- **Variabili principali**: index, onTap, body, isOrigin, dwellSeconds, normalized, train, appState, isReadOnly, isTerminus, currentArrival, isLast, d, hasConflict, stop

**Metodi:**
  * **`timeDisplay`**
    - **Parametri**: `label: String, date: Date?, isInteractive: Bool`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `DwellBadgeView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = DwellBadgeView()`
- **Variabili principali**: dwell, body, appState, isReadOnly

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `TrackBadgeView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrackBadgeView()`
- **Variabili principali**: onTap, body, edge, appState, isReadOnly, hasConflict, stop

**Metodi:**
  * **`calculateSegmentDistance`**
    - **Parametri**: `from: String, to: String, network: RailwayNetwork`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `TrackSelectionSheet`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrackSelectionSheet()`
- **Variabili principali**: body, allTracks, train, preferred, network, nextId, totalTracks, dismiss, stopIndex, prevId, isSelected, node, stop

**Metodi:**
  * **`trackSelectionContent`**
    - **Parametri**: `node: Node`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`trackButton`**
    - **Parametri**: `track: String, node: Node, isPreferred: Bool`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `RailroadNetwork.swift`

#### Struct: `RailroadSnapshot`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RailroadSnapshot()`
- **Variabili principali**: edges, undoStack, last, next, current, snapshot, trains, ferrovie, nodes, canRedo, vehicles, lines, redoStack, canUndo

**Metodi:**
  * **`createCheckpoint`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`undo`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`redo`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`applySnapshot`**
    - **Parametri**: `_ snapshot: RailroadSnapshot`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `TrainsByRouteListView.swift`

#### Struct: `TrainsByRouteListView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrainsByRouteListView()`
- **Variabili principali**: unassignedHeader, allRoutesGrouped, lineStops, appState, lineIndex, allLines, unassignedTrains, trainIndex, linesManager, matchingRoutes, trainsForRoute, routeForCreation, body, train, trainStops

**Metodi:**
  * **`autoAssignTrains`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`isTrainCompatible`**
    - **Parametri**: `_ train: Train, with route: TrainRoute`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `RouteTrainsSection`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RouteTrainsSection()`
- **Variabili principali**: routeSectionHeader, body, appState, route, trains, onCreateTrain, linesManager

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `TrainRowButton`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrainRowButton()`
- **Variabili principali**: body, departureTimeText, train, vehicle, vid, trainTypeBadge, appState, linesManager

- *Nessun metodo rilevato in questa Struct.*

### File: `RailwayMapView.swift`

#### Struct: `RailwayMapView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RailwayMapView()`
- **Variabili principali**: selectedNode, showModeSelector, showGrid, appState, isSchedulerMode, position, selectedLine, icon, selectedEdgeId, isExporting, railroad, displayName, network, highlightedConflictLocation, mode

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `MapBounds`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = MapBounds()`
- **Variabili principali**: edges, pdfContext, lns, printInfo, pdfUrl, consumer, gSize, root, windowScene, controller, m, schs, box, gWidth, minLat

**Metodi:**
  * **`modeButton`**
    - **Parametri**: `for vizMode: MapVisualizationMode`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`exportMap`**
    - **Parametri**: `as format: ExportFormat`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`shareItem`**
    - **Parametri**: `_ item: Any`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`printMap`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `MapSnapshotData`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = MapSnapshotData()`
- **Variabili principali**: Nessuna

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `LineDraw`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = LineDraw()`
- **Variabili principali**: color, bundleSize, name, path

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `TrainDraw`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrainDraw()`
- **Variabili principali**: color, pos, name

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `EdgeDraw`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = EdgeDraw()`
- **Variabili principali**: color, path, points, baseColor, type

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `GroupDraw`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = GroupDraw()`
- **Variabili principali**: isSingle, bottomY, label, positions, center

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `NodeDraw`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = NodeDraw()`
- **Variabili principali**: edges, p2, nodeType, parentHubId, parent, dx, trains, globalLineWidth, baseColor, firstEdge, lat, offsetDistance, name, pPos, rootNode

**Metodi:**
  * **`generateNodeDraws`**
    - **Parametri**: `nodes: [RailwayNode], bounds: MapBounds, snapshotSize: CGSize`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`finalPosition`**
    - **Parametri**: `for node: RailwayNode, bounds: MapBounds, snapshotSize: CGSize, nodes: [RailwayNode]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`generateEdgeDraws`**
    - **Parametri**: `nodes: [RailwayNode], edges: [RailwayEdge], bounds: MapBounds, snapshotSize: CGSize, mode: MapVisualizationMode`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`applyPerpendicularOffset`**
    - **Parametri**: `to points: [CGPoint], offset: CGFloat`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`perpendicular`**
    - **Parametri**: `from p1: CGPoint, to p2: CGPoint`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`generateHubClusters`**
    - **Parametri**: `nodes: [RailwayNode], bounds: MapBounds, snapshotSize: CGSize`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`generateLineDraws`**
    - **Parametri**: `nodes: [RailwayNode], lines: [TrainRoute], bounds: MapBounds, snapshotSize: CGSize`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `SegmentKey`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = SegmentKey()`
- **Variabili principali**: p2, bundleSize, a2, lons, maxLon, dx, s2, lat, s1, path, lon, from, segmentLineMap, d1, sp1

**Metodi:**
  * **`generateTrainDraws`**
    - **Parametri**: `schedules: [TrainSchedule], nodes: [RailwayNode], bounds: MapBounds, snapshotSize: CGSize`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateTrainPosition`**
    - **Parametri**: `schedule: TrainSchedule, now: Date, nodes: [RailwayNode], bounds: MapBounds, snapshotSize: CGSize`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`finalPositionStatic`**
    - **Parametri**: `for node: RailwayNode, bounds: MapBounds, snapshotSize: CGSize`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateBounds`**
    - **Parametri**: `for nodes: [RailwayNode]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`generateSchematicPoints`**
    - **Parametri**: `from p1: CGPoint, to p2: CGPoint`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `RailwayMapSnapshot`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RailwayMapSnapshot()`
- **Variabili principali**: body, bundleMap, appState, renderingContext, renderer, style, data

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `bundles`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = bundles()`
- **Variabili principali**: symbol, point, dummyNode, symbolName, label, style

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `SchematicRailwayView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = SchematicRailwayView()`
- **Variabili principali**: editMode, selectedNode, showGrid, onExport, appState, magnification, coordinateGridStep, zoom, totalZoom, newTrackTo, selectedLine, selectedEdgeId, localizedName, newTrackDistance, gridSize

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `MapBounds`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = MapBounds()`
- **Variabili principali**: moveModeOverlay, next, speed, lon1, maxLon, dx, neighbors, finalMaxLon, firstEdge, offsetDistance, distKm, perpY, fromNode, newEdge, trackCount

**Metodi:**
  * **`canvasSize`**
    - **Parametri**: `for geoSize: CGSize`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`mainViewContainer`**
    - **Parametri**: `size: CGSize, bounds: MapBounds, renderData: MapRenderData`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`scrollViewLayer`**
    - **Parametri**: `size: CGSize, bounds: MapBounds, renderData: MapRenderData`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`mapBasement`**
    - **Parametri**: `size: CGSize, bounds: MapBounds`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`scrollingAnchors`**
    - **Parametri**: `size: CGSize, bounds: MapBounds`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`mapMainLayers`**
    - **Parametri**: `size: CGSize, bounds: MapBounds, renderData: MapRenderData`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`handleCanvasLongPress`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`centerOnPosition`**
    - **Parametri**: `_ position: CGPoint, canvasSize: CGSize, proxy: ScrollViewProxy`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`centerOnNode`**
    - **Parametri**: `_ node: RailwayNode?, size: CGSize, bounds: MapBounds, proxy: ScrollViewProxy`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`centerOnLine`**
    - **Parametri**: `_ line: TrainRoute?, size: CGSize, bounds: MapBounds, proxy: ScrollViewProxy`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`centerOnEdge`**
    - **Parametri**: `_ edgeId: String?, size: CGSize, bounds: MapBounds, proxy: ScrollViewProxy`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`centerOnTrain`**
    - **Parametri**: `_ ids: [UUID], size: CGSize, bounds: MapBounds, proxy: ScrollViewProxy`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`setupLineCreationCallback`**
    - **Parametri**: `isCreating: Bool`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`trackTypeButtonContent`**
    - **Parametri**: `type: RailwayEdge.TrackType`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`handleStationTap`**
    - **Parametri**: `_ node: RailwayNode`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`createTrack`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`handleCanvasTap`**
    - **Parametri**: `at location: CGPoint, in size: CGSize`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`distanceToSegment`**
    - **Parametri**: `p: CGPoint, v: CGPoint, w: CGPoint`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`createStation`**
    - **Parametri**: `at location: CGPoint, in size: CGSize`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `StationNodeView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = StationNodeView()`
- **Variabili principali**: drawHeight, appState, snapToGrid, lat, selectionOverlay, renderNodeIconWithInteraction, gridUnit, lon, dragOffset, unit, drawWidth, isSelected, onDragStarted, bounds, onTap

**Metodi:**
  * **`symbolView`**
    - **Parametri**: `type: RailwayNode.StationVisualType, color: Color`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `CoordinateGridShape`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = CoordinateGridShape()`
- **Variabili principali**: size, bounds, maxA, path, minL, minA, currentLat, y, currentLon, unit, maxL, x

**Metodi:**
  * **`path`**
    - **Parametri**: `in rect: CGRect`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`projectX`**
    - **Parametri**: `_ lon: Double`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`projectY`**
    - **Parametri**: `_ lat: Double`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `MapControlsView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = MapControlsView()`
- **Variabili principali**: editMode, body, network, onExport, appState, onPrint, isMoveModeEnabled, isEditToolbarVisible, zoomLevel

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `InfrastructureCanvas`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = InfrastructureCanvas()`
- **Variabili principali**: fColor, appState, s2, colors, s1, totalZoom, centerX, path, renderData, isSelected, body, selectedInfraLine, edge, points, renderingContext

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `TrainOverlayCanvas`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrainOverlayCanvas()`
- **Variabili principali**: bounds, body, network, appState, canvasSize, renderer, now, pos, isSelected, totalZoom

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `StationMarkersView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = StationMarkersView()`
- **Variabili principali**: index, selectedNode, selectedLine, bounds, onTap, body, network, showGrid, coordinateGridStep, appState, selectedEdgeId, canvasSize, isMoveModeEnabled, nodeBinding

- *Nessun metodo rilevato in questa Struct.*

### File: `TrackCreationView.swift`

#### Struct: `TrackCreationView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrackCreationView()`
- **Variabili principali**: fromCoord, appState, distanceInMeters, toCoord, trackType, from, newEdge, fromStation, distanceInKm, toLocation, capacity, maxSpeed, body, network, canCreate

**Metodi:**
  * **`updateTrackType`**
    - **Parametri**: `_ type: Edge.TrackType`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`trackLabel`**
    - **Parametri**: `for type: Edge.TrackType`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`trackIcon`**
    - **Parametri**: `for type: Edge.TrackType`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateDistance`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`createTrack`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `FdCInspectorPanel.swift`

#### Struct: `FdCInspectorPanel`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = FdCInspectorPanel()`
- **Variabili principali**: body, onClose, title, navigator, content, onBack, page, header, showBackButton

- *Nessun metodo rilevato in questa Struct.*

### File: `EditorModeView.swift`

#### Struct: `EditorModeView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = EditorModeView()`
- **Variabili principali**: inspectorTitle, routeId, lon1, appState, lockedNodeIds, editingRouteId, l2, newLine, encoder, distKm, url, loader, fromNode, newEdge, edgeId

**Metodi:**
  * **`createLineFromSelection`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`createLogicalRoute`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`createNewRailwayLine`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`createStation`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`toggleTrackCreation`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`toggleMultiSelect`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`handleNodeSelection`**
    - **Parametri**: `_ node: RailwayNode?`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`createTrack`**
    - **Parametri**: `from: String, to: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`saveScenario`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`loadScenario`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`deleteSelectedItems`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `EditorButtonStyle`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = EditorButtonStyle()`
- **Variabili principali**: isActive, fgColor, isDestructive

**Metodi:**
  * **`makeBody`**
    - **Parametri**: `configuration: Configuration`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`bgColor`**
    - **Parametri**: `isPressed: Bool`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `ToolIcon`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ToolIcon()`
- **Variabili principali**: help, body, icon, action, isDestructive, active, label

- *Nessun metodo rilevato in questa Struct.*

### File: `StationPickerView.swift`

#### Struct: `StationPickerView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = StationPickerView()`
- **Variabili principali**: ignoreFilters, appState, dismiss, isFiltering, searchText, filteredStations, originId, selectedStationId, body, whitelist, network, result, connectionFiltered, connectedIds, linkedToStationId

**Metodi:**
  * **`filterBySearch`**
    - **Parametri**: `_ list: [Node]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`errorMessage`**
    - **Parametri**: `isLine: Bool, isConn: Bool`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `ConflictCard.swift`

#### Struct: `ConflictCard`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ConflictCard()`
- **Variabili principali**: body, onFocus, conflict, appState, formatter, suggestedResolution, suggestions

**Metodi:**
  * **`formatTime`**
    - **Parametri**: `_ date: Date`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `TrainParticipantView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrainParticipantView()`
- **Variabili principali**: body, appState, name, id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `ConflictCard_Previews`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ConflictCard_Previews()`
- **Variabili principali**: previews

- *Nessun metodo rilevato in questa Struct.*

### File: `RouteEditView.swift`

#### Struct: `RouteEditView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RouteEditView()`
- **Variabili principali**: assignedVehicles, routeId, manualStationId, idx, appState, dismiss, activePicker, suggestionsOverlay, error, assignedVehicleIds, type, suggestions, body, manualAddition, mapPickingType

**Metodi:**
  * **`setupPickingCallback`**
    - **Parametri**: `for type: PickerType`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `FdCEntityList.swift`

#### Struct: `FdCEntityList`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = FdCEntityList()`
- **Variabili principali**: editMode, onAdd, title, searchText, onDelete, query, selectedId, selectedItemId, headerView, onDeleteAll, idStr, listView, body, searchBar, item

**Metodi:**
  * **`deleteItems`**
    - **Parametri**: `at offsets: IndexSet`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`idString`**
    - **Parametri**: `for item: Item`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`isSelected`**
    - **Parametri**: `_ item: Item`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `FdC_Railway_ManagerApp.swift`

#### Struct: `FdC_Railway_ManagerApp`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = FdC_Railway_ManagerApp()`
- **Variabili principali**: body, showSplash, loader, appState, a

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `SplashScreen`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = SplashScreen()`
- **Variabili principali**: body

- *Nessun metodo rilevato in questa Struct.*

### File: `TrainTimetableView.swift`

#### Struct: `TrainTimetableView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrainTimetableView()`
- **Variabili principali**: body, diff, dep, simulator, arr, date, str, formatter, ref, mockSch, sim, schedule, cal

**Metodi:**
  * **`formatTime`**
    - **Parametri**: `_ date: Date?, refDate: Date? = nil`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`formatDwell`**
    - **Parametri**: `_ stop: ScheduleStop`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`isConflict`**
    - **Parametri**: `stationId: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `LineVerticalDiagram.swift`

#### Struct: `LineVerticalDiagram`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = LineVerticalDiagram()`
- **Variabili principali**: body, network, nextId, selectedStation, isLast, lineColor, orderedStations, line, onLineClick, c

- *Nessun metodo rilevato in questa Struct.*

### File: `NetworkListViewModels.swift`

#### Struct: `StationListViewModel`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = StationListViewModel()`
- **Variabili principali**: selectedNode, network, appState, newStation, items

**Metodi:**
  * **`searchText`**
    - **Parametri**: `for node: Node`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`onSelect`**
    - **Parametri**: `_ node: Node`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`onAdd`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`onDelete`**
    - **Parametri**: `_ node: Node`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`onDeleteAll`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `TrackListViewModel`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrackListViewModel()`
- **Variabili principali**: toName, fromName, network, appState, selectedEdgeId, items

**Metodi:**
  * **`searchText`**
    - **Parametri**: `for edge: Edge`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`onSelect`**
    - **Parametri**: `_ edge: Edge`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`onAdd`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`onDelete`**
    - **Parametri**: `_ edge: Edge`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`onDeleteAll`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `FerroviaListViewModel`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = FerroviaListViewModel()`
- **Variabili principali**: network, appState, items

**Metodi:**
  * **`searchText`**
    - **Parametri**: `for ferrovia: Ferrovia`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`onSelect`**
    - **Parametri**: `_ ferrovia: Ferrovia`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`onAdd`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`onDelete`**
    - **Parametri**: `_ ferrovia: Ferrovia`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`onDeleteAll`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `NetworkSymbols`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = NetworkSymbols()`
- **Variabili principali**: swiftColor, color, colorHex

**Metodi:**
  * **`stationSymbol`**
    - **Parametri**: `for node: Node, size: CGFloat = 12`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`trackSymbol`**
    - **Parametri**: `for trackType: Edge.TrackType, width: CGFloat = 24, height: CGFloat = 12`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`ferroviaSymbol`**
    - **Parametri**: `color: String?, size: CGFloat = 12`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `RailwayAIView.swift`

#### Struct: `RailwayAIView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RailwayAIView()`
- **Variabili principali**: baseDate, reporter, routeId, newTrain, cancellables, appState, solutions, showRouteProposalSheet, optimizerStats, trimmedEndpoint, stops, endHour, trainsMsg, uuid, request

**Metodi:**
  * **`runAdvancedOptimization`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`runStandardOptimization`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`performOptimizationCall`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`runFastProposer`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`applySelectedProposals`**
    - **Parametri**: `_ selectedProposals: [ProposedRoute], createTrains: Bool`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `LiveSimulationDashboard.swift`

#### Struct: `LiveSimulationDashboard`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = LiveSimulationDashboard()`
- **Variabili principali**: body, liveSim, activeTrains, simulator, appState, usage

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `TrainSimInfo`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrainSimInfo()`
- **Variabili principali**: firstStart, nextStop, a2, delay, s2, now, d1, progress, lastEnd, a1, s1, currentStatus, name, id

**Metodi:**
  * **`getActiveTrains`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `ResourceUsage`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ResourceUsage()`
- **Variabili principali**: occupants, load, name, id

**Metodi:**
  * **`calculateResourceUsage`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `TrainLiveRow`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrainLiveRow()`
- **Variabili principali**: info, body

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `ResourceLoadRow`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ResourceLoadRow()`
- **Variabili principali**: body, loadColor, resource

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `LogEntryRow`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = LogEntryRow()`
- **Variabili principali**: body, entryColor, entry

- *Nessun metodo rilevato in questa Struct.*

### File: `LaunchScreenView.swift`

#### Struct: `LaunchScreenView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = LaunchScreenView()`
- **Variabili principali**: body

- *Nessun metodo rilevato in questa Struct.*

### File: `TrainRoute.swift`

#### Struct: `TrainRoute`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrainRoute()`
- **Variabili principali**: color, destinationStationId, id, numberPrefix, displayColor, stationIds, intermediateStationIds, serviceCodePrefix, name, originStationId

- *Nessun metodo rilevato in questa Struct.*

### File: `AltimetricProfileView.swift`

#### Struct: `AltimetricProfileView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = AltimetricProfileView()`
- **Variabili principali**: sanitized, idx, selectedNodeIds, lon1, horizontalScale, altitudePoints, pathResult, distKm, currentIdx, minAlt, junctionLat, newN2Alt, alt, edgeJB, midX

**Metodi:**
  * **`updateNode`**
    - **Parametri**: `_ id: String, lat: Double? = nil, lon: Double? = nil, alt: Double? = nil`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`from`**
    - **Parametri**: `_ line: RailwayLine`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`from`**
    - **Parametri**: `_ route: TrainRoute`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`contentView`**
    - **Parametri**: `geo: GeometryProxy`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`profileGraph`**
    - **Parametri**: `stations: [RailwayNode], geo: GeometryProxy`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`smartUpdateNodeAltitude`**
    - **Parametri**: `stationId: String, newAltitude: Double, chain: [RailwayNode]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`updateSegmentAltitude`**
    - **Parametri**: `edgeId: UUID, segmentId: UUID, newAltitude: Double`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`deleteIntermediatePoint`**
    - **Parametri**: `edgeId: UUID, segmentId: UUID`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`getAltitudeForPoint`**
    - **Parametri**: `_ point: PointData`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`handleSegmentTap`**
    - **Parametri**: `p1: PointData, p2: PointData, location: CGPoint, geo: GeometryProxy, minAlt: Double, altRange: Double`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`handleGraphClick`**
    - **Parametri**: `at location: CGPoint, pointsData: [PointData], stations: [RailwayNode], geo: GeometryProxy, minAlt: Double, altRange: Double`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateSlope`**
    - **Parametri**: `from: RailwayNode, to: RailwayNode`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`slopeColor`**
    - **Parametri**: `_ slope: Double`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `PointData`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = PointData()`
- **Variabili principali**: index, prevStation, cumulativeDistances, station, pathResult, service, connected, segmentDistance, x, normalizedAlt, point, edgeId, cumulativeDistance, ids, totalDistance

**Metodi:**
  * **`calculatePoints`**
    - **Parametri**: `stations: [RailwayNode], graphWidth: CGFloat, geoHeight: CGFloat, minAlt: Double, altRange: Double, baseAltRange: Double, pixelsPerKm: CGFloat`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`attemptToChain`**
    - **Parametri**: `_ nodes: [Node]`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`totalDistance`**
    - **Parametri**: `stations: [Node], network: NetworkModel`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `DraggablePointView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = DraggablePointView()`
- **Variabili principali**: isEditing, onCommitEdit, point, body, isDragging, editText, onUpdate, startAlt, isLocked, onToggleLock, effectiveH, station, onCancelEdit, geoHeight, onLongPress

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `MultiSelectionEditor`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = MultiSelectionEditor()`
- **Variabili principali**: displacement, cLat, cLon, appState, left, dx, distVal, lockedNodeIds, l2, currentLon, distKm, right, currentLat, tLat, dirY

**Metodi:**
  * **`alignLatitude`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`alignLongitude`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`relaxLayout`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculateSpringForce`**
    - **Parametri**: `target: Node, current: Node`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`createLineFromSelection`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`updateNode`**
    - **Parametri**: `_ id: String, lat: Double? = nil, lon: Double? = nil, alt: Double? = nil`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`updateAltitude`**
    - **Parametri**: `_ id: String, alt: Double`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `IntermediatePointView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = IntermediatePointView()`
- **Variabili principali**: isEditing, onCommitEdit, point, body, segment, edge, editText, onUpdate, isDragging, startAlt, effectiveH, onCancelEdit, onDelete, geoHeight, onLongPress

- *Nessun metodo rilevato in questa Struct.*

### File: `ContentView.swift`

#### Struct: `ContentView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ContentView()`
- **Variabili principali**: body, tabNameSpace, showCredits, network, aiService, appState, trainManager, isExporting, railroad, railroadService, lines, highlightedConflictLocation

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `LiveSimulationShelf`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = LiveSimulationShelf()`
- **Variabili principali**: body, appState

- *Nessun metodo rilevato in questa Struct.*

### File: `TrackEditView.swift`

#### Struct: `TrackEditView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = TrackEditView()`
- **Variabili principali**: body, toStation, edge, network, appState, fromStation, onDelete, onBack, showDeleteConfirmation

**Metodi:**
  * **`updateTrackType`**
    - **Parametri**: `_ type: Edge.TrackType`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`updateCapacity`**
    - **Parametri**: `for type: Edge.TrackType`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`trackLabel`**
    - **Parametri**: `for type: Edge.TrackType`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`trackIcon`**
    - **Parametri**: `for type: Edge.TrackType`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `CreditsView.swift`

#### Struct: `CreditsView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = CreditsView()`
- **Variabili principali**: body, dismiss

**Metodi:**
  * **`technologyRow`**
    - **Parametri**: `name: String, icon: String, color: Color`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `FdCToolbar.swift`

#### Struct: `FdCToolbar`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = FdCToolbar()`
- **Variabili principali**: printInfo, tmpURL, root, printController, isActive, scene, activityVC, icon, view, ctx, isDestructive, exportButtons, canRedo, pdfData, bounds

**Metodi:**
  * **`itemView`**
    - **Parametri**: `for item: FdCToolbarItem`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`exportJPG`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`exportPDF`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`printView`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`presentActivityVC`**
    - **Parametri**: `_ vc: UIActivityViewController`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `PathPickerComponent.swift`

#### Struct: `PathPickerComponent`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = PathPickerComponent()`
- **Variabili principali**: stationSequence, manualAddition, network, viaStationIds, appState, trainManager, endStationId, startStationId

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `ViaItem`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ViaItem()`
- **Variabili principali**: manualStationId, endIndex, lineAnalysis, stationId, activePicker, useAutomaticSelection, analysis, isAnalyzing, tt, vias, lastId, line, maxStr, viaItems, selectedAlternativeIndex

**Metodi:**
  * **`stationName`**
    - **Parametri**: `_ id: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`calculatePath`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`localize`**
    - **Parametri**: `_ key: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`stationName`**
    - **Parametri**: `_ id: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`combineRecursive`**
    - **Parametri**: `segmentIdx: Int, currentPath: [String], currentDist: Double`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`selectAlternative`**
    - **Parametri**: `_ index: Int`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`invertPath`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`getSuggestions`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`aiAnalysisView`**
    - **Parametri**: `analysis: RailwayAIService.RouteAnalysis`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`findLocalIdealOffset`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `VerticalTrackDiagramView.swift`

#### Struct: `VerticalTrackDiagramView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = VerticalTrackDiagramView()`
- **Variabili principali**: pdfContext, printInfo, showStationPicker, index, intermediatePath, pdfUrl, stationId, idx, appState, removeStart, consumer, isLinkingBefore, onInsertBeforeAction, root, trackTypeText

**Metodi:**
  * **`stationStep`**
    - **Parametri**: `stationId: String, index: Int, lineColor: Color`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`exportDiagram`**
    - **Parametri**: `as format: ExportFormat`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`printDiagram`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`shareItem`**
    - **Parametri**: `_ item: Any`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`stationSheetContent`**
    - **Parametri**: `for id: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`edgeSheetContent`**
    - **Parametri**: `for uuid: UUID`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`infoColumn`**
    - **Parametri**: `stationId: String, index: Int, isLast: Bool`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`prepareEditEdge`**
    - **Parametri**: `_ edge: Edge`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`stationNodeButton`**
    - **Parametri**: `id: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`trackSegmentButton`**
    - **Parametri**: `from: String, to: String, color: Color`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`findEdge`**
    - **Parametri**: `from: String, to: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`removeStation`**
    - **Parametri**: `at index: Int`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`prepareInsert`**
    - **Parametri**: `_ stationId: String, before: Bool`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`insertStation`**
    - **Parametri**: `_ newStationId: String, linkTo stationId: String, before: Bool`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`startIntermediateInsertion`**
    - **Parametri**: `afterStation stationId: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`getConnectedStations`**
    - **Parametri**: `from stationId: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`selectIntermediateStation`**
    - **Parametri**: `_ stationId: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`completeIntermediateInsertion`**
    - **Parametri**: `targetStationId: String, targetIndex: Int`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`cancelIntermediateInsertion`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `SimulationControlView.swift`

#### Struct: `SimulationControlView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = SimulationControlView()`
- **Variabili principali**: liveSim, body, appState

**Metodi:**
  * **`multiplierButton`**
    - **Parametri**: `label: String, value: Double`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `LineTableView.swift`

#### Struct: `LineTableView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = LineTableView()`
- **Variabili principali**: list, idx, selectedConflict, stationId, appState, aiService, parts, trainsToFix, firstId, request, cal, lineConflicts, orderedStations, line, sIdx

**Metodi:**
  * **`deleteAllLineTrains`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`optimizeLineWithAI`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`applyTrackResolution`**
    - **Parametri**: `trainId: UUID, stationId: String, track: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`formatTime`**
    - **Parametri**: `_ date: Date, ref: Date? = nil`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `ScheduleCellView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ScheduleCellView()`
- **Variabili principali**: selectedConflict, appState, stops, station, cal, stop, r1, d1, trainColor, track, depDate, r, cellData, body, train

**Metodi:**
  * **`formatTime`**
    - **Parametri**: `_ date: Date, ref: Date? = nil`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `RoutePDFExportView.swift`

#### Struct: `LinePDFExportView`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = LinePDFExportView()`
- **Variabili principali**: body, sectionTrains, network, dep, arr, lineTrains, route, trains, lastStation, firstIdx, formatter, filtered, isLast, timeStr, lastIdx

**Metodi:**
  * **`timetableSection`**
    - **Parametri**: `title: String, stations: [RailwayNode], isReturn: Bool`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`filterTrains`**
    - **Parametri**: `isReturn: Bool`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`getTimeFor`**
    - **Parametri**: `train: Train, stationId: String`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `RailwayRenderer.swift`

#### Struct: `DiamondShape`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = DiamondShape()`
- **Variabili principali**: top, path, left, bottom, right

**Metodi:**
  * **`path`**
    - **Parametri**: `in rect: CGRect`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

### File: `RenderingTypes.swift`

#### Struct: `RenderingContext`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = RenderingContext()`
- **Variabili principali**: bounds, zoomLevel, canvasSize, mode

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `MapBounds`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = MapBounds()`
- **Variabili principali**: minLat, xRange

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `NodeStyle`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = NodeStyle()`
- **Variabili principali**: size, strokeColor, strokeWidth, fillColor, showLabel, isHighlighted, isSelected

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `StationStyle`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = StationStyle()`
- **Variabili principali**: showTracks, base, style, shape

**Metodi:**
  * **`selected`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`highlighted`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `JunctionStyle`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = JunctionStyle()`
- **Variabili principali**: base, style, showInProfile, standard

**Metodi:**
  * **`highlighted`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `HubStyle`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = HubStyle()`
- **Variabili principali**: base, showConnectionLines

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `EdgeStyle`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = EdgeStyle()`
- **Variabili principali**: strokeColor, lineStyle, strokeWidth, color, dashPattern, width, showDirection, showSegments, isHighlighted, style

**Metodi:**
  * **`forTrackType`**
    - **Parametri**: `_ trackType: Edge.TrackType`
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

  * **`highlighted`**
    - **Parametri**: ``
    - **Scopo e Utilizzo**: Da definire.
    - **Commenti**: // Aggiungi logica qui
    - **Lunghezza**: ~10 righe
    - **Complessità Ciclomatica Stimata**: ~2

#### Struct: `AltitudeProfileStyle`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = AltitudeProfileStyle()`
- **Variabili principali**: backgroundColor, lineWidth, showGrid, gridColor, slopeColors, showSlopes, lineColor

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `SlopeColors`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = SlopeColors()`
- **Variabili principali**: normal, steep, extreme

- *Nessun metodo rilevato in questa Struct.*

### File: `InfrastructureTypes.swift`

#### Struct: `PathResult`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = PathResult()`
- **Variabili principali**: totalDistance, nodes, segments

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `FerroviaProperties`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = FerroviaProperties()`
- **Variabili principali**: segments, totalDistance, stationCount, junctionCount, altitudeProfile, name, id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `AltitudePoint`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = AltitudePoint()`
- **Variabili principali**: distance, altitude, isStation, nodeId, node, id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `FerroviaSegment`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = FerroviaSegment()`
- **Variabili principali**: junctionNodes, reason, errorDescription, from, hasJunctions, toNodeId, ids, fromNodeId, distance, to, id

- *Nessun metodo rilevato in questa Struct.*

#### Struct: `ValidationIssue`
- **Scopo**: Definizione dati/UI.
- **Esempio di Uso**: `let item = ValidationIssue()`
- **Variabili principali**: color, description, affectedEdges, severity, affectedNodes, id

- *Nessun metodo rilevato in questa Struct.*

