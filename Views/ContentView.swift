import SwiftUI
import PhotosUI
import AVKit

/// メインコンテンツビュー
///
/// アプリケーションの主要な画面。
/// 動画未選択時は空状態、動画選択後は解析画面を表示します。
struct ContentView: View {
    /// SwiftDataのモデルコンテキスト（解析結果の保存に使用）
    @Environment(\.modelContext) private var modelContext
    /// 動画解析を管理するViewModel
    @StateObject private var viewModel = VideoViewModel()

    /// 診断レポート表示フラグ
    @State private var showReport = false
    
    var body: some View {
        ZStack {
            // 背景
            Theme.background
                .ignoresSafeArea()
            
            // 動画の有無で表示切り替え
            if viewModel.player == nil {
                // 空状態: 動画未選択
                VStack(spacing: 0) {
                    // ヘッダー（動画選択ボタン付き）
                    HeaderView(viewModel: viewModel)
                    
                    // 空状態コンテンツ
                    EmptyStateView()
                    
                    Spacer() // コンテンツを上部に寄せる
                }
            } else {
                // 動画ロード済み状態: 解析画面
                VideoAnalysisView(viewModel: viewModel, showReport: $showReport)
            }
        }
        // 診断レポートをモーダル表示
        .sheet(isPresented: $showReport) {
            DiagnosisView(report: viewModel.diagnosisReport, isAnalyzing: viewModel.isAnalyzingAI)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        // 初回表示時にmodelContextを設定
        .onAppear {
            viewModel.modelContext = modelContext
        }
    }
}

// MARK: - Video Analysis View

struct VideoAnalysisView: View {
    @ObservedObject var viewModel: VideoViewModel
    @Binding var showReport: Bool
    
    var body: some View {
        // VStackで構造化して重ならないように
        VStack(spacing: 0) {
            // Video Player Area with Overlays
            ZStack {
                // Video Player
                VideoPlayerView(viewModel: viewModel)
                    .aspectRatio(contentMode: .fit)
                
                // Top Header (floating)
                VStack {
                    CustomHeaderView(viewModel: viewModel)
                        .padding(.horizontal, Theme.Spacing.base.rawValue)
                        .padding(.top, Theme.Spacing.md.rawValue)
                    
                    Spacer()
                }
                .zIndex(10)
                
                // Loading Overlay
                if viewModel.status == .analyzing {
                    LoadingOverlay()
                        .zIndex(5)
                }
                
                // Error Overlay
                if viewModel.showError, let errorMsg = viewModel.errorMessage {
                    ErrorOverlay(message: errorMsg)
                        .zIndex(15)
                }
            }
            
            // Bottom Controls (outside ZStack, no overlap)
            if viewModel.status != .analyzing {
                ControlArea(viewModel: viewModel, showReport: $showReport)
                    .padding(.horizontal, Theme.Spacing.base.rawValue)
                    .padding(.bottom, 80) // タブバーの高さを考慮して十分な余白を確保
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(.all, edges: .top)
    }
}

// MARK: - Custom Header View (Redesigned)

struct CustomHeaderView: View {
    @ObservedObject var viewModel: VideoViewModel
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md.rawValue) {
            // Delete Video Button
            if viewModel.player != nil {
                Button(action: {
                    HapticFeedback.warning()
                    withAnimation(Theme.springAnimation) {
                        viewModel.reset()
                    }
                }) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.error)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Theme.surface)
                                .shadow(color: Color.black.opacity(0.1), radius: 8)
                        )
                }
                .hoverGlow(color: Theme.error)
            }
            
            Spacer()
            
            // Replace Video Button
            PhotosPicker(selection: $viewModel.selectedItem, matching: .videos) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.forestGreen)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Theme.surface)
                            .shadow(color: Color.black.opacity(0.1), radius: 8)
                    )
            }
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        HapticFeedback.light()
                    }
            )
            .hoverGlow(color: Theme.forestGreen)
        }
    }
}
