import SwiftUI
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case japanese = "ja"
    case english = "en"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .japanese: return "日本語"
        case .english: return "English"
        }
    }
    
    var locale: Locale {
        return Locale(identifier: rawValue)
    }
}

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @AppStorage("appLanguage") private var savedLanguage: String = "ja"
    @Published var currentLanguage: AppLanguage = .japanese
    
    private init() {
        // 保存された言語設定を読み込む
        if let lang = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = lang
        } else {
            // デフォルトは日本語（または端末設定に合わせるロジックも可）
            self.currentLanguage = .japanese
        }
    }
    
    func setLanguage(_ language: AppLanguage) {
        self.currentLanguage = language
        self.savedLanguage = language.rawValue
    }
    
    /// キーに対応する翻訳テキストを取得する
    func localized(_ key: String) -> String {
        let table = currentLanguage == .japanese ? AppStrings.japanese : AppStrings.english
        return table[key] ?? key
    }
}

// SwiftUIで使いやすくするための拡張
extension String {
    var localized: String {
        LanguageManager.shared.localized(self)
    }
}
