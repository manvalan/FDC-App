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
        
        var resourceOccupations: [String: [(Double, Double, UUID)]] = [:]
        var routingViolationCount = 0
        var constraintPenalty = 0.0
        var conflictingIds = Set<UUID>()
        var conflictLocs: [UUID: Set<String>] = [:]
        var conflictCount = 0
        
        for (i, train) in allTrains.enumerated() {
            let tid = train.id
            let isCandidate = i < updatedSubset.count
            let constraints = allowedTracks[tid]
            
            var totalExtraDwell = 0.0
            
            for j in train.stops.indices {
                let stop = train.stops[j]
                if stop.isSkipped { continue }
                
                // Valutazione vincoli di sosta
                if isCandidate {
                    let totalDwell = stop.minDwell + stop.extraDwell
                    if totalDwell > 15.0 {
                        constraintPenalty += (totalDwell - 15.0) * 500000.0
                    } else if totalDwell < 2.0 {
                        constraintPenalty += (2.0 - totalDwell) * 1000000.0
                    } else if totalDwell < stop.minDwell {
                        constraintPenalty += (stop.minDwell - totalDwell) * 10000.0
                    }
                    totalExtraDwell += stop.extraDwell
                }
                
                // Verifica vincoli di instradamento
                if isCandidate, let currentConstraints = constraints?[j] {
                    if !currentConstraints.contains(stop.track) {
                        routingViolationCount += 1
                        conflictingIds.insert(tid)
                        conflictLocs[tid, default: []].insert("ROUTING::\(stop.stationId)")
                    }
                }
                
                let trackResId = "TRACK::\(stop.stationId)::\(stop.track)"
                let globalResId = "STATION_GLOBAL::\(stop.stationId)"
                
                if let arr = stop.arrival, let dep = stop.departure {
                    let occ = (arr, dep + 5, train.id)
                    resourceOccupations[trackResId, default: []].append(occ)
                    resourceOccupations[globalResId, default: []].append(occ)
                }
                
                // Calcolo transito segmenti
                if j > 0, let depPrev = train.stops[j-1].departure, let arr = stop.arrival {
                    let path = precalculatedPaths[train.id]?[j]
                    if let actualPath = path {
                        let totalTime = arr - depPrev
                        let totalDist = actualPath.reduce(0.0) { $0 + $1.distance }
                        let avgSpeed = totalDist > 0 ? (totalDist / (totalTime / 3600.0)) : 0.0
                        var curr = depPrev
                        for edge in actualPath {
                            let transit = avgSpeed > 0 ? (edge.distance / avgSpeed * 3600.0) : 0.0
                            let exit = curr + transit
                            let s1Id = edge.from < edge.to ? edge.from : edge.to
                            let s2Id = edge.from < edge.to ? edge.to : edge.from
                            let resId = "SEGMENT::\(s1Id)--\(s2Id)"
                            resourceOccupations[resId, default: []].append((curr, exit + 30, train.id))
                            curr = exit
                        }
                    }
                }
            }
            if isCandidate && totalExtraDwell > 30.0 {
                constraintPenalty += (totalExtraDwell - 30.0) * 1000000.0
            }
        }
        
        // Calcolo conflitti risorse
        for (resId, occs) in resourceOccupations {
            let cap = resId.hasPrefix("STATION_GLOBAL") ? (stationCapacities[resId] ?? 1) : (resId.hasPrefix("SEGMENT") ? (segmentCapacities[resId] ?? 1) : 1)
            if occs.count <= cap { continue }
            
            var events: [(Double, Int, UUID)] = []
            for o in occs {
                events.append((o.0, 1, o.2))
                events.append((o.1, -1, o.2))
            }
            events.sort { $0.0 < $1.0 || ($0.0 == $1.0 && $0.1 < $1.1) }
            
            var active = Set<UUID>()
            for e in events {
                if e.1 == 1 {
                    active.insert(e.2)
                    if active.count > cap {
                        conflictCount += (active.count - cap)
                        for id in active {
                            conflictingIds.insert(id)
                            conflictLocs[id, default: []].insert(resId)
                        }
                    }
                } else { active.remove(e.2) }
            }
        }
        
        var travelTimePenalty = 0.0
        var deviationPenalty = 0.0
        var preferredTrackBonus = 0.0
        for (i, train) in updatedSubset.enumerated() {
            for j in train.stops.indices {
                if train.stops[j].isPreferredTrack && train.stops[j].track == candidateTrains[i].stops[j].track {
                    preferredTrackBonus += 500.0
                }
            }
            if let start = train.stops.first?.departure, let end = train.stops.last?.arrival {
                travelTimePenalty += (end - start) / 60.0
            }
            let gene = chromosome.genes[i]
            deviationPenalty += abs(gene.departureOffset) / 30.0
            for j in train.stops.indices {
                if gene.stopTracks[j] != candidateTrains[i].stops[j].track {
                    deviationPenalty += (j == 0 || j == train.stops.count - 1) ? 100.0 : 40.0
                }
            }
        }
        
        let totalScore = Double(conflictCount) + (Double(routingViolationCount) * 10.0)
        let fitness = (totalScore * 2000000.0) + constraintPenalty + (travelTimePenalty * 15.0) + deviationPenalty - preferredTrackBonus
        return (fitness, conflictingIds, conflictLocs)
    }
}
