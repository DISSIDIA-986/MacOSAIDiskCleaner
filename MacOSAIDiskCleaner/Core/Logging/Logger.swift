import Foundation
import os

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.macosaidiskcleaner"

    static let scanner = Logger(subsystem: subsystem, category: "scanner")
    static let ruleEngine = Logger(subsystem: subsystem, category: "ruleEngine")
    static let ai = Logger(subsystem: subsystem, category: "ai")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let system = Logger(subsystem: subsystem, category: "system")
    static let statistics = Logger(subsystem: subsystem, category: "statistics")
    static let appupdates = Logger(subsystem: subsystem, category: "appupdates")
}
