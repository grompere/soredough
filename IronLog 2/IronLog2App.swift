import SwiftUI
import SwiftData

@main
struct IronLog2App: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .dynamicTypeSize(.xLarge)
        }
        .modelContainer(for: [Session.self, WorkoutTemplate.self]) { result in
            guard case .success(let container) = result else { return }
            seedIfNeeded(container: container)
        }
    }
}

// MARK: - Seed Data

private func seedIfNeeded(container: ModelContainer) {
    let context = ModelContext(container)

    // Only seed if no sessions exist yet
    let count = (try? context.fetchCount(FetchDescriptor<Session>())) ?? 0
    guard count == 0 else { return }

    // Import workout history from the bundled CSV
    CSVImporter.importBundledCSV(into: context)
}
