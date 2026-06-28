import SwiftUI
import SwiftData

struct SetRowView: View {
    @Bindable var exerciseSet: ExerciseSet
    let setNumber: Int
    /// Baseline to compare this set's weight against for the progress arrow:
    /// the same-position set from the last completed session. Same weight → no arrow.
    var comparisonWeight: Double? = nil

    @State private var weightText: String = ""
    @State private var repText: String = ""
    @FocusState private var isWeightFocused: Bool
    @FocusState private var isRepFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            // Completion Checkbox
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    toggleCompletion()
                }
            } label: {
                Image(systemName: exerciseSet.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(exerciseSet.isCompleted ? .green : Color(.systemGray4))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Set Number
            Text("\(setNumber)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Spacer()

            // Weight Input
            HStack(spacing: 3) {
                TextField("0", text: $weightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .fontDesign(.rounded)
                    .frame(width: 52, height: 32)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 7))
                    .focused($isWeightFocused)
                    .onSubmit { flushWeight() }
                    .onChange(of: isWeightFocused) { _, focused in
                        if !focused { flushWeight() }
                    }
                Text("lbs")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize()
            }
            .frame(width: 68)

            // Beat-it indicator (vs. absolute best — FR-6)
            if let prev = comparisonWeight, prev > 0, exerciseSet.weight > 0 {
                if exerciseSet.weight > prev {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.green)
                        .frame(width: 14)
                } else if exerciseSet.weight < prev {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.orange)
                        .frame(width: 14)
                } else {
                    Spacer().frame(width: 14)
                }
            } else {
                Spacer().frame(width: 14)
            }

            // Rep Count: typeable field + dropdown (FR-4)
            HStack(spacing: 2) {
                TextField("8", text: $repText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .fontDesign(.rounded)
                    .frame(width: 34, height: 32)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 7))
                    .focused($isRepFocused)
                    .onSubmit { flushReps() }
                    .onChange(of: isRepFocused) { _, focused in
                        if !focused { flushReps() }
                    }

                Menu {
                    ForEach(1...20, id: \.self) { count in
                        Button("\(count) reps") {
                            exerciseSet.repCount = count
                            repText = "\(count)"
                        }
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 32)
                        .contentShape(Rectangle())
                }

                Text("reps")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize()
            }
        }
        .opacity(exerciseSet.isCompleted ? 0.5 : 1.0)
        .onAppear {
            weightText = formatWeight(exerciseSet.weight)
            repText = "\(exerciseSet.repCount)"
        }
        // Resync local text when the model is changed externally (e.g. FR-7
        // "use last max"), but never stomp on the field the user is editing.
        .onChange(of: exerciseSet.weight) { _, newVal in
            if !isWeightFocused { weightText = formatWeight(newVal) }
        }
        .onChange(of: exerciseSet.repCount) { _, newVal in
            if !isRepFocused { repText = "\(newVal)" }
        }
    }

    // MARK: - Actions

    private func toggleCompletion() {
        exerciseSet.isCompleted.toggle()
        exerciseSet.completedAt = exerciseSet.isCompleted ? Date() : nil
    }

    /// Formats a weight for display: "" for 0, integer when whole, else decimal.
    private func formatWeight(_ w: Double) -> String {
        guard w > 0 else { return "" }
        return w == w.rounded() ? String(format: "%.0f", w) : String(w)
    }

    /// Only writes to SwiftData when editing is done (not per-keystroke)
    private func flushWeight() {
        let filtered = weightText.filter { $0.isNumber || $0 == "." }
        if filtered != weightText {
            weightText = filtered
        }
        exerciseSet.weight = Double(filtered) ?? 0
    }

    /// Parses the typed rep count. Empty/zero falls back to 1 (a set has ≥1 rep).
    private func flushReps() {
        let filtered = repText.filter { $0.isNumber }
        let parsed = Int(filtered) ?? 0
        let clamped = max(parsed, 1)
        exerciseSet.repCount = clamped
        repText = "\(clamped)"
    }
}

#Preview {
    SetRowView(exerciseSet: ExerciseSet(), setNumber: 1)
        .modelContainer(for: Session.self, inMemory: true)
        .padding()
}
