import Foundation
import SwiftData

@Model
final class WorkoutTemplate {
    var id: UUID
    var name: String
    var createdAt: Date
    var isArchived: Bool
    var tags: [String]

    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.template)
    var exercises: [TemplateExercise]

    init(name: String = "New Workout") {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.isArchived = false
        self.tags = []
        self.exercises = []
    }

    var sortedExercises: [TemplateExercise] {
        exercises.sorted { $0.sortOrder < $1.sortOrder }
    }
}
