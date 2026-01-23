import Foundation

enum BuiltInRules {
    static let all: [CleanupRule] = [
        CleanupRule(
            id: "xcode.deriveddata",
            name: "Xcode DerivedData",
            kind: .glob,
            pattern: "**/Library/Developer/Xcode/DerivedData/**",
            riskLevel: .low,
            priority: 300
        ),
        CleanupRule(
            id: "node_modules",
            name: "node_modules",
            kind: .glob,
            pattern: "**/node_modules/**",
            riskLevel: .medium,
            priority: 250
        ),
        CleanupRule(
            id: "python.venv",
            name: "Python venv (.venv)",
            kind: .glob,
            pattern: "**/.venv/**",
            riskLevel: .medium,
            priority: 240
        ),
        CleanupRule(
            id: "python.venv2",
            name: "Python venv (venv)",
            kind: .glob,
            pattern: "**/venv/**",
            riskLevel: .medium,
            priority: 239
        ),
        CleanupRule(
            id: "user.caches",
            name: "User Caches",
            kind: .glob,
            pattern: "**/Library/Caches/**",
            riskLevel: .low,
            priority: 200
        ),
    ]
}

