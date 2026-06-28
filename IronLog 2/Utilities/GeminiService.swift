import Foundation

// MARK: - Parsed Models

struct ParsedWorkout: Codable {
    let name: String
    let exercises: [ParsedExercise]
}

struct ParsedExercise: Codable {
    let name: String
    let sets: [ParsedSet]
}

struct ParsedSet: Codable {
    let reps: Int
    let weight: Double
}

// MARK: - Errors

enum GeminiError: LocalizedError {
    case noAPIKey
    case badURL
    case httpError(Int, String)
    case noContent
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key set. Please add your Gemini API key."
        case .badURL:
            return "Invalid API URL."
        case .httpError(let code, let body):
            return "API error (\(code)): \(body.prefix(200))"
        case .noContent:
            return "The AI returned an empty response. Try again."
        case .decodingFailed(let detail):
            return "Could not parse the AI response: \(detail)"
        }
    }
}

// MARK: - Service

struct GeminiService {
    private static let model = "gemini-3.1-flash-lite-preview"
    private static let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    static let apiKeyStorageKey = "geminiAPIKey"

    /// Parses a natural-language workout description into structured data.
    /// - Parameters:
    ///   - text: The raw workout text from a trainer.
    ///   - existingExerciseNames: Exercise names already in the user's history, for dedup matching.
    /// - Returns: A `ParsedWorkout` with inferred name, exercises, and sets.
    static func parseWorkout(
        text: String,
        existingExerciseNames: [String]
    ) async throws -> ParsedWorkout {
        guard let apiKey = UserDefaults.standard.string(forKey: apiKeyStorageKey),
              !apiKey.isEmpty else {
            throw GeminiError.noAPIKey
        }

        let url = try buildURL(apiKey: apiKey)
        let prompt = buildPrompt(text: text, existingNames: existingExerciseNames)
        let body = buildRequestBody(prompt: prompt)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.httpError(0, "No HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? "No body"
            throw GeminiError.httpError(httpResponse.statusCode, responseBody)
        }

        return try extractWorkout(from: data)
    }

    // MARK: - Private Helpers

    private static func buildURL(apiKey: String) throws -> URL {
        guard let url = URL(string: "\(baseURL)/models/\(model):generateContent?key=\(apiKey)") else {
            throw GeminiError.badURL
        }
        return url
    }

    private static func buildPrompt(text: String, existingNames: [String]) -> String {
        let existingList = existingNames.isEmpty
            ? "No existing exercises yet."
            : existingNames.joined(separator: "\n")

        return """
        You are a workout parser. Parse the following natural-language workout description into structured JSON.

        RULES:
        1. Infer a short, descriptive workout name from the exercises (e.g. "Upper Body Push/Pull", "Leg Day", "Full Body").
        2. Parse each exercise with its sets (reps and weight).
        3. Common trainer shorthand:
           - "2x8@135" means 2 sets of 8 reps at 135 lbs
           - "10@30s, 6@50s" means set 1: 10 reps at 30, set 2: 6 reps at 50
           - "1x6e" means 1 set of 6 reps (the "e" means each side — just store 6 as the rep count)
           - "8e@50" means 1 set of 8 reps at 50 lbs
           - "8#" or "14#" means 8 lbs or 14 lbs (the # is a pound sign)
           - "2x8e@135" means 2 sets of 8 reps at 135
           - A line with just "-" is a separator between exercise groups — ignore it
        4. If an exercise has no weight specified (e.g. "1x6e"), use 0 for weight.
        5. IMPORTANT — Exercise name matching: Below is a list of exercise names already in the user's workout history. If a parsed exercise name is similar or equivalent to one of these existing names, USE THE EXISTING NAME instead of creating a new variation. For example, if "Barbell Bench Press" exists and the text says "Bench Press", use "Barbell Bench Press". Be smart about matching — "DB Bench" and "Dumbbell Bench Press" are the same exercise. Only create a new name if no existing name is a reasonable match.

        EXISTING EXERCISE NAMES:
        \(existingList)

        WORKOUT TEXT TO PARSE:
        \(text)
        """
    }

    private static func buildRequestBody(prompt: String) -> [String: Any] {
        return [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema": [
                    "type": "OBJECT",
                    "properties": [
                        "name": [
                            "type": "STRING",
                            "description": "Inferred workout name"
                        ],
                        "exercises": [
                            "type": "ARRAY",
                            "items": [
                                "type": "OBJECT",
                                "properties": [
                                    "name": [
                                        "type": "STRING",
                                        "description": "Exercise name"
                                    ],
                                    "sets": [
                                        "type": "ARRAY",
                                        "items": [
                                            "type": "OBJECT",
                                            "properties": [
                                                "reps": [
                                                    "type": "INTEGER",
                                                    "description": "Number of reps"
                                                ],
                                                "weight": [
                                                    "type": "NUMBER",
                                                    "description": "Weight in lbs, 0 if unspecified"
                                                ]
                                            ],
                                            "required": ["reps", "weight"]
                                        ]
                                    ]
                                ],
                                "required": ["name", "sets"]
                            ]
                        ]
                    ],
                    "required": ["name", "exercises"]
                ]
            ]
        ]
    }

    private static func extractWorkout(from data: Data) throws -> ParsedWorkout {
        // Parse the Gemini response envelope
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw GeminiError.noContent
        }

        // The text should be valid JSON matching our schema
        guard let jsonData = text.data(using: .utf8) else {
            throw GeminiError.decodingFailed("Response text is not valid UTF-8")
        }

        do {
            return try JSONDecoder().decode(ParsedWorkout.self, from: jsonData)
        } catch {
            throw GeminiError.decodingFailed(error.localizedDescription)
        }
    }

    // MARK: - Export Transformation

    /// Transforms workout session data into a custom column format using Gemini.
    /// - Parameters:
    ///   - sessions: The workout sessions to export.
    ///   - format: The user-defined export format (column names + separator).
    /// - Returns: A formatted string (CSV or pipe-separated) matching the requested columns.
    static func transformWorkoutData(
        sessions: [Session],
        format: ExportFormat
    ) async throws -> String {
        guard let apiKey = UserDefaults.standard.string(forKey: apiKeyStorageKey),
              !apiKey.isEmpty else {
            throw GeminiError.noAPIKey
        }

        let url = try buildURL(apiKey: apiKey)
        let serialized = serializeSessions(sessions)
        let prompt = buildExportPrompt(data: serialized, format: format)
        let body = buildPlainTextRequestBody(prompt: prompt)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.httpError(0, "No HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? "No body"
            throw GeminiError.httpError(httpResponse.statusCode, responseBody)
        }

        return try extractPlainText(from: data)
    }

    /// Serializes sessions into a structured text block for the AI prompt.
    private static func serializeSessions(_ sessions: [Session]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        let sorted = sessions.sorted { $0.startedAt < $1.startedAt }
        var lines: [String] = []

        for session in sorted {
            lines.append("--- SESSION ---")
            lines.append("Name: \(session.name)")
            lines.append("Date: \(dateFormatter.string(from: session.startedAt))")
            if !session.tags.isEmpty {
                lines.append("Tags: \(session.tags.joined(separator: ", "))")
            }

            for exercise in session.exercises.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                lines.append("  Exercise: \(exercise.name)")
                for set in exercise.sortedSets {
                    let status = set.isCompleted ? "completed" : "skipped"
                    lines.append("    Set \(set.sortOrder + 1): \(set.repCount) reps @ \(set.weight) lbs (\(status))")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    /// Builds the prompt for export transformation.
    private static func buildExportPrompt(data: String, format: ExportFormat) -> String {
        let sep = format.separator
        let cols = format.columns.joined(separator: " \(sep) ")
        let hasTimestamp = format.columns.contains { col in
            let lower = col.lowercased()
            return lower.contains("date") || lower.contains("time") || lower.contains("timestamp")
        }

        var timestampInstruction = ""
        if !hasTimestamp {
            timestampInstruction = """
            IMPORTANT: The user's format does not include a date/timestamp column. \
            You MUST prepend a "Date" column as the FIRST column so the trainer knows when each workout occurred. \
            Use the format YYYY-MM-DD for dates.
            """
        }

        return """
        You are a workout data formatter. Transform the raw workout data below into a \
        \(sep == "|" ? "pipe-separated" : "comma-separated") dataset.

        RULES:
        1. Output ONLY the formatted dataset — no explanations, no markdown fences, no extra text.
        2. The first line must be the header row.
        3. The columns requested by the user are: \(cols)
        4. Use "\(sep)" as the column separator.
        5. Each set of each exercise should be its own row.
        6. Interpret the column names intelligently. For example:
           - "Sets x Reps" means format as "3x8" style
           - "Weight" means the weight value
           - "Exercise" means the exercise name
           - Be creative mapping natural language column names to the data
        7. Only include completed sets (status = completed), unless a column explicitly asks for status.
        8. Sort rows chronologically by workout date, then by exercise order, then by set order.
        \(timestampInstruction)

        RAW WORKOUT DATA:
        \(data)
        """
    }

    /// Builds a request body that asks for plain text output (no JSON schema).
    private static func buildPlainTextRequestBody(prompt: String) -> [String: Any] {
        return [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "text/plain"
            ]
        ]
    }

    /// Extracts plain text from the Gemini response envelope.
    private static func extractPlainText(from data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw GeminiError.noContent
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GeminiError.noContent
        }

        return trimmed
    }
}
