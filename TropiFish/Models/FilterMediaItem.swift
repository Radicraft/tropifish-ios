import Foundation
import SwiftData

/// A single piece of filter media in a tank's filter, tracked so the app can
/// tell the user when it's due for a change (feature: filter maintenance).
///
/// Like `TestReading`/`WaterChangeEvent`, this is a child of `Tank` with a
/// cascade delete, and carries its own stable `id` for notification identity.
/// Each item is seeded from a `FilterMediaKind` default but its `intervalDays`
/// is user-overridable, so an aquarist running carbon on a fortnightly cycle can
/// say so.
@Model
final class FilterMediaItem {
    var id: UUID = UUID()

    /// What kind of media this is (drives the icon, default cadence, guidance).
    var kind: FilterMediaKind

    /// User-supplied name, used when `kind == .other` (e.g. "Purigen").
    var customName: String?

    /// When this media was last replaced. "Mark changed" sets this to now.
    var lastChanged: Date

    /// How many days between changes for this item. Seeded from
    /// `kind.defaultIntervalDays`, then freely editable.
    var intervalDays: Int

    var note: String?

    var tank: Tank?

    init(
        kind: FilterMediaKind,
        customName: String? = nil,
        lastChanged: Date = Date(),
        intervalDays: Int? = nil,
        note: String? = nil,
        tank: Tank? = nil
    ) {
        self.kind = kind
        self.customName = customName
        self.lastChanged = lastChanged
        self.intervalDays = intervalDays ?? kind.defaultIntervalDays
        self.note = note
        self.tank = tank
    }
}

extension FilterMediaItem {
    /// Display title — the custom name if given, otherwise the kind's name.
    var title: String {
        if let customName, !customName.isEmpty { return customName }
        return kind.displayName
    }

    /// When this media is next due for a change.
    var dueDate: Date {
        Calendar.current.date(byAdding: .day, value: intervalDays, to: lastChanged)
            ?? lastChanged.addingTimeInterval(TimeInterval(intervalDays) * 24 * 60 * 60)
    }

    /// Status against the schedule (green/amber/red), evaluated at `now`.
    func status(now: Date = Date()) -> FilterMediaStatus {
        FilterMediaStatus.of(dueDate: dueDate, now: now)
    }

    /// Whole days until due (negative if overdue), for compact display.
    func daysUntilDue(now: Date = Date()) -> Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: now),
                                        to: Calendar.current.startOfDay(for: dueDate)).day ?? 0
    }
}
