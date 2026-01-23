import Foundation
import os

actor TrashManager {
    private let auditLog = AuditLog()
    private var lastBatch: [TrashRecord] = []

    func trash(items: [CandidateItem], dryRun: Bool) async -> [TrashRecord] {
        let fm = FileManager.default
        var records: [TrashRecord] = []
        records.reserveCapacity(items.count)

        for item in items {
            if Task.isCancelled { break }

            let path = item.url.path

            // extra safety: never trash protected system paths
            if FileScanner.isProtectedSystemPath((path as NSString).standardizingPath) {
                let r = TrashRecord(
                    originalPath: path,
                    trashedPath: nil,
                    sizeBytes: item.sizeBytes,
                    decisionSource: "manual",
                    matchedRuleId: item.ruleMatch?.rule.id,
                    aiRecommendedAction: item.aiAnalysis?.recommendedAction.rawValue,
                    dryRun: dryRun,
                    success: false,
                    errorMessage: "Protected system path"
                )
                await auditLog.append(r)
                records.append(r)
                continue
            }

            // local volume check
            let isLocal = (try? item.url.resourceValues(forKeys: [.volumeIsLocalKey]))?.volumeIsLocal ?? true
            if !isLocal {
                let r = TrashRecord(
                    originalPath: path,
                    trashedPath: nil,
                    sizeBytes: item.sizeBytes,
                    decisionSource: "manual",
                    matchedRuleId: item.ruleMatch?.rule.id,
                    aiRecommendedAction: item.aiAnalysis?.recommendedAction.rawValue,
                    dryRun: dryRun,
                    success: false,
                    errorMessage: "Non-local volume (no Trash support)"
                )
                await auditLog.append(r)
                records.append(r)
                continue
            }

            if dryRun {
                let r = TrashRecord(
                    originalPath: path,
                    trashedPath: nil,
                    sizeBytes: item.sizeBytes,
                    decisionSource: "manual",
                    matchedRuleId: item.ruleMatch?.rule.id,
                    aiRecommendedAction: item.aiAnalysis?.recommendedAction.rawValue,
                    dryRun: true,
                    success: true,
                    errorMessage: nil
                )
                await auditLog.append(r)
                records.append(r)
                continue
            }

            do {
                var trashedURL: NSURL?
                try fm.trashItem(at: item.url, resultingItemURL: &trashedURL)
                let r = TrashRecord(
                    originalPath: path,
                    trashedPath: (trashedURL as URL?)?.path,
                    sizeBytes: item.sizeBytes,
                    decisionSource: "manual",
                    matchedRuleId: item.ruleMatch?.rule.id,
                    aiRecommendedAction: item.aiAnalysis?.recommendedAction.rawValue,
                    dryRun: false,
                    success: true,
                    errorMessage: nil
                )
                await auditLog.append(r)
                records.append(r)
            } catch {
                let r = TrashRecord(
                    originalPath: path,
                    trashedPath: nil,
                    sizeBytes: item.sizeBytes,
                    decisionSource: "manual",
                    matchedRuleId: item.ruleMatch?.rule.id,
                    aiRecommendedAction: item.aiAnalysis?.recommendedAction.rawValue,
                    dryRun: false,
                    success: false,
                    errorMessage: error.localizedDescription
                )
                await auditLog.append(r)
                records.append(r)
            }
        }

        lastBatch = records
        return records
    }

    func undoLastBatch() async -> [TrashRecord] {
        let fm = FileManager.default
        var results: [TrashRecord] = []
        results.reserveCapacity(lastBatch.count)

        for rec in lastBatch where rec.success && rec.dryRun == false {
            guard let trashedPath = rec.trashedPath else { continue }
            let from = URL(fileURLWithPath: trashedPath)
            let to = URL(fileURLWithPath: rec.originalPath)

            do {
                // best-effort: move back
                if fm.fileExists(atPath: to.path) {
                    // avoid overwrite
                    continue
                }
                try fm.moveItem(at: from, to: to)
                let r = TrashRecord(
                    originalPath: rec.originalPath,
                    trashedPath: rec.trashedPath,
                    sizeBytes: rec.sizeBytes,
                    decisionSource: "undo",
                    matchedRuleId: rec.matchedRuleId,
                    aiRecommendedAction: rec.aiRecommendedAction,
                    dryRun: false,
                    success: true,
                    errorMessage: nil
                )
                await auditLog.append(r)
                results.append(r)
            } catch {
                let r = TrashRecord(
                    originalPath: rec.originalPath,
                    trashedPath: rec.trashedPath,
                    sizeBytes: rec.sizeBytes,
                    decisionSource: "undo",
                    matchedRuleId: rec.matchedRuleId,
                    aiRecommendedAction: rec.aiRecommendedAction,
                    dryRun: false,
                    success: false,
                    errorMessage: error.localizedDescription
                )
                await auditLog.append(r)
                results.append(r)
            }
        }

        return results
    }

    func recentAudit(limit: Int = 50) async -> [TrashRecord] {
        await auditLog.readRecent(limit: limit)
    }

    func auditLogFileURL() async -> URL {
        await auditLog.fileURL()
    }
}

