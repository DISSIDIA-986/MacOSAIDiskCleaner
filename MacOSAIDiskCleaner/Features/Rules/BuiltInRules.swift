import Foundation

enum BuiltInRules {
    static let all: [CleanupRule] = [
        // ==================== Xcode (优先级 500+) ====================
        CleanupRule(
            id: "xcode.deriveddata",
            name: "Xcode DerivedData",
            kind: .glob,
            pattern: "**/Library/Developer/Xcode/DerivedData",
            riskLevel: .low,
            priority: 550
        ),
        CleanupRule(
            id: "xcode.archives",
            name: "Xcode Archives",
            kind: .glob,
            pattern: "**/Library/Developer/Xcode/Archives",
            riskLevel: .medium,
            priority: 520
        ),
        CleanupRule(
            id: "xcode.ios_devicesupport",
            name: "iOS DeviceSupport",
            kind: .glob,
            pattern: "**/Library/Developer/Xcode/iOS DeviceSupport",
            riskLevel: .low,
            priority: 510
        ),
        
        // ==================== Node.js (优先级 400+) ====================
        CleanupRule(
            id: "node_modules",
            name: "node_modules",
            kind: .glob,
            pattern: "**/node_modules",
            riskLevel: .medium,
            priority: 450
        ),
        CleanupRule(
            id: "npm_cache",
            name: "NPM Cache",
            kind: .glob,
            pattern: "**/.npm",
            riskLevel: .low,
            priority: 420
        ),
        
        // ==================== Python (优先级 400+) ====================
        CleanupRule(
            id: "python.venv",
            name: "Python venv (.venv)",
            kind: .glob,
            pattern: "**/.venv",
            riskLevel: .medium,
            priority: 440
        ),
        CleanupRule(
            id: "python.venv2",
            name: "Python venv (venv)",
            kind: .glob,
            pattern: "**/venv",
            riskLevel: .medium,
            priority: 439
        ),
        CleanupRule(
            id: "python.pycache",
            name: "Python __pycache__",
            kind: .glob,
            pattern: "**/__pycache__",
            riskLevel: .low,
            priority: 410
        ),
        
        // ==================== Ruby (优先级 400+) ====================
        CleanupRule(
            id: "ruby.gems_cache",
            name: "Ruby Gems Cache",
            kind: .glob,
            pattern: "**/.gem",
            riskLevel: .low,
            priority: 420
        ),
        
        // ==================== Homebrew (优先级 350+) ====================
        CleanupRule(
            id: "homebrew.cache",
            name: "Homebrew Cache",
            kind: .glob,
            pattern: "**/Library/Caches/Homebrew",
            riskLevel: .low,
            priority: 380
        ),
        CleanupRule(
            id: "homebrew.logs",
            name: "Homebrew Logs",
            kind: .glob,
            pattern: "**/Library/Logs/Homebrew",
            riskLevel: .low,
            priority: 370
        ),
        
        // ==================== CocoaPods (优先级 400+) ====================
        CleanupRule(
            id: "cocoapods.cache",
            name: "CocoaPods Cache",
            kind: .glob,
            pattern: "**/Library/Caches/CocoaPods",
            riskLevel: .low,
            priority: 410
        ),
        
        // ==================== Browser (优先级 300+) ====================
        CleanupRule(
            id: "browser.safari_cache",
            name: "Safari Cache",
            kind: .glob,
            pattern: "**/Library/Caches/com.apple.Safari",
            riskLevel: .low,
            priority: 320
        ),
        CleanupRule(
            id: "browser.chrome_cache",
            name: "Chrome Cache",
            kind: .glob,
            pattern: "**/Library/Caches/Google/Chrome",
            riskLevel: .low,
            priority: 310
        ),
        
        // ==================== System (优先级 200+) ====================
        CleanupRule(
            id: "user.caches",
            name: "User Caches",
            kind: .glob,
            pattern: "**/Library/Caches",
            riskLevel: .low,
            priority: 200
        ),
        CleanupRule(
            id: "user.logs",
            name: "User Logs",
            kind: .glob,
            pattern: "**/Library/Logs",
            riskLevel: .low,
            priority: 190
        ),
    ]
}

