import SwiftUI
import SwiftData

struct TemplateListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<WorkoutTemplate> { !$0.isArchived },
        sort: \WorkoutTemplate.createdAt,
        order: .reverse
    )
    private var templates: [WorkoutTemplate]

    @State private var editingTemplate: WorkoutTemplate?
    @State private var newTemplate: WorkoutTemplate?
    @State private var showImporter = false
    @State private var importedTemplate: WorkoutTemplate?

    var body: some View {
        Group {
            if templates.isEmpty {
                ContentUnavailableView {
                    Label("No Templates Yet", systemImage: "oven")
                } description: {
                    Text("Tap below to bake your first workout!")
                }
            } else {
                List {
                    ForEach(templates) { template in
                        templateRow(template)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Pre-baked 🥐")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            bakeButton
        }
        .sheet(item: $editingTemplate) { template in
            NavigationStack {
                TemplateEditorView(template: template, isNew: false)
            }
        }
        .sheet(item: $newTemplate) { template in
            NavigationStack {
                TemplateEditorView(template: template, isNew: true)
            }
        }
        .sheet(isPresented: $showImporter) {
            WorkoutImportView { template in
                importedTemplate = template
            }
        }
        .sheet(item: $importedTemplate) { template in
            NavigationStack {
                TemplateEditorView(template: template, isNew: true)
            }
        }
    }

    // MARK: - Template Row

    private func templateRow(_ template: WorkoutTemplate) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text("\(template.exercises.count) exercise\(template.exercises.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                editingTemplate = template
            } label: {
                Image(systemName: "pencil")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.borderless)

            Button {
                withAnimation {
                    archiveTemplate(template)
                }
            } label: {
                Image(systemName: "archivebox")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
    }

    // MARK: - Bake Button

    private var bakeButton: some View {
        Menu {
            Button {
                let template = WorkoutTemplate()
                newTemplate = template
            } label: {
                Label("From scratch", systemImage: "flame")
            }

            Button {
                showImporter = true
            } label: {
                Label("Add cake mix", systemImage: "doc.text")
            }
        } label: {
            HStack(spacing: 6) {
                Text("🔥")
                Text("Let's bake!")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.orange, Color.orange.opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
            .shadow(color: .orange.opacity(0.3), radius: 12, y: 4)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Actions

    private func archiveTemplate(_ template: WorkoutTemplate) {
        template.isArchived = true
    }
}

#Preview {
    NavigationStack {
        TemplateListView()
    }
    .modelContainer(for: WorkoutTemplate.self, inMemory: true)
}
