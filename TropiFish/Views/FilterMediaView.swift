import SwiftUI
import SwiftData

/// Per-tank filter-media maintenance list (filter-maintenance feature). Shows
/// each piece of media against its replacement schedule with a traffic-light
/// status, a one-tap "Mark Changed", and add/edit/delete — mirroring the
/// List/Section idiom used across the app (e.g. `TestHistoryView`).
struct FilterMediaView: View {
    @Bindable var tank: Tank
    @Environment(\.modelContext) private var modelContext

    @State private var isAdding = false
    @State private var editing: FilterMediaItem?

    /// Soonest-due first, so the most urgent media is at the top.
    private var sortedMedia: [FilterMediaItem] {
        tank.filterMedia.sorted { $0.dueDate < $1.dueDate }
    }

    var body: some View {
        Group {
            if tank.filterMedia.isEmpty {
                emptyState
            } else {
                List {
                    Section {
                        ForEach(sortedMedia) { item in
                            Button {
                                editing = item
                            } label: {
                                FilterMediaRow(item: item)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    markChanged(item)
                                } label: {
                                    Label("Mark Changed", systemImage: "checkmark.circle.fill")
                                }
                                .tint(TrafficLight.green.color)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    delete(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    } footer: {
                        Text("Swipe a media right to mark it changed, left to delete. Never replace all your biological media at once — it holds the bacteria that keep the tank cycled.")
                    }
                }
            }
        }
        .navigationTitle("Filter Media")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        isAdding = true
                    } label: {
                        Label("Add Media", systemImage: "plus")
                    }
                    Button {
                        addStandardSet()
                    } label: {
                        Label("Add Standard Media Set", systemImage: "square.stack.3d.up.fill")
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isAdding) {
            AddFilterMediaView(tank: tank)
        }
        .sheet(item: $editing) { item in
            AddFilterMediaView(tank: tank, existing: item)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Filter Media Tracked", systemImage: "square.stack.3d.up")
        } description: {
            Text("Track your filter's foam, carbon and bio media to get a reminder when each is due for a change.")
        } actions: {
            Button("Add Standard Media Set") { addStandardSet() }
                .buttonStyle(.borderedProminent)
            Button("Add Media Manually") { isAdding = true }
        }
    }

    // MARK: - Actions

    private func markChanged(_ item: FilterMediaItem) {
        item.lastChanged = Date()
        Haptics.success()
        ReminderScheduler.rescheduleFilterReminder(for: tank, requestingPermission: true)
    }

    private func delete(_ item: FilterMediaItem) {
        Haptics.impact(.rigid)
        modelContext.delete(item)
        ReminderScheduler.rescheduleFilterReminder(for: tank)
    }

    /// One-tap add of a standard canister-filter media stack, skipping any kinds
    /// already tracked so it's safe to tap twice.
    private func addStandardSet() {
        let existingKinds = Set(tank.filterMedia.map(\.kind))
        for kind in FilterMediaKind.standardSet where !existingKinds.contains(kind) {
            let item = FilterMediaItem(kind: kind, tank: tank)
            modelContext.insert(item)
        }
        Haptics.success()
        ReminderScheduler.rescheduleFilterReminder(for: tank, requestingPermission: true)
    }
}

/// One media row: status dot, name, guidance, and the "next due" readout.
private struct FilterMediaRow: View {
    let item: FilterMediaItem

    var body: some View {
        let status = item.status()
        HStack(spacing: 12) {
            Image(systemName: item.kind.systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(dueText(status: status))
                    .font(.caption)
                    .foregroundStyle(status == .ok ? .secondary : status.trafficLight.color)
            }

            Spacer()

            statusPill(status)
        }
        .padding(.vertical, 2)
    }

    private func statusPill(_ status: FilterMediaStatus) -> some View {
        Text(status.label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(status.trafficLight.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.trafficLight.color.opacity(0.14), in: Capsule())
    }

    private func dueText(status: FilterMediaStatus) -> String {
        let days = item.daysUntilDue()
        let due = item.dueDate.formatted(date: .abbreviated, time: .omitted)
        switch status {
        case .overdue:
            let overdueBy = -days
            return overdueBy == 0 ? "Due today" : "Overdue by \(overdueBy) day\(overdueBy == 1 ? "" : "s")"
        case .dueSoon:
            return days == 0 ? "Due today" : "Due in \(days) day\(days == 1 ? "" : "s") · \(due)"
        case .ok:
            return "Next change \(due)"
        }
    }
}

#Preview {
    let container = try! TropiFishSchema.makeContainer(inMemory: true)
    let tank = Tank(name: "Living Room 240", volumeLiters: 240, tankType: .cichlid)
    container.mainContext.insert(tank)
    let cal = Calendar.current
    tank.filterMedia.append(FilterMediaItem(kind: .carbon,
        lastChanged: cal.date(byAdding: .day, value: -40, to: Date())!, tank: tank))
    tank.filterMedia.append(FilterMediaItem(kind: .mechanicalFoam, tank: tank))
    tank.filterMedia.append(FilterMediaItem(kind: .bioMax,
        lastChanged: cal.date(byAdding: .day, value: -177, to: Date())!, tank: tank))
    return NavigationStack { FilterMediaView(tank: tank) }
        .modelContainer(container)
}
