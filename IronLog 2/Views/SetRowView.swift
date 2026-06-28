import SwiftUI
import SwiftData

struct SetRowView: View {
    @Bindable var exerciseSet: ExerciseSet
    let setNumber: Int
    var previousWeight: Double? = nil

    @State private var weightText: String = ""
    @FocusState private var isWeightFocused: Bool

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

            // Beat-it indicator
            if let prev = previousWeight, prev > 0, exerciseSet.weight > 0 {
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

            // Rep Count Picker
            Picker("Reps", selection: $exerciseSet.repCount) {
                ForEach(1...20, id: \.self) { count in
                    Text("\(count)").tag(count)
                }
            }
            .pickerStyle(.menu)
            .tint(.primary)
            .frame(width: 66, height: 32)
            .font(.subheadline)
            .fontWeight(.medium)
            .fontDesign(.rounded)
        }
        .opacity(exerciseSet.isCompleted ? 0.5 : 1.0)
        .onAppear {
            if exerciseSet.weight > 0 {
                if exerciseSet.weight == exerciseSet.weight.rounded() {
                    weightText = String(format: "%.0f", exerciseSet.weight)
                } else {
                    weightText = String(exerciseSet.weight)
                }
            }
        }
    }

    // MARK: - Actions

    private func toggleCompletion() {
        exerciseSet.isCompleted.toggle()
        exerciseSet.completedAt = exerciseSet.isCompleted ? Date() : nil
    }

    /// Only writes to SwiftData when editing is done (not per-keystroke)
    private func flushWeight() {
        let filtered = weightText.filter { $0.isNumber || $0 == "." }
        if filtered != weightText {
            weightText = filtered
        }
        exerciseSet.weight = Double(filtered) ?? 0
    }
}

#Preview {
    SetRowView(exerciseSet: ExerciseSet(), setNumber: 1)
        .modelContainer(for: Session.self, inMemory: true)
        .padding()
}
