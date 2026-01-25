import SwiftUI

@main
struct MacOSAIDiskCleanerApp: App {
    @StateObject private var viewModel = DiskCleanerViewModel()
    @StateObject private var updateManager = UpdateManager()

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: viewModel)
                .frame(minWidth: 980, minHeight: 640)
                .task {
                    // One-time migration from audit.log into statistics
                    let key = "StatisticsMigratedFromAuditLog"
                    if !UserDefaults.standard.bool(forKey: key) {
                        let stats = StatisticsManager()
                        let audit = AuditLog()
                        await stats.migrateFromAuditLog(auditLog: audit)
                        UserDefaults.standard.set(true, forKey: key)
                    }
                }
        }
        .windowStyle(.automatic)

        Settings {
            SettingsView(viewModel: viewModel.settings)
        }
        
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updateManager.checkForUpdates()
                }
            }
        }
    }
}

