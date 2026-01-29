// Helper function to apply selected proposals
private func applySelectedProposals(_ selectedProposals: [ProposedLine]) {
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
        
        // 2. Create sample trains for this line (Cadenced)
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
    
    proposedLines = []
    aiResult = "Creazione completata: \(selectedProposals.count) linee aggiunte alla rete."
    trainManager.validateSchedules(with: network)
}
