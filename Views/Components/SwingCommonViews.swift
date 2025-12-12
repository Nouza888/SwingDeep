import SwiftUI
import PhotosUI
import AVKit
import UIKit

// MARK: - Header & Overlays

/// ヘッダービュー: 画面上部に表示されるナビゲーションバー
/// - 左側: アプリ名「GolfScan AI」

/// - 右側: 動画選択ボタン（未選択時）/ 閉じるボタン（選択時）
struct HeaderView: View {
    @ObservedObject var viewModel: VideoViewModel
    
    var body: some View {
        HStack {
            Text("GolfScan AI")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundColor(.white) // 動画上のため白文字固定
                .shadow(color: Color.black.opacity(0.8), radius: 2, x: 0, y: 1) // 視認性向上のため濃い影を追加
                .shadow(color: Theme.accent.opacity(0.5), radius: 8)
            
            Spacer()
            
            if viewModel.player == nil {
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
                    .foregroundColor(Theme.textPrimary) // 視認性向上のため黒文字に変更
                }
            } else {
                Button(action: { viewModel.reset() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

/// 動画プレーヤーとオーバーレイ
/// - 動画の再生表示と、その上に重ねる骨格検出結果やガイド表示を管理します
/// - Note: VideoPlayerはAVKitのネイティブコンポーネントを使用しています
struct VideoPlayerView: View {
    @ObservedObject var viewModel: VideoViewModel
    
    var body: some View {
        VideoPlayer(player: viewModel.player)
            .aspectRatio(viewModel.videoAspectRatio, contentMode: .fit)
            .overlay(
                ZStack {
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
                    
                    // ガイド表示（設定モード中で、まだアドレス・インパクトが設定されていない場合）
                    if viewModel.status == .setting && !viewModel.canAnalyze {
                        GuideOverlay()
                    }
                }
            )
    }
}

/// ガイドオーバーレイ（アドレス・インパクト未設定時）
/// - ユーザーに次のアクションを促すメッセージを表示します
/// - Note: アドレスとインパクトの両方が設定されるまで表示され続けます
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
        .background(Color.black.opacity(0.4)) // 背景を薄暗くして視認性向上
        .cornerRadius(30)
        .padding(.top, 60) // ヘッダーの下に配置
        .frame(maxHeight: .infinity, alignment: .top) // 画面上部に固定
    }
}

/// 動画未選択時の表示
/// - ユーザーに動画選択を促す画面を表示します
/// - Note: 撮影のガイドライン（カメラ固定、DTL視点など）も併せて表示します
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 32) {
            // カメラ撮影イメージ
            ZStack {
                // カメラ枠 (4:3の比率を意識)
                Rectangle()
                    .stroke(Theme.textSecondary.opacity(0.3), lineWidth: 2)
                    .frame(width: 320, height: 240)
                    .background(Color.gray.opacity(0.05))
                
                // シルエット画像: バンドルから読み込み
                if let silhouetteImage = loadSilhouetteImage() {
                    Image(uiImage: silhouetteImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300) // 枠(320)に合わせて最大化
                        .opacity(0.6)
                        .offset(y: 20) // 少し下に配置
                } else {
                    // フォールバック: 画像が見つからない場合はSFシンボルを表示
                    Image(systemName: "figure.golf")
                        .font(.system(size: 150))
                        .foregroundColor(Theme.textSecondary.opacity(0.5))
                }
                
                // カメラアイコン (枠外下部に配置)
                Image(systemName: "camera.fill")
                    .font(.title2)
                    .foregroundColor(Theme.textSecondary)
                    .padding(8)
                    .background(Theme.background)
                    .clipShape(Circle())
                    .offset(y: 120) // 枠の下端 (240/2 = 120)
            }
            
            VStack(spacing: 16) {
                Text("empty_state_title".localized)
                    .font(.title2.bold())
                    .foregroundColor(Theme.textPrimary)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("analysis_tips_title".localized)
                        .font(.subheadline.bold())
                        .foregroundColor(Theme.textPrimary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            Text("・")
                            Text("tip_camera".localized)
                        }
                        HStack(alignment: .top) {
                            Text("・")
                            Text("tip_fixed".localized)
                        }
                        HStack(alignment: .top) {
                            Text("・")
                            Text("tip_angle".localized)
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                }
                .padding()
                .background(Theme.surface)
                .cornerRadius(12)
            }
        }
        .padding()
        .frame(maxWidth: .infinity) // 画面中央に配置
    }
    
    /// シルエット画像をバンドルから読み込むヘルパーメソッド
    /// - Returns: 読み込みに成功した場合はUIImage、失敗した場合はnil
    /// - Note: guide_silhouette.pngがバンドルに含まれている必要があります
    private func loadSilhouetteImage() -> UIImage? {
        guard let path = Bundle.main.path(forResource: "guide_silhouette", ofType: "png") else {
            print("⚠️ guide_silhouette.png が見つかりません")
            return nil
        }
        guard let uiImage = UIImage(contentsOfFile: path) else {
            print("⚠️ guide_silhouette.png の読み込みに失敗しました")
            return nil
        }
        return uiImage
    }
}

/// ローディング中のオーバーレイ
/// - AI解析中（MediaPipeによる骨格検出中）に表示されます
/// - Note: 動画全体の解析には数秒〜数十秒かかる場合があります
struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                    .scaleEffect(1.5)
                
                VStack(spacing: 8) {
                    Text("AI解析中...")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("骨格データを抽出しています")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(40)
            .background(Theme.glassMaterial) // マテリアル背景を明示的に適用
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius)) // 角丸でクリップ
            .glassCard() // 追加のエフェクト（ボーダーなど）
        }
    }
}

/// エラー表示オーバーレイ
/// - 動画読み込みエラーやAPI呼び出しエラーなどを表示します
/// - Parameter message: ユーザーに表示するエラーメッセージ
struct ErrorOverlay: View {
    let message: String
    
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
