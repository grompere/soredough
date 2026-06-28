import SwiftUI
import SwiftData

struct AllTemplatesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(
        filter: #Predicate<WorkoutTemplate> { !$0.isArchived },
        sort: \WorkoutTemplate.createdAt,
        order: .reverse
    )
    private var templates: [WorkoutTemplate]

    var onStartWorkout: (Session) -> Void

    var body: some View {
        Group {
            if templates.isEmpty {
                ContentUnavailableView {
                    Label("No Templates", systemImage: "oven")
                } description: {
                    Text("Create templates from Settings → Pre-baked workouts.")
                }
            } else {
                List {
                    ForEach(templates) { template in
                        Button {
                            startFromTemplate(template)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                Text("\(template.exercises.count) exercise\(template.exercises.count == 1 ? "" : "s")")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(.primary)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("All Templates")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Actions

    private func startFromTemplate(_ template: WorkoutTemplate) {
        let session = createSession(from: template, in: modelContext)
        onStartWorkout(session)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        AllTemplatesView { _ in }
    }
    .modelContainer(for: [Session.self, WorkoutTemplate.self], inMemory: true)
}
