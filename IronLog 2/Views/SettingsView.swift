import SwiftUI
import SwiftData

/// Wrapper to make URL usable with .sheet(item:)
private struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var formatStore = ExportFormatStore.shared
    
    @State private var hasCompletedSessions = false
    @State private var exportFile: ExportFile?
    @State private var showExportWorkouts = false

    var body: some View {
        List {
            Section {
                NavigationLink {
                    TemplateListView()
                } label: {
                    Label {
                        Text("Pre-baked workouts")
                    } icon: {
                        Text("🥐")
                            .font(.title3)
                    }
                }
            }
            
            Section("Export") {
                NavigationLink {
                    ExportFormatListView()
                } label: {
                    Label {
                        HStack {
                            Text("Cookie Cutters")
                            Spacer()
                            if !formatStore.formats.isEmpty {
                                Text("\(formatStore.formats.count)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color(.systemGray5), in: Capsule())
                            }
                        }
                    } icon: {
                        Text("🍪")
                            .font(.title3)
                    }
                }
                
                Button {
                    showExportWorkouts = true
                } label: {
                    Label {
                        Text("Export Workouts")
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .disabled(!hasCompletedSessions || formatStore.formats.isEmpty)
            }
            
            Section("Data") {
                Button {
                    exportData()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Data to CSV")
                    }
                }
                .disabled(!hasCompletedSessions)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .sheet(item: $exportFile) { file in
            ShareSheet(activityItems: [file.url])
        }
        .sheet(isPresented: $showExportWorkouts) {
            WorkoutExportView()
        }
        .onAppear {
            var descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.completedAt != nil })
            descriptor.fetchLimit = 1
            hasCompletedSessions = ((try? modelContext.fetchCount(descriptor)) ?? 0) > 0
        }
    }
    
    // MARK: - Export Logic
    
    private func exportData() {
        do {
            let descriptor = FetchDescriptor<Session>(
                predicate: #Predicate { $0.completedAt != nil },
                sortBy: [SortDescriptor(\Session.startedAt)]
            )
            let sessions = try modelContext.fetch(descriptor)
            let url = try CSVExporter.exportToTemporaryFile(sessions: sessions)
            self.exportFile = ExportFile(url: url)
        } catch {
            print("Failed to export CSV: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: [Session.self, WorkoutTemplate.self], inMemory: true)
}
