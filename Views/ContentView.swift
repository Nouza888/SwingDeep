import SwiftUI
import PhotosUI
import AVKit
import SwiftData

struct ContentView: View {
    @StateObject private var viewModel = VideoViewModel()
    @State private var showReport = false
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ZStack {
            // Background with subtle texture
            Theme.background
                .ignoresSafeArea()
            
            if viewModel.player == nil {
                // Empty State: No video loaded
                VStack(spacing: 0) {
                    // Header with video selection button
                    HeaderView(viewModel: viewModel)
                    
                    // Empty State Content
                    EmptyStateView()
                    
                    Spacer() // コンテンツを上部に寄せる
                }
            } else {
                // Video Loaded State
                VideoAnalysisView(viewModel: viewModel, showReport: $showReport)
            }
        }
        .sheet(isPresented: $showReport) {
            DiagnosisView(report: viewModel.diagnosisReport, isAnalyzing: viewModel.isAnalyzingAI)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            // ViewModelにmodelContextを渡して履歴保存を有効にする
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
