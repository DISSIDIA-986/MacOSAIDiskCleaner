import Foundation

enum PathSanitizer {
    static func sanitize(_ path: String) -> String {
        var out = path

        // /Users/<name>/... -> ~/...
        out = out.replacingOccurrences(
            of: #"^/Users/[^/]+"#,
            with: "~",
            options: [.regularExpression]
        )

        // /Volumes/<anything> -> /Volumes/[SystemVolume] (keep remainder)
        out = out.replacingOccurrences(
            of: #"^/Volumes/[^/]+"#,
            with: "/Volumes/[SystemVolume]",
            options: [.regularExpression]
        )

        // UUID patterns -> [UUID]
        out = out.replacingOccurrences(
            of: #"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"#,
            with: "[UUID]",
            options: [.regularExpression]
        )

        // Very long hex tokens -> [HEX]
        out = out.replacingOccurrences(
            of: #"\b[0-9A-Fa-f]{16,}\b"#,
            with: "[HEX]",
            options: [.regularExpression]
        )

        return out
    }
}

