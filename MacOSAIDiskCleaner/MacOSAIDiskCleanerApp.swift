import SwiftUI

@main
struct MacOSAIDiskCleanerApp: App {
    @StateObject private var viewModel = DiskCleanerViewModel()
    @StateObject private var updateManager = UpdateManager()

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: viewModel)
                .frame(minWidth: 980, minHeight: 640)
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

