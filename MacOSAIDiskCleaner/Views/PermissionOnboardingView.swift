import SwiftUI

struct PermissionOnboardingView: View {
    @ObservedObject var permissionManager: PermissionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("需要 Full Disk Access")
                .font(.title2.weight(.semibold))

            Text("""
为了安全扫描并识别系统与应用产生的垃圾文件，本应用需要你在「系统设置 → 隐私与安全性 → 完全磁盘访问权限」中开启权限。

说明：macOS 不支持应用直接弹出 Full Disk Access 授权框，只能由你手动开启。
""")
            .font(.body)

            HStack(spacing: 12) {
                Button("打开系统设置") {
                    permissionManager.openFullDiskAccessSystemSettings()
                }
                Button("重新检测") {
                    permissionManager.refresh()
                }
            }

            Text("当前状态：\(permissionManager.fullDiskAccessStatus == .granted ? "已授权" : "未授权")")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: 720)
        .onAppear { permissionManager.refresh() }
    }
}

