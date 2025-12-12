import Foundation

struct AppStrings {
    static let japanese: [String: String] = [
        // Tabs
        "tab_diagnose": "分析",
        "tab_history": "履歴",
        "tab_settings": "設定",
        
        // History
        "history_title": "履歴",
        "history_section_title": "診断履歴",
        "history_empty": "まだ履歴がありません",
        "analyzing_status": "解析中...",
        
        // Analysis View
        "diagnose_title": "AIスイング分析",
        "select_video": "動画を選択",
        "delete_video": "動画を削除",
        "analyzing": "AIコーチが分析中...",
        "analyze_swing": "コーチを選択する", // Flow Change: First step
        "start_analysis": "分析を開始する",   // Flow Change: Second step
        "view_report": "レポートを見る",
        "close": "閉じる",
        "share_result": "分析結果をシェア",
        "no_data": "分析データがありません",
        "retry": "再試行",
        "error_video_too_long": "動画が長すぎます（2分以内）",
        "error_skeleton_extraction_failed": "スイングを検出できませんでした。全身が映っている動画を使用してください。",
        "coach_comment": "コーチからのコメント",
        "diagnosis_detail": "詳細分析",
        "severity": "重要度",
        "prescription_drill": "処方箋ドリル",
        "premium_unlock": "Premiumで詳細を表示",
        "swing_rank": "Swing Rank",
        "total_score": "Total Score",
        "playback_speed": "再生速度",
        "set_address": "アドレスを設定",
        "set_impact": "インパクトを設定",

        "ghost_toggle": "ゴーストを表示",
        "guide_overlay_message": "アドレスとインパクトのタイミングを指定してください",
        
        // Chat UI
        "analysis_complete": "分析が完了しました！",
        "coach_typing": "入力中...",
        "tap_to_view_details": "タップして詳細を見る",
        "locked_content": "Premiumコンテンツ",
        "unlock_to_view": "ロックを解除して表示",

        
        // Empty State
        "empty_state_title": "動画を選択してください",
        "analysis_tips_title": "正確な分析のために",
        "tip_camera": "iPhone標準カメラで撮影",
        "tip_fixed": "開始から終了までカメラを固定",
        "tip_angle": "後方（Down The Line）から撮影",
        
        // Settings
        "settings_title": "設定",
        "plan_settings": "プラン設定",
        "current_plan": "現在のプラン",
        "upgrade_premium": "プレミアムにアップグレード",
        "coach_settings": "AIコーチ設定",
        "default_coach": "デフォルトのコーチ",
        "coach_note": "※ 分析時に毎回変更することも可能です",
        "language_settings": "言語 / Language",
        "app_info": "アプリ情報",
        "version": "バージョン",
        "terms": "利用規約",
        "privacy": "プライバシーポリシー",
        
        // Coach Names & Descriptions
        "coach_normal": "標準",
        "coach_spartan": "鬼軍曹",
        "coach_kind": "お姉さん",
        "coach_kansai_mom": "関西おかん",
        "coach_comedian": "芸人",
        
        "desc_normal": "データに基づいた冷静かつ論理的な分析を行います。",
        "desc_spartan": "甘えを許さない厳しい指導で、徹底的に鍛え上げます。",
        "desc_kind": "優しく褒めて伸ばすスタイル。初心者の方におすすめです。",
        "desc_kansai_mom": "愛のあるツッコミとお節介で、親身にアドバイスします。",
        "desc_comedian": "ユニークな例え話で、楽しみながらスイング改善できます。",
        
        // Coach Selection
        "select_coach_title": "コーチ選択",
        "select_coach_desc": "あなたのスイングを分析する専属コーチを選んでください",
        "cancel": "キャンセル"
    ]
    
    static let english: [String: String] = [
        // Tabs
        "tab_diagnose": "Analysis",
        "tab_history": "History",
        "tab_settings": "Settings",
        
        // History
        "history_title": "History",
        "history_section_title": "Diagnosis History",
        "history_empty": "No history yet",
        "analyzing_status": "Analyzing...",
        
        // Analysis View
        "diagnose_title": "AI Swing Analysis",
        "select_video": "Select Video",
        "delete_video": "Delete Video",
        "analyzing": "AI Coach is analyzing...",
        "analyze_swing": "Select Coach", // Flow Change: First step
        "start_analysis": "Start Analysis", // Flow Change: Second step
        "view_report": "View Report",
        "close": "Close",
        "share_result": "Share Result",
        "no_data": "No analysis data",
        "retry": "Retry",
        "error_video_too_long": "Video is too long (Max 2 min)",
        "error_skeleton_extraction_failed": "Could not detect swing. Please use a video showing full body.",
        "coach_comment": "Coach's Comment",
        "diagnosis_detail": "Analysis Detail",
        "severity": "Severity",
        "prescription_drill": "Drill",
        "premium_unlock": "Unlock with Premium",
        "swing_rank": "Swing Rank",
        "total_score": "Total Score",
        "playback_speed": "Speed",
        "set_address": "Set Address",
        "set_impact": "Set Impact",

        "ghost_toggle": "Show Ghost",
        "guide_overlay_message": "Set Address and Impact timing",
        
        // Chat UI
        "analysis_complete": "Analysis Complete!",
        "coach_typing": "Coach is typing...",
        "tap_to_view_details": "Tap to view details",
        "locked_content": "Premium Content",
        "unlock_to_view": "Unlock to view",

        
        // Empty State
        "empty_state_title": "Please select a video",
        "analysis_tips_title": "For Accurate Analysis",
        "tip_camera": "Use iPhone standard camera",
        "tip_fixed": "Keep camera fixed",
        "tip_angle": "Film from Down The Line (DTL)",
        
        // Settings
        "settings_title": "Settings",
        "plan_settings": "Plan Settings",
        "current_plan": "Current Plan",
        "upgrade_premium": "Upgrade to Premium",
        "coach_settings": "AI Coach Settings",
        "default_coach": "Default Coach",
        "coach_note": "* You can change this for each analysis",
        "language_settings": "Language",
        "app_info": "App Info",
        "version": "Version",
        "terms": "Terms of Service",
        "privacy": "Privacy Policy",
        
        // Coach Names & Descriptions
        "coach_normal": "Standard",
        "coach_spartan": "Drill Sergeant",
        "coach_kind": "Supportive Sister",
        "coach_kansai_mom": "Hollywood Hero", // Mapping Kansai Mom to Hollywood Hero for EN
        "coach_comedian": "British Butler", // Mapping Comedian to British Butler for EN
        
        "desc_normal": "Provides calm, logical analysis based on data.",
        "desc_spartan": "Strict guidance with no excuses. Toughens you up.",
        "desc_kind": "Praises and encourages. Recommended for beginners.",
        "desc_kansai_mom": "Dramatic and inspiring feedback like a movie star.",
        "desc_comedian": "Polite, dry wit, and sophisticated advice.",
        
        // Coach Selection
        "select_coach_title": "Select Coach",
        "select_coach_desc": "Choose your personal AI coach for this analysis",
        "cancel": "Cancel"
    ]
}
