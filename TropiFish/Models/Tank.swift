import Foundation
import SwiftData

/// A single aquarium (brief §4.1). Owns its test readings and water-change
/// events, and carries its own configurable safe ranges so a shrimp tank and an
/// African cichlid tank can target very different water (§3).
@Model
final class Tank {
    /// Stable identity independent of SwiftData's persistent ID — handy for
    /// widgets, notifications, and (Phase 2) CloudKit reconciliation.
    var id: UUID = UUID()

    var name: String
    /// Water volume in litres (used later by the Phase 2 dosing calculator, §5).
    var volumeLiters: Double
    var dateEstablished: Date
    var tankType: TankType

    /// Freshly-set-up tank flag (brief §6.2 caveat). While true, ammonia
    /// guidance copy reads as informational rather than alarming, since a
    /// cycling tank shows ammonia most days as a matter of course.
    var isCycling: Bool

    /// One-time measured nitrate baseline of the tap/source water in ppm
    /// (brief §6.4). `nil` until the user runs the setup step. When known, it
    /// lets the app avoid recommending a water change that can't lower nitrate
    /// below what comes out of the tap.
    var tapWaterNitrate: Double?

    /// Water-change reminder cadence in days (brief §4.6). `nil` = reminders off.
    var reminderIntervalDays: Int?

    /// Per-tank safe ranges and stability thresholds, seeded from the preset at
    /// creation and user-overridable (brief §3).
    var targets: ParameterTargets

    var createdAt: Date

    // Cascade so deleting a tank removes its logs. Inverses are declared on the
    // child models.
    @Relationship(deleteRule: .cascade, inverse: \TestReading.tank)
    var readings: [TestReading] = []

    @Relationship(deleteRule: .cascade, inverse: \WaterChangeEvent.tank)
    var waterChanges: [WaterChangeEvent] = []

    init(
        name: String,
        volumeLiters: Double,
        dateEstablished: Date = Date(),
        tankType: TankType = .community,
        isCycling: Bool = false,
        tapWaterNitrate: Double? = nil,
        reminderIntervalDays: Int? = 7,
        targets: ParameterTargets? = nil,
        createdAt: Date = Date()
    ) {
        self.name = name
        self.volumeLiters = volumeLiters
        self.dateEstablished = dateEstablished
        self.tankType = tankType
        self.isCycling = isCycling
        self.tapWaterNitrate = tapWaterNitrate
        self.reminderIntervalDays = reminderIntervalDays
        // Default to the preset's ranges unless explicit overrides are supplied.
        self.targets = targets ?? tankType.defaultTargets
        self.createdAt = createdAt
    }
}

extension Tank {
    /// Readings newest-first — the order every assessment and chart needs.
    var readingsByDateDescending: [TestReading] {
        readings.sorted { $0.timestamp > $1.timestamp }
    }

    var latestReading: TestReading? {
        readingsByDateDescending.first
    }

    var lastWaterChange: WaterChangeEvent? {
        waterChanges.max { $0.timestamp < $1.timestamp }
    }
}
