//
//  SwingDeepApp.swift
//  SwingDeep
//
//  Created by Nozo on 2025/11/23.
//  githubaaa

import SwiftUI
import SwiftData

@main
struct SwingDeepApp: App {
    var body: some Scene {
        WindowGroup {
            // アプリのルートビューをTabViewに変更
            MainTabView()
                // SwiftDataのコンテナを設定
                .modelContainer(for: [GolferProfile.self, SwingAnalysis.self])
        }
    }
}

