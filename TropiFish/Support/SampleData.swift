#if DEBUG
import Foundation
import SwiftData

/// Demo data for previews, screenshots, and manual QA in the simulator. Gated to
/// DEBUG so it can never ship. Triggered by launching with the `-seedDemoData`
/// argument into an otherwise-empty store.
enum SampleData {
    static func seedIfRequested(_ context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-seedDemoData") else { return }
        // Skip first-run onboarding for QA/screenshot runs.
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        let existing = (try? context.fetch(FetchDescriptor<Tank>()))?.isEmpty ?? true
        guard existing else { return }
        seed(context)
    }

    static func seed(_ context: ModelContext) {
        let cal = Calendar.current
        let now = Date()
        func daysAgo(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: now)! }

        // A warm, alkaline cichlid tank with rising nitrate and a whiff of ammonia
        // at high pH — exercises the toxicity calc and the nitrate trend.
        let cichlid = Tank(name: "Living Room 240", volumeLiters: 240,
                           dateEstablished: daysAgo(400), tankType: .cichlid,
                           tapWaterNitrate: 10)
        context.insert(cichlid)
        let cichlidReadings: [(Int, Double, Double, Double, Double)] = [
            // (daysAgo, TAN, nitrate, ph, temp)
            (24, 0.0, 20, 8.0, 26), (18, 0.0, 25, 8.1, 26),
            (12, 0.25, 30, 8.2, 26.5), (6, 0.25, 35, 8.2, 27), (0, 0.5, 45, 8.3, 27)
        ]
        for (d, tan, no3, ph, t) in cichlidReadings {
            context.insert(TestReading(timestamp: daysAgo(d), ammoniaTAN: tan, nitrite: 0,
                                       nitrate: no3, kh: 14, gh: 16, ph: ph, temperatureC: t, tank: cichlid))
        }
        context.insert(WaterChangeEvent(timestamp: daysAgo(6), percentChanged: 25, tank: cichlid))
        // Canister media: an overdue carbon (changed 40d ago, 30d cycle), a
        // due-soon set of bio rings, and a fresh mechanical foam — exercises all
        // three traffic-light states in the Filter section.
        cichlid.filterModel = "External canister"
        context.insert(FilterMediaItem(kind: .carbon, lastChanged: daysAgo(40), tank: cichlid))
        context.insert(FilterMediaItem(kind: .bioMax, lastChanged: daysAgo(177), tank: cichlid))
        context.insert(FilterMediaItem(kind: .mechanicalFoam, lastChanged: daysAgo(20), tank: cichlid))

        // Cichlid tank stock: an angelfish + a big Oscar hint at predation/size
        // conflicts if neons were added, and drive a heavier stocking level.
        context.insert(StockedSpecies(speciesID: "angelfish", quantity: 2, tank: cichlid))
        context.insert(StockedSpecies(speciesID: "bristlenose-pleco", quantity: 1, tank: cichlid))

        // A healthy planted tank, all in range, with a balanced community —
        // but only 3 neons, so the stocking check flags a shoaling shortfall.
        let planted = Tank(name: "Office Planted 60", volumeLiters: 60,
                           dateEstablished: daysAgo(120), tankType: .planted)
        context.insert(planted)
        context.insert(TestReading(timestamp: daysAgo(2), ammoniaTAN: 0, nitrite: 0,
                                   nitrate: 15, kh: 5, gh: 8, ph: 6.8, temperatureC: 25, tank: planted))
        context.insert(StockedSpecies(speciesID: "neon-tetra", quantity: 3, tank: planted))
        context.insert(StockedSpecies(speciesID: "harlequin-rasbora", quantity: 8, tank: planted))
        context.insert(StockedSpecies(speciesID: "bronze-cory", quantity: 6, tank: planted))

        // A cycling shrimp nano — ammonia present, but flagged as cycling.
        let shrimp = Tank(name: "Shrimp Nano", volumeLiters: 25,
                          dateEstablished: daysAgo(10), tankType: .shrimp, isCycling: true)
        context.insert(shrimp)
        context.insert(TestReading(timestamp: daysAgo(0), ammoniaTAN: 1.0, nitrite: 0.25,
                                   nitrate: 5, kh: 3, gh: 6, ph: 7.0, temperatureC: 24, tank: shrimp))

        // A driftwood/blackwater planted tank exercising the hardness rules:
        // KH still in range but falling three tests running (leading pH-crash
        // indicator, §6.5), and GH below its ideal range (suitability amber, §6.6).
        let blackwater = Tank(name: "Blackwater 90", volumeLiters: 90,
                              dateEstablished: daysAgo(200), tankType: .planted)
        context.insert(blackwater)
        let khSeries: [(Int, Double, Double)] = [
            // (daysAgo, kh, gh) — KH 7→6→5→4 (falling, still ≥ min 3), GH 3 (< min 4)
            (18, 7, 5), (12, 6, 4), (6, 5, 4), (0, 4, 3)
        ]
        for (d, kh, gh) in khSeries {
            context.insert(TestReading(timestamp: daysAgo(d), ammoniaTAN: 0, nitrite: 0,
                                       nitrate: 15, kh: kh, gh: gh, ph: 6.6, temperatureC: 25, tank: blackwater))
        }

        try? context.save()
    }
}
#endif
