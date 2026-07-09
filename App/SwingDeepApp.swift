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
    
    init() {
        // Firebase初期化
        FirebaseApp.configure()
        
        // デバッグビルドでのCrashlyticsコンテキスト設定
        #if DEBUG
        CrashLogger.shared.log("App launched (DEBUG)")
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            // アプリのルートビューをTabViewに変更
            MainTabView()
                // SwiftDataのコンテナを設定
                .modelContainer(for: [GolferProfile.self, SwingAnalysis.self])
        }
    }
}
