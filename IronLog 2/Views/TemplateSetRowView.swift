import SwiftUI
import SwiftData

struct TemplateSetRowView: View {
    @Bindable var templateSet: TemplateSet
    let setNumber: Int

    @State private var weightText: String = ""
    @State private var repText: String = ""
    @FocusState private var isWeightFocused: Bool
    @FocusState private var isRepFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            // Set Number
            Text("\(setNumber)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(width: 32)

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
                    .onChange(of: weightText) { _, newValue in
                        parseWeight(newValue)
                    }
                Text("lbs")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize()
            }
            .frame(width: 68)

            Spacer()

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
                            templateSet.repCount = count
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
            }
        }
        .onAppear {
            if templateSet.weight > 0 {
                if templateSet.weight == templateSet.weight.rounded() {
                    weightText = String(format: "%.0f", templateSet.weight)
                } else {
                    weightText = String(templateSet.weight)
                }
            }
            repText = "\(templateSet.repCount)"
        }
    }

    // MARK: - Helpers

    private func parseWeight(_ text: String) {
        let filtered = text.filter { $0.isNumber || $0 == "." }
        if filtered != text {
            weightText = filtered
        }
        templateSet.weight = Double(filtered) ?? 0
    }

    /// Parses the typed rep count. Empty/zero falls back to 1 (a set has ≥1 rep).
    private func flushReps() {
        let filtered = repText.filter { $0.isNumber }
        let clamped = max(Int(filtered) ?? 0, 1)
        templateSet.repCount = clamped
        repText = "\(clamped)"
    }
}

#Preview {
    TemplateSetRowView(templateSet: TemplateSet(), setNumber: 1)
        .modelContainer(for: WorkoutTemplate.self, inMemory: true)
        .padding()
}
