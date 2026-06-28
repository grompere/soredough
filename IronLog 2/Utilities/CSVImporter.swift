import Foundation
import SwiftData

struct CSVImporter {

    /// Imports sessions from the bundled `SoreDough_Export.csv` into the given context.
    /// Call this only when the database is empty (fresh install / new build).
    static func importBundledCSV(into context: ModelContext) {
        guard let url = Bundle.main.url(forResource: "SoreDough_Export", withExtension: "csv") else {
            print("[CSVImporter] SoreDough_Export.csv not found in bundle.")
            return
        }

        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            print("[CSVImporter] Failed to read SoreDough_Export.csv.")
            return
        }

        let rows = parseCSV(content)
        guard !rows.isEmpty else { return }

        // Group rows into sessions by (date, workout name)
        // Use an ordered grouping to preserve session order
        var sessionKeys: [(date: String, name: String)] = []
        var sessionGroups: [String: [CSVRow]] = [:]

        for row in rows {
            let key = "\(row.date)|\(row.workoutName)"
            if sessionGroups[key] == nil {
                sessionKeys.append((date: row.date, name: row.workoutName))
            }
            sessionGroups[key, default: []].append(row)
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        for sessionKey in sessionKeys {
            let key = "\(sessionKey.date)|\(sessionKey.name)"
            guard let sessionRows = sessionGroups[key],
                  let startDate = isoFormatter.date(from: sessionKey.date) else { continue }

            let session = Session(name: sessionKey.name)
            session.startedAt = startDate
            session.completedAt = startDate.addingTimeInterval(3600)

            // Parse session-level tags from the first row
            let rawTags = sessionRows.first?.tags ?? ""
            let sessionTags = rawTags
                .split(separator: ";")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            session.tags = sessionTags

            context.insert(session)

            // Group rows by exercise name (preserving order)
            var exerciseNames: [String] = []
            var exerciseGroups: [String: [CSVRow]] = [:]

            for row in sessionRows {
                let name = row.exerciseName
                if exerciseGroups[name] == nil {
                    exerciseNames.append(name)
                }
                exerciseGroups[name, default: []].append(row)
            }

            for (exerciseOrder, exerciseName) in exerciseNames.enumerated() {
                guard let setRows = exerciseGroups[exerciseName] else { continue }

                let exercise = Exercise(name: exerciseName, sortOrder: exerciseOrder)
                exercise.tags = sessionTags
                session.exercises.append(exercise)

                for setRow in setRows {
                    let set = ExerciseSet(
                        weight: setRow.weight,
                        repCount: setRow.reps,
                        sortOrder: setRow.setNumber - 1
                    )
                    set.isCompleted = setRow.isCompleted
                    if setRow.isCompleted {
                        set.completedAt = startDate.addingTimeInterval(Double(setRow.setNumber) * 300)
                    }
                    exercise.sets.append(set)
                }
            }
        }

        try? context.save()
        print("[CSVImporter] Imported \(sessionKeys.count) sessions from CSV.")
    }

    // MARK: - CSV Parsing

    private struct CSVRow {
        let date: String
        let workoutName: String
        let tags: String
        let exerciseName: String
        let setNumber: Int
        let weight: Double
        let reps: Int
        let isCompleted: Bool
    }

    private static func parseCSV(_ content: String) -> [CSVRow] {
        let lines = content.components(separatedBy: .newlines)
        guard lines.count > 1 else { return [] }

        var rows: [CSVRow] = []

        // Skip header (line 0)
        for i in 1..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            let fields = parseCSVLine(line)
            guard fields.count >= 8 else { continue }

            let row = CSVRow(
                date: fields[0],
                workoutName: fields[1],
                tags: fields[2],
                exerciseName: fields[3].trimmingCharacters(in: .whitespaces),
                setNumber: Int(fields[4]) ?? 1,
                weight: Double(fields[5]) ?? 0,
                reps: Int(fields[6]) ?? 0,
                isCompleted: fields[7].lowercased() == "true"
            )
            rows.append(row)
        }

        return rows
    }

    /// Handles quoted CSV fields (commas inside quotes, escaped double-quotes).
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var chars = line.makeIterator()

        while let ch = chars.next() {
            if inQuotes {
                if ch == "\"" {
                    // Peek: if next char is also a quote, it's an escaped quote
                    // We can't peek with makeIterator, so use a flag approach
                    current.append(ch)
                    // Simple approach: toggle quote mode; handle "" in post-processing
                    inQuotes = false
                } else {
                    current.append(ch)
                }
            } else {
                if ch == "\"" {
                    inQuotes = true
                } else if ch == "," {
                    fields.append(current)
                    current = ""
                } else {
                    current.append(ch)
                }
            }
        }
        fields.append(current)

        // Post-process: un-escape doubled quotes
        return fields.map { $0.replacingOccurrences(of: "\"\"", with: "\"") }
    }
}
