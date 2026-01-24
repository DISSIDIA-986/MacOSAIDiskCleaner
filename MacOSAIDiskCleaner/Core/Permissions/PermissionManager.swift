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
        let hasPermission = Self.checkFullDiskAccess()
        fullDiskAccessStatus = hasPermission ? .granted : .notGranted
        Logger.scanner.info("Full Disk Access status: \(String(describing: self.fullDiskAccessStatus)), detected: \(hasPermission)")
    }

    /// 通过尝试访问受保护目录来"探测"是否已开启 FDA。
    static func checkFullDiskAccess() -> Bool {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        // 测试多个可能的受保护路径，提高检测成功率
        let candidates: [(URL, String)] = [
            // TCC 数据库 - 最可靠的测试路径
            (home.appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db"), "TCC.db"),
            // Safari 数据 - 大多数用户都有
            (home.appendingPathComponent("Library/Safari"), "Safari"),
            // Mail 数据
            (home.appendingPathComponent("Library/Mail"), "Mail"),
            // Messages 数据
            (home.appendingPathComponent("Library/Messages"), "Messages"),
        ]

        for (url, name) in candidates {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else {
                // 路径不存在，跳过
                continue
            }

            do {
                if isDir.boolValue {
                    // 尝试列出目录内容
                    _ = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
                    // 成功！有 Full Disk Access
                    return true
                } else {
                    // 尝试读取文件属性
                    _ = try fm.attributesOfItem(atPath: url.path)
                    // 成功！有 Full Disk Access
                    return true
                }
            } catch {
                // 访问被拒绝，继续尝试下一个路径
                continue
            }
        }

        // 所有路径都无法访问，没有 Full Disk Access
        return false
    }

    func openFullDiskAccessSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else { return }
        NSWorkspace.shared.open(url)
    }
}
