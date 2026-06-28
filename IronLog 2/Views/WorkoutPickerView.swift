import SwiftUI
import SwiftData

struct WorkoutPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(
        filter: #Predicate<WorkoutTemplate> { !$0.isArchived },
        sort: \WorkoutTemplate.createdAt,
        order: .reverse
    )
    private var allTemplates: [WorkoutTemplate]

    var onStartWorkout: (Session) -> Void

    private var recentTemplates: [WorkoutTemplate] {
        Array(allTemplates.prefix(5))
    }

    private var hasMore: Bool {
        allTemplates.count > 5
    }

    @State private var showAllTemplates = false

    var body: some View {
        NavigationStack {
            List {
                if !recentTemplates.isEmpty {
                    Section("Recent Templates") {
                        ForEach(recentTemplates) { template in
                            Button {
                                startFromTemplate(template)
                            } label: {
                                templateRow(template)
                            }
                            .tint(.primary)
                        }

                        if hasMore {
                            Button {
                                showAllTemplates = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "list.bullet")
                                        .font(.subheadline)
                                        .foregroundStyle(.orange)
                                    Text("See more")
                                        .font(.subheadline)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        startCustomWorkout()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                            Text("Custom Workout")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Start Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $showAllTemplates) {
                AllTemplatesView { session in
                    onStartWorkout(session)
                    dismiss()
                }
            }
        }
    }

    // MARK: - Template Row

    private func templateRow(_ template: WorkoutTemplate) -> some View {
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

    // MARK: - Actions

    private func startFromTemplate(_ template: WorkoutTemplate) {
        let session = createSession(from: template, in: modelContext)
        onStartWorkout(session)
        dismiss()
    }

    private func startCustomWorkout() {
        let session = Session()
        modelContext.insert(session)
        onStartWorkout(session)
        dismiss()
    }
}

// MARK: - Hydration Helper

func createSession(from template: WorkoutTemplate, in modelContext: ModelContext) -> Session {
    let session = Session(name: template.name)
    session.tags = template.tags
    modelContext.insert(session)

    for templateExercise in template.sortedExercises {
        let exercise = Exercise(name: templateExercise.name, sortOrder: templateExercise.sortOrder)
        session.exercises.append(exercise)

        for templateSet in templateExercise.sortedSets {
            let exerciseSet = ExerciseSet(
                weight: templateSet.weight,
                repCount: templateSet.repCount,
                sortOrder: templateSet.sortOrder
            )
            exercise.sets.append(exerciseSet)
        }
    }

    return session
}

#Preview {
    WorkoutPickerView { _ in }
        .modelContainer(for: [Session.self, WorkoutTemplate.self], inMemory: true)
}
