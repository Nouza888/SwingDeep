import Foundation
import MediaPipeTasksVision
import SwiftUI

/// スイング解析ロジックを担当する構造体
/// アドレスとインパクトの2点を比較し、エラー（悪い癖）を診断する
struct SwingAnalyzer {
    
    // MARK: - Constants (定数定義)
    
    /// 解析で使用する各種定数
    ///
    /// マジックナンバーを避け、意味のある名前で定義することで、
    /// メンテナンス性と可読性を向上させます。
    private struct Constants {
        // データ品質関連
        static let minDataPoints = 30                   // 最小データ点数（これ以下は解析不能）
        static let landmarkToleranceMs = 100            // ランドマークデータの許容誤差（ミリ秒）
        static let addressSearchStartMs = 300           // アドレス探索開始時刻（開始直後のノイズ回避）
        static let impactSearchDelayMs = 1500           // インパクト探索開始遅延（バックスイング中の誤検知防止）
        
        // 診断基準値 - アーリーエクステンション（お尻の離脱）
        static let earlyExtensionThresholdBad: Float = 0.05     // 重度（5cm以上の移動）
        static let earlyExtensionThresholdCheck: Float = 0.02   // 要注意（2cm以上の移動）
        
        // 診断基準値 - 前傾角度の維持（Spine Angle）
        static let spineAngleThresholdBad: Double = 10.0        // 重度（10度以上の変化）
        static let spineAngleThresholdGood: Double = 5.0        // 良好（5度以内の維持）
        
        // スイングパス判定の閾値
        static let swingPathOutsideThreshold: Float = 0.05      // Outside-In判定（手が前に出る）
        static let swingPathInsideThreshold: Float = -0.05      // Inside-Out判定（手が後ろ）
        
        // MediaPipe ランドマークインデックス
        struct LandmarkIndex {
            static let nose = 0             // 鼻
            static let leftShoulder = 11    // 左肩
            static let leftWrist = 15       // 左手首
            static let rightWrist = 16      // 右手首
            static let leftHip = 23         // 左腰
        }
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
    
    /// AI診断用のスイングメトリクス（数値データ）を計算する
    ///
    /// アドレスとインパクトの2点間で以下の6つの指標を計算します：
    /// 1. 背骨角度の変化量（起き上がり・沈み込み）
    /// 2. 腰のX方向移動量（アーリーエクステンション）
    /// 3. 頭のY方向移動量（浮き上がり・沈み込み）
    /// 4. テンポ比率（バックスイング時間 / ダウンスイング時間）
    /// 5. 手の浮き上がり量（ハンドアクション）
    /// 6. スイングパスタイプ（Inside-Out, Outside-In, Straight）
    ///
    /// - Parameters:
    ///   - phases: スイングフェーズ（アドレスとインパクトの時刻）
    ///   - cache: 全フレームの骨格データキャッシュ
    /// - Returns: 計算されたSwingMetrics
    static func calculateMetrics(phases: SwingPhases, cache: [Int: [NormalizedLandmark]]) -> SwingMetrics {
        /// 指定時刻に最も近いランドマークデータを取得する
        ///
        /// 完全一致ではなく、許容範囲内で最も近いデータを返します。
        /// これにより、フレームレートの違いやタイミングのずれに対応します。
        ///
        /// - Parameter target: 目標時刻（ミリ秒）
        /// - Returns: 最も近いランドマークデータ（許容範囲外の場合はnil）
        func getClosest(target: Int) -> [NormalizedLandmark]? {
            let sortedKeys = cache.keys.sorted()
            guard let closestKey = sortedKeys.min(by: { abs($0 - target) < abs($1 - target) }) else { return nil }
            // 許容誤差内（100ms以内）かチェック
            if abs(closestKey - target) < Constants.landmarkToleranceMs {
                return cache[closestKey]
            }
            return nil
        }
        
        guard let addressLM = getClosest(target: phases.address),
              let impactLM = getClosest(target: phases.impact) else {
            // データが見つからない場合はゼロを返すが、ログを出力すべき
            print("⚠️ SwingAnalyzer: Landmarks not found for metrics calculation")
            return SwingMetrics(spineAngleDiffDeg: 0, hipMoveRatio: 0, headMoveY: 0, tempoRatio: 0, handRaiseY: 0, swingPathType: "Unknown")
        }
        
        // 1. 背骨角度の変化量（Spine Angle Diff）
        // 肩(11)と腰(23)を結ぶ線と垂直線のなす角度を計算
        let addressSpineAngle = calculateVerticalAngle(
            p1: addressLM[Constants.LandmarkIndex.leftShoulder],
            p2: addressLM[Constants.LandmarkIndex.leftHip]
        )
        let impactSpineAngle = calculateVerticalAngle(
            p1: impactLM[Constants.LandmarkIndex.leftShoulder],
            p2: impactLM[Constants.LandmarkIndex.leftHip]
        )
        let spineAngleDiff = impactSpineAngle - addressSpineAngle  // マイナス = 起き上がり、プラス = 沈み込み
        
        // 2. 腰の前方移動量（Hip Move Ratio - Early Extension指標）
        // 左腰(23)のX座標の変化量（プラス = 前方移動 = アーリーエクステンション）
        let hipMove = impactLM[Constants.LandmarkIndex.leftHip].x - addressLM[Constants.LandmarkIndex.leftHip].x
        
        // 3. 頭の浮き沈み（Head Move Y）
        // 鼻(0)のY座標の変化量（マイナス = 沈み込み、プラス = 浮き上がり）
        // ※ 画像座標系では上が0なので注意
        let headMove = impactLM[Constants.LandmarkIndex.nose].y - addressLM[Constants.LandmarkIndex.nose].y
        
        // 4. テンポ比率（Tempo Ratio）
        // バックスイング時間とダウンスイング時間の比率を計算
        // 理想的には3:1程度と言われている
        let topTime = findTopPositionTime(phases: phases, cache: cache)
        let backswingTime = Double(topTime - phases.address)
        let downswingTime = Double(phases.impact - topTime)
        let tempoRatio = downswingTime > 0 ? backswingTime / downswingTime : 0.0
        
        // 5. 手の浮き上がり量（Hand Raise Y - ハンドアクション）
        // アドレスとインパクトで手の高さがどれだけ変化したか
        // 左右の手首(15, 16)の平均Y座標を比較
        let addressHandY = (addressLM[Constants.LandmarkIndex.leftWrist].y + addressLM[Constants.LandmarkIndex.rightWrist].y) / 2.0
        let impactHandY = (impactLM[Constants.LandmarkIndex.leftWrist].y + impactLM[Constants.LandmarkIndex.rightWrist].y) / 2.0
        let handRaiseY = addressHandY - impactHandY  // Yは上が0なので、プラス = 手が浮いている
        
        // 6. スイングパスタイプの推定（Swing Path Type）
        // インパクト時の手の位置から、スイング軌道を簡易推定
        // ※ 本来は3D解析が必要だが、ここでは手のX座標の変化で判定
        let addressHandX = (addressLM[Constants.LandmarkIndex.leftWrist].x + addressLM[Constants.LandmarkIndex.rightWrist].x) / 2.0
        let impactHandX = (impactLM[Constants.LandmarkIndex.leftWrist].x + impactLM[Constants.LandmarkIndex.rightWrist].x) / 2.0
        let handPathDiffX = impactHandX - addressHandX
        
        let swingPathType: String
        if handPathDiffX > Constants.swingPathOutsideThreshold {
            swingPathType = "Outside-In"  // 手が前（外側）に出ている = カット軌道傾向
        } else if handPathDiffX < Constants.swingPathInsideThreshold {
            swingPathType = "Inside-Out"  // 手が後ろ（内側）にある = インサイドアウト傾向
        } else {
            swingPathType = "Straight"    // ニュートラル
        }
        
        return SwingMetrics(
            spineAngleDiffDeg: spineAngleDiff,
            hipMoveRatio: Double(hipMove),
            headMoveY: Double(headMove),
            tempoRatio: tempoRatio,
            handRaiseY: Double(handRaiseY),
            swingPathType: swingPathType
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
