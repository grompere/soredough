import Foundation
import SwiftData

@Model
final class Exercise {
    var id: UUID
    var name: String
    var sortOrder: Int
    var tags: [String]
    /// Free-text note for this exercise (e.g. "felt easy", "left shoulder twinge").
    /// Default "" keeps SwiftData lightweight migration automatic for existing stores.
    var notes: String = ""
    var session: Session?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.exercise)
    var sets: [ExerciseSet]

    init(name: String = "New Exercise", sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.sortOrder = sortOrder
        self.tags = []
        self.notes = ""
        self.sets = []
    }

    var sortedSets: [ExerciseSet] {
        sets.sorted { $0.sortOrder < $1.sortOrder }
    }
}
