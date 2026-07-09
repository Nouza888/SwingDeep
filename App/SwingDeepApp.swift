//
//  SwingDeepApp.swift
//  SwingDeep
//
//  Created by Nozo on 2025/11/23.
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct SwingDeepApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .modelContainer(for: [GolferProfile.self, SwingAnalysis.self])
        }
    }
}

/// Firebaseの初期化をUIKitのライフサイクルへ分離する。
/// 設定ファイルがない開発環境では、On-device機能だけで起動できるようにする。
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
            FirebaseApp.configure()

            #if DEBUG
            CrashLogger.shared.log("App launched (DEBUG)")
            #endif
        } else {
            #if DEBUG
            print("ℹ️ GoogleService-Info.plist is not bundled; cloud reporting is disabled.")
            #endif
        }

        return true
    }
}
