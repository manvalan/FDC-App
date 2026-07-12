import Foundation

// MARK: - Takt alignment & diagnostic

extension ScheduleCreationViewModel {

    /// Allinea l'orario di partenza al minuto Takt della prima stazione con nodo Takt.
    func alignToTakt(isReturn: Bool) {
        if let newDate = taktEngine.calculateAlignedStartTime(
            startTime: startTime,
            stationSequence: stationSequence,
            taktStationId: taktStationId,
            train: makeDummyTrain(),
            isReturn: isReturn) {
            startTime = newDate
            updatePreview()
        }
    }

    func presetTaktHub() {
        taktStationId = pathResolver.presetTaktHub(
            stationSequence: stationSequence, currentHubId: taktStationId
        )
    }

    /// Calcola i suggerimenti Takt per ogni stazione con minuto Takt configurato.
    func calculateTaktSuggestions() -> [(
        stationId: String, stationName: String, taktMinute: Int,
        suggestedArrival: String, suggestedDeparture: String
    )] {
        taktEngine.calculateTaktSuggestions(stationSequence: stationSequence)
    }

    /// Verifica il posizionamento Takt per tutti i treni generati.
    func validateNonMainTaktPlacement() -> [TaktDiagnosticEntry] {
        taktEngine.validateTaktPlacement(
            trains: generatedTrains ?? [], taktStationId: taktStationId
        )
    }
}
