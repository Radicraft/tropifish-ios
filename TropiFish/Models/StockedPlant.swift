import Foundation
import SwiftData

/// A plant the user actually keeps in a tank (plant-tracking feature). User data
/// — a child of `Tank` — referencing the bundled `PlantCatalog` by `plantID`
/// slug, mirroring `StockedSpecies`. Carries the same dated event log so keepers
/// can record when a plant was added, trimmed, or is struggling.
@Model
final class StockedPlant {
    var id: UUID = UUID()

    /// Slug into `PlantCatalog` (e.g. "java-fern").
    var plantID: String

    /// Rough count of portions/pots — informational only (plants don't feed the
    /// bioload estimate the way fish do).
    var quantity: Int

    var dateAdded: Date

    var note: String?

    var tank: Tank?

    /// Dated history for this plant — added/trimmed/health notes.
    @Relationship(deleteRule: .cascade, inverse: \StockEvent.stockedPlant)
    var events: [StockEvent] = []

    init(
        plantID: String,
        quantity: Int = 1,
        dateAdded: Date = Date(),
        note: String? = nil,
        tank: Tank? = nil
    ) {
        self.plantID = plantID
        self.quantity = max(1, quantity)
        self.dateAdded = dateAdded
        self.note = note
        self.tank = tank
    }
}

extension StockedPlant {
    /// Resolve the reference plant from the bundled catalog, if present.
    var plant: Plant? { PlantCatalog.shared.byID(plantID) }

    /// History newest-first for display.
    var eventsByDateDescending: [StockEvent] {
        events.sorted { $0.date > $1.date }
    }
}
