import SwiftUI
import SwiftData

/// The tank hub (brief §4.5, §12): traffic-light status at a glance, the most
/// urgent guidance, quick actions to log a test or water change, the full
/// per-parameter breakdown, and links into history and trend charts.
struct TankDetailView: View {
    @Bindable var tank: Tank
    @Environment(\.modelContext) private var modelContext

    @State private var isLoggingTest = false
    @State private var isLoggingWaterChange = false
    @State private var isEditingTank = false
    @State private var isAddingSpecies = false
    @State private var isAddingPlant = false
    /// Set after adding a fish that isn't a clean match, to surface a warning.
    @State private var addWarning: CompatibilityReport?
    #if DEBUG
    @State private var debugShowCharts = ProcessInfo.processInfo.arguments.contains("-openCharts")
    @State private var debugShowFilter = ProcessInfo.processInfo.arguments.contains("-openFilterMedia")
    @State private var debugShowStockLog = ProcessInfo.processInfo.arguments.contains("-openStockLog")
    #endif

    private var assessment: TankAssessment { AssessmentEngine.assess(tank: tank) }

    var body: some View {
        List {
            statusSection

            Section {
                Button {
                    isLoggingTest = true
                } label: {
                    Label("Log Test", systemImage: "plus.circle.fill")
                }
                Button {
                    isLoggingWaterChange = true
                } label: {
                    Label("Log Water Change", systemImage: "drop.fill")
                }
            }

            if assessment.hasData {
                latestReadingSection
                guidanceSection
            }

            stockSection

            plantsSection

            Section {
                NavigationLink {
                    TestHistoryView(tank: tank)
                } label: {
                    Label("History", systemImage: "clock")
                }
                NavigationLink {
                    ParameterChartsView(tank: tank)
                } label: {
                    Label("Trends", systemImage: "chart.xyaxis.line")
                }
            }

            filterSection

            setupSection
        }
        .navigationTitle(tank.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditingTank = true }
            }
        }
        .sheet(isPresented: $isLoggingTest) {
            LogTestView(tank: tank)
        }
        .sheet(isPresented: $isLoggingWaterChange) {
            LogWaterChangeView(tank: tank)
        }
        .sheet(isPresented: $isEditingTank) {
            EditTankView(tank: tank)
        }
        .sheet(isPresented: $isAddingSpecies) {
            NavigationStack {
                SpeciesBrowserView(onSelect: addSpecies, compatibilityTank: tank)
            }
        }
        .sheet(isPresented: $isAddingPlant) {
            NavigationStack {
                PlantBrowserView(onSelect: addPlant)
            }
        }
        .alert("Heads up", isPresented: Binding(
            get: { addWarning != nil },
            set: { if !$0 { addWarning = nil } }
        ), presenting: addWarning) { _ in
            Button("Keep it", role: .cancel) {}
        } message: { report in
            Text(addWarningMessage(report))
        }
        #if DEBUG
        .navigationDestination(isPresented: $debugShowCharts) {
            ParameterChartsView(tank: tank)
        }
        .navigationDestination(isPresented: $debugShowFilter) {
            FilterMediaView(tank: tank)
        }
        .navigationDestination(isPresented: $debugShowStockLog) {
            if let first = tank.stock.sorted(by: { $0.dateAdded < $1.dateAdded }).first {
                StockedSpeciesDetailView(stocked: first)
            }
        }
        #endif
    }

    // MARK: - Sections

    private var statusSection: some View {
        Section {
            if assessment.hasData {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        TrafficLightBadge(light: assessment.overall)
                        Spacer()
                        if let latest = tank.latestReading {
                            Text(latest.timestamp.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let headline = assessment.headline {
                        Text(headline)
                            .font(.subheadline)
                    } else {
                        Text("Everything looks good. Keep logging to track trends over time.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if tank.isCycling {
                        Label("Tank is cycling — ammonia guidance stays informational.",
                              systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } else {
                ContentUnavailableView {
                    Label("No Tests Yet", systemImage: "drop")
                } description: {
                    Text("Log your first water test to see this tank's status and guidance.")
                } actions: {
                    Button("Log Test") { isLoggingTest = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private var latestReadingSection: some View {
        Section("Latest reading") {
            ForEach(assessment.parameters) { param in
                ParameterStatusRow(assessment: param)
            }
        }
    }

    @ViewBuilder
    private var guidanceSection: some View {
        let flagged = assessment.flagged.filter { $0.guidance != nil }
        if !flagged.isEmpty {
            Section("Guidance") {
                ForEach(flagged) { param in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: param.risk.trafficLight.systemImage)
                            .foregroundStyle(param.risk.color)
                            .font(.subheadline)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(param.parameter.displayName)
                                .font(.subheadline.weight(.semibold))
                            Text(param.guidance ?? "")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Stock

    @ViewBuilder
    private var stockSection: some View {
        let report = StockingAssessment.assess(tank: tank)
        Section {
            if !tank.stock.isEmpty {
                stockingSummary(report)
            }
            ForEach(tank.stock.sorted { $0.dateAdded < $1.dateAdded }) { stocked in
                stockRow(stocked)
            }
            .onDelete(perform: deleteStock)

            Button {
                isAddingSpecies = true
            } label: {
                Label("Add Fish", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("Stock")
        } footer: {
            if !tank.stock.isEmpty {
                Text("Stocking level is an estimate to guide you — your water tests are the real measure of whether a tank is coping.")
            }
        }
    }

    private func stockingSummary(_ report: StockingReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TrafficLightBadgeLabel(light: report.overall, text: report.level.displayName)
                Spacer()
                if report.percentEstimate > 0 {
                    Text("~\(report.percentEstimate)% full")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(report.concerns.first?.message ?? report.level.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func stockRow(_ stocked: StockedSpecies) -> some View {
        if let species = stocked.species {
            NavigationLink {
                StockedSpeciesDetailView(stocked: stocked)
            } label: {
                HStack(spacing: 12) {
                    SpeciesImage(species: species, cornerRadius: 6)
                        .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(species.commonName)
                        Text(species.scientificName)
                            .font(.caption2).italic()
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Stepper("×\(stocked.quantity)", value: Binding(
                        get: { stocked.quantity },
                        set: {
                            stocked.quantity = max(1, $0)
                            Haptics.selection()
                        }
                    ), in: 1...999)
                    .labelsHidden()
                    .fixedSize()
                    Text("×\(stocked.quantity)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            // Species slug not in the current catalog (older data / removed entry).
            Label(stocked.speciesID, systemImage: "questionmark.circle")
                .foregroundStyle(.secondary)
        }
    }

    private func addSpecies(_ species: Species) {
        // Merge into an existing entry if already stocked, else insert. Either
        // way, log an "added 1" history entry so the timeline stays truthful.
        let entry: StockedSpecies
        if let existing = tank.stock.first(where: { $0.speciesID == species.id }) {
            existing.quantity += 1
            entry = existing
        } else {
            let created = StockedSpecies(speciesID: species.id, tank: tank)
            modelContext.insert(created)
            entry = created
        }
        modelContext.insert(StockEvent(kind: .added, quantityDelta: 1, stockedSpecies: entry))
        // Warn if the newly-added fish isn't a clean match for the tank — the
        // haptic mirrors the outcome: a caution buzz with the alert, else a
        // satisfying confirm.
        let report = CompatibilityEngine.assess(candidate: species, against: tank)
        if report.overall != .green {
            addWarning = report
            Haptics.warning()
        } else {
            Haptics.success()
        }
    }

    private func deleteStock(at offsets: IndexSet) {
        Haptics.impact(.rigid)
        let sorted = tank.stock.sorted { $0.dateAdded < $1.dateAdded }
        for index in offsets { modelContext.delete(sorted[index]) }
    }

    // MARK: - Plants

    @ViewBuilder
    private var plantsSection: some View {
        Section {
            ForEach(tank.plants.sorted { $0.dateAdded < $1.dateAdded }) { planted in
                plantRow(planted)
            }
            .onDelete(perform: deletePlants)

            Button {
                isAddingPlant = true
            } label: {
                Label("Add Plant", systemImage: "leaf.fill")
            }
        } header: {
            Text("Plants")
        } footer: {
            if tank.plants.isEmpty {
                Text("Track the plants you keep, and log when you add, trim, or lose them.")
            }
        }
    }

    @ViewBuilder
    private func plantRow(_ planted: StockedPlant) -> some View {
        if let plant = planted.plant {
            NavigationLink {
                StockedPlantDetailView(stocked: planted)
            } label: {
                HStack(spacing: 12) {
                    PlantImage(plant: plant, cornerRadius: 6)
                        .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(plant.commonName)
                        Text(plant.placement.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("×\(planted.quantity)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Label(planted.plantID, systemImage: "questionmark.circle")
                .foregroundStyle(.secondary)
        }
    }

    private func addPlant(_ plant: Plant) {
        let entry: StockedPlant
        if let existing = tank.plants.first(where: { $0.plantID == plant.id }) {
            existing.quantity += 1
            entry = existing
        } else {
            let created = StockedPlant(plantID: plant.id, tank: tank)
            modelContext.insert(created)
            entry = created
        }
        modelContext.insert(StockEvent(kind: .added, quantityDelta: 1, stockedPlant: entry))
        Haptics.success()
    }

    private func deletePlants(at offsets: IndexSet) {
        Haptics.impact(.rigid)
        let sorted = tank.plants.sorted { $0.dateAdded < $1.dateAdded }
        for index in offsets { modelContext.delete(sorted[index]) }
    }

    private func addWarningMessage(_ report: CompatibilityReport) -> String {
        let lead = report.overall == .red
            ? "\(report.candidate.commonName) may not be a good fit for \(tank.name):"
            : "A couple of things to watch with \(report.candidate.commonName) in \(tank.name):"
        let reasons = report.concerns.prefix(3).map { "• \($0.message)" }.joined(separator: "\n")
        return lead + "\n\n" + reasons
    }

    // MARK: - Filter

    @ViewBuilder
    private var filterSection: some View {
        Section("Filter") {
            NavigationLink {
                FilterMediaView(tank: tank)
            } label: {
                if let soonest = tank.filterMediaSoonestDue {
                    let status = soonest.status()
                    HStack(spacing: 12) {
                        Image(systemName: "square.stack.3d.up")
                            .foregroundStyle(status.trafficLight.color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Filter media")
                            Text(filterSummary(for: soonest, status: status))
                                .font(.caption)
                                .foregroundStyle(status == .ok ? .secondary : status.trafficLight.color)
                        }
                    }
                } else {
                    Label("Track filter media", systemImage: "square.stack.3d.up")
                }
            }
        }
    }

    private func filterSummary(for item: FilterMediaItem, status: FilterMediaStatus) -> String {
        let days = item.daysUntilDue()
        switch status {
        case .overdue:
            let by = -days
            return "\(item.title) overdue" + (by > 0 ? " by \(by) day\(by == 1 ? "" : "s")" : " today")
        case .dueSoon:
            return days == 0 ? "\(item.title) due today" : "\(item.title) due in \(days) day\(days == 1 ? "" : "s")"
        case .ok:
            return "Next: \(item.title), \(item.dueDate.formatted(date: .abbreviated, time: .omitted))"
        }
    }

    private var setupSection: some View {
        Section("Setup") {
            LabeledContent("Type", value: tank.tankType.displayName)
            LabeledContent("Volume", value: "\(volumeText) L")
            LabeledContent("Established", value: tank.dateEstablished.formatted(date: .abbreviated, time: .omitted))
            if let interval = tank.reminderIntervalDays {
                LabeledContent("Water-change reminder", value: "Every \(interval) days")
            } else {
                LabeledContent("Water-change reminder", value: "Off")
            }
            if let tap = tank.tapWaterNitrate {
                LabeledContent("Tap-water nitrate", value: WaterParameter.nitrate.formatted(tap))
            }
        }
    }

    private var volumeText: String {
        let liters = tank.volumeLiters
        return liters == liters.rounded() ? String(Int(liters)) : String(format: "%.1f", liters)
    }
}

#Preview {
    let container = try! TropiFishSchema.makeContainer(inMemory: true)
    let tank = Tank(name: "Living Room 240", volumeLiters: 240, tankType: .cichlid)
    container.mainContext.insert(tank)
    tank.readings.append(TestReading(ammoniaTAN: 0.5, nitrite: 0, nitrate: 30, kh: 12, gh: 16, ph: 8.2, temperatureC: 26, tank: tank))
    return NavigationStack { TankDetailView(tank: tank) }
        .modelContainer(container)
}
