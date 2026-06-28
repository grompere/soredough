import Foundation
import SwiftData

@Model
final class ExerciseSet {
    var id: UUID
    var weight: Double
    var repCount: Int
    var isCompleted: Bool
    var completedAt: Date?
    var sortOrder: Int
    var exercise: Exercise?

    init(weight: Double = 0, repCount: Int = 8, sortOrder: Int = 0) {
        self.id = UUID()
        self.weight = weight
        self.repCount = repCount
        self.isCompleted = false
        self.completedAt = nil
        self.sortOrder = sortOrder
    }
}
