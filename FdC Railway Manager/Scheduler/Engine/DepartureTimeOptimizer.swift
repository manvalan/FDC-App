import Foundation

/// Ottimizzatore genetico per orari di partenza di coppie di treni
/// Trova gli orari ottimali che minimizzano conflitti e tempi di attesa
class DepartureTimeOptimizer {
    
    // MARK: - Progress Callback
    
    var progressCallback: ((Int, Int, Double) -> Void)?  // (currentGen, totalGen, bestFitness)
    
    // MARK: - Configuration
    
    struct Config {
        let populationSize: Int = 50
        let maxGenerations: Int = 100
        let mutationProbability: Double = 0.15
        let eliteCount: Int = 2  // Elitismo: mantieni i 2 migliori
        let tournamentSize: Int = 3
        let timeResolutionMinutes: Int = 1  // Granularità al minuto
    }
    
    // MARK: - Individual (Cromosoma)
    
    /// Rappresenta una soluzione: orari di partenza per entrambe le direzioni
    struct Individual {
        var outboundDepartureMinute: Int  // Orario andata (0-1439 minuti dal giorno)
        var returnDepartureMinute: Int    // Orario ritorno (0-1439 minuti dal giorno)
        var fitness: Double = Double.infinity
        
        init(outbound: Int, returnTrip: Int) {
            self.outboundDepartureMinute = outbound
            self.returnDepartureMinute = returnTrip
        }
    }
    
    // MARK: - Context
    
    struct OptimizationContext {
        let route: TrainRoute
        let network: RailwayNetwork
        let existingTrains: [Train]
        let timeWindow: ClosedRange<Int>  // Finestra temporale in minuti (es: 360-1200 per 6:00-20:00)
        let estimatedTravelTime: Int  // Tempo di viaggio stimato in minuti
    }
    
    private let config = Config()
    
    // MARK: - Main Optimization Function
    
    /// Ottimizza gli orari di partenza per una coppia di treni
    func optimize(context: OptimizationContext) -> (outbound: Date, returnTrip: Date) {
        print("🧬 [DepartureTimeOptimizer] Starting optimization")
        print("   Time window: \(context.timeWindow)")
        print("   Travel time: \(context.estimatedTravelTime) min")
        
        // 1. INIZIALIZZAZIONE
        var population = generateInitialPopulation(context: context)
        var bestEver: Individual?
        
        // 2. EVOLUZIONE
        for generation in 0..<config.maxGenerations {
            // 2.1 VALUTAZIONE
            population = population.map { individual in
                var evaluated = individual
                evaluated.fitness = calculateFitness(individual: individual, context: context)
                return evaluated
            }
            
            // Ordina per fitness (minore è meglio)
            population.sort { $0.fitness < $1.fitness }
            
            // Aggiorna miglior soluzione
            if bestEver == nil || population[0].fitness < bestEver!.fitness {
                bestEver = population[0]
            }
            
            // Debug ogni 20 generazioni
            if generation % 20 == 0 {
                print("   Gen \(generation): Best fitness = \(String(format: "%.2f", population[0].fitness))")
            }
            
            // Notifica progresso
            progressCallback?(generation, config.maxGenerations, population[0].fitness)
            
            // Early stopping se trovata soluzione ottima
            if population[0].fitness < 10 {
                print("   ✅ Optimal solution found at generation \(generation)")
                break
            }
            
            // 2.2 NUOVA GENERAZIONE
            var newPopulation: [Individual] = []
            
            // 2.3 ELITISMO: Mantieni i migliori
            for i in 0..<config.eliteCount {
                newPopulation.append(population[i])
            }
            
            // 2.4 SELEZIONE, CROSSOVER, MUTAZIONE
            while newPopulation.count < config.populationSize {
                // Selezione torneo
                let parent1 = tournamentSelection(population: population)
                let parent2 = tournamentSelection(population: population)
                
                // Crossover
                var offspring1: Individual
                var offspring2: Individual
                (offspring1, offspring2) = singlePointCrossover(parent1: parent1, parent2: parent2)
                
                // Mutazione
                if Double.random(in: 0...1) < config.mutationProbability {
                    offspring1 = mutate(individual: offspring1, context: context)
                }
                if Double.random(in: 0...1) < config.mutationProbability {
                    offspring2 = mutate(individual: offspring2, context: context)
                }
                
                newPopulation.append(offspring1)
                if newPopulation.count < config.populationSize {
                    newPopulation.append(offspring2)
                }
            }
            
            population = newPopulation
        }
        
        // 3. RESTITUZIONE MIGLIOR SOLUZIONE
        let best = bestEver ?? population.sorted(by: { $0.fitness < $1.fitness })[0]
        print("   🎯 Final fitness: \(String(format: "%.2f", best.fitness))")
        
        return convertToAbsoluteTimes(individual: best)
    }
    
    // MARK: - Population Initialization
    
    private func generateInitialPopulation(context: OptimizationContext) -> [Individual] {
        var population: [Individual] = []
        
        for _ in 0..<config.populationSize {
            let outbound = Int.random(in: context.timeWindow)
            let returnStart = outbound + context.estimatedTravelTime + Int.random(in: 10...30)
            let returnClamped = min(returnStart, context.timeWindow.upperBound)
            
            population.append(Individual(outbound: outbound, returnTrip: returnClamped))
        }
        
        return population
    }
    
    // MARK: - Fitness Calculation
    
    /// Calcola il fitness di un individuo (minore è meglio)
    private func calculateFitness(individual: Individual, context: OptimizationContext) -> Double {
        var score: Double = 0.0
        
        // 1. Penalità per conflitti con treni esistenti
        let conflictPenalty = calculateConflictPenalty(
            outboundTime: individual.outboundDepartureMinute,
            returnTime: individual.returnDepartureMinute,
            context: context
        )
        score += conflictPenalty * 100  // Peso alto per conflitti
        
        // 2. Penalità per tempi di attesa non ottimali
        // Vogliamo che il treno di ritorno parta poco dopo l'arrivo dell'andata
        let expectedReturnStart = individual.outboundDepartureMinute + context.estimatedTravelTime
        let waitingTime = abs(individual.returnDepartureMinute - expectedReturnStart)
        
        // Tempo di attesa ideale: 15-30 minuti
        let idealWaitPenalty: Double
        if waitingTime < 15 {
            idealWaitPenalty = Double(15 - waitingTime) * 2  // Troppo poco tempo
        } else if waitingTime > 30 {
            idealWaitPenalty = Double(waitingTime - 30) * 0.5  // Troppo tempo di attesa
        } else {
            idealWaitPenalty = 0  // Ideale
        }
        score += idealWaitPenalty
        
        // 3. Penalità per orari scomodi (preferenza per orari "tondi")
        // Es: 08:00 meglio di 08:17
        let outboundRoundness = individual.outboundDepartureMinute % 15
        let returnRoundness = individual.returnDepartureMinute % 15
        score += Double(min(outboundRoundness, 15 - outboundRoundness)) * 0.5
        score += Double(min(returnRoundness, 15 - returnRoundness)) * 0.5
        
        // 4. Bonus per cadenza regolare (multipli di 30 o 60 minuti)
        if individual.outboundDepartureMinute % 30 == 0 {
            score -= 5  // Bonus
        }
        
        return max(0, score)
    }
    
    /// Calcola penalità per conflitti con treni esistenti (singolo orario)
    private func calculateSingleConflictPenalty(departureTime: Int, context: OptimizationContext) -> Double {
        var conflicts = 0
        let safetyBuffer = 10
        
        for train in context.existingTrains {
            guard train.routeId == context.route.id else { continue }
            guard let departure = train.departureTime else { continue }
            
            let trainMinute = departure.minutesSinceMidnight
            
            if abs(trainMinute - departureTime) < safetyBuffer {
                conflicts += 1
            }
        }
        
        return Double(conflicts)
    }
    
    /// Calcola penalità per conflitti con treni esistenti
    private func calculateConflictPenalty(outboundTime: Int, returnTime: Int, context: OptimizationContext) -> Double {
        var conflicts = 0
        
        // Buffer di sicurezza: treni devono essere distanti almeno 10 minuti
        let safetyBuffer = 10
        
        for train in context.existingTrains {
            guard train.routeId == context.route.id else { continue }
            guard let departure = train.departureTime else { continue }
            
            let trainMinute = departure.minutesSinceMidnight
            
            // Controlla conflitto con andata
            if abs(trainMinute - outboundTime) < safetyBuffer {
                conflicts += 1
            }
            
            // Controlla conflitto con ritorno
            if abs(trainMinute - returnTime) < safetyBuffer {
                conflicts += 1
            }
        }
        
        return Double(conflicts)
    }
    
    // MARK: - Genetic Operators
    
    /// Selezione a torneo
    private func tournamentSelection(population: [Individual]) -> Individual {
        var best: Individual?
        
        for _ in 0..<config.tournamentSize {
            let candidate = population.randomElement()!
            if best == nil || candidate.fitness < best!.fitness {
                best = candidate
            }
        }
        
        return best!
    }
    
    /// Crossover a punto singolo
    private func singlePointCrossover(parent1: Individual, parent2: Individual) -> (Individual, Individual) {
        // Scambia casualmente outbound o return tra i genitori
        if Bool.random() {
            return (
                Individual(outbound: parent1.outboundDepartureMinute, returnTrip: parent2.returnDepartureMinute),
                Individual(outbound: parent2.outboundDepartureMinute, returnTrip: parent1.returnDepartureMinute)
            )
        } else {
            return (
                Individual(outbound: parent2.outboundDepartureMinute, returnTrip: parent1.returnDepartureMinute),
                Individual(outbound: parent1.outboundDepartureMinute, returnTrip: parent2.returnDepartureMinute)
            )
        }
    }
    
    /// Mutazione: sposta casualmente l'orario di ±15 minuti
    private func mutate(individual: Individual, context: OptimizationContext) -> Individual {
        var mutated = individual
        
        // Muta outbound
        if Bool.random() {
            let offset = Int.random(in: -15...15)
            mutated.outboundDepartureMinute = clamp(
                mutated.outboundDepartureMinute + offset,
                to: context.timeWindow
            )
        }
        
        // Muta return
        if Bool.random() {
            let offset = Int.random(in: -15...15)
            mutated.returnDepartureMinute = clamp(
                mutated.returnDepartureMinute + offset,
                to: context.timeWindow
            )
        }
        
        return mutated
    }
    
    // MARK: - Utilities
    
    /// Clamp value to range
    private func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        return max(range.lowerBound, min(range.upperBound, value))
    }
    
    /// Converte minuti in Date assolute
    private func convertToAbsoluteTimes(individual: Individual) -> (outbound: Date, returnTrip: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let outbound = calendar.date(byAdding: .minute, value: individual.outboundDepartureMinute, to: today)!
        let returnTrip = calendar.date(byAdding: .minute, value: individual.returnDepartureMinute, to: today)!
        
        return (outbound, returnTrip)
    }
    
    // MARK: - Cadence Optimization
    
    /// Individuo per ottimizzazione cadenzata: orario iniziale + intervallo
    struct CadenceIndividual {
        var startMinute: Int           // Orario di partenza del primo treno (0-1439)
        var intervalMinutes: Int       // Intervallo tra i treni (5-240 minuti)
        var returnStartMinute: Int     // Orario di partenza del primo treno di ritorno
        var returnIntervalMinutes: Int // Intervallo tra i treni di ritorno
        var fitness: Double = Double.infinity
        
        init(start: Int, interval: Int, returnStart: Int, returnInterval: Int) {
            self.startMinute = start
            self.intervalMinutes = interval
            self.returnStartMinute = returnStart
            self.returnIntervalMinutes = returnInterval
        }
    }
    
    struct CadenceContext {
        let route: TrainRoute
        let network: RailwayNetwork
        let existingTrains: [Train]
        let timeWindow: ClosedRange<Int>
        let endTime: Int  // Orario di fine servizio
        let estimatedTravelTime: Int
        let scheduleReturn: Bool
        let returnEndTime: Int
    }
    
    /// Ottimizza orari e intervalli per una batteria di treni cadenzati
    func optimizeCadence(context: CadenceContext) -> (startTime: Date, interval: Int, returnStartTime: Date, returnInterval: Int) {
        print("🧬 [CadenceOptimizer] Starting cadence optimization")
        print("   Time window: \(context.timeWindow)")
        print("   End time: \(context.endTime)")
        print("   Travel time: \(context.estimatedTravelTime) min")
        print("   Schedule return: \(context.scheduleReturn)")
        
        var population = generateCadencePopulation(context: context)
        var bestEver: CadenceIndividual?
        
        for generation in 0..<config.maxGenerations {
            // Valutazione
            population = population.map { individual in
                var evaluated = individual
                evaluated.fitness = calculateCadenceFitness(individual: individual, context: context)
                return evaluated
            }
            
            population.sort { $0.fitness < $1.fitness }
            
            if bestEver == nil || population[0].fitness < bestEver!.fitness {
                bestEver = population[0]
            }
            
            if generation % 20 == 0 {
                print("   Gen \(generation): Best fitness = \(String(format: "%.2f", population[0].fitness))")
            }
            
            // Notifica progresso
            progressCallback?(generation, config.maxGenerations, population[0].fitness)
            
            if population[0].fitness < 20 {
                print("   ✅ Optimal cadence found at generation \(generation)")
                break
            }
            
            var newPopulation: [CadenceIndividual] = []
            
            // Elitismo
            for i in 0..<config.eliteCount {
                newPopulation.append(population[i])
            }
            
            // Generazione nuovi individui
            while newPopulation.count < config.populationSize {
                let parent1 = cadenceTournamentSelection(population: population)
                let parent2 = cadenceTournamentSelection(population: population)
                
                var (offspring1, offspring2) = cadenceCrossover(parent1: parent1, parent2: parent2)
                
                if Double.random(in: 0...1) < config.mutationProbability {
                    offspring1 = cadenceMutate(individual: offspring1, context: context)
                }
                if Double.random(in: 0...1) < config.mutationProbability {
                    offspring2 = cadenceMutate(individual: offspring2, context: context)
                }
                
                newPopulation.append(offspring1)
                if newPopulation.count < config.populationSize {
                    newPopulation.append(offspring2)
                }
            }
            
            population = newPopulation
        }
        
        let best = bestEver ?? population.sorted(by: { $0.fitness < $1.fitness })[0]
        print("   🎯 Final cadence fitness: \(String(format: "%.2f", best.fitness))")
        print("   📊 Start: \(minutesToTime(best.startMinute)), Interval: \(best.intervalMinutes)min")
        if context.scheduleReturn {
            print("   📊 Return Start: \(minutesToTime(best.returnStartMinute)), Interval: \(best.returnIntervalMinutes)min")
        }
        
        return convertCadenceToTimes(individual: best)
    }
    
    private func generateCadencePopulation(context: CadenceContext) -> [CadenceIndividual] {
        var population: [CadenceIndividual] = []
        
        for _ in 0..<config.populationSize {
            let start = Int.random(in: context.timeWindow)
            let interval = Int.random(in: 10...120) // 10-120 minuti
            
            let returnStart: Int
            
            if context.scheduleReturn {
                // Ritorno idealmente dopo il tempo di viaggio + attesa
                let idealReturn = start + context.estimatedTravelTime + Int.random(in: 15...30)
                returnStart = min(context.timeWindow.upperBound, max(context.timeWindow.lowerBound, idealReturn))
            } else {
                returnStart = 0
            }
            
            // IMPORTANTE: Stesso intervallo per andata e ritorno
            population.append(CadenceIndividual(
                start: start,
                interval: interval,
                returnStart: returnStart,
                returnInterval: interval  // Uguale all'intervallo di andata
            ))
        }
        
        return population
    }
    
    private func calculateCadenceFitness(individual: CadenceIndividual, context: CadenceContext) -> Double {
        var score: Double = 0.0
        
        // Genera tutti gli orari dei treni nella batteria
        var outboundTimes: [Int] = []
        var currentTime = individual.startMinute
        while currentTime <= context.endTime {
            outboundTimes.append(currentTime)
            currentTime += individual.intervalMinutes
        }
        
        var returnTimes: [Int] = []
        if context.scheduleReturn {
            var currentReturn = individual.returnStartMinute
            while currentReturn <= context.returnEndTime {
                returnTimes.append(currentReturn)
                currentReturn += individual.returnIntervalMinutes
            }
        }
        
        // 1. Penalità per conflitti con treni esistenti
        let optimizationContext = OptimizationContext(
            route: context.route,
            network: context.network,
            existingTrains: context.existingTrains,
            timeWindow: context.timeWindow,
            estimatedTravelTime: context.estimatedTravelTime
        )
        
        for outTime in outboundTimes {
            score += calculateSingleConflictPenalty(departureTime: outTime, context: optimizationContext) * 100
        }
        
        for retTime in returnTimes {
            score += calculateSingleConflictPenalty(departureTime: retTime, context: optimizationContext) * 100
        }
        
        // 2. Penalità per intervalli non ideali (preferiti: 15, 30, 60 minuti)
        let idealIntervals = [15, 30, 60]
        let outboundIntervalPenalty = idealIntervals.map { abs(individual.intervalMinutes - $0) }.min() ?? 0
        score += Double(outboundIntervalPenalty) * 0.5
        
        if context.scheduleReturn {
            let returnIntervalPenalty = idealIntervals.map { abs(individual.returnIntervalMinutes - $0) }.min() ?? 0
            score += Double(returnIntervalPenalty) * 0.5
        }
        
        // 3. Penalità per tempi di attesa non ottimali tra andata e ritorno
        if context.scheduleReturn && !outboundTimes.isEmpty {
            for (outTime, retTime) in zip(outboundTimes, returnTimes) {
                let expectedReturnStart = outTime + context.estimatedTravelTime
                let waitingTime = abs(retTime - expectedReturnStart)
                
                if waitingTime < 15 {
                    score += Double(15 - waitingTime) * 2
                } else if waitingTime > 30 {
                    score += Double(waitingTime - 30) * 0.5
                }
            }
        }
        
        // 4. Bonus per orari rotondi
        if individual.startMinute % 15 == 0 {
            score -= 5
        }
        if context.scheduleReturn && individual.returnStartMinute % 15 == 0 {
            score -= 5
        }
        
        // 5. Penalità se genera troppo pochi treni (minimo 2)
        if outboundTimes.count < 2 {
            score += 100
        }
        if context.scheduleReturn && returnTimes.count < 2 {
            score += 100
        }
        
        return max(0, score)
    }
    
    private func cadenceTournamentSelection(population: [CadenceIndividual]) -> CadenceIndividual {
        var tournament: [CadenceIndividual] = []
        for _ in 0..<config.tournamentSize {
            tournament.append(population.randomElement()!)
        }
        return tournament.min(by: { $0.fitness < $1.fitness })!
    }
    
    private func cadenceCrossover(parent1: CadenceIndividual, parent2: CadenceIndividual) -> (CadenceIndividual, CadenceIndividual) {
        // Crossover su singolo punto per ciascun parametro
        let useParent1Start = Bool.random()
        let useParent1Interval = Bool.random()
        
        // IMPORTANTE: L'intervallo deve essere uguale per andata e ritorno
        let interval1 = useParent1Interval ? parent1.intervalMinutes : parent2.intervalMinutes
        let interval2 = useParent1Interval ? parent2.intervalMinutes : parent1.intervalMinutes
        
        let offspring1 = CadenceIndividual(
            start: useParent1Start ? parent1.startMinute : parent2.startMinute,
            interval: interval1,
            returnStart: useParent1Start ? parent1.returnStartMinute : parent2.returnStartMinute,
            returnInterval: interval1  // Stesso intervallo per andata e ritorno
        )
        
        let offspring2 = CadenceIndividual(
            start: useParent1Start ? parent2.startMinute : parent1.startMinute,
            interval: interval2,
            returnStart: useParent1Start ? parent2.returnStartMinute : parent1.returnStartMinute,
            returnInterval: interval2  // Stesso intervallo per andata e ritorno
        )
        
        return (offspring1, offspring2)
    }
    
    private func cadenceMutate(individual: CadenceIndividual, context: CadenceContext) -> CadenceIndividual {
        var mutated = individual
        
        // Muta orario di partenza (±30 minuti)
        if Bool.random() {
            mutated.startMinute = max(context.timeWindow.lowerBound, 
                                     min(context.timeWindow.upperBound, 
                                         mutated.startMinute + Int.random(in: -30...30)))
        }
        
        // Muta intervallo (±5 minuti) - IMPORTANTE: stesso intervallo per andata e ritorno
        if Bool.random() {
            let newInterval = max(10, min(120, mutated.intervalMinutes + Int.random(in: -5...5)))
            mutated.intervalMinutes = newInterval
            mutated.returnIntervalMinutes = newInterval  // Mantieni uguale
        }
        
        // Muta ritorno (solo orario di partenza, non intervallo)
        if context.scheduleReturn {
            if Bool.random() {
                mutated.returnStartMinute = max(context.timeWindow.lowerBound,
                                               min(context.timeWindow.upperBound,
                                                   mutated.returnStartMinute + Int.random(in: -30...30)))
            }
        }
        
        return mutated
    }
    
    private func convertCadenceToTimes(individual: CadenceIndividual) -> (startTime: Date, interval: Int, returnStartTime: Date, returnInterval: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let startTime = calendar.date(byAdding: .minute, value: individual.startMinute, to: today)!
        let returnStartTime = calendar.date(byAdding: .minute, value: individual.returnStartMinute, to: today)!
        
        return (startTime, individual.intervalMinutes, returnStartTime, individual.returnIntervalMinutes)
    }
    
    private func minutesToTime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%02d:%02d", hours, mins)
    }
}

// MARK: - Extensions

extension Date {
    /// Restituisce i minuti dalla mezzanotte (0-1439)
    var minutesSinceMidnight: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: self)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}
