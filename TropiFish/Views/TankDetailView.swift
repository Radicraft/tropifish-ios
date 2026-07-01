import SwiftUI
import SwiftData

/// The tank hub (brief §4.5, §12): traffic-light status at a glance, the most
/// urgent guidance, quick actions to log a test or water change, the full
/// per-parameter breakdown, and links into history and trend charts.
struct TankDetailView: View {
    @Bindable var tank: Tank

    @State private var isLoggingTest = false
    @State private var isLoggingWaterChange = false
    @State private var isEditingTank = false
    #if DEBUG
    @State private var debugShowCharts = ProcessInfo.processInfo.arguments.contains("-openCharts")
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
        #if DEBUG
        .navigationDestination(isPresented: $debugShowCharts) {
            ParameterChartsView(tank: tank)
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
