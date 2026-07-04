import SwiftUI
import SwiftData

/// Log a water-change event, kept distinct from a test (brief §4.6) so change
/// frequency can be plotted against the nitrate trend and drive the reminder
/// cadence. Also reschedules the next reminder from "now".
struct LogWaterChangeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let tank: Tank
    var existing: WaterChangeEvent?

    @State private var timestamp = Date()
    @State private var percentText = ""
    @State private var note = ""

    private var percent: Double? { Double(percentText.replacingOccurrences(of: ",", with: ".")) }

    /// Litres implied by the percentage, shown as a helpful readout.
    private var impliedLiters: Double? {
        percent.map { tank.volumeLiters * $0 / 100 }
    }

    private var impliedLitersText: String? {
        guard let impliedLiters else { return nil }
        let changed = impliedLiters.formatted(.number.precision(.fractionLength(0...1)))
        let total = tank.volumeLiters.formatted(.number.precision(.fractionLength(0...0)))
        return "≈ \(changed) L of \(total) L"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date & time", selection: $timestamp, in: ...Date())
                    LabeledContent("Amount changed") {
                        HStack(spacing: 4) {
                            TextField("%", text: $percentText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 80)
                            Text("%")
                        }
                    }
                } footer: {
                    if let impliedLitersText {
                        Text(impliedLitersText)
                    }
                }

                Section("Note") {
                    TextField("e.g. gravel vac, added dechlorinator", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                }
            }
            .navigationTitle(existing == nil ? "Log Water Change" : "Edit Water Change")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
            .onAppear(perform: loadExisting)
        }
    }

    private func loadExisting() {
        guard let existing else { return }
        timestamp = existing.timestamp
        percentText = existing.percentChanged.map { $0 == $0.rounded() ? String(Int($0)) : String($0) } ?? ""
        note = existing.note ?? ""
    }

    private func save() {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing {
            existing.timestamp = timestamp
            existing.percentChanged = percent
            existing.note = trimmedNote.isEmpty ? nil : trimmedNote
        } else {
            let event = WaterChangeEvent(
                timestamp: timestamp,
                percentChanged: percent,
                volumeLiters: impliedLiters,
                note: trimmedNote.isEmpty ? nil : trimmedNote,
                tank: tank
            )
            modelContext.insert(event)
        }
        // A fresh change resets the reminder clock (§4.6).
        Haptics.success()
        ReminderScheduler.reschedule(for: tank)
        dismiss()
    }
}

#Preview {
    let container = try! TropiFishSchema.makeContainer(inMemory: true)
    let tank = Tank(name: "Demo", volumeLiters: 120)
    container.mainContext.insert(tank)
    return LogWaterChangeView(tank: tank)
        .modelContainer(container)
}
