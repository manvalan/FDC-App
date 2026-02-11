import Foundation

/// Responsabile per la trasformazione dei dati tra i modelli reali e quelli "lite" dell'ottimizzatore
struct ScheduleTransformer {
    
    static func convertToLite(train: Train) -> LiteTrain {
        let departure = train.departureTime?.timeIntervalSinceReferenceDate ?? 0
        let stops = train.stops.map { stop in
            LiteStop(
                stationId: stop.stationId,
                arrival: stop.arrival?.timeIntervalSinceReferenceDate,
                departure: stop.departure?.timeIntervalSinceReferenceDate,
                extraDwell: stop.extraDwellTime, 
                track: stop.track ?? "1", 
                isManualTrack: stop.isManualTrack, 
                isPreferredTrack: stop.isPreferredTrack,
                isSkipped: stop.isSkipped, 
                minDwell: Double(stop.minDwellTime), 
                plannedArrival: stop.plannedArrival?.timeIntervalSinceReferenceDate, 
                plannedDeparture: stop.plannedDeparture?.timeIntervalSinceReferenceDate
            )
        }
        return LiteTrain(
            id: train.id,
            name: train.name,
            lineId: train.lineId,
            departureTime: departure,
            stops: stops,
            maxSpeed: train.maxSpeed,
            acceleration: train.acceleration,
            deceleration: train.deceleration
        )
    }

    static func reconstructTrains(lite: [LiteTrain], original: [Train]) -> [Train] {
        var result = original
        for i in result.indices {
            guard let l = lite.first(where: { $0.id == result[i].id }) else { continue }
            result[i].departureTime = Date(timeIntervalSinceReferenceDate: l.departureTime)
            for j in result[i].stops.indices {
                result[i].stops[j].extraDwellTime = l.stops[j].extraDwell
                result[i].stops[j].track = l.stops[j].track
                if let arr = l.stops[j].arrival { result[i].stops[j].arrival = Date(timeIntervalSinceReferenceDate: arr) }
                if let dep = l.stops[j].departure { result[i].stops[j].departure = Date(timeIntervalSinceReferenceDate: dep) }
            }
        }
        return result
    }

    static func apply(chromosome: Chromosome, to trains: [LiteTrain]) -> [LiteTrain] {
        var result = trains
        for i in result.indices {
            guard let gene = chromosome.genes.first(where: { $0.trainId == result[i].id }) else { continue }
            result[i].departureTime += gene.departureOffset
            
            var totalExtra = 0.0
            for j in result[i].stops.indices {
                let minAllowedExtra = max(-5.0, 2.0 - result[i].stops[j].minDwell)
                let maxAllowedExtra = max(0, 15.0 - result[i].stops[j].minDwell)
                var extra = max(minAllowedExtra, min(maxAllowedExtra, gene.stopDwellOffsets[j]))
                
                if totalExtra + extra > 30.0 {
                    extra = max(0, 30.0 - totalExtra)
                }
                
                result[i].stops[j].extraDwell = extra
                totalExtra += extra
                result[i].stops[j].track = gene.stopTracks[j]
            }
            
            var curr = result[i].departureTime
            let origin = result[i].stops.first?.stationId ?? ""
            for j in result[i].stops.indices {
                let stop = result[i].stops[j]
                if stop.stationId == origin && j == 0 {
                    result[i].stops[j].arrival = nil
                    let dep = max(curr, stop.plannedDeparture ?? 0)
                    result[i].stops[j].departure = dep
                    curr = dep
                } else {
                    let transit = gene.legTransitTimes[j]
                    curr += transit
                    
                    let arrival = max(curr, stop.plannedArrival ?? 0)
                    result[i].stops[j].arrival = arrival
                    
                    let baseDwell = (stop.isSkipped ? 0 : stop.minDwell + stop.extraDwell) * 60.0
                    let earliestDeparture = arrival + baseDwell
                    
                    let dep = max(earliestDeparture, stop.plannedDeparture ?? 0)
                    result[i].stops[j].departure = (j < result[i].stops.count - 1) ? dep : nil
                    curr = dep
                }
            }
        }
        return result
    }
}
