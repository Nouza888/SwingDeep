import SwiftUI
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case japanese = "ja"
    case english = "en"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .japanese: return "\u65E5\u672C\u8A9E"
        case .english: return "English"
        }
    }
    
    var locale: Locale { Locale(identifier: rawValue) }
}

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    @AppStorage("appLanguage") private var savedLanguage: String = "ja"
    @Published var currentLanguage: AppLanguage = .japanese
    
    private init() { loadSavedLanguage() }
    
    func setLanguage(_ language: AppLanguage) {
        self.currentLanguage = language
        self.savedLanguage = language.rawValue
    }
    
    func localized(_ key: String) -> String {
        let table = currentLanguage == .japanese ? AppStrings.japanese : AppStrings.english
        return table[key] ?? key
    }
    
    private func loadSavedLanguage() {
        if let lang = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = lang
        } else {
            self.currentLanguage = .japanese
        }
    }
}

extension String {
    var localized: String { LanguageManager.shared.localized(self) }
}
