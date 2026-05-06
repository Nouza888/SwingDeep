import SwiftUI
import PhotosUI
import AVKit
import UIKit

// MARK: - Header View

struct HeaderView: View {
    @ObservedObject var viewModel: VideoViewModel
    
    var body: some View {
        HStack {
            Text("GolfScan AI")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)
                .shadow(color: Theme.accent.opacity(0.5), radius: 8, x: 0, y: 0)
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
                    .foregroundColor(Theme.textPrimary)
                }
            } else {
                let usageLimiter = UsageLimiter.shared
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill").font(.system(size: 10))
                    if usageLimiter.isUnlimited {
                        Text("unlimited".localized).font(.system(size: 11, weight: .semibold))
                    } else {
                        Text(String(format: "remaining_display".localized, usageLimiter.displayRemainingCount, usageLimiter.monthlyLimit))
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .foregroundColor(usageLimiter.isUnlimited || usageLimiter.displayRemainingCount > 5 ? Theme.textPrimary : Theme.accentOrange)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Theme.glassMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(usageLimiter.isUnlimited || usageLimiter.displayRemainingCount > 5 ? Theme.accent.opacity(0.3) : Theme.accentOrange.opacity(0.5), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

// MARK: - Video Player View

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
                    if viewModel.status == .setting && !viewModel.canAnalyze {
                        GuideOverlay()
                    }
                }
            )
    }
}

// MARK: - Guide Overlay

struct GuideOverlay: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.tap.fill").font(.system(size: 20)).foregroundColor(.white)
            Text("guide_overlay_message".localized).font(.subheadline.bold()).foregroundColor(.white)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(Color.black.opacity(0.4))
        .cornerRadius(30)
        .padding(.top, 60)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 32) {
            ZStack {
                Rectangle()
                    .stroke(Theme.textSecondary.opacity(0.3), lineWidth: 2)
                    .frame(width: 320, height: 240)
                    .background(Color.gray.opacity(0.05))
                if let image = loadSilhouetteImage() {
                    Image(uiImage: image).resizable().scaledToFit().frame(width: 300).opacity(0.6).offset(y: 20)
                } else {
                    Image(systemName: "figure.golf").font(.system(size: 150)).foregroundColor(Theme.textSecondary.opacity(0.5))
                }
                Image(systemName: "camera.fill").font(.title2).foregroundColor(Theme.textSecondary)
                    .padding(8).background(Theme.background).clipShape(Circle()).offset(y: 120)
            }
            VStack(spacing: 16) {
                Text("empty_state_title".localized).font(.title2.bold()).foregroundColor(Theme.textPrimary)
                VStack(alignment: .leading, spacing: 12) {
                    Text("analysis_tips_title".localized).font(.subheadline.bold()).foregroundColor(Theme.textPrimary)
                    VStack(alignment: .leading, spacing: 8) {
                        tipRow("tip_camera".localized)
                        tipRow("tip_fixed".localized)
                        tipRow("tip_angle".localized)
                    }.font(.subheadline).foregroundColor(Theme.textSecondary)
                }.padding().background(Theme.surface).cornerRadius(12)
            }
        }.padding().frame(maxWidth: .infinity)
    }
    
    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top) { Text("・"); Text(text) }
    }
    
    private func loadSilhouetteImage() -> UIImage? {
        guard let path = Bundle.main.path(forResource: "guide_silhouette", ofType: "png") else { return nil }
        return UIImage(contentsOfFile: path)
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
            VStack(spacing: 20) {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Theme.accent)).scaleEffect(1.5)
                Text("analyzing_status".localized).font(.headline).foregroundColor(.white)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius).fill(Theme.glassGradient)
                    .background(RoundedRectangle(cornerRadius: Theme.cornerRadius).fill(.ultraThinMaterial))
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .shadow(color: Theme.forestGreen.opacity(0.1), radius: 16, x: 0, y: 8)
        }
    }
}

// MARK: - Error Overlay

struct ErrorOverlay: View {
    let message: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundColor(.yellow)
            Text(message).font(.subheadline).foregroundColor(.white).multilineTextAlignment(.center)
        }
        .padding().background(Color.black.opacity(0.8)).cornerRadius(12).padding()
    }
}
