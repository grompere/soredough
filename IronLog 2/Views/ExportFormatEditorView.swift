import SwiftUI

struct ExportFormatEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ExportFormatStore

    @State private var name = ""
    @State private var columnDefinition = ""

    private var detectedSeparator: String {
        ExportFormat.detectSeparator(in: columnDefinition)
    }

    private var previewColumns: [String] {
        columnDefinition
            .components(separatedBy: detectedSeparator)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !previewColumns.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section {
                        TextField("e.g. Trainer Weekly Report", text: $name)
                            .font(.subheadline)
                    } header: {
                        Text("Cookie Cutter Name")
                    }

                    Section {
                        TextField("Date, Exercise, Sets x Reps, Weight", text: $columnDefinition, axis: .vertical)
                            .font(.subheadline)
                            .lineLimit(3...6)
                    } header: {
                        Text("Column Definitions")
                    } footer: {
                        Text("Separate columns with commas or | pipes. Use natural language — Gemini will figure out the mapping.")
                            .font(.caption2)
                    }

                    if !previewColumns.isEmpty {
                        Section {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(previewColumns, id: \.self) { col in
                                        Text(col)
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(.orange.opacity(0.12), in: Capsule())
                                            .foregroundStyle(.orange)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        } header: {
                            HStack(spacing: 4) {
                                Text("Preview")
                                Text("·")
                                Text("separator: \(detectedSeparator == "|" ? "pipe |" : "comma ,")")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Save button
                VStack(spacing: 0) {
                    Divider()

                    Button {
                        save()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption.weight(.bold))
                            Text("Save Cookie Cutter")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            LinearGradient(
                                colors: canSave
                                    ? [.orange, .orange.opacity(0.8)]
                                    : [.gray.opacity(0.4), .gray.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                    }
                    .disabled(!canSave)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 6)
                }
                .background(.ultraThinMaterial)
            }
            .navigationTitle("New Cookie Cutter 🍪")
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
            }
        }
    }

    private func save() {
        var format = ExportFormat(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            columnDefinition: columnDefinition.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        format.separator = detectedSeparator
        store.add(format)
        dismiss()
    }
}

#Preview {
    ExportFormatEditorView(store: ExportFormatStore.shared)
}
