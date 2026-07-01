import Foundation
import SwiftData

/// A water-change event, logged distinctly from a test (brief §4.6) so the app
/// can plot change frequency against the nitrate trend on the same chart and
/// drive the water-change reminder cadence.
@Model
final class WaterChangeEvent {
    var id: UUID = UUID()

    var timestamp: Date

    /// Percentage of tank volume replaced (e.g. 20 for a 20% change). Optional
    /// because a user may only remember one of percent/volume.
    var percentChanged: Double?

    /// Absolute volume replaced in litres, if the user prefers to log it that
    /// way. Feeds the Phase 2 dosing calculator (§5).
    var volumeLiters: Double?

    var note: String?

    var tank: Tank?

    init(
        timestamp: Date = Date(),
        percentChanged: Double? = nil,
        volumeLiters: Double? = nil,
        note: String? = nil,
        tank: Tank? = nil
    ) {
        self.timestamp = timestamp
        self.percentChanged = percentChanged
        self.volumeLiters = volumeLiters
        self.note = note
        self.tank = tank
    }
}
