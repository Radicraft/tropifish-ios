import Foundation
import SwiftData

/// A single dated entry in an inhabitant's or plant's history — the event-log
/// pattern behind livestock tracking (added / removed / health note / trim).
///
/// One event belongs to *either* a `StockedSpecies` (fish, shrimp, snails…) or a
/// `StockedPlant`, via the two optional inverse relationships below. Keeping a
/// single event type — rather than one per parent — lets the log UI and the
/// `EventKind` vocabulary be shared. `quantityDelta` is signed: positive for
/// additions, negative for removals/losses, and zero for observation notes.
@Model
final class StockEvent {
    var id: UUID = UUID()

    var date: Date

    var kindRaw: String

    /// Signed change to the population (+n added, −n removed/died, 0 for notes).
    var quantityDelta: Int

    var note: String?

    /// Set when this event belongs to a stocked animal.
    var stockedSpecies: StockedSpecies?

    /// Set when this event belongs to a plant.
    var stockedPlant: StockedPlant?

    init(
        kind: EventKind,
        date: Date = Date(),
        quantityDelta: Int = 0,
        note: String? = nil,
        stockedSpecies: StockedSpecies? = nil,
        stockedPlant: StockedPlant? = nil
    ) {
        self.kindRaw = kind.rawValue
        self.date = date
        self.quantityDelta = quantityDelta
        self.note = note
        self.stockedSpecies = stockedSpecies
        self.stockedPlant = stockedPlant
    }
}

extension StockEvent {
    /// Typed accessor over the persisted `kindRaw` (SwiftData stores primitives).
    var kind: EventKind {
        get { EventKind(rawValue: kindRaw) ?? .note }
        set { kindRaw = newValue.rawValue }
    }
}

/// The kinds of history entry a keeper can log against an inhabitant or plant.
/// `trimmed` is plant-only; the rest apply to both.
enum EventKind: String, Codable, CaseIterable, Identifiable {
    case added
    case removed
    case note
    case trimmed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .added:   return "Added"
        case .removed: return "Removed / lost"
        case .note:    return "Health note"
        case .trimmed: return "Trimmed"
        }
    }

    /// Short verb for compact log rows ("Added 6", "Trimmed").
    var shortName: String {
        switch self {
        case .added:   return "Added"
        case .removed: return "Removed"
        case .note:    return "Note"
        case .trimmed: return "Trimmed"
        }
    }

    var systemImage: String {
        switch self {
        case .added:   return "plus.circle.fill"
        case .removed: return "minus.circle.fill"
        case .note:    return "text.bubble.fill"
        case .trimmed: return "scissors"
        }
    }

    /// Whether this kind moves the population count (drives the quantity stepper
    /// in the log-entry form).
    var affectsQuantity: Bool {
        self == .added || self == .removed
    }
}
