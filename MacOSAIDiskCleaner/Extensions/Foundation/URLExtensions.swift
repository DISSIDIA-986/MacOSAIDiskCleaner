//
//  URLExtensions.swift
//  MacOSAIDiskCleaner
//
//  Created on 2026-02-05.
//

import Foundation

extension URL {
    /// 获取 URL 的规范路径（解析符号链接）
    ///
    /// 使用 `canonicalPathKey` 获取真实路径，防止通过符号链接
    /// 绕过安全检查。如果无法获取，返回标准路径。
    ///
    /// - Important: 对于安全敏感操作，应始终使用 `canonicalPath`
    ///   而不是 `path` 或 `standardizedPath`
    ///
    /// - Returns: 规范化的绝对路径
    ///
    /// # Example
    /// ```swift
    /// let symlink = URL(fileURLWithPath: "/Users/test/evil")
    /// // /Users/test/evil -> /System
    /// print(symlink.canonicalPath) // "/System"
    /// ```
    var canonicalPath: String {
        (try? resourceValues(forKeys: [.canonicalPathKey]))?.canonicalPath
        ?? path
    }

    /// 检查 URL 是否为系统保护路径
    ///
    /// - Returns: 如果路径在保护列表中返回 `true`
    var isProtectedSystemPath: Bool {
        FileScanner.isProtectedSystemPath(canonicalPath)
    }

    /// 检查 URL 是否在本地卷上
    ///
    /// - Returns: 如果是本地卷返回 `true`
    var isLocalVolume: Bool {
        (try? resourceValues(forKeys: [.volumeIsLocalKey]))?.volumeIsLocal ?? true
    }

    /// 获取文件的实际分配大小
    ///
    /// - Returns: 文件占用的字节数（包括块大小）
    var allocatedSize: Int64 {
        Int64(
            (try? resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?.totalFileAllocatedSize
            ?? (try? resourceValues(forKeys: [.fileAllocatedSizeKey]))?.fileAllocatedSize
            ?? (try? resourceValues(forKeys: [.fileSizeKey]))?.fileSize
            ?? 0
        )
    }

    /// 检查是否为符号链接
    var isSymlink: Bool {
        (try? resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink ?? false
    }

    /// 检查是否为目录
    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }

    /// 检查是否为 iCloud 占位符
    var isUbiquitousItem: Bool {
        (try? resourceValues(forKeys: [.isUbiquitousItemKey]))?.isUbiquitousItem ?? false
    }

    /// 检查 iCloud 文件是否已下载到本地
    var isUbiquitousItemDownloaded: Bool {
        guard isUbiquitousItem else { return true }
        return (try? resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]))?.ubiquitousItemDownloadingStatus == .current
    }
}
