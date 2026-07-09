import SwiftUI
import MediaPipeTasksVision

/// 動画の上に重ねて表示するオーバーレイレイヤー
/// 骨格（スケルトン）や診断結果（ライン描画）を担当する
struct OverlayView: View {
    // MARK: - Properties

    /// 現在フレームの検出ランドマーク（リアルタイム表示用）
    var landmarks: [NormalizedLandmark]?

    // MARK: - Ghost Mode Properties
    /// アドレス時のランドマーク（ゴースト表示用）
    var addressGhostLandmarks: [NormalizedLandmark]?
    /// インパクト時のランドマーク（ゴースト表示用）
    var impactGhostLandmarks: [NormalizedLandmark]?
    /// ゴーストを表示するかどうか
    var isGhostVisible: Bool
    /// 軌道を表示するかどうか
    var showTrajectory: Bool = false

    // MARK: - Diagnosis Properties
    var addressTime: Int?
    var impactTime: Int?
    var currentTime: Double
    /// 全フレームのキャッシュデータ（診断結果表示用）
    var cachedLandmarks: [Int: [NormalizedLandmark]]
    /// 診断が完了しているかどうか
    var isComplete: Bool

    private let hipIndex = 23 // 左腰のインデックス

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. ゴースト骨格 (アドレス・インパクト)
                if isGhostVisible {
                    // アドレスゴースト（赤）
                    if let ghost = addressGhostLandmarks {
                        drawSkeleton(landmarks: ghost, size: geometry.size)
                            .stroke(Theme.address.opacity(0.6), lineWidth: 2)

                        drawJoints(landmarks: ghost, size: geometry.size)
                            .fill(Theme.address.opacity(0.6))

                        drawVerticalLine(geometry: geometry, landmarks: ghost, color: Theme.address.opacity(0.6), label: "Address")
                    }

                    // インパクトゴースト（青）
                    if let ghost = impactGhostLandmarks {
                        drawSkeleton(landmarks: ghost, size: geometry.size)
                            .stroke(Theme.impact.opacity(0.6), lineWidth: 2)

                        drawJoints(landmarks: ghost, size: geometry.size)
                            .fill(Theme.impact.opacity(0.6))

                        // インパクト基準線
                        drawVerticalLine(geometry: geometry, landmarks: ghost, color: Theme.impact.opacity(0.6), label: "Impact", isTop: true)
                    }
                }

                // 2. スイング軌道 (手首の軌跡 - 彗星エフェクト)
                if showTrajectory {
                    drawCometTail(geometry: geometry, cache: cachedLandmarks)
                }

                // 3. 診断結果ビジュアル (完了時かつインパクト付近)
                if isComplete, let aTime = addressTime, let iTime = impactTime,
                   let addressLM = cachedLandmarks[aTime], let impactLM = cachedLandmarks[iTime] {

                    // インパクトの瞬間付近（±300ms）でのみ結果を表示
                    if isNearTimestamp(target: iTime, current: Int(currentTime * 1000), range: 300) {
                         drawImpactFeedback(geometry: geometry, addressLandmarks: addressLM, impactLandmarks: impactLM)
                    }
                }

                // 3. リアルタイム骨格
                if let landmarks = landmarks {
                    // グロー効果のために重ねて描画
                    drawSkeleton(landmarks: landmarks, size: geometry.size)
                        .stroke(Color.white.opacity(0.3), lineWidth: 4)
                        .blur(radius: 2)

                    drawSkeleton(landmarks: landmarks, size: geometry.size)
                        .stroke(Color.white, lineWidth: 2)

                    // 関節点 (白)
                    drawJoints(landmarks: landmarks, size: geometry.size)
                        .fill(Color.white)

                    // リアルタイム基準線
                    if !isComplete {
                        drawVerticalLine(geometry: geometry, landmarks: landmarks, color: .white.opacity(0.5))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Drawing Helpers

    /// お尻の位置（Hip）を通る垂直線を描画する
    @ViewBuilder
    private func drawVerticalLine(geometry: GeometryProxy, landmarks: [NormalizedLandmark], color: Color, label: String? = nil, isTop: Bool = false) -> some View {
        let hipX = CGFloat(landmarks[hipIndex].x) * geometry.size.width

        ZStack {
            Path { path in
                path.move(to: CGPoint(x: hipX, y: 0))
                path.addLine(to: CGPoint(x: hipX, y: geometry.size.height))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1, dash: [4, 2]))

            if let label = label {
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color)
                    .cornerRadius(4)
                    .position(x: hipX, y: isTop ? 20 : geometry.size.height - 20) // 上または下に表示
            }
        }
    }

    /// インパクト時の診断フィードバック（起き上がり検知など）を描画する
    @ViewBuilder
    private func drawImpactFeedback(geometry: GeometryProxy, addressLandmarks: [NormalizedLandmark], impactLandmarks: [NormalizedLandmark]) -> some View {
        let addressX = CGFloat(addressLandmarks[hipIndex].x) * geometry.size.width
        let impactX = CGFloat(impactLandmarks[hipIndex].x) * geometry.size.width

        // アーリーエクステンション（お尻が前に出る）の可視化
        if impactX > addressX + 5 {
            Path { path in
                path.move(to: CGPoint(x: addressX, y: 0))
                path.addLine(to: CGPoint(x: impactX, y: 0))
                path.addLine(to: CGPoint(x: impactX, y: geometry.size.height))
                path.addLine(to: CGPoint(x: addressX, y: geometry.size.height))
                path.closeSubpath()
            }
            .fill(Color.red.opacity(0.4))

            // 警告ラベル
            VStack {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("overlay_early_extension".localized)
                }
                .font(.headline.bold())
                .foregroundColor(.white)
            }
            .padding(12)
            .background(Color.red.opacity(0.8))
            .cornerRadius(12)
            .shadow(radius: 4)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }

    private func isNearTimestamp(target: Int, current: Int, range: Int) -> Bool {
        return abs(target - current) < range
    }

    private func drawSkeleton(landmarks: [NormalizedLandmark], size: CGSize) -> Path {
        var path = Path()
        let connections: [(Int, Int)] = [
            (11, 12), (11, 23), (12, 24), (23, 24), // 体幹
            (11, 13), (13, 15), // 左腕
            (12, 14), (14, 16), // 右腕
            (23, 25), (25, 27), // 左脚
            (24, 26), (26, 28)  // 右脚
        ]

        for (start, end) in connections {
            guard landmarks.indices.contains(start), landmarks.indices.contains(end) else { continue }
            let s = landmarks[start]
            let e = landmarks[end]
            path.move(to: CGPoint(x: CGFloat(s.x) * size.width, y: CGFloat(s.y) * size.height))
            path.addLine(to: CGPoint(x: CGFloat(e.x) * size.width, y: CGFloat(e.y) * size.height))
        }
        return path
    }

    private func drawJoints(landmarks: [NormalizedLandmark], size: CGSize) -> Path {
        var path = Path()
        // 主要な関節のみ描画 (右手首:16 は別途描画するため除外)
        let joints = [11, 12, 13, 14, 15, 23, 24, 25, 26, 27, 28]

        for i in joints {
            guard landmarks.indices.contains(i) else { continue }
            let lm = landmarks[i]
            let point = CGPoint(x: CGFloat(lm.x) * size.width, y: CGFloat(lm.y) * size.height)
            let radius: CGFloat = 3
            path.addEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
        }
        return path
    }

    private func drawRightWrist(landmarks: [NormalizedLandmark], size: CGSize) -> Path {
        var path = Path()
        let i = 16 // 右手首
        if landmarks.indices.contains(i) {
            let lm = landmarks[i]
            let point = CGPoint(x: CGFloat(lm.x) * size.width, y: CGFloat(lm.y) * size.height)
            let radius: CGFloat = 5 // 少し大きく強調
            path.addEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
        }
        return path
    }

    @ViewBuilder
    private func drawCometTail(geometry: GeometryProxy, cache: [Int: [NormalizedLandmark]]) -> some View {
        let currentMs = Int(currentTime * 1000)
        let windowMs = 500 // 0.5秒
        let validKeys = cache.keys.filter { $0 <= currentMs && $0 > currentMs - windowMs }.sorted()

        if validKeys.count > 1 {
            ForEach(0..<validKeys.count - 1, id: \.self) { i in
                let t1 = validKeys[i]
                let t2 = validKeys[i+1]

                if let lm1 = cache[t1], let lm2 = cache[t2] {
                    let p1 = getRightWristPoint(landmarks: lm1, size: geometry.size)
                    let p2 = getRightWristPoint(landmarks: lm2, size: geometry.size)

                    // 透明度の計算 (新しいほど濃い)
                    let age = Double(currentMs - t2)
                    let opacity = max(0, 1.0 - (age / Double(windowMs)))

                    Path { path in
                        path.move(to: p1)
                        path.addLine(to: p2)
                    }
                    .stroke(Color.orange.opacity(opacity), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                }
            }
        }
    }

    private func getRightWristPoint(landmarks: [NormalizedLandmark], size: CGSize) -> CGPoint {
        let rightWrist = landmarks[16]
        return CGPoint(x: CGFloat(rightWrist.x) * size.width, y: CGFloat(rightWrist.y) * size.height)
    }
}
