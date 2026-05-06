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
            Theme.background.ignoresSafeArea()
            
            if viewModel.player == nil {
                VStack(spacing: 0) {
                    HeaderView(viewModel: viewModel)
                    EmptyStateView()
                    Spacer()
                }
            } else {
                VideoAnalysisView(viewModel: viewModel, showReport: $showReport)
            }
        }
        .sheet(isPresented: $showReport) {
            DiagnosisView(report: viewModel.diagnosisReport, isAnalyzing: viewModel.isAnalyzingAI)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onAppear { viewModel.modelContext = modelContext }
    }
}

struct VideoAnalysisView: View {
    @ObservedObject var viewModel: VideoViewModel
    @Binding var showReport: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                VideoPlayerView(viewModel: viewModel)
                    .aspectRatio(contentMode: .fit)
                VStack {
                    CustomHeaderView(viewModel: viewModel)
                        .padding(.horizontal, Theme.Spacing.base.rawValue)
                        .padding(.top, Theme.Spacing.md.rawValue)
                    Spacer()
                }
                .zIndex(10)
                if viewModel.status == .analyzing {
                    LoadingOverlay().zIndex(5)
                }
                if viewModel.showError, let errorMsg = viewModel.errorMessage {
                    ErrorOverlay(message: errorMsg).zIndex(15)
                }
            }
            if viewModel.status != .analyzing {
                ControlArea(viewModel: viewModel, showReport: $showReport)
                    .padding(.horizontal, Theme.Spacing.base.rawValue)
                    .padding(.bottom, 80)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(.all, edges: .top)
    }
}

struct CustomHeaderView: View {
    @ObservedObject var viewModel: VideoViewModel
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md.rawValue) {
            if viewModel.player != nil {
                Button(action: {
                    HapticFeedback.warning()
                    withAnimation(Theme.springAnimation) { viewModel.reset() }
                }) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.error)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.surface).shadow(color: Color.black.opacity(0.1), radius: 8))
                }
                .hoverGlow(color: Theme.error)
            }
            Spacer()
            PhotosPicker(selection: $viewModel.selectedItem, matching: .videos) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.forestGreen)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.surface).shadow(color: Color.black.opacity(0.1), radius: 8))
            }
            .simultaneousGesture(TapGesture().onEnded { _ in HapticFeedback.light() })
            .hoverGlow(color: Theme.forestGreen)
        }
    }
}
