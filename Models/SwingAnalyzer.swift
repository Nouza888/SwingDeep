import Foundation
import MediaPipeTasksVision

/// スイング解析のコアロジック
/// MediaPipeの骨格データから各種メトリクスを計算し、診断結果を生成します
///
/// ## 主な機能
/// - フェーズ自動検出（アドレス・インパクト位置の推定）
/// - 骨格データからのメトリクス計算
/// - ルールベースの診断実行
///
/// ## v2.0 胴体長比ベース
/// - headMoveY: 胴体長に対する頭の上下動の比率
/// - hipMoveRatio: 胴体長に対する腰の前後移動の比率
/// - handRaiseY: 胴体長に対するインパクト時の手の浮きの比率
/// - spineAngleDiffDeg: 耳-腰ベースの前傾角度差（度）
struct SwingAnalyzer {
    
    // MARK: - Data Types
    
    /// スイングフェーズ（アドレスとインパクトの時刻）
    struct SwingPhases {
        let address: Int // ミリ秒
        let impact: Int  // ミリ秒
    }
    
    /// 解析結果の1項目
    struct AnalysisResult {
        let title: String
        let status: String // Good, Check, Bad
        let value: Double
        let description: String
    }
    
    // MARK: - Phase Detection
    
    /// 骨格データからスイングフェーズ（アドレス・インパクト）を自動推定する
    ///
    /// ## アルゴリズム
    /// 1. 右手首(index:16)のY座標が最も低い時刻 = アドレス（構え位置）
    /// 2. アドレス以降で右手首のX座標の変化速度が最大の時刻 = インパクト
    ///
    /// - Parameter cache: フレームごとの骨格データキャッシュ [タイムスタンプ(ms): ランドマーク配列]
    /// - Returns: 推定されたフェーズ情報。推定不可の場合はnil
    static func suggestPhases(from cache: [Int: [NormalizedLandmark]]) -> SwingPhases? {
        let sortedKeys = cache.keys.sorted()
        guard sortedKeys.count > 10 else { return nil }
        
        // 右手首のインデックス（MediaPipe Pose Landmarker仕様）
        let rightWristIndex = 16
        
        // 1. アドレス推定: 右手首のY座標が最も低い（値が大きい = 画面下方）時刻
        var addressTime: Int?
        var maxWristY: Float = -1
        for key in sortedKeys {
            guard let landmarks = cache[key], landmarks.indices.contains(rightWristIndex) else { continue }
            let wristY = landmarks[rightWristIndex].y
            if wristY > maxWristY {
                maxWristY = wristY
                addressTime = key
            }
        }
        
        guard let address = addressTime else { return nil }
        
        // 2. インパクト推定: アドレス以降で手首の移動速度が最大の時刻
        let postAddressKeys = sortedKeys.filter { $0 > address }
        guard postAddressKeys.count > 2 else { return nil }
        
        var impactTime: Int?
        var maxSpeed: Float = 0
        
        for i in 1..<postAddressKeys.count {
            let prevKey = postAddressKeys[i - 1]
            let currKey = postAddressKeys[i]
            guard let prevLandmarks = cache[prevKey], let currLandmarks = cache[currKey] else { continue }
            guard prevLandmarks.indices.contains(rightWristIndex), currLandmarks.indices.contains(rightWristIndex) else { continue }
            
            let dx = currLandmarks[rightWristIndex].x - prevLandmarks[rightWristIndex].x
            let dy = currLandmarks[rightWristIndex].y - prevLandmarks[rightWristIndex].y
            let speed = sqrt(dx * dx + dy * dy)
            
            if speed > maxSpeed {
                maxSpeed = speed
                impactTime = currKey
            }
        }
        
        guard let impact = impactTime else { return nil }
        
        return SwingPhases(address: address, impact: impact)
    }
    
    // MARK: - Metrics Calculation
    
    /// 骨格データからスイングメトリクスを計算する
    ///
    /// v2.0: 胴体長比ベースの計算
    /// - 胴体長 = 左肩(11)のY座標 - 左腰(23)のY座標 の絶対値
    /// - 各メトリクスを胴体長で正規化することで、カメラ距離やプレーヤーの体格差を吸収
    ///
    /// - Parameters:
    ///   - phases: スイングフェーズ（アドレスとインパクトの時刻）
    ///   - cache: フレームごとの骨格データキャッシュ
    /// - Returns: 計算されたスイングメトリクス
    static func calculateMetrics(phases: SwingPhases, cache: [Int: [NormalizedLandmark]]) -> SwingMetrics {
        // アドレスとインパクト時のランドマークを取得
        let addressLandmarks = getNearestLandmarks(timestamp: phases.address, cache: cache)
        let impactLandmarks = getNearestLandmarks(timestamp: phases.impact, cache: cache)
        
        guard let aLM = addressLandmarks, let iLM = impactLandmarks else {
            return SwingMetrics.empty
        }
        
        // 胴体長の計算（アドレス時の左肩-左腰の距離）
        let torsoLength = calculateTorsoLength(landmarks: aLM)
        let safeTorso = max(torsoLength, 0.01) // ゼロ除算防止
        
        // 1. 前傾角度差（耳-腰ベース、度）
        let addressSpineAngle = calculateEarHipAngle(landmarks: aLM)
        let impactSpineAngle = calculateEarHipAngle(landmarks: iLM)
        let spineAngleDiff = impactSpineAngle - addressSpineAngle
        
        // 2. 腰の移動量（胴体長比）
        let hipMoveRatio = calculateHipMovement(address: aLM, impact: iLM) / safeTorso
        
        // 3. 頭の上下動（胴体長比）
        let headMoveY = calculateHeadMovement(address: aLM, impact: iLM) / safeTorso
        
        // 4. テンポ比率
        let tempoRatio = calculateTempoRatio(phases: phases, cache: cache)
        
        // 5. 手の浮き（胴体長比）
        let handRaiseY = calculateHandRaise(address: aLM, impact: iLM) / safeTorso
        
        // 6. スイング軌道
        let swingPathType = detectSwingPathType(phases: phases, cache: cache)
        
        return SwingMetrics(
            spineAngleDiffDeg: spineAngleDiff,
            hipMoveRatio: hipMoveRatio,
            headMoveY: headMoveY,
            tempoRatio: tempoRatio,
            handRaiseY: handRaiseY,
            swingPathType: swingPathType
        )
    }
    
    // MARK: - Rule-Based Analysis
    
    /// ルールベースのスイング診断を実行する
    static func analyzeSwing(phases: SwingPhases, cache: [Int: [NormalizedLandmark]]) -> [AnalysisResult] {
        let metrics = calculateMetrics(phases: phases, cache: cache)
        var results: [AnalysisResult] = []
        
        // 前傾角度
        let spineStatus = abs(metrics.spineAngleDiffDeg) < 3 ? "Good" : abs(metrics.spineAngleDiffDeg) < 6 ? "Check" : "Bad"
        results.append(AnalysisResult(
            title: "前傾キープ",
            status: spineStatus,
            value: metrics.spineAngleDiffDeg,
            description: String(format: "%.1f° の変化", metrics.spineAngleDiffDeg)
        ))
        
        // 腰の移動
        let hipStatus = abs(metrics.hipMoveRatio) < 0.10 ? "Good" : abs(metrics.hipMoveRatio) < 0.20 ? "Check" : "Bad"
        results.append(AnalysisResult(
            title: "腰の安定性",
            status: hipStatus,
            value: metrics.hipMoveRatio,
            description: String(format: "胴体長の%.0f%%移動", metrics.hipMoveRatio * 100)
        ))
        
        // 頭の上下動
        let headStatus = abs(metrics.headMoveY) < 0.10 ? "Good" : abs(metrics.headMoveY) < 0.20 ? "Check" : "Bad"
        results.append(AnalysisResult(
            title: "頭の安定性",
            status: headStatus,
            value: metrics.headMoveY,
            description: String(format: "胴体長の%.0f%%移動", metrics.headMoveY * 100)
        ))
        
        return results
    }
    
    // MARK: - Private Helpers
    
    /// 指定時刻に最も近い骨格データを取得する
    private static func getNearestLandmarks(timestamp: Int, cache: [Int: [NormalizedLandmark]]) -> [NormalizedLandmark]? {
        let nearest = cache.keys.min(by: { abs($0 - timestamp) < abs($1 - timestamp) })
        guard let key = nearest else { return nil }
        return cache[key]
    }
    
    /// 胴体長を計算（左肩 - 左腰のY座標差の絶対値）
    private static func calculateTorsoLength(landmarks: [NormalizedLandmark]) -> Double {
        guard landmarks.count > 23 else { return 0.1 }
        let shoulderY = Double(landmarks[11].y) // 左肩
        let hipY = Double(landmarks[23].y)       // 左腰
        return abs(shoulderY - hipY)
    }
    
    /// 耳-腰ベースの前傾角度を計算（度）
    private static func calculateEarHipAngle(landmarks: [NormalizedLandmark]) -> Double {
        guard landmarks.count > 23 else { return 0 }
        // 左耳(7)と左腰(23)を使用
        let earX = Double(landmarks[7].x)
        let earY = Double(landmarks[7].y)
        let hipX = Double(landmarks[23].x)
        let hipY = Double(landmarks[23].y)
        
        let dx = earX - hipX
        let dy = earY - hipY
        let angleRad = atan2(dx, -dy) // 上方向を0とした角度
        return angleRad * 180.0 / .pi
    }
    
    /// 腰の前後移動を計算
    private static func calculateHipMovement(address: [NormalizedLandmark], impact: [NormalizedLandmark]) -> Double {
        guard address.count > 24, impact.count > 24 else { return 0 }
        let addressHipX = (Double(address[23].x) + Double(address[24].x)) / 2
        let impactHipX = (Double(impact[23].x) + Double(impact[24].x)) / 2
        return impactHipX - addressHipX
    }
    
    /// 頭の上下動を計算
    private static func calculateHeadMovement(address: [NormalizedLandmark], impact: [NormalizedLandmark]) -> Double {
        guard address.count > 0, impact.count > 0 else { return 0 }
        let addressNoseY = Double(address[0].y)
        let impactNoseY = Double(impact[0].y)
        return impactNoseY - addressNoseY
    }
    
    /// テンポ比率を計算（ダウンスイング時間 / バックスイング時間）
    private static func calculateTempoRatio(phases: SwingPhases, cache: [Int: [NormalizedLandmark]]) -> Double {
        let sortedKeys = cache.keys.sorted()
        let rightWristIndex = 16
        
        // トップ位置を推定（手首のY座標が最小 = 最も高い位置）
        let addressToImpact = sortedKeys.filter { $0 >= phases.address && $0 <= phases.impact }
        guard !addressToImpact.isEmpty else { return 3.0 }
        
        var topTime: Int = phases.address
        var minWristY: Float = Float.greatestFiniteMagnitude
        
        for key in addressToImpact {
            guard let landmarks = cache[key], landmarks.indices.contains(rightWristIndex) else { continue }
            let wristY = landmarks[rightWristIndex].y
            if wristY < minWristY {
                minWristY = wristY
                topTime = key
            }
        }
        
        let backswingDuration = Double(topTime - phases.address)
        let downswingDuration = Double(phases.impact - topTime)
        
        guard downswingDuration > 0 else { return 3.0 }
        return backswingDuration / downswingDuration
    }
    
    /// 手の浮きを計算
    private static func calculateHandRaise(address: [NormalizedLandmark], impact: [NormalizedLandmark]) -> Double {
        guard address.count > 16, impact.count > 16 else { return 0 }
        let addressWristY = Double(address[16].y)
        let impactWristY = Double(impact[16].y)
        return addressWristY - impactWristY
    }
    
    /// スイング軌道タイプを検出
    private static func detectSwingPathType(phases: SwingPhases, cache: [Int: [NormalizedLandmark]]) -> String {
        guard let impactLM = getNearestLandmarks(timestamp: phases.impact, cache: cache) else {
            return "Unknown"
        }
        
        let rightWristIndex = 16
        let rightElbowIndex = 14
        
        guard impactLM.count > rightWristIndex, impactLM.count > rightElbowIndex else {
            return "Unknown"
        }
        
        let wristX = Double(impactLM[rightWristIndex].x)
        let elbowX = Double(impactLM[rightElbowIndex].x)
        
        let diff = wristX - elbowX
        
        if diff > 0.03 {
            return "Outside-In"
        } else if diff < -0.03 {
            return "Inside-Out"
        } else {
            return "Straight"
        }
    }
}
