import SwiftUI
import Combine

// MARK: - アプリ言語

/// アプリでサポートする言語
///
/// ## 対応言語
/// - japanese: 日本語
/// - english: 英語
enum AppLanguage: String, CaseIterable, Identifiable {
    case japanese = "ja"
    case english = "en"
    
    // MARK: - Identifiable
    
    var id: String { rawValue }
    
    // MARK: - Display Properties
    
    /// 言語の表示名（各言語のネイティブ表記）
    var displayName: String {
        switch self {
        case .japanese: return "日本語"
        case .english: return "English"
        }
    }
    
    /// Localeオブジェクト
    var locale: Locale {
        return Locale(identifier: rawValue)
    }
}

// MARK: - 言語管理

/// アプリの言語設定を管理するシングルトン
///
/// ## 機能
/// - 現在の言語状態を保持
/// - 言語変更時にUserDefaultsに永続化
/// - ローカライズ文字列の取得
///
/// ## 使用例
/// ```swift
/// // 現在の言語を取得
/// let lang = LanguageManager.shared.currentLanguage
///
/// // 言語を変更
/// LanguageManager.shared.setLanguage(.english)
///
/// // ローカライズ文字列を取得
/// let text = "hello".localized
/// ```
class LanguageManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = LanguageManager()
    
    // MARK: - Properties
    
    /// 保存された言語設定（UserDefaults）
    @AppStorage("appLanguage") private var savedLanguage: String = "ja"
    
    /// 現在の言語（Published）
    @Published var currentLanguage: AppLanguage = .japanese
    
    // MARK: - Initialization
    
    private init() {
        loadSavedLanguage()
    }
    
    // MARK: - Public Methods
    
    /// 言語を設定する
    ///
    /// - Parameter language: 設定する言語
    ///
    /// - Note: この変更はUserDefaultsに永続化されます
    func setLanguage(_ language: AppLanguage) {
        self.currentLanguage = language
        self.savedLanguage = language.rawValue
    }
    
    /// キーに対応する翻訳テキストを取得する
    ///
    /// - Parameter key: ローカライズキー
    /// - Returns: 翻訳されたテキスト（キーが見つからない場合はキーをそのまま返す）
    func localized(_ key: String) -> String {
        let table = currentLanguage == .japanese ? AppStrings.japanese : AppStrings.english
        return table[key] ?? key
    }
    
    // MARK: - Private Methods
    
    /// 保存された言語設定を読み込む
    private func loadSavedLanguage() {
        if let lang = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = lang
        } else {
            // デフォルトは日本語
            self.currentLanguage = .japanese
        }
    }
}

// MARK: - String Extension

/// ローカライズ用のString拡張
extension String {
    /// このキーに対応するローカライズ文字列を返す
    ///
    /// ## 使用例
    /// ```swift
    /// let text = "hello".localized // → "こんにちは" or "Hello"
    /// ```
    var localized: String {
        LanguageManager.shared.localized(self)
    }
}
