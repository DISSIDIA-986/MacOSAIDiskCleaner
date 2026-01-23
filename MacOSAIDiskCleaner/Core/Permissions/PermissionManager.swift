import AppKit
import Foundation
import os

enum FullDiskAccessStatus: Equatable {
    case granted
    case notGranted
}

/// 负责 Full Disk Access 引导与探测。
///
/// 注意：macOS 不支持“代码弹窗请求 FDA”，只能引导用户打开系统设置手动开启。
@MainActor
final class PermissionManager: ObservableObject {
    @Published private(set) var fullDiskAccessStatus: FullDiskAccessStatus = .notGranted

    func refresh() {
        fullDiskAccessStatus = Self.checkFullDiskAccess() ? .granted : .notGranted
        Logger.system.info("Full Disk Access status: \(String(describing: self.fullDiskAccessStatus))")
    }

    /// 通过尝试访问受保护目录来“探测”是否已开启 FDA。
    static func checkFullDiskAccess() -> Bool {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        let candidates: [URL] = [
            // 通常存在且受 TCC/FDA 保护
            home.appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db"),
            home.appendingPathComponent("Library/Mail", isDirectory: true),
            home.appendingPathComponent("Library/Messages", isDirectory: true),
        ]

        for url in candidates {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }
            do {
                if isDir.boolValue {
                    _ = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                    return true
                } else {
                    _ = try fm.attributesOfItem(atPath: url.path)
                    return true
                }
            } catch {
                continue
            }
        }
        return false
    }

    func openFullDiskAccessSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else { return }
        NSWorkspace.shared.open(url)
    }
}
