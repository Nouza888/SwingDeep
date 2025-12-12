import SwiftUI
import UIKit

// MARK: - Control Area & Buttons

/// コントロールエリア（下部シート）
/// - 動画の再生コントロール、設定ボタン、診断実行ボタンを含む統合UIです
/// - Note: ガラスモーフィズム風のデザインを採用しています
struct ControlArea: View {
    @ObservedObject var viewModel: VideoViewModel
    @Binding var showReport: Bool
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md.rawValue) {
            // Status Guide
            if let guideText = getGuideText() {
                HStack(spacing: Theme.Spacing.xs.rawValue) {
                    Image(systemName: getGuideIcon())
                        .font(.system(size: 12, weight: .semibold))
                    Text(guideText)
                        .font(.system(size: 11))
                }
                .foregroundColor(getGuideColor())
                .padding(.horizontal, Theme.Spacing.sm.rawValue)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(getGuideColor().opacity(0.1))
                )
            }
            // Seek Bar
            CustomSlider(
                value: Binding(
                    get: { viewModel.currentTime },
                    set: { viewModel.seek(to: $0) }
                ),
                range: 0...viewModel.duration,
                addressTime: viewModel.addressTime,
                impactTime: viewModel.impactTime,
                duration: viewModel.duration,
                onEditingChanged: { editing in
                    if editing { viewModel.startSeeking() } else { viewModel.endSeeking() }
                }
            )
            
            // Playback Controls
            PlaybackControls(viewModel: viewModel)
            
            // Settings Buttons
            SettingsButtons(viewModel: viewModel)
            
            // Analyze Button
            if viewModel.canAnalyze {
                AnalyzeButton(viewModel: viewModel, showReport: $showReport)
            }
        }
        .padding(Theme.Spacing.md.rawValue)
        .glassCard(elevation: .medium)
    }
    
    private func getGuideText() -> String? {
        switch viewModel.status {
        case .setting: return "スライダーをドラッグして位置を設定"
        case .complete: return "診断完了！レポートを確認できます"
        default: return nil
        }
    }
    
    private func getGuideIcon() -> String {
        switch viewModel.status {
        case .setting: return "hand.tap.fill"
        case .complete: return "checkmark.circle.fill"
        default: return "info.circle"
        }
    }
    
    private func getGuideColor() -> Color {
        switch viewModel.status {
        case .complete: return Theme.forestGreen
        default: return Theme.textSecondary
        }
    }
}

/// カスタムスライダー: 動画のシークバーとマーカー表示を統合したコンポーネント
/// - アドレスとインパクトの位置をマーカーで表示します
/// - Note: SwiftUIの標準Sliderの上に、GeometryReaderを使ってマーカーを重ねています
struct CustomSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var addressTime: Int?
    var impactTime: Int?
    var duration: Double
    var onEditingChanged: (Bool) -> Void
    
    var body: some View {
        ZStack {
            // マーカー表示層（スライダーの背景に重ねる）
            // GeometryReaderでスライダーの幅を取得し、時刻に応じた位置にマーカーを配置
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // アドレスマーカー（赤色の円）
                    if let address = addressTime, duration > 0 {
                        let offsetX = calculateMarkerOffset(timeMs: address, duration: duration, width: geometry.size.width)
                        Circle()
                            .fill(Theme.address)
                            .frame(width: 12, height: 12)
                            .offset(x: offsetX)
                    }
                    
                    // インパクトマーカー（青色の円）
                    if let impact = impactTime, duration > 0 {
                        let offsetX = calculateMarkerOffset(timeMs: impact, duration: duration, width: geometry.size.width)
                        Circle()
                            .fill(Theme.impact)
                            .frame(width: 12, height: 12)
                            .offset(x: offsetX)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 10) // スライダーのパディングに合わせる
                .offset(y: 10) // スライダーのトラック中心位置に合わせる
            }
            .frame(height: 20)
            
            Slider(value: $value, in: range, onEditingChanged: onEditingChanged)
                .accentColor(Theme.accent)
        }
    }
    
    /// マーカーのX座標オフセットを計算するヘルパーメソッド
    /// - Parameters:
    ///   - timeMs: マーカーを配置する時刻（ミリ秒）
    ///   - duration: 動画の総再生時間（秒）
    ///   - width: スライダーの幅（ポイント）
    /// - Returns: マーカー円の中心を配置するX座標オフセット
    private func calculateMarkerOffset(timeMs: Int, duration: Double, width: CGFloat) -> CGFloat {
        let timeRatio = Double(timeMs) / 1000.0 / duration // 0.0〜1.0の範囲
        let markerRadius: CGFloat = 6 // マーカー円の半径
        return (timeRatio * width) - markerRadius
    }
}

/// 再生コントロール群
/// - コマ送り/戻し、再生/停止、速度変更を統合したUIです
/// - Note: コマ送りボタンは長押しで連続実行できます（ContinuousButton使用）
struct PlaybackControls: View {
    @ObservedObject var viewModel: VideoViewModel
    
    var body: some View {
        HStack(spacing: 20) {
            // コマ戻し
            VStack(spacing: 2) {
                ContinuousButton(
                    imageName: "chevron.backward.circle.fill",
                    action: {
                        HapticFeedback.light()
                        viewModel.stepFrame(count: -1)
                    }
                )
                Text("1コマ戻す")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
            
            // 再生/一時停止ボタン（小さめに）
            Button(action: { viewModel.togglePlayPause() }) {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundColor(Theme.forestGreen)
                    .shadow(color: Theme.forestGreen.opacity(0.3), radius: 8)
            }
            
            Spacer()
            
            // コマ送り
            VStack(spacing: 2) {
                ContinuousButton(
                    imageName: "chevron.forward.circle.fill",
                    action: {
                        HapticFeedback.light()
                        viewModel.stepFrame(count: 1)
                    }
                )
                Text("1コマ進む")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textSecondary)
            }
            
            // 速度変更メニュー
            Menu {
                Button("0.25x") { viewModel.setPlaybackRate(0.25) }
                Button("0.5x") { viewModel.setPlaybackRate(0.5) }
                Button("1.0x") { viewModel.setPlaybackRate(1.0) }
            } label: {
                Text(String(format: "%.2gx", viewModel.playbackRate))
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.surface.opacity(0.5))
                    .cornerRadius(4)
                    .foregroundColor(Theme.textPrimary)
            }
        }
    }
}

/// 設定ボタン群（アドレス・インパクト・ゴースト）
/// - ユーザーがスイングの重要な瞬間を設定するためのボタンです
struct SettingsButtons: View {
    @ObservedObject var viewModel: VideoViewModel
    
    var body: some View {
        HStack(spacing: 8) {
            // アドレス設定ボタン
            SettingButton(
                title: "Address",
                icon: "figure.golf",
                isSet: viewModel.addressTime != nil,
                timestamp: viewModel.addressTime,
                color: Theme.address,
                action: {
                    HapticFeedback.medium() // 決定感のある振動
                    viewModel.setAddress()
                }
            )
            
            // インパクト設定ボタン
            SettingButton(
                title: "Impact",
                icon: "figure.golf",
                isSet: viewModel.impactTime != nil,
                timestamp: viewModel.impactTime,
                color: Theme.impact,
                action: {
                    HapticFeedback.medium() // 決定感のある振動
                    viewModel.setImpact()
                }
            )
            
            // ゴースト表示切り替えボタン
            Button(action: { viewModel.toggleGhost() }) {
                VStack(spacing: 4) {
                    Image(systemName: viewModel.showGhosts ? "eye" : "eye.slash")
                        .font(.system(size: 20))
                    Text("Ghost")
                        .font(.caption.bold())
                }
                .frame(maxWidth: .infinity)
                .frame(height: 60) // SettingButtonと高さを合わせる（概算）
                .background(Theme.surface.opacity(0.5))
                .foregroundColor(viewModel.showGhosts ? Theme.textPrimary : Theme.textSecondary)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.textSecondary.opacity(0.3), lineWidth: 1)
                )
            }
            .disabled(viewModel.addressTime == nil && viewModel.impactTime == nil)
            .opacity(viewModel.addressTime == nil && viewModel.impactTime == nil ? 0.5 : 1.0)
        }
    }
}

/// 個別の設定ボタン（アドレス/インパクト用）
/// - 設定状態に応じて色とアイコンが変化します
/// - Parameter timestamp: 設定された時刻（ミリ秒）。nilの場合は未設定
struct SettingButton: View {
    let title: String
    let icon: String
    let isSet: Bool
    let timestamp: Int?
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: isSet ? "checkmark.circle.fill" : "circle")
                    Text(title)
                }
                .font(.subheadline.bold())
                
                if let ms = timestamp {
                    Text(String(format: "%.2f s", Double(ms) / 1000.0))
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                isSet ? color.opacity(0.2) : Theme.surface.opacity(0.5)
            )
            .foregroundColor(isSet ? color : Theme.textPrimary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSet ? color : Theme.textSecondary.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

/// 診断実行ボタン
/// - アドレスとインパクトが設定されている場合のみ表示されます
/// - Note: 診断完了後は「レポートを見る」ボタンに変化します
/// 診断実行ボタン
/// - アドレスとインパクトが設定されている場合のみ表示されます
/// - Note: 診断完了後は「レポートを見る」ボタンに変化します
struct AnalyzeButton: View {
    @ObservedObject var viewModel: VideoViewModel
    @Binding var showReport: Bool
    @State private var showCoachSelection = false
    
    var body: some View {
        Button(action: {
            if viewModel.status == .complete {
                HapticFeedback.success()
                showReport = true
            } else {
                HapticFeedback.medium()
                showCoachSelection = true
            }
        }) {
            HStack {
                Image(systemName: "sparkles")
                Text(viewModel.status == .complete ? "view_report".localized : "analyze_swing".localized)
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .sheet(isPresented: $showCoachSelection) {
            CoachSelectionView(viewModel: viewModel, isPresented: $showCoachSelection)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

/// コーチ選択ビュー（シート表示用）
struct CoachSelectionView: View {
    @ObservedObject var viewModel: VideoViewModel
    @Binding var isPresented: Bool
    @ObservedObject var languageManager = LanguageManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("select_coach_title".localized)
                .font(.headline)
                .padding(.top)
            
            Text("select_coach_desc".localized)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 12) {
                    let personas = CoachPersona.availablePersonas(for: languageManager.currentLanguage)
                    
                    ForEach(personas) { persona in
                        Button(action: {
                            HapticFeedback.selection()
                            viewModel.coachMode = persona
                            // IDを保存
                            UserDefaults.standard.set(persona.id, forKey: "coachModeId")
                            
                            isPresented = false
                            // 少し遅延させてシートが閉じた後に診断を開始する（アニメーション競合回避）
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                HapticFeedback.medium()
                                viewModel.runDiagnosis()
                            }
                        }) {
                            HStack(spacing: 16) {
                                Text(persona.icon)
                                    .font(.system(size: 40))
                                    .frame(width: 60, height: 60)
                                    .background(Theme.surface)
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.1), radius: 4)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(persona.name)
                                        .font(.headline)
                                        .foregroundColor(Theme.textPrimary)
                                    
                                    Text(persona.description)
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                        .multilineTextAlignment(.leading)
                                }
                                
                                Spacer()
                                
                                if viewModel.coachMode.id == persona.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Theme.forestGreen)
                                        .font(.title2)
                                }
                            }
                            .padding()
                            .background(Theme.background)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(viewModel.coachMode.id == persona.id ? Theme.forestGreen : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
        }
        .background(Theme.surface.ignoresSafeArea())
    }
}
    


/// 長押しで連続的にアクションを実行するボタン
/// - コマ送り/コマ戻しボタンで使用されます
/// - Note: タイマーを使用して0.1秒間隔でアクションを繰り返します
/// - Important: ボタンを離すとタイマーは自動的に停止します
struct ContinuousButton: View {
    let imageName: String
    let action: () -> Void
    
    @State private var timer: Timer?
    
    var body: some View {
        Button(action: {}) {
            Image(systemName: imageName)
                .font(.system(size: 40))
                .foregroundColor(Theme.textPrimary)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if timer == nil {
                        // 最初の1回を即座に実行（レスポンシブな操作感のため）
                        action()
                        // タイマーで連続実行（0.1秒間隔）
                        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                            action()
                        }
                    }
                }
                .onEnded { _ in
                    // ボタンを離したらタイマーを停止してクリーンアップ
                    timer?.invalidate()
                    timer = nil
                }
        )
    }
}
