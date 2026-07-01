import SwiftUI
import SwiftData

/// Edit a tank's setup, reminder cadence, tap-water baseline, and per-parameter
/// safe ranges (brief §3 "let the user override per tank", §4.6 reminders, §6.4
/// tap-water baseline). Also the home for the one-time tap-water nitrate step.
struct EditTankView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var tank: Tank

    // Editable working copies; committed on Save.
    @State private var name = ""
    @State private var tankType: TankType = .community
    @State private var volumeText = ""
    @State private var dateEstablished = Date()
    @State private var isCycling = false

    @State private var remindersOn = true
    @State private var reminderInterval = 7

    @State private var tapNitrateText = ""

    @State private var targets = ParameterTargets(
        nitrateMax: 40, khMin: 3, khMax: 8, ghMin: 4, ghMax: 12,
        phMin: 6.5, phMax: 7.5, temperatureMin: 24, temperatureMax: 28,
        ammoniaSensitivity: .standard, phStabilityDelta: 0.4, temperatureStabilityDelta: 2.0
    )

    private var volume: Double? { Double(volumeText.replacingOccurrences(of: ",", with: ".")) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tank") {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $tankType) {
                        ForEach(TankType.allCases) { Text($0.displayName).tag($0) }
                    }
                    LabeledContent("Volume (L)") {
                        TextField("L", text: $volumeText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    DatePicker("Date established", selection: $dateEstablished,
                               in: ...Date(), displayedComponents: .date)
                    Toggle("Tank is still cycling", isOn: $isCycling)
                }

                Section("Water-change reminder") {
                    Toggle("Remind me", isOn: $remindersOn)
                    if remindersOn {
                        Stepper("Every \(reminderInterval) days",
                                value: $reminderInterval, in: 1...60)
                    }
                }

                Section {
                    LabeledContent("Nitrate baseline") {
                        TextField("ppm", text: $tapNitrateText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Tap / source water")
                } footer: {
                    Text("Test your tap water for nitrate once. If your tank is close to this baseline, a water change won't lower nitrate much — the app will say so instead of repeating advice that won't work.")
                }

                Section {
                    Picker("Ammonia sensitivity", selection: $targets.ammoniaSensitivity) {
                        Text("Standard").tag(AmmoniaSensitivity.standard)
                        Text("Sensitive").tag(AmmoniaSensitivity.sensitive)
                    }
                    rangeRow("Nitrate max", value: $targets.nitrateMax, step: 5, range: 5...200)
                } header: {
                    Text("Safe ranges")
                } footer: {
                    Text("Seeded from the \(tankType.displayName) preset. Ammonia uses calculated NH₃-N risk tiers; nitrite is always zero-tolerance, so neither has a min/max here.")
                }

                Section("KH / GH (dKH / dGH)") {
                    minMaxRow("KH", min: $targets.khMin, max: $targets.khMax, step: 1, range: 0...25)
                    minMaxRow("GH", min: $targets.ghMin, max: $targets.ghMax, step: 1, range: 0...30)
                }

                Section("pH & temperature") {
                    minMaxRow("pH", min: $targets.phMin, max: $targets.phMax, step: 0.1, range: 5.0...9.0)
                    minMaxRow("Temp °C", min: $targets.temperatureMin, max: $targets.temperatureMax, step: 0.5, range: 15...34)
                    rangeRow("pH stability ±", value: $targets.phStabilityDelta, step: 0.1, range: 0.1...1.0)
                    rangeRow("Temp stability ±", value: $targets.temperatureStabilityDelta, step: 0.5, range: 0.5...5.0)
                }

                Section {
                    Button("Reset ranges to \(tankType.displayName) defaults") {
                        targets = tankType.defaultTargets
                    }
                }
            }
            .navigationTitle("Edit Tank")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || volume == nil)
                }
            }
            .onAppear(perform: load)
        }
    }

    // Single-value stepper row.
    private func rangeRow(_ label: String, value: Binding<Double>, step: Double, range: ClosedRange<Double>) -> some View {
        Stepper(value: value, in: range, step: step) {
            LabeledContent(label, value: value.wrappedValue.formatted(.number.precision(.fractionLength(0...1))))
        }
    }

    // Paired min/max steppers on one row.
    private func minMaxRow(_ label: String, min: Binding<Double>, max: Binding<Double>, step: Double, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline.weight(.medium))
            Stepper(value: min, in: range.lowerBound...max.wrappedValue, step: step) {
                LabeledContent("Min", value: min.wrappedValue.formatted(.number.precision(.fractionLength(0...1))))
            }
            Stepper(value: max, in: min.wrappedValue...range.upperBound, step: step) {
                LabeledContent("Max", value: max.wrappedValue.formatted(.number.precision(.fractionLength(0...1))))
            }
        }
        .padding(.vertical, 2)
    }

    private func load() {
        name = tank.name
        tankType = tank.tankType
        volumeText = tank.volumeLiters == tank.volumeLiters.rounded()
            ? String(Int(tank.volumeLiters)) : String(tank.volumeLiters)
        dateEstablished = tank.dateEstablished
        isCycling = tank.isCycling
        remindersOn = tank.reminderIntervalDays != nil
        reminderInterval = tank.reminderIntervalDays ?? 7
        tapNitrateText = tank.tapWaterNitrate.map {
            $0 == $0.rounded() ? String(Int($0)) : String($0)
        } ?? ""
        targets = tank.targets
    }

    private func save() {
        tank.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        tank.tankType = tankType
        if let volume { tank.volumeLiters = volume }
        tank.dateEstablished = dateEstablished
        tank.isCycling = isCycling
        tank.reminderIntervalDays = remindersOn ? reminderInterval : nil
        tank.tapWaterNitrate = Double(tapNitrateText.replacingOccurrences(of: ",", with: "."))
        tank.targets = targets
        ReminderScheduler.reschedule(for: tank, requestingPermission: remindersOn)
        dismiss()
    }
}

#Preview {
    let container = try! TropiFishSchema.makeContainer(inMemory: true)
    let tank = Tank(name: "Demo", volumeLiters: 120, tankType: .planted)
    container.mainContext.insert(tank)
    return EditTankView(tank: tank)
        .modelContainer(container)
}
