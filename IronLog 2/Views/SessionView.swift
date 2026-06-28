import SwiftUI
import SwiftData

struct SessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: Session
    @State private var showTagEditor = false

    /// Tracks which exercise the user last interacted with.
    @State private var focusedExerciseID: UUID?
    /// The ID of the most recently added exercise, used for scroll targeting.
    @State private var scrollTargetID: UUID?

    @Query(
        filter: #Predicate<Session> { $0.completedAt != nil },
        sort: \Session.startedAt,
        order: .reverse
    )
    private var completedSessions: [Session]

    /// Find sorted sets from the most recent completed session for a given exercise name.
    private func previousSets(for exerciseName: String) -> [ExerciseSet] {
        let name = exerciseName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return [] }

        for completed in completedSessions {
            guard completed.id != session.id else { continue }
            if let exercise = completed.exercises.first(where: {
                $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
            }) {
                return exercise.sortedSets
            }
        }
        return []
    }

    private func formatWeight(_ w: Double) -> String {
        w == w.rounded() ? String(format: "%.0f", w) : String(w)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 24) {
                    ForEach(session.exercises.sorted { $0.sortOrder < $1.sortOrder }) { exercise in
                        exerciseSection(exercise)
                            .id(exercise.id)
                            .padding(.horizontal)
                            .onTapGesture {
                                focusedExerciseID = exercise.id
                            }
                    }
                }
                .padding(.top, 16)
            }
            .onChange(of: scrollTargetID) { _, newID in
                guard let newID else { return }
                // Small delay lets SwiftUI lay out the new exercise before scrolling
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(newID, anchor: .center)
                    }
                }
                scrollTargetID = nil
            }
        }
        .background(Color(.systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TextField("Session Name", text: $session.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
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
        .sheet(isPresented: $showTagEditor) {
            TagEditorView(tags: $session.tags)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Exercise Section

    @ViewBuilder
    private func exerciseSection(_ exercise: Exercise) -> some View {
        let sortedSets = exercise.sets.sorted { $0.sortOrder < $1.sortOrder }
        let prevSets = previousSets(for: exercise.name)
        
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                TextField("Exercise Name", text: Bindable(exercise).name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .textCase(nil)
                    .foregroundStyle(.primary)
                    .onTapGesture {
                        focusedExerciseID = exercise.id
                    }
                Spacer()

                // Move up/down buttons
                let sorted = session.exercises.sorted { $0.sortOrder < $1.sortOrder }
                let isFirst = sorted.first?.id == exercise.id
                let isLast = sorted.last?.id == exercise.id

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        moveExercise(exercise, direction: .up)
                    }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(isFirst)
                .opacity(isFirst ? 0.3 : 1)

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        moveExercise(exercise, direction: .down)
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(isLast)
                .opacity(isLast ? 0.3 : 1)

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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))

            // Previous workout banner
            if !prevSets.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 9))
                    Text("Last: " + prevSets.map { "\(formatWeight($0.weight))×\($0.repCount)" }.joined(separator: ", "))
                        .font(.caption2)
                }
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
            }
            
            Divider()
                .padding(.leading, 16)
            
            // Set rows
            ForEach(Array(sortedSets.enumerated()), id: \.element.id) { index, exerciseSet in
                VStack(spacing: 0) {
                    HStack {
                        SetRowView(
                            exerciseSet: exerciseSet,
                            setNumber: index + 1,
                            previousWeight: index < prevSets.count ? prevSets[index].weight : nil
                        )
                        
                        // Inline delete button for custom layout
                        Button(role: .destructive) {
                            withAnimation {
                                deleteSet(exerciseSet, from: exercise)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color(.systemGray4))
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemGroupedBackground))
                    .onTapGesture {
                        focusedExerciseID = exercise.id
                    }
                    
                    if index < sortedSets.count - 1 {
                        Divider()
                            .padding(.leading, 48)
                    }
                }
            }
            
            Divider()
                .padding(.leading, 16)

            // Add Set button
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
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemGroupedBackground))
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
                    withAnimation {
                        completeWorkout()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                        Text("Complete Workout")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
                .disabled(session.isCompleted)
                .opacity(session.isCompleted ? 0.5 : 1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 6)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Actions

    private func addExercise() {
        let sortedExercises = session.exercises.sorted { $0.sortOrder < $1.sortOrder }

        // Determine insert position: right after the focused exercise, or at the end
        let insertOrder: Int
        if let focusedID = focusedExerciseID,
           let focusedIndex = sortedExercises.firstIndex(where: { $0.id == focusedID }) {
            insertOrder = sortedExercises[focusedIndex].sortOrder + 1
        } else {
            insertOrder = (sortedExercises.last?.sortOrder ?? -1) + 1
        }

        // Bump sortOrder for all exercises at or after the insert position
        for exercise in sortedExercises where exercise.sortOrder >= insertOrder {
            exercise.sortOrder += 1
        }

        let exercise = Exercise(sortOrder: insertOrder)
        let defaultSet = ExerciseSet(sortOrder: 0)
        exercise.sets.append(defaultSet)
        session.exercises.append(exercise)

        // Update focus and scroll target to the new exercise
        focusedExerciseID = exercise.id
        scrollTargetID = exercise.id
    }

    private func addSet(to exercise: Exercise) {
        let newSet = ExerciseSet(sortOrder: exercise.sets.count)
        exercise.sets.append(newSet)
    }

    private func deleteExercise(_ exercise: Exercise) {
        // If the deleted exercise was focused, clear focus
        if focusedExerciseID == exercise.id {
            focusedExerciseID = nil
        }
        session.exercises.removeAll { $0.id == exercise.id }
        modelContext.delete(exercise)
    }

    private enum MoveDirection { case up, down }

    private func moveExercise(_ exercise: Exercise, direction: MoveDirection) {
        let sorted = session.exercises.sorted { $0.sortOrder < $1.sortOrder }
        guard let currentIndex = sorted.firstIndex(where: { $0.id == exercise.id }) else { return }

        let targetIndex: Int
        switch direction {
        case .up:   targetIndex = currentIndex - 1
        case .down: targetIndex = currentIndex + 1
        }

        guard sorted.indices.contains(targetIndex) else { return }

        // Swap sortOrder values
        let temp = sorted[currentIndex].sortOrder
        sorted[currentIndex].sortOrder = sorted[targetIndex].sortOrder
        sorted[targetIndex].sortOrder = temp

        // Keep focus on the moved exercise
        focusedExerciseID = exercise.id
    }

    private func deleteSet(_ set: ExerciseSet, from exercise: Exercise) {
        exercise.sets.removeAll { $0.id == set.id }
        modelContext.delete(set)
    }

    private func completeWorkout() {
        for exercise in session.exercises {
            exercise.tags = session.tags
        }
        session.completedAt = Date()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        SessionView(session: Session(name: "Test Workout"))
    }
    .modelContainer(for: Session.self, inMemory: true)
}

