import SwiftUI
import SwiftData

/// Add or edit a single piece of filter media (filter-maintenance feature).
/// Follows the same Form + Cancel/Save sheet pattern as `LogWaterChangeView`.
/// The replacement interval is pre-filled from the media kind's default but
/// stays editable, mirroring how tank targets seed from the type preset.
struct AddFilterMediaView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let tank: Tank
    var existing: FilterMediaItem?

    @State private var kind: FilterMediaKind = .carbon
    @State private var customName = ""
    @State private var lastChanged = Date()
    @State private var intervalDays = FilterMediaKind.carbon.defaultIntervalDays
    @State private var note = ""
    /// Tracks whether the user has hand-edited the interval, so changing the
    /// kind can safely refresh the default without clobbering a manual value.
    @State private var intervalEdited = false

    private var isCustom: Bool { kind == .other }

    private var canSave: Bool {
        intervalDays > 0 && (!isCustom || !customName.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(FilterMediaKind.allCases) { k in
                            Text(k.displayName).tag(k)
                        }
                    }
                    if isCustom {
                        TextField("Name (e.g. Purigen)", text: $customName)
                    }
                } header: {
                    Text("Media")
                } footer: {
                    Text(kind.guidance)
                }

                Section("Schedule") {
                    DatePicker("Last changed", selection: $lastChanged,
                               in: ...Date(), displayedComponents: .date)
                    Stepper(value: $intervalDays, in: 1...730) {
                        LabeledContent("Replace every") {
                            Text("\(intervalDays) day\(intervalDays == 1 ? "" : "s")")
                        }
                    }
                    .onChange(of: intervalDays) { _, _ in intervalEdited = true }
                    LabeledContent("Next change due", value: dueDatePreview)
                }

                Section("Note") {
                    TextField("Optional note", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                }
            }
            .navigationTitle(existing == nil ? "Add Filter Media" : "Edit Filter Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
            .onChange(of: kind) { _, newKind in
                // Adopt the new kind's default cadence unless the user set their own.
                if !intervalEdited { intervalDays = newKind.defaultIntervalDays }
            }
            .onAppear(perform: loadExisting)
        }
    }

    private var dueDatePreview: String {
        let due = Calendar.current.date(byAdding: .day, value: intervalDays, to: lastChanged) ?? lastChanged
        return due.formatted(date: .abbreviated, time: .omitted)
    }

    private func loadExisting() {
        guard let existing else { return }
        kind = existing.kind
        customName = existing.customName ?? ""
        lastChanged = existing.lastChanged
        intervalDays = existing.intervalDays
        note = existing.note ?? ""
        intervalEdited = true   // don't overwrite a saved interval when the picker changes
    }

    private func save() {
        let trimmedName = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing {
            existing.kind = kind
            existing.customName = isCustom && !trimmedName.isEmpty ? trimmedName : nil
            existing.lastChanged = lastChanged
            existing.intervalDays = intervalDays
            existing.note = trimmedNote.isEmpty ? nil : trimmedNote
        } else {
            let item = FilterMediaItem(
                kind: kind,
                customName: isCustom && !trimmedName.isEmpty ? trimmedName : nil,
                lastChanged: lastChanged,
                intervalDays: intervalDays,
                note: trimmedNote.isEmpty ? nil : trimmedNote,
                tank: tank
            )
            modelContext.insert(item)
        }
        ReminderScheduler.rescheduleFilterReminder(for: tank, requestingPermission: true)
        dismiss()
    }
}

#Preview {
    let container = try! TropiFishSchema.makeContainer(inMemory: true)
    let tank = Tank(name: "Demo", volumeLiters: 120)
    container.mainContext.insert(tank)
    return AddFilterMediaView(tank: tank)
        .modelContainer(container)
}
