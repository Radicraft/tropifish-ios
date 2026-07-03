import Foundation
import SwiftData

/// A species the user actually keeps in a tank (species-suitability feature).
/// This is user data — a child of `Tank` — and references the bundled reference
/// catalog by `speciesID` slug rather than duplicating the care data, so catalog
/// updates flow through automatically.
@Model
final class StockedSpecies {
    var id: UUID = UUID()

    /// Slug into `SpeciesCatalog` (e.g. "neon-tetra").
    var speciesID: String

    /// How many of this species are in the tank (drives the stocking estimate).
    var quantity: Int

    var dateAdded: Date

    var note: String?

    var tank: Tank?

    init(
        speciesID: String,
        quantity: Int = 1,
        dateAdded: Date = Date(),
        note: String? = nil,
        tank: Tank? = nil
    ) {
        self.speciesID = speciesID
        self.quantity = max(1, quantity)
        self.dateAdded = dateAdded
        self.note = note
        self.tank = tank
    }
}

extension StockedSpecies {
    /// Resolve the reference species from the bundled catalog, if present.
    var species: Species? { SpeciesCatalog.shared.byID(speciesID) }
}
