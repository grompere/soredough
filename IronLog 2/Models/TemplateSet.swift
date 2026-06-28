import Foundation
import SwiftData

@Model
final class TemplateSet {
    var id: UUID
    var weight: Double
    var repCount: Int
    var sortOrder: Int
    var exercise: TemplateExercise?

    init(weight: Double = 0, repCount: Int = 8, sortOrder: Int = 0) {
        self.id = UUID()
        self.weight = weight
        self.repCount = repCount
        self.sortOrder = sortOrder
    }
}
