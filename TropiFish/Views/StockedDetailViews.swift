import SwiftUI
import SwiftData

/// A kept inhabitant's page: photo, current count, a link to the full care
/// sheet, and its dated history log (added / removed / health notes). Reached by
/// tapping a fish/invert in a tank's Stock section.
struct StockedSpeciesDetailView: View {
    @Bindable var stocked: StockedSpecies
    @Environment(\.modelContext) private var modelContext

    @State private var isAddingEvent = false

    var body: some View {
        List {
            if let species = stocked.species {
                headerSection(species)
                Section {
                    NavigationLink {
                        SpeciesDetailView(species: species)
                    } label: {
                        Label("Full care sheet", systemImage: "book")
                    }
                }
            } else {
                Section {
                    Label(stocked.speciesID, systemImage: "questionmark.circle")
                        .foregroundStyle(.secondary)
                }
            }

            EventLogListSection(
                events: stocked.eventsByDateDescending,
                addTitle: "Log an entry",
                onAdd: { isAddingEvent = true },
                onDelete: deleteEvents
            )
        }
        .navigationTitle(stocked.species?.commonName ?? "Inhabitant")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isAddingEvent) {
            AddEventView(allowTrim: false, onSave: addEvent)
        }
    }

    private func headerSection(_ species: Species) -> some View {
        Section {
            HStack(spacing: 14) {
                SpeciesImage(species: species, cornerRadius: 12)
                    .frame(width: 76, height: 76)
                VStack(alignment: .leading, spacing: 3) {
                    Text(species.commonName).font(.headline)
                    Text(species.scientificName)
                        .font(.caption).italic().foregroundStyle(.secondary)
                    Text("Added \(stocked.dateAdded.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
            }
            Stepper(value: Binding(
                get: { stocked.quantity },
                set: { stocked.quantity = max(0, $0); Haptics.selection() }
            ), in: 0...999) {
                HStack {
                    Text("In this tank")
                    Spacer()
                    Text("×\(stocked.quantity)").foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
    }

    private func addEvent(_ kind: EventKind, _ date: Date, _ delta: Int, _ note: String?) {
        let event = StockEvent(kind: kind, date: date, quantityDelta: delta,
                               note: note, stockedSpecies: stocked)
        modelContext.insert(event)
        if delta != 0 { stocked.quantity = max(0, stocked.quantity + delta) }
    }

    private func deleteEvents(_ events: [StockEvent]) {
        Haptics.impact(.rigid)
        for event in events { modelContext.delete(event) }
    }
}

/// A kept plant's page: photo, current count, a link to the full care sheet, and
/// its history log (added / trimmed / health notes). Reached by tapping a plant
/// in a tank's Plants section.
struct StockedPlantDetailView: View {
    @Bindable var stocked: StockedPlant
    @Environment(\.modelContext) private var modelContext

    @State private var isAddingEvent = false

    var body: some View {
        List {
            if let plant = stocked.plant {
                headerSection(plant)
                Section {
                    NavigationLink {
                        PlantDetailView(plant: plant)
                    } label: {
                        Label("Full care sheet", systemImage: "book")
                    }
                }
            } else {
                Section {
                    Label(stocked.plantID, systemImage: "questionmark.circle")
                        .foregroundStyle(.secondary)
                }
            }

            EventLogListSection(
                events: stocked.eventsByDateDescending,
                addTitle: "Log an entry",
                onAdd: { isAddingEvent = true },
                onDelete: deleteEvents
            )
        }
        .navigationTitle(stocked.plant?.commonName ?? "Plant")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isAddingEvent) {
            AddEventView(allowTrim: true, onSave: addEvent)
        }
    }

    private func headerSection(_ plant: Plant) -> some View {
        Section {
            HStack(spacing: 14) {
                PlantImage(plant: plant, cornerRadius: 12)
                    .frame(width: 76, height: 76)
                VStack(alignment: .leading, spacing: 3) {
                    Text(plant.commonName).font(.headline)
                    Text(plant.scientificName)
                        .font(.caption).italic().foregroundStyle(.secondary)
                    Text("Added \(stocked.dateAdded.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
            }
            Stepper(value: Binding(
                get: { stocked.quantity },
                set: { stocked.quantity = max(0, $0); Haptics.selection() }
            ), in: 0...999) {
                HStack {
                    Text("Portions in this tank")
                    Spacer()
                    Text("×\(stocked.quantity)").foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
    }

    private func addEvent(_ kind: EventKind, _ date: Date, _ delta: Int, _ note: String?) {
        let event = StockEvent(kind: kind, date: date, quantityDelta: delta,
                               note: note, stockedPlant: stocked)
        modelContext.insert(event)
        if delta != 0 { stocked.quantity = max(0, stocked.quantity + delta) }
    }

    private func deleteEvents(_ events: [StockEvent]) {
        Haptics.impact(.rigid)
        for event in events { modelContext.delete(event) }
    }
}

/// Shared "History" section: an add button plus the event rows, newest-first,
/// with swipe-to-delete. Kept generic so fish, inverts and plants render the
/// same log.
struct EventLogListSection: View {
    let events: [StockEvent]
    let addTitle: String
    let onAdd: () -> Void
    let onDelete: ([StockEvent]) -> Void

    var body: some View {
        Section {
            Button {
                onAdd()
            } label: {
                Label(addTitle, systemImage: "plus.circle.fill")
            }

            if events.isEmpty {
                Text("No history yet. Log when you add stock, lose some, trim, or spot a problem — it builds a timeline you can look back on.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(events) { event in
                    EventRow(event: event)
                }
                .onDelete { offsets in
                    onDelete(offsets.map { events[$0] })
                }
            }
        } header: {
            Text("History")
        }
    }
}
