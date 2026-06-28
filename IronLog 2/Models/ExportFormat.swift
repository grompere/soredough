import Foundation

// MARK: - Export Format Model

struct ExportFormat: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var columnDefinition: String
    var separator: String

    init(name: String = "", columnDefinition: String = "") {
        self.id = UUID()
        self.name = name
        self.columnDefinition = columnDefinition
        self.separator = ExportFormat.detectSeparator(in: columnDefinition)
    }

    /// Auto-detect separator: if `|` is present, use `|`; otherwise default to `,`.
    static func detectSeparator(in text: String) -> String {
        text.contains("|") ? "|" : ","
    }

    /// Column names parsed from the definition string.
    var columns: [String] {
        columnDefinition
            .components(separatedBy: separator)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Persistent Store (UserDefaults-backed)

final class ExportFormatStore: ObservableObject {
    static let shared = ExportFormatStore()

    private static let storageKey = "exportFormats"

    @Published var formats: [ExportFormat] {
        didSet { save() }
    }

    private init() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([ExportFormat].self, from: data) else {
            self.formats = []
            return
        }
        self.formats = decoded
    }

    func add(_ format: ExportFormat) {
        formats.append(format)
    }

    func delete(at offsets: IndexSet) {
        formats.remove(atOffsets: offsets)
    }

    func delete(id: UUID) {
        formats.removeAll { $0.id == id }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(formats) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
