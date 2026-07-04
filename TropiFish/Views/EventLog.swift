import SwiftUI

/// Sheet for adding a history entry to a stocked inhabitant or plant. Kind-driven:
/// "Added" / "Removed" reveal a count stepper and adjust the population; "Health
/// note" and (plants only) "Trimmed" are pure journal entries. The parent owns
/// persistence — this view just gathers input and hands back the result.
struct AddEventView: View {
    /// Show the plant-only "Trimmed" kind.
    var allowTrim: Bool
    /// `(kind, date, signed quantity delta, note)` — the parent builds the
    /// `StockEvent`, attaches it to the right owner, and applies the delta.
    let onSave: (EventKind, Date, Int, String?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var kind: EventKind = .note
    @State private var date: Date = Date()
    @State private var count: Int = 1
    @State private var note: String = ""

    private var kinds: [EventKind] {
        allowTrim ? [.added, .removed, .trimmed, .note] : [.added, .removed, .note]
    }

    private var signedDelta: Int {
        switch kind {
        case .added:   return count
        case .removed: return -count
        default:       return 0
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Entry", selection: $kind) {
                        ForEach(kinds) { k in
                            Label(k.displayName, systemImage: k.systemImage).tag(k)
                        }
                    }
                }

                if kind.affectsQuantity {
                    Section {
                        Stepper(value: $count, in: 1...999) {
                            HStack {
                                Text(kind == .added ? "Number added" : "Number removed")
                                Spacer()
                                Text("\(count)").foregroundStyle(.secondary).monospacedDigit()
                            }
                        }
                    }
                }

                Section {
                    DatePicker("When", selection: $date, in: ...Date(), displayedComponents: .date)
                }

                Section("Note") {
                    TextField(notePrompt, text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .navigationTitle("Log Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(kind, date, signedDelta, trimmed.isEmpty ? nil : trimmed)
                        Haptics.success()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var notePrompt: String {
        switch kind {
        case .added:   return "e.g. added from the LFS, quarantined first"
        case .removed: return "e.g. rehomed, or lost to a jump"
        case .trimmed: return "e.g. topped and replanted the cuttings"
        case .note:    return "e.g. colouring up nicely / spotted fin rot"
        }
    }
}

/// One row in an inhabitant's or plant's history log.
struct EventRow: View {
    let event: StockEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.kind.systemImage)
                .foregroundStyle(tint)
                .font(.subheadline)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(event.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let note = event.note, !note.isEmpty {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var title: String {
        switch event.kind {
        case .added:   return "Added \(abs(event.quantityDelta))"
        case .removed: return "Removed \(abs(event.quantityDelta))"
        case .trimmed: return "Trimmed"
        case .note:    return "Health note"
        }
    }

    private var tint: Color {
        switch event.kind {
        case .added:   return TrafficLight.green.color
        case .removed: return TrafficLight.red.color
        case .trimmed: return .teal
        case .note:    return .blue
        }
    }
}
