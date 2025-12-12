import Foundation
import MediaPipeTasksVision
import UIKit

/// MediaPipeのPoseLandmarkerを管理するクラス
/// - 動画フレームから骨格ランドマーク（33ポイント）を検出します
/// - Note: MediaPipe Pose Landmarker Liteモデルを使用しています
/// - Important: バンドルに`pose_landmarker_lite.task`ファイルが必要です
class MediaPipeManager {
    private var poseLandmarker: PoseLandmarker?
    
    init() {
        setupLandmarker()
    }
    
    /// PoseLandmarkerの初期設定を行う
    /// - Note: アプリ起動時にinit()から自動的に呼ばれます
    /// - Important: モデルファイルが見つからない場合はエラーメッセージを出力します
    private func setupLandmarker() {
        let options = PoseLandmarkerOptions()
        // モデルファイルのパス設定（バンドル内のファイルを指定）
        options.baseOptions.modelAssetPath = "pose_landmarker_lite.task"
        
        // 実行モード: 動画モード（複数フレームを連続処理する）
        options.runningMode = .video
        
        // 検出する人数（1人のみ）
        // ゴルフスイングの場合、フレーム内にプレーヤーは1人のみと仮定
        options.numPoses = 1
        
        // 信頼度のしきい値（これ以下の検出結果は無視される）
        options.minPoseDetectionConfidence = 0.5  // 人物検出の信頼度
        options.minPosePresenceConfidence = 0.5   // ポーズ存在の信頼度
        options.minTrackingConfidence = 0.5       // 追跡精度
        
        do {
            poseLandmarker = try PoseLandmarker(options: options)
        } catch {
            print("❌ MediaPipeManager 初期化エラー: \(error.localizedDescription)")
            // 初期化失敗時のリカバリー処理や通知をここに記述する（必要に応じて）
            // TODO: ユーザーにエラーを通知する機構を追加する
        }
    }
    
    /// 画像フレームから骨格を検出する
    /// - Parameters:
    ///   - image: MediaPipe用の画像データ
    ///   - timestamp: 動画内のタイムスタンプ（ミリ秒）
    /// - Returns: 検出結果（PoseLandmarkerResult）
    /// - Throws: 初期化エラーまたは検出エラー
    func detect(image: MPImage, timestamp: Int) throws -> PoseLandmarkerResult {
        guard let poseLandmarker = poseLandmarker else {
            throw NSError(
                domain: "MediaPipeManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "PoseLandmarkerが初期化されていません。モデルファイルを確認してください。"]
            )
        }
        return try poseLandmarker.detect(videoFrame: image, timestampInMilliseconds: timestamp)
    }
}
