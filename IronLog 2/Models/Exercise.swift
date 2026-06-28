import Foundation
import SwiftData

@Model
final class Exercise {
    var id: UUID
    var name: String
    var sortOrder: Int
    var tags: [String]
    var session: Session?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.exercise)
    var sets: [ExerciseSet]

    init(name: String = "New Exercise", sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.sortOrder = sortOrder
        self.tags = []
        self.sets = []
    }

    var sortedSets: [ExerciseSet] {
        sets.sorted { $0.sortOrder < $1.sortOrder }
    }
}
