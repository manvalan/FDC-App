import Foundation

/// Responsabile per la valutazione del fitness e la rilevazione dei conflitti
struct ScheduleEvaluator {
    let stationCapacities: [String: Int]
    let segmentCapacities: [String: Int]
    let allowedTracks: [UUID: [Set<String>]]
    let precalculatedPaths: [UUID: [[Edge]?]]

    /// Valuta un cromosoma e restituisce il fitness, i treni in conflitto e le posizioni dei conflitti
    func evaluate(
        chromosome: Chromosome,
        candidateTrains: [LiteTrain],
        fixedTrains: [LiteTrain]
    ) -> (Double, Set<UUID>, [UUID: Set<String>]) {
        let updatedSubset = ScheduleTransformer.apply(chromosome: chromosome, to: candidateTrains)
        let allTrains = updatedSubset + fixedTrains
        
        var context = EvaluationContext()
        
        collectOccupationsAndPenalties(allTrains: allTrains, candidateCount: updatedSubset.count, context: &context)
        calculateResourceConflicts(context: &context)
        let fitness = calculateFitness(updatedSubset: updatedSubset, candidateTrains: candidateTrains, chromosome: chromosome, context: context)
        
        return (fitness, context.conflictingIds, context.conflictLocs)
    }

    private class EvaluationContext {
        var resourceOccupations: [String: [(Double, Double, UUID)]] = [:]
        var routingViolationCount = 0
        var constraintPenalty = 0.0
        var conflictingIds = Set<UUID>()
        var conflictLocs: [UUID: Set<String>] = [:]
        var conflictCount = 0
    }

    private func collectOccupationsAndPenalties(allTrains: [LiteTrain], candidateCount: Int, context: inout EvaluationContext) {
        for (i, train) in allTrains.enumerated() {
            let isCandidate = i < candidateCount
            let constraints = allowedTracks[train.id]
            var totalExtraDwell = 0.0
            
            for j in train.stops.indices {
                let stop = train.stops[j]
                if stop.isSkipped { continue }
                
                if isCandidate {
                    context.constraintPenalty += calculateDwellPenalty(stop: stop)
                    totalExtraDwell += stop.extraDwell
                    
                    if let currentConstraints = constraints?[j], !currentConstraints.contains(stop.track) {
                        context.routingViolationCount += 1
                        context.conflictingIds.insert(train.id)
                        context.conflictLocs[train.id, default: []].insert("ROUTING::\(stop.stationId)")
                    }
                }
                
                addStationOccupations(train: train, stop: stop, context: &context)
                if j > 0 {
                    addSegmentOccupations(train: train, stopIdx: j, context: &context)
                }
            }
            if isCandidate && totalExtraDwell > 30.0 {
                context.constraintPenalty += (totalExtraDwell - 30.0) * 1000000.0
            }
        }
    }

    private func calculateDwellPenalty(stop: LiteStop) -> Double {
        let totalDwell = stop.minDwell + stop.extraDwell
        if totalDwell > 15.0 { return (totalDwell - 15.0) * 500000.0 }
        if totalDwell < 2.0 { return (2.0 - totalDwell) * 1000000.0 }
        if totalDwell < stop.minDwell { return (stop.minDwell - totalDwell) * 10000.0 }
        return 0
    }

    private func addStationOccupations(train: LiteTrain, stop: LiteStop, context: inout EvaluationContext) {
        if let arr = stop.arrival, let dep = stop.departure {
            let occ = (arr, dep + 5, train.id)
            context.resourceOccupations["TRACK::\(stop.stationId)::\(stop.track)", default: []].append(occ)
            context.resourceOccupations["STATION_GLOBAL::\(stop.stationId)", default: []].append(occ)
        }
    }

    private func addSegmentOccupations(train: LiteTrain, stopIdx: Int, context: inout EvaluationContext) {
        guard let depPrev = train.stops[stopIdx-1].departure, 
              let arr = train.stops[stopIdx].arrival,
              let actualPath = precalculatedPaths[train.id]?[stopIdx] else { return }
        
        let totalTime = arr - depPrev
        let totalDist = actualPath.reduce(0.0) { $0 + $1.distance }
        let avgSpeed = totalDist > 0 ? (totalDist / (totalTime / 3600.0)) : 0.0
        
        var curr = depPrev
        for edge in actualPath {
            let transit = avgSpeed > 0 ? (edge.distance / avgSpeed * 3600.0) : 0.0
            let exit = curr + transit
            let resId = "SEGMENT::\(edge.from < edge.to ? edge.from : edge.to)--\(edge.from < edge.to ? edge.to : edge.from)"
            context.resourceOccupations[resId, default: []].append((curr, exit + 30, train.id))
            curr = exit
        }
    }

    private func calculateResourceConflicts(context: inout EvaluationContext) {
        for (resId, occs) in context.resourceOccupations {
            let cap = getResourceCapacity(resId: resId)
            if occs.count <= cap { continue }
            
            let events = generateConflictEvents(occs: occs)
            var active = Set<UUID>()
            for e in events {
                if e.1 == 1 {
                    active.insert(e.2)
                    if active.count > cap {
                        context.conflictCount += (active.count - cap)
                        for id in active {
                            context.conflictingIds.insert(id)
                            context.conflictLocs[id, default: []].insert(resId)
                        }
                    }
                } else { active.remove(e.2) }
            }
        }
    }

    private func getResourceCapacity(resId: String) -> Int {
        if resId.hasPrefix("STATION_GLOBAL") { return stationCapacities[resId] ?? 1 }
        if resId.hasPrefix("SEGMENT") { return segmentCapacities[resId] ?? 1 }
        return 1
    }

    private func generateConflictEvents(occs: [(Double, Double, UUID)]) -> [(Double, Int, UUID)] {
        var events: [(Double, Int, UUID)] = []
        for o in occs {
            events.append((o.0, 1, o.2))
            events.append((o.1, -1, o.2))
        }
        return events.sorted { $0.0 < $1.0 || ($0.0 == $1.0 && $0.1 < $1.1) }
    }

    private func calculateFitness(updatedSubset: [LiteTrain], candidateTrains: [LiteTrain], chromosome: Chromosome, context: EvaluationContext) -> Double {
        var travelTimePenalty = 0.0
        var deviationPenalty = 0.0
        var preferredTrackBonus = 0.0
        
        for (i, train) in updatedSubset.enumerated() {
            preferredTrackBonus += calculateTrackBonus(train: train, candidates: candidateTrains[i])
            if let start = train.stops.first?.departure, let end = train.stops.last?.arrival {
                travelTimePenalty += (end - start) / 60.0
            }
            
            let gene = chromosome.genes[i]
            deviationPenalty += abs(gene.departureOffset) / 30.0
            deviationPenalty += calculateTrackDeviationPenalty(train: train, gene: gene, candidates: candidateTrains[i])
        }
        
        let totalScore = Double(context.conflictCount) + (Double(context.routingViolationCount) * 10.0)
        return (totalScore * 2000000.0) + context.constraintPenalty + (travelTimePenalty * 15.0) + deviationPenalty - preferredTrackBonus
    }

    private func calculateTrackBonus(train: LiteTrain, candidates: LiteTrain) -> Double {
        var bonus = 0.0
        for j in train.stops.indices {
            if train.stops[j].isPreferredTrack && train.stops[j].track == candidates.stops[j].track {
                bonus += 500.0
            }
        }
        return bonus
    }

    private func calculateTrackDeviationPenalty(train: LiteTrain, gene: TrainGene, candidates: LiteTrain) -> Double {
        var penalty = 0.0
        for j in train.stops.indices {
            if gene.stopTracks[j] != candidates.stops[j].track {
                penalty += (j == 0 || j == train.stops.count - 1) ? 100.0 : 40.0
            }
        }
        return penalty
    }
}
