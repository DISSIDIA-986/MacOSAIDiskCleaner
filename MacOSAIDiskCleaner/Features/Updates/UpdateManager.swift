import AppKit
import Foundation

#if canImport(Sparkle)
import Sparkle
#endif

/// Manages Sparkle auto-update integration for MacOSAIDiskCleaner
@MainActor
final class UpdateManager: ObservableObject {
    // MARK: - Published Properties

    /// Whether Sparkle is available and properly configured
    @Published var canCheckForUpdates = false

    /// Whether automatic update checks are enabled
    @Published var automaticallyChecksForUpdates = false

    #if canImport(Sparkle)
    private let updaterController: SPUStandardUpdaterController

    private var updater: SPUUpdater {
        updaterController.updater
    }
    #endif

    // MARK: - Initialization

    init() {
        #if canImport(Sparkle)
        // Initialize with delegate for better control
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )

        // Load current configuration
        self.canCheckForUpdates = true
        self.automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        #else
        self.canCheckForUpdates = false
        self.automaticallyChecksForUpdates = false
        #endif
    }

    // MARK: - Public Methods

    /// Trigger manual update check from UI
    func checkForUpdates() {
        #if canImport(Sparkle)
        updaterController.checkForUpdates(nil)
        #else
        showSparkleNotIntegratedAlert()
        #endif
    }

    /// Get current app version (e.g., "0.1.0")
    func getCurrentVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    /// Get current build version (e.g., "1")
    func getCurrentBuildVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    /// Toggle automatic update checks
    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        #if canImport(Sparkle)
        updater.automaticallyChecksForUpdates = enabled
        automaticallyChecksForUpdates = enabled
        #endif
    }

    // MARK: - Private Methods

    private func showSparkleNotIntegratedAlert() {
        let alert = NSAlert()
        alert.messageText = "Sparkle 未集成"
        alert.informativeText = """
        当前工程未添加 Sparkle 依赖。

        请按照以下步骤启用自动更新：
        1. 在 Xcode 中打开项目设置
        2. 选择 "Package Dependencies" 标签
        3. 添加 Sparkle: https://github.com/sparkle-project/Sparkle
        4. 选择版本 2.x
        5. 重新构建应用
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - SPUUpdaterDelegate

#if canImport(Sparkle)
extension UpdateManager: SPUUpdaterDelegate {
    /// Callback when an update is found
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        Logger.appupdates.info("Found update: \(item.versionString)")
    }

    /// Callback when no update is available
    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error?) {
        if let error = error {
            Logger.appupdates.error("No update found: \(error.localizedDescription)")
        } else {
            Logger.appupdates.info("Already on latest version")
        }
    }

    /// Callback when update download completes
    func updater(_ updater: SPUUpdater, didFinishDownloading item: SUAppcastItem) {
        Logger.appupdates.info("Downloaded update: \(item.versionString)")
    }

    /// Callback when update installation finishes
    func updater(_ updater: SPUUpdater, didFinishUpdate item: SUAppcastItem, error: Error?) {
        if let error = error {
            Logger.appupdates.error("Update failed: \(error.localizedDescription)")
        } else {
            Logger.appupdates.info("Update successful: \(item.versionString)")
        }
    }

    /// Allow automatic installation of major updates (optional)
    func updater(_ updater: SPUUpdater, shouldAllowApplicationToQuitForUpdate item: SUAppcastItem) -> Bool {
        // Default behavior: allow quitting for updates
        true
    }
}
#endif

