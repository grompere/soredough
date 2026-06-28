import Foundation
import SwiftData

@Model
final class Session {
    var id: UUID
    var name: String
    var startedAt: Date
    var completedAt: Date?
    var tags: [String]

    @Relationship(deleteRule: .cascade, inverse: \Exercise.session)
    var exercises: [Exercise]

    init(name: String = "") {
        self.id = UUID()
        let now = Date()
        self.startedAt = now
        self.completedAt = nil
        self.tags = []
        self.exercises = []

        if name.isEmpty {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            self.name = "Workout — \(formatter.string(from: now))"
        } else {
            self.name = name
        }
    }

    var isCompleted: Bool {
        completedAt != nil
    }
}
