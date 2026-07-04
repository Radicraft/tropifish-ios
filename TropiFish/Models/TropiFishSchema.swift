import Foundation
import SwiftData

/// Central SwiftData schema + container factory (brief §4.7, §7 — on-device,
/// no login, no backend in v1). Kept in one place so the app entry point,
/// previews, and tests all build the store the same way.
///
/// Phase 2 adds CloudKit sync (§5); switching `cloudKitDatabase` on the
/// configuration is the main change there, which is why the container is built
/// through this single helper rather than inline in the app struct.
enum TropiFishSchema {
    /// All persisted model types. `ParameterTargets` and its nested value types
    /// are stored inline on `Tank` as Codable values, so only the `@Model`
    /// classes are listed here.
    static let models: [any PersistentModel.Type] = [
        Tank.self,
        TestReading.self,
        WaterChangeEvent.self,
        FilterMediaItem.self,
        StockedSpecies.self,
        StockedPlant.self,
        StockEvent.self
    ]

    static var schema: Schema { Schema(models) }

    /// Build a container. `inMemory` gives an ephemeral store for previews and
    /// unit tests.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
