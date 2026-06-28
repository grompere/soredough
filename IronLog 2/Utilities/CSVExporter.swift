import Foundation
import SwiftData

struct CSVExporter {
    
    /// Generates a CSV string representation of all provided sessions.
    ///
    /// - Parameter sessions: The sessions to include in the export.
    /// - Returns: A formatted CSV string.
    static func generateCSV(from sessions: [Session]) -> String {
        var csvString = "Date,Workout Name,Tags,Exercise,Set Number,Weight (lbs),Reps,Completed\n"
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        
        // Sort sessions chronologically
        let sortedSessions = sessions.sorted { $0.startedAt < $1.startedAt }
        
        for session in sortedSessions {
            let sessionDate = dateFormatter.string(from: session.startedAt)
            let sessionName = escapeCSV(session.name)
            let sessionTags = escapeCSV(session.tags.joined(separator: "; "))
            
            for exercise in session.exercises.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                let exerciseName = escapeCSV(exercise.name)
                
                for set in exercise.sortedSets {
                    let fields = [
                        sessionDate,
                        sessionName,
                        sessionTags,
                        exerciseName,
                        "\(set.sortOrder + 1)",
                        "\(set.weight)",
                        "\(set.repCount)",
                        set.isCompleted ? "true" : "false"
                    ]
                    
                    csvString.append(fields.joined(separator: ",") + "\n")
                }
            }
        }
        
        return csvString
    }
    
    /// Escapes a string for CSV formatting.
    /// - If the string contains commas, quotes, or newlines, it wraps the entire string in double quotes.
    /// - Any existing double quotes are doubled (e.g. " becomes "").
    private static func escapeCSV(_ text: String) -> String {
        guard text.contains(",") || text.contains("\"") || text.contains("\n") else {
            return text
        }
        
        let escapedQuotes = text.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escapedQuotes)\""
    }
    
    /// Generates the CSV and writes it to a temporary file, returning the URL.
    static func exportToTemporaryFile(sessions: [Session]) throws -> URL {
        let csvString = generateCSV(from: sessions)
        let filename = "SoreDough_Export_\(Int(Date().timeIntervalSince1970)).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }
}
