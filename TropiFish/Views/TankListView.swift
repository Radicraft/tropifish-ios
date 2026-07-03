import SwiftUI
import SwiftData

/// Home screen for build-order step 2: the list of tanks with create + delete.
/// The richer card-based dashboard with traffic-light status (brief §12, §6)
/// arrives in step 6; this is the navigational backbone it will grow into.
struct TankListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tank.createdAt, order: .reverse) private var tanks: [Tank]

    @State private var isAddingTank = false
    @State private var path: [Tank] = []
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if tanks.isEmpty {
                    ContentUnavailableView {
                        Label("No Tanks Yet", systemImage: "drop")
                    } description: {
                        Text("Add your first aquarium to start logging water tests.")
                    } actions: {
                        Button("Add Tank") { isAddingTank = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(tanks) { tank in
                            NavigationLink(value: tank) {
                                TankRow(tank: tank)
                            }
                        }
                        .onDelete(perform: deleteTanks)
                    }
                }
            }
            .navigationTitle("TropiFish")
            .navigationDestination(for: Tank.self) { tank in
                TankDetailView(tank: tank)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingTank = true
                    } label: {
                        Label("Add Tank", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingTank) {
                AddTankView()
            }
            .sheet(isPresented: Binding(
                get: { !hasCompletedOnboarding },
                set: { if !$0 { hasCompletedOnboarding = true } }
            )) {
                WelcomeView()
            }
        }
        .task {
            #if DEBUG
            SampleData.seedIfRequested(modelContext)
            if let target = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("-openTank=") })?
                .replacingOccurrences(of: "-openTank=", with: ""),
               let tank = tanks.first(where: { $0.name == target }) {
                path = [tank]
            }
            #endif
            // Keep pending reminders in step with the current data on each launch
            // (dates drift, tanks may have been added on another device later).
            for tank in tanks where tank.reminderIntervalDays != nil {
                ReminderScheduler.reschedule(for: tank)
            }
            // Same for filter-media reminders — refresh whichever media is due next.
            for tank in tanks where !tank.filterMedia.isEmpty {
                ReminderScheduler.rescheduleFilterReminder(for: tank)
            }
        }
    }

    private func deleteTanks(at offsets: IndexSet) {
        for index in offsets {
            let tank = tanks[index]
            ReminderScheduler.cancel(for: tank)
            modelContext.delete(tank)
        }
    }
}

/// One card in the tank list — name, preset, and a traffic-light status summary
/// from the latest reading (brief §4.5, §12: dashboard → detail).
private struct TankRow: View {
    let tank: Tank

    private var assessment: TankAssessment { AssessmentEngine.assess(tank: tank) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tank.name)
                        .font(.headline)
                    Text("\(tank.tankType.displayName) · \(volumeText)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if assessment.hasData {
                    TrafficLightBadge(light: assessment.overall, compact: true)
                }
            }

            if assessment.hasData {
                if let headline = assessment.headline {
                    Text(headline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("All parameters in range.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No tests logged yet.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var volumeText: String {
        let liters = tank.volumeLiters
        let shown = liters == liters.rounded() ? String(Int(liters)) : String(format: "%.1f", liters)
        return "\(shown) L"
    }
}

#Preview("Empty") {
    TankListView()
        .modelContainer(try! TropiFishSchema.makeContainer(inMemory: true))
}

#Preview("With tanks") {
    let container = try! TropiFishSchema.makeContainer(inMemory: true)
    container.mainContext.insert(Tank(name: "Living Room 240", volumeLiters: 240, tankType: .cichlid))
    container.mainContext.insert(Tank(name: "Shrimp Nano", volumeLiters: 30, tankType: .shrimp))
    return TankListView()
        .modelContainer(container)
}
