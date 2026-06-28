import Foundation
import SwiftData

@Model
final class TemplateExercise {
    var id: UUID
    var name: String
    var sortOrder: Int
    var template: WorkoutTemplate?

    @Relationship(deleteRule: .cascade, inverse: \TemplateSet.exercise)
    var sets: [TemplateSet]

    init(name: String = "New Exercise", sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.sortOrder = sortOrder
        self.sets = []
    }

    var sortedSets: [TemplateSet] {
        sets.sorted { $0.sortOrder < $1.sortOrder }
    }
}
