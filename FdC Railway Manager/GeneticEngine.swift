import Foundation

/// Motore genetico puro: gestisce l'evoluzione della popolazione
struct GeneticEngine {
    let nodes: [Node]
    let contextTrains: [LiteTrain]
    let allowedTracks: [UUID: [Set<String>]]
    
    func selectParent(from population: [Chromosome]) -> Chromosome {
        let i1 = Int.random(in: 0..<population.count)
        let i2 = Int.random(in: 0..<population.count)
        return population[i1].fitness < population[i2].fitness ? population[i1] : population[i2]
    }
    
    func crossover(p1: Chromosome, p2: Chromosome) -> Chromosome {
        var childGenes: [TrainGene] = []
        for i in p1.genes.indices {
            childGenes.append(Bool.random() ? p1.genes[i] : p2.genes[i])
        }
        return Chromosome(genes: childGenes)
    }
    
    func mutate(chromosome: inout Chromosome, rate: Double) {
        let conflictingIndices = chromosome.genes.indices.filter { i in 
            chromosome.conflictingTrainIds.contains(chromosome.genes[i].trainId) 
        }
        let targets = conflictingIndices.isEmpty ? Array(chromosome.genes.indices) : conflictingIndices
        
        for i in targets {
            let trainId = chromosome.genes[i].trainId
            let isConflicting = chromosome.conflictingTrainIds.contains(trainId)
            let mutationChance = isConflicting ? rate * 2.5 : rate * 0.3
            
            if Double.random(in: 0...1) < mutationChance {
                let r = Double.random(in: 0...1)
                
                // Mutazione mirata ai conflitti
                if isConflicting, let locs = chromosome.conflictLocations[trainId], !locs.isEmpty {
                    let targetLoc = locs.randomElement() ?? ""
                    if targetLoc.contains("STATION") || targetLoc.contains("TRACK") || targetLoc.contains("ROUTING") {
                        let sid = targetLoc.components(separatedBy: "::").count > 1 ? targetLoc.components(separatedBy: "::")[1] : ""
                        if let stopIdx = contextTrains.firstIndex(where: { $0.id == trainId }),
                           let sIdx = contextTrains[stopIdx].stops.firstIndex(where: { $0.stationId == sid }) {
                            
                            if contextTrains[stopIdx].stops[sIdx].isManualTrack { continue }
                            
                            let allowed = allowedTracks[trainId]?[sIdx] ?? ["1"]
                            if allowed.count > 1 {
                                let current = chromosome.genes[i].stopTracks[sIdx]
                                let others = allowed.filter { $0 != current }
                                chromosome.genes[i].stopTracks[sIdx] = others.randomElement() ?? current
                                continue
                            }
                        }
                    } else if targetLoc.hasPrefix("SEGMENT::") {
                        let seg = targetLoc.replacingOccurrences(of: "SEGMENT::", with: "")
                        if let trainIdx = contextTrains.firstIndex(where: { $0.id == trainId }),
                           let stopIdx = contextTrains[trainIdx].stops.firstIndex(where: { seg.contains($0.stationId) }) {
                            let current = chromosome.genes[i].stopDwellOffsets[stopIdx]
                            chromosome.genes[i].stopDwellOffsets[stopIdx] = min(15.0, current + Double.random(in: 1.0...3.0))
                            continue
                        }
                    }
                }
                
                // Mutazione casuale
                if r < 0.4 {
                    chromosome.genes[i].departureOffset += Double.random(in: -300...300)
                } else if r < 0.7 {
                    if !chromosome.genes[i].stopDwellOffsets.isEmpty {
                        let j = Int.random(in: 0..<chromosome.genes[i].stopDwellOffsets.count)
                        chromosome.genes[i].stopDwellOffsets[j] = max(-5.0, min(15.0, chromosome.genes[i].stopDwellOffsets[j] + Double.random(in: -1...2)))
                    }
                } else {
                    if !chromosome.genes[i].stopTracks.isEmpty {
                        let j = Int.random(in: 0..<chromosome.genes[i].stopTracks.count)
                        if let trainIdx = contextTrains.firstIndex(where: { $0.id == trainId }),
                           contextTrains[trainIdx].stops.indices.contains(j),
                           !contextTrains[trainIdx].stops[j].isManualTrack { 
                            let allowed = allowedTracks[trainId]?[j] ?? ["1"]
                            chromosome.genes[i].stopTracks[j] = allowed.randomElement() ?? "1"
                        }
                    }
                }
            }
        }
    }
}
