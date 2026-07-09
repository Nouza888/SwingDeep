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
        "analyzing": "%@が分析中...",  // ペルソナ名が入る
        "analyze_swing": "コーチを選択する",
        "start_analysis": "分析を開始する",
        "view_report": "レポートを作成",
        "generate_report": "レポートを作成",
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
        "ready_to_generate": "レポートを作成する準備ができました",
        
        // Frame Navigation
        "slider_hint": "スライダーをドラッグして位置を設定",
        "previous_frame": "1コマ戻す",
        "next_frame": "1コマ進む",
        
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
        
        // Coach Names & Descriptions (短縮版)
        "coach_gentle_sister": "お姉さん",
        "coach_spartan": "鬼軍曹",
        "coach_standard": "理論派コーチ",
        "coach_comedian": "ツッコミ芸人",
        "coach_gal": "ギャル",
        "coach_toxic_pro": "毒舌プロ",
        
        "desc_gentle_sister": "穏やかで優しい。長所を見つけるのが得意。",
        "desc_spartan": "容赦なし。言い訳不可。",
        "desc_standard": "データ重視の標準コーチ。",
        "desc_comedian": "ミスは笑う。要点は鋭い。",
        "desc_gal": "ノリと勢いでモチベを上げる。",
        "desc_toxic_pro": "回りくどい説明はしない。",
        
        "quote_gentle_sister": "「できてる所、ちゃんと見えてるからね。」",
        "quote_spartan": "「できない理由は聞かん。やるか、死ぬ気でやるかだ」",
        "quote_standard": "数値と事実でスイングを分解。",
        "quote_comedian": "「いや、そこは打つ前に気づかんかい」",
        "quote_gal": "「え待って？ 今の普通に笑っちゃったw」",
        "quote_toxic_pro": "「このまま続けたら、同じミスを繰り返す。」",
        
        // Coach Selection
        "select_coach_title": "コーチ選択",
        "select_coach_desc": "あなたのスイングを分析する専属コーチを選んでください",
        "cancel": "キャンセル",
        
        // Error Messages (LLM / Usage)
        "error_validation": "入力データに問題があります。再度お試しください。",
        "error_payload_too_large": "データが大きすぎます。短い動画でお試しください。",
        "error_rate_limit": "リクエストが多すぎます。しばらくお待ちください。",
        "error_provider": "AIサービスが一時的に利用できません。しばらくしてから再試行してください。",
        "error_timeout": "タイムアウトしました。再度お試しください。",
        "error_network": "ネットワークに接続できません。接続を確認して再試行してください。",
        "error_unknown": "予期しないエラーが発生しました。再度お試しください。",
        "error_usage_limit_reached": "今月の無料枠を使い切りました。来月1日にリセットされます。",
        "remaining_count": "残り%d回",
        "usage_limit_title": "利用制限",
        
        // Usage Status (Settings)
        "usage_status": "利用状況",
        "monthly_usage": "今月の利用",
        "next_reset": "次回リセット",
        "total_reports": "累計レポート",
        "reports_used": "%d回使用済み",
        "unlimited": "無制限",
        "reports_count": "%d回",
        
        // Graph Metrics
        "metric_total_score": "総合スコア",
        "metric_spine_angle": "前傾キープ",
        "metric_tempo": "切り返しリズム",
        "metric_swing_path": "スイング軌道",
        "metric_head_movement": "頭の安定感",
        "metric_hand_position": "インパクト時の手元",
        "metric_early_extension": "腰の伸び上がり",
        
        // Graph Axis
        "graph_attempt": "%d回目",
        
        // Remaining Usage Display
        "remaining_display": "残り %d/%d",
        "monthly_remaining": "今月の残り: %d/%d回",
        
        // Diagnosis Report
        "detail_analysis": "詳細分析",
        "improvement_drill": "改善ドリル",
        "drill_steps": "手順",
        "drill_caution": "注意",
        "drill_locked": "改善ドリルはロックされています",
        "drill_time": "%d分",
        "check_plan": "プランを確認する",
        
        // Graph
        "graph_data_insufficient": "データが不足しています（2件以上必要）",
        "graph_premium_locked": "スコア推移グラフを確認できます",
        "premium_feature": "Premium限定機能",
        "standard_unlock": "Standardプラン以上で\nロックが解除されます",
        
        // Overlay
        "overlay_early_extension": "起き上がり",
        
        // Improvement Drills Section
        "improvement_drills_title": "今回の改善ドリル",
        "improvement_drills_sub": "まずはここだけでOK",
        "improvement_target": "改善対象項目:"
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
        "analyzing": "%@ is analyzing...",  // ペルソナ名が入る
        "analyze_swing": "Select Coach",
        "start_analysis": "Start Analysis",
        "view_report": "Generate Report",
        "generate_report": "Generate Report",
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
        "ready_to_generate": "Ready to Generate Report",
        
        // Frame Navigation
        "slider_hint": "Drag the slider to set the timing",
        "previous_frame": "Previous frame",
        "next_frame": "Next frame",
        
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
        
        // Coach Names & Descriptions (短縮版)
        "coach_gentle_sister": "Big Sis",
        "coach_spartan": "Drill Sergeant",
        "coach_standard": "Analyst",
        "coach_comedian": "Comedian",
        "coach_gal": "Hype Girl",
        "coach_toxic_pro": "Tough Pro",
        
        "desc_gentle_sister": "Calm and kind. Finds your strengths.",
        "desc_spartan": "No mercy. No excuses.",
        "desc_standard": "Data-driven standard coach.",
        "desc_comedian": "Laughs at mistakes. Sharp on points.",
        "desc_gal": "Vibes and energy to boost you up.",
        "desc_toxic_pro": "No sugarcoating.",
        
        "quote_gentle_sister": "\"I can see what you're doing right.\"",
        "quote_spartan": "\"I don't want excuses. Do or die.\"",
        "quote_standard": "Breaking down your swing with facts.",
        "quote_comedian": "\"Wait, you didn't notice that before hitting?\"",
        "quote_gal": "\"OMG wait, that was actually funny lol\"",
        "quote_toxic_pro": "\"Keep this up and you'll repeat the same mistake.\"",
        
        // Coach Selection
        "select_coach_title": "Select Coach",
        "select_coach_desc": "Choose your personal AI coach for this analysis",
        "cancel": "Cancel",
        
        // Error Messages (LLM / Usage)
        "error_validation": "There was an issue with the input data. Please try again.",
        "error_payload_too_large": "Data is too large. Please try with a shorter video.",
        "error_rate_limit": "Too many requests. Please wait a moment.",
        "error_provider": "AI service is temporarily unavailable. Please try again later.",
        "error_timeout": "Request timed out. Please try again.",
        "error_network": "Cannot connect to the network. Please check your connection and try again.",
        "error_unknown": "An unexpected error occurred. Please try again.",
        "error_usage_limit_reached": "You've used all free analyses this month. Resets on the 1st.",
        "remaining_count": "%d left",
        "usage_limit_title": "Usage Limit",
        
        // Usage Status (Settings)
        "usage_status": "Usage Status",
        "monthly_usage": "This Month",
        "next_reset": "Next Reset",
        "total_reports": "Total Reports",
        "reports_used": "%d reports used",
        "unlimited": "Unlimited",
        "reports_count": "%d reports",
        
        // Graph Metrics
        "metric_total_score": "Overall Score",
        "metric_spine_angle": "Spine Angle Consistency",
        "metric_tempo": "Transition Tempo",
        "metric_swing_path": "Swing Path",
        "metric_head_movement": "Head Stability",
        "metric_hand_position": "Hand Position",
        "metric_early_extension": "Early Extension",
        
        // Graph Axis
        "graph_attempt": "#%d",
        
        // Remaining Usage Display
        "remaining_display": "%d/%d left",
        "monthly_remaining": "This month: %d/%d",
        
        // Diagnosis Report
        "detail_analysis": "Detailed Analysis",
        "improvement_drill": "Improvement Drill",
        "drill_steps": "Steps",
        "drill_caution": "Caution",
        "drill_locked": "Improvement Drill is locked",
        "drill_time": "%d min",
        "check_plan": "Check Plan",
        
        // Graph
        "graph_data_insufficient": "Insufficient data (2+ required)",
        "graph_premium_locked": "View score trend graph",
        "premium_feature": "Premium Feature",
        "standard_unlock": "Unlock with Standard plan\\nor higher",
        
        // Overlay
        "overlay_early_extension": "Early Extension",
        
        // Improvement Drills Section
        "improvement_drills_title": "Today's Practice Drills",
        "improvement_drills_sub": "Focus on just this for now",
        "improvement_target": "Target:"
    ]
}

