import Foundation

public enum StudioKit {
    public static let version = "1.0.0"

    public static func normalizedSource(_ source: String) -> String {
        source.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    public static func lineCount(in source: String) -> Int {
        guard !source.isEmpty else { return 0 }
        return normalizedSource(source).components(separatedBy: "\n").count
    }

    public static func fileName(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "Untitled" : trimmed
        return base.hasSuffix(".lua") || base.hasSuffix(".luau") ? base : "\(base).lua"
    }

    public static func sourceSummary(_ source: String) -> String {
        let normalized = normalizedSource(source)
        let characters = normalized.count
        let lines = lineCount(in: normalized)
        return "\(lines) lines • \(characters) characters"
    }
}
