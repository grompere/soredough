import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]
    @State private var navigationPath: [Session] = []
    @State private var showWorkoutPicker = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView {
                        Label("No Workouts Yet", systemImage: "figure.strengthtraining.traditional")
                    } description: {
                        Text("Start your first session below.")
                    }
                } else {
                    List {
                        ForEach(sessions) { session in
                            NavigationLink(value: session) {
                                sessionRow(session)
                            }
                        }
                        .onDelete(perform: deleteSessions)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Sore Dough 🥖💪")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.subheadline)
                    }
                }
            }
            .navigationDestination(for: Session.self) { session in
                SessionView(session: session)
            }
            .safeAreaInset(edge: .bottom) {
                bottomButtons
            }
            .sheet(isPresented: $showWorkoutPicker) {
                WorkoutPickerView { session in
                    navigationPath.append(session)
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .tint(.orange)
    }

    // MARK: - Session Row

    private func sessionRow(_ session: Session) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(session.startedAt, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                TagFlowView(tags: session.tags, compact: true)
            }
            Spacer()
            if session.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
            } else {
                Text("Active")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.12), in: Capsule())
            }
        }
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        HStack(spacing: 12) {
            // Progress button
            NavigationLink {
                ProgressListView()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.footnote.weight(.bold))
                    Text("Progress")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    Color(.systemGray5),
                    in: Capsule()
                )
            }

            // Start Workout button
            Button {
                showWorkoutPicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.footnote.weight(.bold))
                    Text("Start Workout")
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
        }
        .padding(.bottom, 8)
    }

    // MARK: - Actions

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sessions[index])
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Session.self, WorkoutTemplate.self], inMemory: true)
}
