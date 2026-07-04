import SwiftUI
import SwiftData
import UserNotifications

/// App entry point (brief §7). Builds the on-device SwiftData store through the
/// single `TropiFishSchema` factory and injects it into the environment.
@main
struct TropiFishApp: App {
    let container: ModelContainer
    private let notificationDelegate = NotificationDelegate()

    init() {
        do {
            container = try TropiFishSchema.makeContainer()
        } catch {
            // A store that won't open is unrecoverable; fail loudly in dev.
            fatalError("Failed to create ModelContainer: \(error)")
        }
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
    }
}

/// App shell: the tank dashboard and the standalone "Fish Guide" browser as
/// peer tabs (species-suitability feature), so a keeper can look up a fish in a
/// shop without first drilling into a tank.
struct RootTabView: View {
    @State private var selection = 0
    @State private var guidePath: [Species] = []
    @State private var plantPath: [Plant] = []

    var body: some View {
        TabView(selection: $selection) {
            TankListView()
                .tabItem { Label("Tanks", systemImage: "drop.fill") }
                .tag(0)

            NavigationStack(path: $guidePath) {
                SpeciesBrowserView(onSelect: nil, compatibilityTank: nil)
                    .navigationDestination(for: Species.self) { species in
                        SpeciesDetailView(species: species)
                    }
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            NavigationLink {
                                ImageCreditsView()
                            } label: {
                                Label("Photo Credits", systemImage: "info.circle")
                            }
                        }
                    }
            }
            .tabItem { Label("Fish Guide", systemImage: "fish.fill") }
            .tag(1)

            NavigationStack(path: $plantPath) {
                PlantBrowserView(onSelect: nil)
                    .navigationDestination(for: Plant.self) { plant in
                        PlantDetailView(plant: plant)
                    }
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            NavigationLink {
                                ImageCreditsView()
                            } label: {
                                Label("Photo Credits", systemImage: "info.circle")
                            }
                        }
                    }
            }
            .tabItem { Label("Plant Guide", systemImage: "leaf.fill") }
            .tag(2)
        }
        .onChange(of: selection) { _, _ in Haptics.selection() }
        #if DEBUG
        .onAppear(perform: applyDebugDeepLinks)
        #endif
    }

    #if DEBUG
    /// QA deep links, mirroring the `-openTank=` / `-openCharts` pattern used in
    /// the tank views, so the Fish Guide surfaces can be screenshotted headlessly.
    private func applyDebugDeepLinks() {
        let args = ProcessInfo.processInfo.arguments
        if let arg = args.first(where: { $0.hasPrefix("-openSpecies=") }) {
            let slug = arg.replacingOccurrences(of: "-openSpecies=", with: "")
            if let species = SpeciesCatalog.shared.byID(slug) {
                selection = 1
                guidePath = [species]
                return
            }
        }
        if args.contains("-openFishGuide") { selection = 1 }
        if let arg = args.first(where: { $0.hasPrefix("-openPlant=") }) {
            let slug = arg.replacingOccurrences(of: "-openPlant=", with: "")
            if let plant = PlantCatalog.shared.byID(slug) {
                selection = 2
                plantPath = [plant]
                return
            }
        }
        if args.contains("-openPlantGuide") { selection = 2 }
    }
    #endif
}

/// Presents water-change reminders even while the app is in the foreground, so a
/// reminder isn't silently swallowed if the user happens to have the app open.
private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
