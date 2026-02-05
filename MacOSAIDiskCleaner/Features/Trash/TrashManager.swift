import Foundation
import os

actor TrashManager {
    private let auditLog = AuditLog()
    private var lastBatch: [TrashRecord] = []

    func trash(items: [CandidateItem], dryRun: Bool, settings: SettingsViewModel) async -> [TrashRecord] {
        // 🔧 SECURITY FIX: 强制从设置读取 dry-run 状态，防止绕过
        let actualDryRun = await settings.dryRun || dryRun

        let fm = FileManager.default
        var records: [TrashRecord] = []
        records.reserveCapacity(items.count)

        for item in items {
            if Task.isCancelled { break }

            let path = item.url.path

            // 🔧 P0-2 FIX: extra safety - use canonical path to prevent symlink attacks
            let canonicalPath = (try? item.url.resourceValues(forKeys: [.canonicalPathKey]))?.canonicalPath
                              ?? (path as NSString).standardizingPath

            if FileScanner.isProtectedSystemPath(canonicalPath) {
                let r = TrashRecord(
                    originalPath: path,
                    trashedPath: nil,
                    sizeBytes: item.sizeBytes,
                    decisionSource: "manual",
                    matchedRuleId: item.ruleMatch?.rule.id,
                    aiRecommendedAction: item.aiAnalysis?.recommendedAction.rawValue,
                    dryRun: actualDryRun,
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
                    dryRun: actualDryRun,
                    success: false,
                    errorMessage: "Non-local volume (no Trash support)"
                )
                await auditLog.append(r)
                records.append(r)
                continue
            }

            if actualDryRun {
                let r = TrashRecord(
                    originalPath: path,
                    trashedPath: nil,
                    sizeBytes: item.sizeBytes,
                    decisionSource: "manual",
                    matchedRuleId: item.ruleMatch?.rule.id,
                    aiRecommendedAction: item.aiAnalysis?.recommendedAction.rawValue,
                    dryRun: actualDryRun,
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
                    dryRun: actualDryRun,
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
                    dryRun: actualDryRun,
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

