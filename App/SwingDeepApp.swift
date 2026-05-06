import SwiftUI
import SwiftData
import FirebaseCore

/// SwingDeepアプリのエントリーポイント
/// Firebase初期化とSwiftDataモデルコンテナの設定を行います
@main
struct SwingDeepApp: App {
    
    // MARK: - Firebase Initialization
    
    /// Firebase初期化用のAppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: SwingAnalysis.self)
    }
}

// MARK: - App Delegate

/// Firebase初期化を担当するAppDelegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}
