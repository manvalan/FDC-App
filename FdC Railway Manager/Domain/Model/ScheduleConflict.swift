import Foundation

public struct ScheduleConflict: Identifiable, Hashable, Sendable {
    public enum LocationType: String, Sendable, Codable {
        case station = "Stazione"
        case line = "Linea"
        case routing = "Instradamento"
    }

    public let trainAId: UUID
    public let trainBId: UUID
    public let trainAName: String
    public let trainBName: String
    public let locationType: LocationType
    public let locationName: String
    public let locationId: String
    public let timeStart: Date
    public let timeEnd: Date
    public let capacity: Int
    public let occupantsCount: Int

    public var id: String {
        "\(trainAId.uuidString)_\(trainBId.uuidString)_\(locationId)_\(Int(timeStart.timeIntervalSince1970))"
    }

    public init(
        trainAId: UUID,
        trainBId: UUID,
        trainAName: String,
        trainBName: String,
        locationType: LocationType,
        locationName: String,
        locationId: String,
        timeStart: Date,
        timeEnd: Date,
        capacity: Int,
        occupantsCount: Int
    ) {
        self.trainAId = trainAId
        self.trainBId = trainBId
        self.trainAName = trainAName
        self.trainBName = trainBName
        self.locationType = locationType
        self.locationName = locationName
        self.locationId = locationId
        self.timeStart = timeStart
        self.timeEnd = timeEnd
        self.capacity = capacity
        self.occupantsCount = occupantsCount
    }
}
