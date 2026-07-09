import Foundation
import MediaPipeTasksVision
import SwiftUI

/// スイング解析ロジックを担当する構造体
/// アドレスとインパクトの2点を比較し、エラー（悪い癖）を診断する
struct SwingAnalyzer {
    
    // MARK: - Constants
    
    private struct Constants {
        static let minDataPoints = 30
        static let addressSearchStartMs = 300 // 開始直後のノイズ回避（300ms以降から探索）
        
        // 診断基準値
        // アーリーエクステンション（お尻の離脱）の許容範囲
        static let earlyExtensionThresholdBad: Float = 0.05
        static let earlyExtensionThresholdCheck: Float = 0.02
        
        // 前傾角度の維持（Spine Angle）の許容範囲（度数）
        static let spineAngleThresholdBad: Double = 10.0
        static let spineAngleThresholdGood: Double = 5.0
    }
    
    // MARK: - Types
    
    /// スイングの重要な局面（フェーズ）
    /// 今回は「アドレス」と「インパクト」の2点のみを特定する
    struct SwingPhases {
        let address: Int
        let impact: Int
    }
    
    /// 診断結果の評価レベル
    enum Evaluation: String {
        case excellent = "Excellent"
        case good = "Good"
        case bad = "Bad"
        case check = "Check"
        
        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .bad: return .red
            case .check: return .orange
            }
        }
    }
    
    /// UI表示用の診断結果モデル
    struct AnalysisResult: Identifiable {
        let id = UUID()
        let title: String
        let valueStr: String
        let evaluation: Evaluation
        let advice: String
    }
    
    // MARK: - Phase Detection Logic (Auto Suggestion)
    
    /// AIがスイングのフェーズ（アドレス・インパクト）を自動推定する
    /// - Parameter landmarkCache: 全フレームのランドマークデータ
    /// - Returns: 推定されたフェーズ（見つからない場合はnil）
    static func suggestPhases(from landmarkCache: [Int: [NormalizedLandmark]]) -> SwingPhases? {
        // データ点数が少なすぎる場合は解析不能
        guard landmarkCache.count > Constants.minDataPoints else { return nil }
        
        let sortedKeys = landmarkCache.keys.sorted()
        
        // 1. アドレス候補の探索
        // 動画開始直後は安定していない可能性があるため、少し経過した時点を採用
        guard let addressTime = sortedKeys.first(where: { $0 > Constants.addressSearchStartMs }) else { return nil }
        
        // 2. インパクト候補の探索
        // 「アドレス時の手の高さ（Y座標）」に再び戻ってきた瞬間をインパクトと仮定する
        guard let addressLandmarks = landmarkCache[addressTime] else { return nil }
        // 手首のY座標（左右の手の低い方、つまり画面上で下にある方）を取得
        let addressHandY = min(addressLandmarks[15].y, addressLandmarks[16].y)
        
        var impactTime = addressTime
        var minDiff: Float = 100.0 // 差分の初期値（十分大きな値）
        
        // アドレスからある程度（例えば1.5秒）経った後から探索開始して、バックスイング中の誤検知を防ぐ
        let searchStartTime = addressTime + 1500
        
        for time in sortedKeys where time > searchStartTime {
            guard let landmarks = landmarkCache[time] else { continue }
            let currentHandY = min(landmarks[15].y, landmarks[16].y)
            let diff = abs(currentHandY - addressHandY)
            
            // 最もアドレスの高さに近い（戻ってきた）瞬間を更新
            if diff < minDiff {
                minDiff = diff
                impactTime = time
            }
        }
        
        // もしインパクトが見つからなければ、動画の最後の方を仮定する（フォールバック）
        if impactTime == addressTime, let last = sortedKeys.last {
            impactTime = last
        }
        
        return SwingPhases(address: addressTime, impact: impactTime)
    }
    
    // MARK: - Diagnosis Logic
    
    /// スイング診断を実行するメインメソッド
    static func analyzeSwing(phases: SwingPhases, cache: [Int: [NormalizedLandmark]]) -> [AnalysisResult] {
        guard let addressLM = cache[phases.address],
              let impactLM = cache[phases.impact] else { return [] }
        
        var results: [AnalysisResult] = []
        
        // 1. アーリーエクステンション診断
        results.append(evaluateEarlyExtension(address: addressLM, impact: impactLM))
        
        // 2. 前傾角度（Spine Angle）診断
        results.append(evaluateSpineAngle(address: addressLM, impact: impactLM))
        
        return results
    }
    
    // MARK: - Metrics Calculation for AI
    
    /// AI診断用の数値データを計算する
    /// - Important: v2.0から相対評価（体格基準）に変更
    /// - 各メトリクスはユーザーの体格（肩幅、手〜頭距離、身長）を基準に正規化
    static func calculateMetrics(phases: SwingPhases, cache: [Int: [NormalizedLandmark]]) -> SwingMetrics {
        // 完全一致ではなく、許容範囲(100ms)内で最も近いデータを探す
        func getClosest(target: Int) -> [NormalizedLandmark]? {
            let sortedKeys = cache.keys.sorted()
            guard let closestKey = sortedKeys.min(by: { abs($0 - target) < abs($1 - target) }) else { return nil }
            if abs(closestKey - target) < 100 {
                return cache[closestKey]
            }
            return nil
        }
        
        guard let addressLM = getClosest(target: phases.address),
              let impactLM = getClosest(target: phases.impact) else {
            print("⚠️ SwingAnalyzer: Landmarks not found for metrics calculation")
            return SwingMetrics(
                spineAngleDiffDeg: 0, hipMoveRatio: 0, headMoveY: 0,
                tempoRatio: 0, handRaiseY: 0, swingPathType: "Unknown"
            )
        }
        
        // ============================================================
        // 基準スケールの計算（アドレス時のユーザー体格）
        // 後方（DTL）アングルで最も視認性が高く安定している
        // 「胴体の長さ（Torso Length）」を基準スケールとして採用
        // ============================================================
        
        // 胴体長: 左肩(11)から左腰(23)までの2Dユークリッド距離
        // 剛体として安定しており、パースペクティブの影響を受けにくい
        let torsoLength = sqrt(
            pow(Double(addressLM[23].x - addressLM[11].x), 2) +
            pow(Double(addressLM[23].y - addressLM[11].y), 2)
        )
        
        // 手元のY座標（後で使用）
        let addressHandY = Double((addressLM[15].y + addressLM[16].y) / 2.0)
        let headY = Double(addressLM[0].y)
        
        // ============================================================
        // 1. Spine Angle（前傾キープ）- 耳(7)-腰(23)ベース
        // ============================================================
        // 右打ちゴルファーの後方アングルでは左耳(Index 7)が見えやすい
        let addressSpineAngle = calculateVerticalAngle(p1: addressLM[7], p2: addressLM[23])
        let impactSpineAngle = calculateVerticalAngle(p1: impactLM[7], p2: impactLM[23])
        let spineAngleDiff = impactSpineAngle - addressSpineAngle
        
        // ============================================================
        // 2. Early Extension（腰の伸び上がり）- 胴体長比
        // ============================================================
        let hipMoveX = Double(impactLM[23].x - addressLM[23].x)
        let hipMoveRatio = hipMoveX / max(0.01, torsoLength)
        // 結果例: 0.1 = 胴体長の10%前方移動
        
        // ============================================================
        // 3. Head Movement（頭の安定感）- 胴体長比
        // ============================================================
        let headMoveYRaw = Double(impactLM[0].y - addressLM[0].y)
        let headMoveRatio = headMoveYRaw / max(0.01, torsoLength)
        // 結果例: 0.05 = 胴体長の5%上下動（+は下がった、-は上がった）
        
        // ============================================================
        // 4. Tempo（切り返しリズム）
        // ============================================================
        let topTime = findTopPositionTime(phases: phases, cache: cache)
        let backswingTime = Double(topTime - phases.address)
        let downswingTime = Double(phases.impact - topTime)
        let tempoRatio = downswingTime > 0 ? backswingTime / downswingTime : 0.0
        
        // ============================================================
        // 5. Hand Position（手元の浮き）- 胴体長比
        // ============================================================
        let impactHandY = Double((impactLM[15].y + impactLM[16].y) / 2.0)
        let handRaiseRaw = addressHandY - impactHandY  // Yは上が0なので、正なら浮いている
        let handRaiseRatio = handRaiseRaw / max(0.01, torsoLength)
        // 結果例: 0.1 = 胴体長の10%浮き
        
        // ============================================================
        // 6. Swing Path（スイング軌道）- 胴体長比
        // ============================================================
        let addressHandX = Double((addressLM[15].x + addressLM[16].x) / 2.0)
        let impactHandX = Double((impactLM[15].x + impactLM[16].x) / 2.0)
        let handPathDiffX = impactHandX - addressHandX
        let handPathRatio = handPathDiffX / max(0.01, torsoLength)
        
        // 胴体長の5%以上で判定
        let swingPathType: String
        if handPathRatio > 0.05 {
            swingPathType = "Outside-In"
        } else if handPathRatio < -0.05 {
            swingPathType = "Inside-Out"
        } else {
            swingPathType = "Straight"
        }
        
        return SwingMetrics(
            spineAngleDiffDeg: spineAngleDiff,
            hipMoveRatio: hipMoveRatio,
            headMoveY: headMoveRatio,
            tempoRatio: tempoRatio,
            handRaiseY: handRaiseRatio,
            swingPathType: swingPathType,
            shoulderWidth: torsoLength,  // 実際は胴体長だが、互換性のためフィールド名は維持
            handToHeadDistance: torsoLength,
            bodyHeight: torsoLength
        )
    }
    
    /// トップの位置（手が最も高い位置）の時間を特定する
    private static func findTopPositionTime(phases: SwingPhases, cache: [Int: [NormalizedLandmark]]) -> Int {
        var topTime = phases.address
        var minHandY: Float = 100.0 // Yは上が0なので、最小値を探す
        
        let sortedKeys = cache.keys.sorted().filter { $0 >= phases.address && $0 <= phases.impact }
        
        for time in sortedKeys {
            guard let landmarks = cache[time] else { continue }
            // 左右の手首(15, 16)の平均高さ
            let handY = (landmarks[15].y + landmarks[16].y) / 2.0
            
            if handY < minHandY {
                minHandY = handY
                topTime = time
            }
        }
        
        return topTime
    }

    // MARK: - Evaluation Helpers
    
    /// アーリーエクステンション（お尻の離脱）を評価する
    private static func evaluateEarlyExtension(address: [NormalizedLandmark], impact: [NormalizedLandmark]) -> AnalysisResult {
        let hipIndex = 23 // 左腰（後方アングルで見えている側）
        
        // X座標の差分（インパクト - アドレス）
        // MediaPipeの座標系は左上が(0,0)。右打者の後方アングルでは、お尻が前に出る＝Xが増加する方向と仮定
        // ※ 実際の座標系やカメラ位置によって符号は調整が必要
        let diffX = impact[hipIndex].x - address[hipIndex].x
        
        let evaluation: Evaluation
        let advice: String
        
        if diffX > Constants.earlyExtensionThresholdBad {
            evaluation = .bad
            advice = "お尻が前に出ています。手元が詰まり、スライスやシャンクの原因になります。"
        } else if diffX > Constants.earlyExtensionThresholdCheck {
            evaluation = .check
            advice = "少し起き上がりの傾向があります。お尻を後ろに残す意識を持ちましょう。"
        } else {
            evaluation = .excellent
            advice = "お尻の位置がキープできています！プロのようなインパクトです。"
        }
        
        return AnalysisResult(title: "Early Extension", valueStr: evaluation.rawValue, evaluation: evaluation, advice: advice)
    }
    
    /// 前傾角度（Spine Angle）を評価する
    private static func evaluateSpineAngle(address: [NormalizedLandmark], impact: [NormalizedLandmark]) -> AnalysisResult {
        // 肩(11)と腰(23)を結ぶ線の角度を計算
        let addressAngle = calculateVerticalAngle(p1: address[11], p2: address[23])
        let impactAngle = calculateVerticalAngle(p1: impact[11], p2: impact[23])
        
        // 角度の変化量（絶対値）
        let diff = abs(addressAngle - impactAngle)
        
        let evaluation: Evaluation
        let advice: String
        
        if diff > Constants.spineAngleThresholdBad {
            evaluation = .bad
            advice = "上体が起き上がっています。ボールに力が伝わりにくい状態です。"
        } else if diff > Constants.spineAngleThresholdGood {
            evaluation = .good
            advice = "許容範囲内ですが、もう少し前傾を深く保てるとより良いです。"
        } else {
            evaluation = .excellent
            advice = "前傾角度が完璧に保たれています。"
        }
        
        return AnalysisResult(title: "Spine Angle", valueStr: "\(Int(diff))° Loss", evaluation: evaluation, advice: advice)
    }
    
    /// 2点間の垂直角度を計算する
    private static func calculateVerticalAngle(p1: NormalizedLandmark, p2: NormalizedLandmark) -> Double {
        let dy = p2.y - p1.y
        let dx = p2.x - p1.x
        // atan2で角度（ラジアン）を求め、度数法に変換
        return Double(atan2(abs(dx), abs(dy)) * 180 / .pi)
    }
}
