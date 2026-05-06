import Foundation
import MediaPipeTasksVision
import UIKit

/// MediaPipeのPoseLandmarkerを管理するクラス
class MediaPipeManager {
    private var poseLandmarker: PoseLandmarker?
    
    init() {
        setupLandmarker()
    }
    
    private func setupLandmarker() {
        let options = PoseLandmarkerOptions()
        options.baseOptions.modelAssetPath = "pose_landmarker_lite.task"
        options.runningMode = .video
        options.numPoses = 1
        options.minPoseDetectionConfidence = 0.5
        options.minPosePresenceConfidence = 0.5
        options.minTrackingConfidence = 0.5
        
        do {
            poseLandmarker = try PoseLandmarker(options: options)
        } catch {
            print("\u{274C} MediaPipeManager \u521D\u671F\u5316\u30A8\u30E9\u30FC: \(error.localizedDescription)")
        }
    }
    
    func detect(image: MPImage, timestamp: Int) throws -> PoseLandmarkerResult {
        guard let poseLandmarker = poseLandmarker else {
            throw NSError(
                domain: "MediaPipeManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "PoseLandmarker\u304C\u521D\u671F\u5316\u3055\u308C\u3066\u3044\u307E\u305B\u3093\u3002\u30E2\u30C7\u30EB\u30D5\u30A1\u30A4\u30EB\u3092\u78BA\u8A8D\u3057\u3066\u304F\u3060\u3055\u3044\u3002"]
            )
        }
        return try poseLandmarker.detect(videoFrame: image, timestampInMilliseconds: timestamp)
    }
}
