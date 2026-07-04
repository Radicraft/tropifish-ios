import SwiftUI
import SwiftData

/// Fast test-entry screen (brief §4.2, build-order step 3 — the
/// highest-frequency screen). All seven parameters logged in one session; the
/// ammonia/pH/temperature trio is grouped because the NH₃ toxicity calculation
/// is only meaningful when all three come from the same test (§6.2). Doubles as
/// the edit screen for an existing reading (build-order step 4).
struct LogTestView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let tank: Tank
    /// When non-nil, we're editing this reading rather than creating a new one.
    var existing: TestReading?

    @State private var timestamp = Date()
    @State private var ammoniaTAN: Double?
    @State private var ph: Double?
    @State private var temperatureText = ""
    @State private var nitrite: Double?
    @State private var nitrate: Double?
    @State private var khText = ""
    @State private var ghText = ""
    @State private var note = ""

    private var temperatureC: Double? { Double(temperatureText.replacingOccurrences(of: ",", with: ".")) }
    private var kh: Double? { Double(khText.replacingOccurrences(of: ",", with: ".")) }
    private var gh: Double? { Double(ghText.replacingOccurrences(of: ",", with: ".")) }

    /// Live NH₃-N preview once the whole bundle is present (§6.2) — the payoff
    /// that makes logging pH+temp alongside ammonia feel worthwhile.
    private var calculatedAmmonia: Double? {
        guard let ammoniaTAN, let ph, let temperatureC else { return nil }
        return AmmoniaToxicity.unIonizedAmmonia(totalAmmoniaTAN: ammoniaTAN, ph: ph, temperatureC: temperatureC)
    }

    private var ammoniaRisk: RiskLevel? {
        calculatedAmmonia.map {
            AmmoniaToxicity.riskLevel(unIonizedAmmonia: $0, thresholds: tank.targets.ammoniaThresholds)
        }
    }

    /// At least one parameter must be filled in to save something meaningful.
    private var hasAnyValue: Bool {
        ammoniaTAN != nil || ph != nil || temperatureC != nil
            || nitrite != nil || nitrate != nil || kh != nil || gh != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date & time", selection: $timestamp, in: ...Date())
                }

                Section {
                    KitValuePicker(label: "Ammonia (TAN)", values: TestKitScale.ammonia,
                                   unit: "ppm", selection: $ammoniaTAN)
                    KitValuePicker(label: "pH", values: TestKitScale.ph,
                                   unit: "", selection: $ph, fractionDigits: 1)
                    LabeledContent("Temperature") {
                        DecimalEntryField(text: $temperatureText, placeholder: "°C")
                    }
                    if let calculatedAmmonia, let ammoniaRisk {
                        LabeledContent("Toxic NH₃-N") {
                            HStack(spacing: 6) {
                                Circle().fill(ammoniaRisk.color).frame(width: 9, height: 9)
                                Text(WaterParameter.ammonia.formatted(calculatedAmmonia))
                                    .monospacedDigit()
                                    .foregroundStyle(ammoniaRisk.color)
                            }
                        }
                    }
                } header: {
                    Text("Ammonia bundle")
                } footer: {
                    Text("Ammonia toxicity depends on pH and temperature, so log all three together — the app shows the calculated toxic NH₃-N, not just the raw kit reading.")
                }

                Section("Other parameters") {
                    KitValuePicker(label: "Nitrite", values: TestKitScale.nitrite,
                                   unit: "ppm", selection: $nitrite)
                    KitValuePicker(label: "Nitrate", values: TestKitScale.nitrate,
                                   unit: "ppm", selection: $nitrate)
                    LabeledContent("KH") {
                        DecimalEntryField(text: $khText, placeholder: "dKH")
                    }
                    LabeledContent("GH") {
                        DecimalEntryField(text: $ghText, placeholder: "dGH")
                    }
                }

                Section("Note") {
                    TextField("e.g. added Prime, did 20% change", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                }
            }
            .navigationTitle(existing == nil ? "Log Test" : "Edit Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!hasAnyValue)
                }
            }
            .onAppear(perform: loadExisting)
        }
    }

    private func loadExisting() {
        guard let existing else { return }
        timestamp = existing.timestamp
        ammoniaTAN = existing.ammoniaTAN
        ph = existing.ph
        temperatureText = existing.temperatureC.map { format($0) } ?? ""
        nitrite = existing.nitrite
        nitrate = existing.nitrate
        khText = existing.kh.map { format($0) } ?? ""
        ghText = existing.gh.map { format($0) } ?? ""
        note = existing.note ?? ""
    }

    private func save() {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing {
            existing.timestamp = timestamp
            existing.ammoniaTAN = ammoniaTAN
            existing.ph = ph
            existing.temperatureC = temperatureC
            existing.nitrite = nitrite
            existing.nitrate = nitrate
            existing.kh = kh
            existing.gh = gh
            existing.note = trimmedNote.isEmpty ? nil : trimmedNote
        } else {
            let reading = TestReading(
                timestamp: timestamp,
                ammoniaTAN: ammoniaTAN, nitrite: nitrite, nitrate: nitrate,
                kh: kh, gh: gh, ph: ph, temperatureC: temperatureC,
                note: trimmedNote.isEmpty ? nil : trimmedNote,
                tank: tank
            )
            modelContext.insert(reading)
        }
        Haptics.success()
        dismiss()
    }

    private func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

/// A quick picker over a test kit's discrete colour-chart increments, plus a
/// "not measured" option so a skipped parameter stays `nil` rather than 0.
private struct KitValuePicker: View {
    let label: String
    let values: [Double]
    let unit: String
    @Binding var selection: Double?
    var fractionDigits: Int = 2

    var body: some View {
        Picker(label, selection: $selection) {
            Text("—").tag(Double?.none)
            ForEach(values, id: \.self) { value in
                Text(display(value)).tag(Double?.some(value))
            }
        }
    }

    private func display(_ value: Double) -> String {
        let number = value.formatted(.number.precision(.fractionLength(0...fractionDigits)))
        return unit.isEmpty ? number : "\(number) \(unit)"
    }
}

/// Decimal text field right-aligned for numeric entry (temperature, KH, GH).
private struct DecimalEntryField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
    }
}

#Preview {
    let container = try! TropiFishSchema.makeContainer(inMemory: true)
    let tank = Tank(name: "Demo", volumeLiters: 120, tankType: .community)
    container.mainContext.insert(tank)
    return LogTestView(tank: tank)
        .modelContainer(container)
}
