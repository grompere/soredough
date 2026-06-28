import SwiftUI
import SwiftData

struct TemplateSetRowView: View {
    @Bindable var templateSet: TemplateSet
    let setNumber: Int

    @State private var weightText: String = ""

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

            // Rep Count Picker
            Picker("Reps", selection: $templateSet.repCount) {
                ForEach(1...20, id: \.self) { count in
                    Text("\(count)").tag(count)
                }
            }
            .pickerStyle(.menu)
            .tint(.primary)
            .frame(width: 56, height: 32)
            .font(.subheadline)
            .fontWeight(.medium)
            .fontDesign(.rounded)
        }
        .onAppear {
            if templateSet.weight > 0 {
                if templateSet.weight == templateSet.weight.rounded() {
                    weightText = String(format: "%.0f", templateSet.weight)
                } else {
                    weightText = String(templateSet.weight)
                }
            }
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
}

#Preview {
    TemplateSetRowView(templateSet: TemplateSet(), setNumber: 1)
        .modelContainer(for: WorkoutTemplate.self, inMemory: true)
        .padding()
}
