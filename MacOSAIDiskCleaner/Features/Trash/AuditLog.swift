import Foundation
import os

actor AuditLog {
    private let logURL: URL

    init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MacOSAIDiskCleaner", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        self.logURL = base.appendingPathComponent("audit.log", isDirectory: false)
    }

    func append(_ record: TrashRecord) {
        do {
            let data = try JSONEncoder().encode(record)
            var line = data
            line.append(0x0A) // newline

            if FileManager.default.fileExists(atPath: logURL.path) {
                let handle = try FileHandle(forWritingTo: logURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: line)
                try handle.close()
            } else {
                try line.write(to: logURL)
            }
        } catch {
            Logger.system.error("AuditLog append failed: \(error.localizedDescription)")
        }
    }

    func readRecent(limit: Int = 50) -> [TrashRecord] {
        guard let data = try? Data(contentsOf: logURL),
              let text = String(data: data, encoding: .utf8) else { return [] }

        let lines = text.split(separator: "\n").suffix(max(0, limit))
        var out: [TrashRecord] = []
        out.reserveCapacity(lines.count)

        for line in lines {
            if let d = line.data(using: .utf8),
               let rec = try? JSONDecoder().decode(TrashRecord.self, from: d) {
                out.append(rec)
            }
        }
        return out.reversed()
    }
}

