import SwiftUI
import SwiftData

/// Tank creation form (brief §4.1, build-order step 2). Collects the handful of
/// setup facts the model needs; the per-parameter safe ranges are seeded
/// automatically from the chosen `TankType` preset (§3) and stay editable later.
struct AddTankView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var tankType: TankType = .community
    @State private var volumeText = ""
    @State private var volumeUnit: VolumeUnit = .liters
    @State private var dateEstablished = Date()
    @State private var isCycling = false
    @State private var remindersOn = true
    @State private var reminderInterval = 7

    /// Parsed volume in the currently-selected display unit, if valid and > 0.
    private var enteredVolume: Double? {
        guard let v = Double(volumeText.replacingOccurrences(of: ",", with: ".")),
              v > 0 else { return nil }
        return v
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && enteredVolume != nil
    }

    /// Preview of the ranges this preset will seed, so the choice feels concrete.
    private var seededTargets: ParameterTargets { tankType.defaultTargets }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tank") {
                    TextField("Name", text: $name)

                    Picker("Type", selection: $tankType) {
                        ForEach(TankType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    HStack {
                        TextField("Volume", text: $volumeText)
                            .keyboardType(.decimalPad)
                        Picker("Unit", selection: $volumeUnit) {
                            ForEach(VolumeUnit.allCases) { unit in
                                Text(unit.label).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }

                    DatePicker(
                        "Date established",
                        selection: $dateEstablished,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                }

                Section {
                    Toggle("Tank is still cycling", isOn: $isCycling)
                } footer: {
                    Text("While cycling, ammonia guidance stays informational rather than alarming — a new tank shows ammonia most days as it establishes.")
                }

                Section {
                    Toggle("Water-change reminder", isOn: $remindersOn)
                    if remindersOn {
                        Stepper("Every \(reminderInterval) days", value: $reminderInterval, in: 1...60)
                    }
                } footer: {
                    Text("A weekly change suits most stocked tanks; lightly-stocked or heavily-planted tanks are often fine at 10–14 days. You can change this any time.")
                }

                Section("Default safe ranges (\(tankType.displayName))") {
                    LabeledContent("pH", value: "\(fmt(seededTargets.phMin))–\(fmt(seededTargets.phMax))")
                    LabeledContent("Temperature", value: "\(fmt(seededTargets.temperatureMin))–\(fmt(seededTargets.temperatureMax)) °C")
                    LabeledContent("Nitrate", value: "≤ \(fmt(seededTargets.nitrateMax)) ppm")
                    LabeledContent("KH", value: "\(fmt(seededTargets.khMin))–\(fmt(seededTargets.khMax)) dKH")
                    LabeledContent("GH", value: "\(fmt(seededTargets.ghMin))–\(fmt(seededTargets.ghMax)) dGH")
                }
            }
            .navigationTitle("New Tank")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        guard let volume = enteredVolume else { return }
        let tank = Tank(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            volumeLiters: volumeUnit.toLiters(volume),
            dateEstablished: dateEstablished,
            tankType: tankType,
            isCycling: isCycling,
            reminderIntervalDays: remindersOn ? reminderInterval : nil
        )
        modelContext.insert(tank)
        Haptics.success()
        ReminderScheduler.reschedule(for: tank, requestingPermission: true)
        dismiss()
    }

    /// Trim a trailing ".0" so whole numbers read cleanly in the range preview.
    private func fmt(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

/// Display-only volume unit. The model stores canonical litres (see
/// tropifish-key-decisions); conversion lives here at the UI edge.
enum VolumeUnit: String, CaseIterable, Identifiable {
    case liters
    case usGallons

    var id: String { rawValue }

    var label: String {
        switch self {
        case .liters:    return "L"
        case .usGallons: return "US gal"
        }
    }

    private static let litersPerUSGallon = 3.785411784

    func toLiters(_ value: Double) -> Double {
        switch self {
        case .liters:    return value
        case .usGallons: return value * Self.litersPerUSGallon
        }
    }
}

#Preview {
    AddTankView()
        .modelContainer(try! TropiFishSchema.makeContainer(inMemory: true))
}
