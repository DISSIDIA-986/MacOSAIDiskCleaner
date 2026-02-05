import Foundation
import os

/// Phase 1/2 使用的安全扫描器：负责安全边界、防御性遍历、并流式产生 UI 需要的聚合数据。
actor FileScanner {
    private let fileManager = FileManager.default

    /// 关键：系统保护路径（硬编码安全名单）。这些路径永远不扫描、不清理。
    static let systemProtectedPrefixes: [String] = [
        "/System",
        "/usr",
        "/bin",
        "/sbin",
        "/private/var/db",
        "/Library/Apple",
        "/.Trashes",
        "/.Spotlight-V100",
        "/.fseventsd",
        "/Volumes/.timemachine",
    ]

    struct ScanProgress: Sendable, Equatable {
        var visitedEntries: Int = 0
        var countedFiles: Int = 0
        var countedBytes: Int64 = 0
    }

    struct ScanOptions: Sendable {
        var skipICloudPlaceholders: Bool = true
        var requireLocalVolume: Bool = true
    }

    /// 扫描 `root` 下的所有文件，并将「顶层子目录/文件」做 size 聚合后回调给 UI。
    ///
    /// - 防御：Symlink 不进入、iCloud 占位符不触发下载、系统保护路径跳过、支持取消。
    func scanTopLevelAggregates(
        root: URL,
        options: ScanOptions = .init(),
        onProgress: @Sendable (ScanProgress) -> Void,
        onUpdate: @Sendable (ScannedItem) -> Void
    ) throws {
        // 🔧 P0 FIX: 使用 canonical path 防止符号链接绕过保护检查
        let rootPath = (try? root.resourceValues(forKeys: [.canonicalPathKey]))?.canonicalPath
                     ?? (root.path as NSString).standardizingPath

        if Self.isProtectedSystemPath(rootPath) {
            throw DiskCleanerError.permissionDenied(rootPath)
        }

        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .fileSizeKey,
            .volumeIdentifierKey,
            .volumeIsLocalKey,
            .fileResourceIdentifierKey,
        ]

        // Root volume constraints (local volume only, by default)
        let rootValues = try? root.resourceValues(forKeys: [.volumeIdentifierKey, .volumeIsLocalKey])
        if options.requireLocalVolume, rootValues?.volumeIsLocal == false {
            throw DiskCleanerError.permissionDenied("Non-local volume: \(rootPath)")
        }
        let rootVolumeId = rootValues?.volumeIdentifier as? NSObject

        var progress = ScanProgress()
        var topLevelSizes: [URL: Int64] = [:]
        var topLevelIsDir: [URL: Bool] = [:]
        var seenResourceIds: Set<AnyHashable> = []

        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants],
            errorHandler: { url, error in
                Logger.scanner.error("Error accessing \(url.path): \(error.localizedDescription)")
                return true
            }
        ) else {
            throw DiskCleanerError.permissionDenied(rootPath)
        }

        for case let url as URL in enumerator {
            if Task.isCancelled { throw DiskCleanerError.scanCancelled }
            progress.visitedEntries += 1

            // 🔧 P0-2 FIX: 使用 canonical path 防止符号链接绕过保护检查
            let canonicalPath = (try? url.resourceValues(forKeys: [.canonicalPathKey]))?.canonicalPath
                              ?? (url.path as NSString).standardizingPath

            // 系统保护路径：跳过且不深入
            if Self.isProtectedSystemPath(canonicalPath) {
                enumerator.skipDescendants()
                continue
            }

            let values = try? url.resourceValues(forKeys: keys)
            let isDir = values?.isDirectory ?? false
            let isSymlink = values?.isSymbolicLink ?? false

            // Symlink 防御：不进入
            if isSymlink {
                if isDir { enumerator.skipDescendants() }
                continue
            }

            // iCloud 占位符防御：避免触发下载
            if options.skipICloudPlaceholders, (values?.isUbiquitousItem ?? false) {
                if values?.ubiquitousItemDownloadingStatus != .current {
                    if isDir { enumerator.skipDescendants() }
                    continue
                }
            }

            // Volume boundary / firmlink / external volumes: stick to root volume id when present
            if let rootVolumeId, let curVolumeId = (values?.volumeIdentifier as? NSObject), !curVolumeId.isEqual(rootVolumeId) {
                if isDir { enumerator.skipDescendants() }
                continue
            }

            // inode / resource identifier dedupe (hardlinks / clones)
            if let rid = values?.fileResourceIdentifier as? AnyHashable {
                if seenResourceIds.contains(rid) {
                    continue
                }
                seenResourceIds.insert(rid)
            }

            guard !isDir else { continue }
            let size = Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? values?.fileSize ?? 0)
            guard size > 0 else { continue }

            progress.countedFiles += 1
            progress.countedBytes += size

            guard canonicalPath.hasPrefix(rootPath + "/") else { continue }
            let relative = String(canonicalPath.dropFirst((rootPath + "/").count))
            guard let firstComponent = relative.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true).first else { continue }
            let topURL = root.appendingPathComponent(String(firstComponent), isDirectory: false)

            if topLevelIsDir[topURL] == nil {
                var isDirTop: ObjCBool = false
                _ = fileManager.fileExists(atPath: topURL.path, isDirectory: &isDirTop)
                topLevelIsDir[topURL] = isDirTop.boolValue
            }

            topLevelSizes[topURL, default: 0] += size
            onUpdate(
                ScannedItem(
                    id: topURL,
                    url: topURL,
                    isDirectory: topLevelIsDir[topURL] ?? false,
                    sizeBytes: topLevelSizes[topURL] ?? 0
                )
            )

            // 轻量进度：每 256 次回调一次，避免 UI 过载（UI 侧仍会 BatchUpdater 聚合）
            if (progress.visitedEntries & 0xFF) == 0 {
                onProgress(progress)
            }
        }

        onProgress(progress)
    }

    static func isProtectedSystemPath(_ standardizedPath: String) -> Bool {
        for prefix in systemProtectedPrefixes {
            if standardizedPath == prefix || standardizedPath.hasPrefix(prefix + "/") {
                return true
            }
        }
        return false
    }
    
    /// Quick estimate of total files in directory (for progress percentage).
    /// Uses skipDescendants to avoid deep traversal.
    nonisolated func estimateTotalFiles(root: URL) async -> Int {
        // 🔧 P0-2 FIX: 使用 canonical path 防止符号链接绕过保护检查
        let rootPath = (try? root.resourceValues(forKeys: [.canonicalPathKey]))?.canonicalPath
                     ?? (root.path as NSString).standardizingPath
        guard !Self.isProtectedSystemPath(rootPath) else { return 0 }
        
        return await withCheckedContinuation { continuation in
            Task.detached {
                var count = 0
                let fm = FileManager.default
                guard let enumerator = fm.enumerator(
                    at: root,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else {
                    continuation.resume(returning: 0)
                    return
                }
                
                while let url = enumerator.nextObject() as? URL {
                    if Task.isCancelled { break }
                    count += 1
                    // Skip descendants for directories to speed up estimation
                    if let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory, isDir {
                        enumerator.skipDescendants()
                    }
                    // Limit estimation to avoid long delays
                    if count >= 10_000 {
                        break
                    }
                }
                continuation.resume(returning: count)
            }
        }
    }
}
