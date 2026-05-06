import SwiftUI
import UIKit

// MARK: - Control Area

struct ControlArea: View {
    @ObservedObject var viewModel: VideoViewModel
    @Binding var showReport: Bool
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md.rawValue) {
            if let guideText = getGuideText() {
                HStack(spacing: Theme.Spacing.xs.rawValue) {
                    Image(systemName: getGuideIcon()).font(.system(size: 12, weight: .semibold))
                    Text(guideText).font(.system(size: 11))
                }
                .foregroundColor(getGuideColor())
                .padding(.horizontal, Theme.Spacing.sm.rawValue).padding(.vertical, 4)
                .background(Capsule().fill(getGuideColor().opacity(0.1)))
            }
            CustomSlider(
                value: Binding(get: { viewModel.currentTime }, set: { viewModel.seek(to: $0) }),
                range: 0...viewModel.duration,
                addressTime: viewModel.addressTime, impactTime: viewModel.impactTime, duration: viewModel.duration,
                onEditingChanged: { editing in if editing { viewModel.startSeeking() } else { viewModel.endSeeking() } }
            )
            PlaybackControls(viewModel: viewModel)
            SettingsButtons(viewModel: viewModel)
            if viewModel.canAnalyze { AnalyzeButton(viewModel: viewModel, showReport: $showReport) }
        }
        .padding(Theme.Spacing.md.rawValue)
        .glassCard(elevation: ThemeGlassCardModifier.Elevation.medium)
    }
    
    private func getGuideText() -> String? {
        switch viewModel.status {
        case .setting: return "slider_hint".localized
        case .complete: return "ready_to_generate".localized
        default: return nil
        }
    }
    private func getGuideIcon() -> String {
        switch viewModel.status { case .setting: return "hand.tap.fill"; case .complete: return "checkmark.circle.fill"; default: return "info.circle" }
    }
    private func getGuideColor() -> Color {
        switch viewModel.status { case .complete: return Theme.forestGreen; default: return Theme.textSecondary }
    }
}

// MARK: - Custom Slider

struct CustomSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var addressTime: Int?
    var impactTime: Int?
    var duration: Double
    var onEditingChanged: (Bool) -> Void
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    if let address = addressTime, duration > 0 {
                        let offsetX = calculateMarkerOffset(timeMs: address, duration: duration, width: geometry.size.width)
                        Circle().fill(Theme.address).frame(width: 12, height: 12).offset(x: offsetX)
                    }
                    if let impact = impactTime, duration > 0 {
                        let offsetX = calculateMarkerOffset(timeMs: impact, duration: duration, width: geometry.size.width)
                        Circle().fill(Theme.impact).frame(width: 12, height: 12).offset(x: offsetX)
                    }
                }
                .frame(height: 4).padding(.horizontal, 10).offset(y: 10)
            }.frame(height: 20)
            Slider(value: $value, in: range, onEditingChanged: onEditingChanged).accentColor(Theme.accent)
        }
    }
    
    private func calculateMarkerOffset(timeMs: Int, duration: Double, width: CGFloat) -> CGFloat {
        let timeRatio = Double(timeMs) / 1000.0 / duration
        return (timeRatio * width) - 6
    }
}

// MARK: - Playback Controls

struct PlaybackControls: View {
    @ObservedObject var viewModel: VideoViewModel
    
    var body: some View {
        HStack(spacing: 20) {
            VStack(spacing: 2) {
                ContinuousButton(imageName: "chevron.backward.circle.fill", action: { HapticFeedback.light(); viewModel.stepFrame(count: -1) })
                Text("previous_frame".localized).font(.system(size: 10)).foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Button(action: { viewModel.togglePlayPause() }) {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 50, weight: .medium)).foregroundColor(Theme.forestGreen)
                    .shadow(color: Theme.forestGreen.opacity(0.3), radius: 8)
            }
            Spacer()
            VStack(spacing: 2) {
                ContinuousButton(imageName: "chevron.forward.circle.fill", action: { HapticFeedback.light(); viewModel.stepFrame(count: 1) })
                Text("next_frame".localized).font(.system(size: 10)).foregroundColor(Theme.textSecondary)
            }
            Menu {
                Button("0.25x") { viewModel.setPlaybackRate(0.25) }
                Button("0.5x") { viewModel.setPlaybackRate(0.5) }
                Button("1.0x") { viewModel.setPlaybackRate(1.0) }
            } label: {
                Text(String(format: "%.2gx", viewModel.playbackRate))
                    .font(.caption.bold()).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Theme.surface.opacity(0.5)).cornerRadius(4).foregroundColor(Theme.textPrimary)
            }
        }
    }
}

// MARK: - Settings Buttons

struct SettingsButtons: View {
    @ObservedObject var viewModel: VideoViewModel
    
    var body: some View {
        HStack(spacing: 8) {
            SettingButton(title: "Address", icon: "figure.golf", isSet: viewModel.addressTime != nil,
                         timestamp: viewModel.addressTime, color: Theme.address, action: { HapticFeedback.medium(); viewModel.setAddress() })
            SettingButton(title: "Impact", icon: "figure.golf", isSet: viewModel.impactTime != nil,
                         timestamp: viewModel.impactTime, color: Theme.impact, action: { HapticFeedback.medium(); viewModel.setImpact() })
            Button(action: { viewModel.toggleGhost() }) {
                VStack(spacing: 4) {
                    Image(systemName: viewModel.showGhosts ? "eye" : "eye.slash").font(.system(size: 20))
                    Text("Ghost").font(.caption.bold())
                }
                .frame(maxWidth: .infinity).frame(height: 60)
                .background(Theme.surface.opacity(0.5))
                .foregroundColor(viewModel.showGhosts ? Theme.textPrimary : Theme.textSecondary)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.textSecondary.opacity(0.3), lineWidth: 1))
            }
            .disabled(viewModel.addressTime == nil && viewModel.impactTime == nil)
            .opacity(viewModel.addressTime == nil && viewModel.impactTime == nil ? 0.5 : 1.0)
        }
    }
}

struct SettingButton: View {
    let title: String; let icon: String; let isSet: Bool; let timestamp: Int?; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: isSet ? "checkmark.circle.fill" : "circle")
                    Text(title)
                }.font(.subheadline.bold())
                if let ms = timestamp {
                    Text(String(format: "%.2f s", Double(ms) / 1000.0)).font(.caption2).foregroundColor(Theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(isSet ? color.opacity(0.2) : Theme.surface.opacity(0.5))
            .foregroundColor(isSet ? color : Theme.textPrimary)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSet ? color : Theme.textSecondary.opacity(0.3), lineWidth: 1))
        }
    }
}

// MARK: - Analyze Button

struct AnalyzeButton: View {
    @ObservedObject var viewModel: VideoViewModel
    @Binding var showReport: Bool
    @State private var showCoachSelection = false
    
    var body: some View {
        VStack(spacing: 8) {
            if viewModel.status != .complete {
                let usageLimiter = UsageLimiter.shared
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill").font(.system(size: 10))
                    if usageLimiter.isUnlimited {
                        Text("unlimited".localized).font(.system(size: 11, weight: .medium))
                    } else {
                        Text(String(format: "monthly_remaining".localized, usageLimiter.displayRemainingCount, usageLimiter.monthlyLimit))
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .foregroundColor(usageLimiter.isUnlimited || usageLimiter.displayRemainingCount > 5 ? Theme.textSecondary : Theme.accentOrange)
            }
            Button(action: {
                if viewModel.status == .complete { HapticFeedback.success(); showReport = true }
                else { HapticFeedback.medium(); showCoachSelection = true }
            }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text(viewModel.status == .complete ? "view_report".localized : "analyze_swing".localized)
                }
                .font(Theme.Typography.headlineMedium.font).foregroundColor(.white)
                .padding(.vertical, Theme.Spacing.base.rawValue).padding(.horizontal, Theme.Spacing.xl.rawValue)
                .frame(maxWidth: .infinity).background(Theme.heroGradient).cornerRadius(Theme.cornerRadius)
                .shadow(color: Theme.championshipGold.opacity(0.4), radius: 12, x: 0, y: 6)
            }
        }
        .sheet(isPresented: $showCoachSelection) {
            CoachSelectionView(viewModel: viewModel, isPresented: $showCoachSelection)
                .presentationDetents([.medium]).presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Coach Selection View

struct CoachSelectionView: View {
    @ObservedObject var viewModel: VideoViewModel
    @Binding var isPresented: Bool
    @ObservedObject var languageManager = LanguageManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("select_coach_title".localized).font(.headline).padding(.top)
            Text("select_coach_desc".localized).font(.caption).foregroundColor(Theme.textSecondary).multilineTextAlignment(.center).padding(.horizontal)
            ScrollView {
                VStack(spacing: 12) {
                    let personas = CoachPersona.availablePersonas(for: languageManager.currentLanguage)
                    ForEach(personas) { persona in
                        Button(action: {
                            HapticFeedback.selection()
                            viewModel.coachMode = persona
                            UserDefaults.standard.set(persona.id, forKey: "coachModeId")
                            isPresented = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                HapticFeedback.medium(); viewModel.runDiagnosis()
                            }
                        }) {
                            HStack(spacing: 16) {
                                Text(persona.icon).font(.system(size: 40)).frame(width: 60, height: 60)
                                    .background(Theme.surface).clipShape(Circle()).shadow(color: Color.black.opacity(0.1), radius: 4)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(persona.name).font(.headline).foregroundColor(Theme.textPrimary)
                                    Text(persona.description).font(.caption).foregroundColor(Theme.textSecondary).multilineTextAlignment(.leading)
                                }
                                Spacer()
                                if viewModel.coachMode.id == persona.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(Theme.forestGreen).font(.title2)
                                }
                            }
                            .padding().background(Theme.background).cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(viewModel.coachMode.id == persona.id ? Theme.forestGreen : Color.clear, lineWidth: 2))
                        }.buttonStyle(PlainButtonStyle())
                    }
                }.padding()
            }
        }.background(Theme.surface.ignoresSafeArea())
    }
}

// MARK: - Continuous Button

struct ContinuousButton: View {
    let imageName: String; let action: () -> Void
    @State private var timer: Timer?
    
    var body: some View {
        Button(action: {}) {
            Image(systemName: imageName).font(.system(size: 40)).foregroundColor(Theme.textPrimary)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if timer == nil {
                        action()
                        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in action() }
                    }
                }
                .onEnded { _ in timer?.invalidate(); timer = nil }
        )
    }
}
