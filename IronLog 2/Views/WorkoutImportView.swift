import SwiftUI
import SwiftData

struct WorkoutImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Session> { $0.completedAt != nil })
    private var completedSessions: [Session]

    /// Callback when a template is ready for review.
    var onParsed: (WorkoutTemplate) -> Void

    @State private var workoutText = ""
    @AppStorage(GeminiService.apiKeyStorageKey) private var apiKey = ""
    @State private var isParsing = false
    @State private var errorMessage: String?
    @State private var showAPIKeyField = false

    private var needsAPIKey: Bool {
        apiKey.isEmpty
    }

    /// All unique exercise names from completed sessions, for AI matching.
    private var existingExerciseNames: [String] {
        var seen = Set<String>()
        var names: [String] = []
        for session in completedSessions {
            for exercise in session.exercises {
                let key = exercise.name.lowercased().trimmingCharacters(in: .whitespaces)
                guard !key.isEmpty, !seen.contains(key) else { continue }
                seen.insert(key)
                names.append(exercise.name)
            }
        }
        return names.sorted()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if needsAPIKey || showAPIKeyField {
                    apiKeySection
                }

                textInputSection

                Spacer(minLength: 0)

                parseButton
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Add cake mix 🧁")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAPIKeyField.toggle()
                        }
                    } label: {
                        Image(systemName: "key")
                            .font(.caption)
                            .foregroundStyle(showAPIKeyField ? .orange : .secondary)
                    }
                }
            }
            .disabled(isParsing)
        }
    }

    // MARK: - API Key Section

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gemini API Key")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 8) {
                SecureField("Paste your API key", text: $apiKey)
                    .font(.subheadline)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                if !apiKey.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAPIKeyField = false
                        }
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(.background, in: RoundedRectangle(cornerRadius: 10))

            Text("Get a free key at [aistudio.google.com](https://aistudio.google.com/apikey)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Text Input

    private var textInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workout Plan")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $workoutText)
                    .font(.subheadline)
                    .scrollContentBackground(.hidden)
                    .padding(8)

                if workoutText.isEmpty {
                    Text("Paste your trainer's workout here...\n\ne.g.\nIncline Bench Press DBs 10@30s, 6@50s\nRDL Barbell 6@95, 8@135, 8@185\nSeated Lat Pulldown 8@90, 2x8@135")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 200)
            .background(.background, in: RoundedRectangle(cornerRadius: 10))

            if let errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text(errorMessage)
                        .font(.caption2)
                }
                .foregroundStyle(.red)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - Parse Button

    private var parseButton: some View {
        VStack(spacing: 0) {
            Divider()

            Button {
                Task { await parseWorkout() }
            } label: {
                Group {
                    if isParsing {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(.white)
                            Text("Mixing the batter...")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "wand.and.stars")
                                .font(.caption.weight(.bold))
                            Text("Parse Workout")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    LinearGradient(
                        colors: canParse
                            ? [.orange, .orange.opacity(0.8)]
                            : [.gray.opacity(0.4), .gray.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 12)
                )
            }
            .disabled(!canParse)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 6)
        }
        .background(.ultraThinMaterial)
    }

    private var canParse: Bool {
        !isParsing
        && !workoutText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !apiKey.isEmpty
    }

    // MARK: - Actions

    @MainActor
    private func parseWorkout() async {
        isParsing = true
        errorMessage = nil

        do {
            let parsed = try await GeminiService.parseWorkout(
                text: workoutText,
                existingExerciseNames: existingExerciseNames
            )

            let template = buildTemplate(from: parsed)
            dismiss()

            // Small delay to let the sheet dismiss animation complete
            try? await Task.sleep(for: .milliseconds(350))
            onParsed(template)
        } catch {
            withAnimation(.easeInOut(duration: 0.2)) {
                errorMessage = error.localizedDescription
            }
        }

        isParsing = false
    }

    private func buildTemplate(from parsed: ParsedWorkout) -> WorkoutTemplate {
        let template = WorkoutTemplate(name: parsed.name)

        for (index, parsedExercise) in parsed.exercises.enumerated() {
            let exercise = TemplateExercise(
                name: parsedExercise.name,
                sortOrder: index
            )

            for (setIndex, parsedSet) in parsedExercise.sets.enumerated() {
                let set = TemplateSet(
                    weight: parsedSet.weight,
                    repCount: parsedSet.reps,
                    sortOrder: setIndex
                )
                exercise.sets.append(set)
            }

            template.exercises.append(exercise)
        }

        return template
    }
}

#Preview {
    WorkoutImportView { _ in }
        .modelContainer(for: [Session.self, WorkoutTemplate.self], inMemory: true)
}
