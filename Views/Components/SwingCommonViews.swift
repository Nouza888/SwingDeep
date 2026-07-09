import SwiftUI
import PhotosUI
import AVKit
import UIKit

// MARK: - 共通ビューコンポーネント

/// このファイルにはアプリ全体で使用される共通ビューコンポーネントが含まれます。
///
/// ## 含まれるコンポーネント
/// - HeaderView: ナビゲーションヘッダー
/// - VideoPlayerView: 動画プレーヤー
/// - GuideOverlay: ガイドメッセージ
/// - EmptyStateView: 動画未選択時の表示
/// - LoadingOverlay: AI解析中の表示
/// - ErrorOverlay: エラー表示

// MARK: - ヘッダービュー

/// 画面上部に表示されるナビゲーションヘッダー
///
/// ## 表示内容
/// - 左側: アプリ名「GolfScan AI」
/// - 右側: 動画選択ボタン（未選択時）/ 閉じるボタン（選択時）
struct HeaderView: View {
    
    // MARK: - Properties
    
    /// ビューモデル
    @ObservedObject var viewModel: VideoViewModel
    
    // MARK: - Body
    
    var body: some View {
        HStack {
            appTitle
            Spacer()
            actionButton
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
    
    // MARK: - Components
    
    /// アプリタイトル
    private var appTitle: some View {
        Text("GolfScan AI")
            .font(.system(size: 24, weight: .heavy, design: .rounded))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1) // 黒いアウトライン
            .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2) // 追加の深み
            .shadow(color: Theme.accent.opacity(0.5), radius: 8, x: 0, y: 0) // アクセントグロー
    }
    
    /// アクションボタン（動画選択 or 残り回数表示）
    @ViewBuilder
    private var actionButton: some View {
        if viewModel.player == nil {
            videoPickerButton
        } else {
            remainingCountPill
        }
    }
    
    /// 動画選択ボタン
    private var videoPickerButton: some View {
        PhotosPicker(selection: $viewModel.selectedItem, matching: .videos) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text("select_video".localized)
            }
            .font(.subheadline.bold())
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.glassMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.accent.opacity(0.5), lineWidth: 1))
            .foregroundColor(Theme.textPrimary)
        }
    }
    
    /// 残り回数ピル
    private var remainingCountPill: some View {
        let usageLimiter = UsageLimiter.shared
        
        return HStack(spacing: 4) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 10))
            if usageLimiter.isUnlimited {
                Text("unlimited".localized)
                    .font(.system(size: 11, weight: .semibold))
            } else {
                Text(String(format: "remaining_display".localized, usageLimiter.displayRemainingCount, usageLimiter.monthlyLimit))
                    .font(.system(size: 11, weight: .semibold))
            }
        }
        .foregroundColor(usageLimiter.isUnlimited || usageLimiter.displayRemainingCount > 5 ? Theme.textPrimary : Theme.accentOrange)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.glassMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(usageLimiter.isUnlimited || usageLimiter.displayRemainingCount > 5 ? Theme.accent.opacity(0.3) : Theme.accentOrange.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - 動画プレーヤービュー

/// 動画プレーヤーとオーバーレイ
///
/// ## 機能
/// - 動画の再生表示
/// - 骨格検出結果のオーバーレイ
/// - ガイド表示（設定モード中）
struct VideoPlayerView: View {
    
    // MARK: - Properties
    
    /// ビューモデル
    @ObservedObject var viewModel: VideoViewModel
    
    // MARK: - Body
    
    var body: some View {
        VideoPlayer(player: viewModel.player)
            .aspectRatio(viewModel.videoAspectRatio, contentMode: .fit)
            .overlay(overlayContent)
    }
    
    // MARK: - Components
    
    /// オーバーレイコンテンツ
    private var overlayContent: some View {
        ZStack {
            // 骨格検出オーバーレイ
            OverlayView(
                landmarks: viewModel.currentFrameLandmarks,
                addressGhostLandmarks: viewModel.addressLandmarks,
                impactGhostLandmarks: viewModel.impactLandmarks,
                isGhostVisible: viewModel.showGhosts,
                showTrajectory: viewModel.showTrajectory,
                addressTime: viewModel.addressTime,
                impactTime: viewModel.impactTime,
                currentTime: viewModel.currentTime,
                cachedLandmarks: viewModel.landmarkCache,
                isComplete: viewModel.status == .complete
            )
            
            // ガイド表示（設定モード中で、まだ設定が完了していない場合）
            if shouldShowGuide {
                GuideOverlay()
            }
        }
    }
    
    /// ガイドを表示すべきかどうか
    private var shouldShowGuide: Bool {
        viewModel.status == .setting && !viewModel.canAnalyze
    }
}

// MARK: - ガイドオーバーレイ

/// アドレス・インパクト未設定時のガイドメッセージ
///
/// ユーザーに次のアクションを促すメッセージを表示します。
struct GuideOverlay: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)
            Text("guide_overlay_message".localized)
                .font(.subheadline.bold())
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.4))
        .cornerRadius(30)
        .padding(.top, 60)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - 空状態ビュー

/// 動画未選択時に表示される画面
///
/// ## 表示内容
/// - シルエット画像
/// - 動画選択の促し
/// - 撮影のガイドライン
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 32) {
            cameraPreviewArea
            instructionsArea
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Components
    
    /// カメラプレビューエリア
    private var cameraPreviewArea: some View {
        ZStack {
            // カメラ枠（4:3比率）
            Rectangle()
                .stroke(Theme.textSecondary.opacity(0.3), lineWidth: 2)
                .frame(width: 320, height: 240)
                .background(Color.gray.opacity(0.05))
            
            // シルエット画像
            silhouetteImage
            
            // カメラアイコン
            cameraIcon
        }
    }
    
    /// シルエット画像
    @ViewBuilder
    private var silhouetteImage: some View {
        if let image = loadSilhouetteImage() {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 300)
                .opacity(0.6)
                .offset(y: 20)
        } else {
            // フォールバック
            Image(systemName: "figure.golf")
                .font(.system(size: 150))
                .foregroundColor(Theme.textSecondary.opacity(0.5))
        }
    }
    
    /// カメラアイコン
    private var cameraIcon: some View {
        Image(systemName: "camera.fill")
            .font(.title2)
            .foregroundColor(Theme.textSecondary)
            .padding(8)
            .background(Theme.background)
            .clipShape(Circle())
            .offset(y: 120)
    }
    
    /// 説明エリア
    private var instructionsArea: some View {
        VStack(spacing: 16) {
            Text("empty_state_title".localized)
                .font(.title2.bold())
                .foregroundColor(Theme.textPrimary)
            
            tipsCard
        }
    }
    
    /// ヒントカード
    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("analysis_tips_title".localized)
                .font(.subheadline.bold())
                .foregroundColor(Theme.textPrimary)
            
            VStack(alignment: .leading, spacing: 8) {
                tipRow("tip_camera".localized)
                tipRow("tip_fixed".localized)
                tipRow("tip_angle".localized)
            }
            .font(.subheadline)
            .foregroundColor(Theme.textSecondary)
        }
        .padding()
        .background(Theme.surface)
        .cornerRadius(12)
    }
    
    /// ヒント行
    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top) {
            Text("・")
            Text(text)
        }
    }
    
    // MARK: - Helpers
    
    /// シルエット画像をバンドルから読み込む
    ///
    /// - Returns: 読み込みに成功した場合はUIImage、失敗した場合はnil
    private func loadSilhouetteImage() -> UIImage? {
        guard let path = Bundle.main.path(forResource: "guide_silhouette", ofType: "png") else {
            logImageError("guide_silhouette.png が見つかりません")
            return nil
        }
        guard let uiImage = UIImage(contentsOfFile: path) else {
            logImageError("guide_silhouette.png の読み込みに失敗しました")
            return nil
        }
        return uiImage
    }
    
    /// 画像エラーをログ出力
    private func logImageError(_ message: String) {
        print("⚠️ \(message)")
    }
}

// MARK: - ローディングオーバーレイ

/// AI解析中に表示されるローディングオーバーレイ
///
/// MediaPipeによる骨格検出処理中に表示されます。
/// 動画全体の解析には数秒〜数十秒かかる場合があります。
struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            // 背景（半透明黒）
            Color.black.opacity(0.7)
            
            // ローディングコンテンツ
            loadingContent
        }
    }
    
    // MARK: - Components
    
    /// ローディングコンテンツ
    private var loadingContent: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                .scaleEffect(1.5)
            
            VStack(spacing: 8) {
                Text("analyzing_status".localized)
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
        .padding(40)
        .background(glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .shadow(color: Theme.forestGreen.opacity(0.1), radius: 16, x: 0, y: 8)
    }
    
    /// ガラスモーフィズム背景
    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: Theme.cornerRadius)
            .fill(Theme.glassGradient)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .fill(.ultraThinMaterial)
            )
    }
}

// MARK: - エラーオーバーレイ

/// エラー表示オーバーレイ
///
/// 動画読み込みエラーやAPI呼び出しエラーなどを表示します。
struct ErrorOverlay: View {
    
    // MARK: - Properties
    
    /// ユーザーに表示するエラーメッセージ
    let message: String
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.yellow)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
        .padding()
    }
}
