import SwiftUI
import SwiftData

struct TemplateEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var template: WorkoutTemplate
    let isNew: Bool
    @State private var showTagEditor = false
    @FocusState private var focusedExerciseId: UUID?

    // Historical exercise data for suggestions
    @Query(filter: #Predicate<Session> { $0.completedAt != nil })
    private var completedSessions: [Session]

    /// All unique exercise names sorted by completion frequency (descending).
    private var exerciseNamesByFrequency: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        var displayNames: [String: String] = [:]

        for session in completedSessions {
            for exercise in session.exercises {
                let key = exercise.name.lowercased().trimmingCharacters(in: .whitespaces)
                guard !key.isEmpty else { continue }
                counts[key, default: 0] += 1
                displayNames[key] = exercise.name
            }
        }

        return counts.map { (name: displayNames[$0.key]!, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    /// Returns up to 5 suggestion names for a given query, sorted by frequency.
    private func suggestions(for query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()

        // If query is empty or the default name, show top exercises
        let isDefault = trimmed.isEmpty || trimmed == "new exercise"

        return exerciseNamesByFrequency
            .filter { entry in
                if isDefault { return true }
                return entry.name.lowercased().contains(trimmed)
                    && entry.name.lowercased().trimmingCharacters(in: .whitespaces) != trimmed
            }
            .prefix(5)
            .map(\.name)
    }

    var body: some View {
        Form {
            ForEach(template.sortedExercises) { exercise in
                exerciseSection(exercise)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TextField("Workout Name", text: $template.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
            }
            if isNew {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showTagEditor = true } label: {
                    Image(systemName: "tag.fill")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
                .fontWeight(.semibold)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomButtons
        }
        .interactiveDismissDisabled(isNew)
        .sheet(isPresented: $showTagEditor) {
            TagEditorView(tags: $template.tags)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Exercise Section

    @ViewBuilder
    private func exerciseSection(_ exercise: TemplateExercise) -> some View {
        Section {
            ForEach(exercise.sortedSets) { templateSet in
                TemplateSetRowView(
                    templateSet: templateSet,
                    setNumber: (exercise.sortedSets.firstIndex(where: { $0.id == templateSet.id }) ?? 0) + 1
                )
            }
            .onDelete { offsets in
                deleteSets(from: exercise, at: offsets)
            }

            Button {
                withAnimation(.spring(response: 0.3)) {
                    addSet(to: exercise)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.caption2.weight(.bold))
                    Text("Add Set")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.secondary)
            }
        } header: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    TextField("Exercise Name", text: Bindable(exercise).name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .textCase(nil)
                        .foregroundStyle(.primary)
                        .focused($focusedExerciseId, equals: exercise.id)
                    Spacer()
                    Button(role: .destructive) {
                        withAnimation(.easeOut(duration: 0.25)) {
                            deleteExercise(exercise)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }

                // Suggestion chips
                if focusedExerciseId == exercise.id {
                    let matches = suggestions(for: exercise.name)
                    if !matches.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(matches, id: \.self) { name in
                                    Button {
                                        withAnimation(.easeOut(duration: 0.15)) {
                                            exercise.name = name
                                            focusedExerciseId = nil
                                        }
                                    } label: {
                                        Text(name)
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.orange)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(
                                                .orange.opacity(0.12),
                                                in: Capsule()
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .padding(.bottom, 4)
            .animation(.easeInOut(duration: 0.2), value: focusedExerciseId)
        }
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.35)) {
                        addExercise()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.caption.weight(.bold))
                        Text("New Exercise")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        .orange.opacity(0.15),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }

                Button {
                    saveTemplate()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.caption.weight(.bold))
                        Text("Save")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        LinearGradient(
                            colors: [.orange, .orange.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 6)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Actions

    private func addExercise() {
        let exercise = TemplateExercise(sortOrder: template.exercises.count)
        let defaultSet = TemplateSet(sortOrder: 0)
        exercise.sets.append(defaultSet)
        template.exercises.append(exercise)

        // Auto-focus the new exercise's name field
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focusedExerciseId = exercise.id
        }
    }

    private func addSet(to exercise: TemplateExercise) {
        let newSet = TemplateSet(sortOrder: exercise.sets.count)
        exercise.sets.append(newSet)
    }

    private func deleteExercise(_ exercise: TemplateExercise) {
        template.exercises.removeAll { $0.id == exercise.id }
        modelContext.delete(exercise)
    }

    private func deleteSets(from exercise: TemplateExercise, at offsets: IndexSet) {
        let sortedSets = exercise.sortedSets
        for index in offsets {
            let setToDelete = sortedSets[index]
            exercise.sets.removeAll { $0.id == setToDelete.id }
            modelContext.delete(setToDelete)
        }
    }

    private func saveTemplate() {
        if isNew {
            modelContext.insert(template)
        }
        dismiss()
    }
}

#Preview {
    NavigationStack {
        TemplateEditorView(template: WorkoutTemplate(name: "Push Day"), isNew: true)
    }
    .modelContainer(for: [WorkoutTemplate.self, Session.self], inMemory: true)
}

