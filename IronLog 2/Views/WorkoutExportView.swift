import SwiftUI
import SwiftData

struct WorkoutExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(
        filter: #Predicate<Session> { $0.completedAt != nil },
        sort: \Session.startedAt,
        order: .reverse
    )
    private var completedSessions: [Session]

    @ObservedObject private var store = ExportFormatStore.shared
    @AppStorage(GeminiService.apiKeyStorageKey) private var apiKey = ""

    @State private var selectedFormat: ExportFormat?
    @State private var selectedSessionIDs: Set<UUID> = []
    @State private var isExporting = false
    @State private var exportResult: String?
    @State private var errorMessage: String?
    @State private var copied = false

    private var canExport: Bool {
        selectedFormat != nil
        && !selectedSessionIDs.isEmpty
        && !isExporting
        && !apiKey.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let exportResult {
                    resultView(exportResult)
                } else {
                    selectionView
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(exportResult != nil ? "Export Result" : "Export Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if exportResult != nil {
                            // Go back to selection
                            withAnimation(.easeInOut(duration: 0.2)) {
                                self.exportResult = nil
                                self.errorMessage = nil
                            }
                        } else {
                            dismiss()
                        }
                    } label: {
                        if exportResult != nil {
                            Image(systemName: "chevron.left")
                                .font(.caption.weight(.semibold))
                        } else {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if exportResult != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Done")
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Selection View

    private var selectionView: some View {
        VStack(spacing: 0) {
            List {
                // Format picker
                Section {
                    if store.formats.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text("No Cookie Cutters yet. Add one in Settings → Cookie Cutters.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(store.formats) { format in
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedFormat = format
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(format.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary)

                                        Text(format.columns.joined(separator: " \(format.separator) "))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    if selectedFormat?.id == format.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.orange)
                                            .font(.title3)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(Color(.systemGray4))
                                            .font(.title3)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text("Cookie Cutter")
                }

                // API key warning
                if apiKey.isEmpty {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "key.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text("Set your Gemini API key in the Import view first.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Workout selection
                Section {
                    if completedSessions.isEmpty {
                        Text("No completed workouts yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        // Select All / Deselect All
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if selectedSessionIDs.count == completedSessions.count {
                                    selectedSessionIDs.removeAll()
                                } else {
                                    selectedSessionIDs = Set(completedSessions.map(\.id))
                                }
                            }
                        } label: {
                            Text(selectedSessionIDs.count == completedSessions.count ? "Deselect All" : "Select All")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.orange)
                        }

                        ForEach(completedSessions) { session in
                            Button {
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    if selectedSessionIDs.contains(session.id) {
                                        selectedSessionIDs.remove(session.id)
                                    } else {
                                        selectedSessionIDs.insert(session.id)
                                    }
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: selectedSessionIDs.contains(session.id)
                                          ? "checkmark.square.fill"
                                          : "square")
                                        .foregroundStyle(selectedSessionIDs.contains(session.id) ? .orange : Color(.systemGray4))
                                        .font(.title3)

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(session.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)

                                        Text(session.startedAt, style: .date)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Text("\(session.exercises.count) ex")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Workouts")
                        Spacer()
                        if !selectedSessionIDs.isEmpty {
                            Text("\(selectedSessionIDs.count) selected")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text(errorMessage)
                        .font(.caption2)
                }
                .foregroundStyle(.red)
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
                .transition(.opacity)
            }

            // Export button
            VStack(spacing: 0) {
                Divider()

                Button {
                    Task { await runExport() }
                } label: {
                    Group {
                        if isExporting {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .tint(.white)
                                Text("Baking your export...")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        } else {
                            HStack(spacing: 6) {
                                Text("🍪")
                                    .font(.caption)
                                Text("Bake Export")
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
                            colors: canExport
                                ? [.orange, .orange.opacity(0.8)]
                                : [.gray.opacity(0.4), .gray.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
                .disabled(!canExport)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 6)
            }
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Result View

    private func resultView(_ text: String) -> some View {
        VStack(spacing: 0) {
            // Copy bar
            HStack {
                Text("\(text.components(separatedBy: "\n").filter { !$0.isEmpty }.count) rows")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    UIPasteboard.general.string = text
                    withAnimation(.easeInOut(duration: 0.2)) {
                        copied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            copied = false
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.caption2.weight(.semibold))
                        Text(copied ? "Copied!" : "Copy")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(copied ? .green : .orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        (copied ? Color.green : Color.orange).opacity(0.12),
                        in: Capsule()
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            Divider()

            // Result text
            ScrollView {
                Text(text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Export Logic

    @MainActor
    private func runExport() async {
        guard let format = selectedFormat else { return }

        isExporting = true
        errorMessage = nil

        let sessions = completedSessions.filter { selectedSessionIDs.contains($0.id) }

        do {
            let result = try await GeminiService.transformWorkoutData(
                sessions: sessions,
                format: format
            )
            withAnimation(.easeInOut(duration: 0.25)) {
                exportResult = result
            }
        } catch {
            withAnimation(.easeInOut(duration: 0.2)) {
                errorMessage = error.localizedDescription
            }
        }

        isExporting = false
    }
}

#Preview {
    WorkoutExportView()
        .modelContainer(for: [Session.self, WorkoutTemplate.self], inMemory: true)
}
