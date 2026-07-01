import Foundation
import SwiftData

/// A single water-test session (brief §4.2). All seven v1 parameters are logged
/// together in one fast-entry screen; ammonia, pH and temperature in particular
/// are a *bundled* group because the NH₃ toxicity calculation is only meaningful
/// when all three come from the same session (brief §6.2, §6.8).
///
/// Fields are optional so a partial log (or an in-progress edit) is representable
/// — a value of `0` is a real, meaningful reading and must never stand in for
/// "not measured". Assessment code treats `nil` as "no data for this parameter".
///
/// **Canonical units** match `ParameterTargets`: ammonia/nitrite/nitrate in ppm,
/// KH in dKH, GH in dGH, pH unitless, temperature in °C.
@Model
final class TestReading {
    var id: UUID = UUID()

    /// When the test was taken (defaults to now on the entry screen).
    var timestamp: Date

    /// Total ammonia nitrogen (TAN) as read straight off the test kit, ppm.
    /// This is the raw reading; the headline figure the app displays is the
    /// calculated `unIonizedAmmonia` derived from it (brief §6.2).
    var ammoniaTAN: Double?

    var nitrite: Double?
    var nitrate: Double?
    var kh: Double?
    var gh: Double?
    var ph: Double?
    /// Temperature in °C. Required for a full log and feeds the ammonia calc.
    var temperatureC: Double?

    /// Optional free-text note, e.g. "added Prime, did 20% change" (§4.2).
    var note: String?

    var tank: Tank?

    init(
        timestamp: Date = Date(),
        ammoniaTAN: Double? = nil,
        nitrite: Double? = nil,
        nitrate: Double? = nil,
        kh: Double? = nil,
        gh: Double? = nil,
        ph: Double? = nil,
        temperatureC: Double? = nil,
        note: String? = nil,
        tank: Tank? = nil
    ) {
        self.timestamp = timestamp
        self.ammoniaTAN = ammoniaTAN
        self.nitrite = nitrite
        self.nitrate = nitrate
        self.kh = kh
        self.gh = gh
        self.ph = ph
        self.temperatureC = temperatureC
        self.note = note
        self.tank = tank
    }
}

extension TestReading {
    /// Calculated toxic un-ionized ammonia (NH₃-N, ppm) for this session — the
    /// app's headline ammonia figure (brief §6.2). Returns `nil` unless total
    /// ammonia, pH and temperature were all recorded in this session, because
    /// the calculation is meaningless without all three.
    var unIonizedAmmonia: Double? {
        guard let ammoniaTAN, let ph, let temperatureC else { return nil }
        return AmmoniaToxicity.unIonizedAmmonia(
            totalAmmoniaTAN: ammoniaTAN,
            ph: ph,
            temperatureC: temperatureC
        )
    }

    /// True when this session carries the full ammonia-toxicity input bundle.
    var hasAmmoniaBundle: Bool {
        ammoniaTAN != nil && ph != nil && temperatureC != nil
    }
}
