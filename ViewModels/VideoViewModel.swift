import SwiftUI
import PhotosUI
import AVKit
import AVFoundation
import Combine
import MediaPipeTasksVision
import SwiftData

/// 動画の再生・解析・状態管理を行うViewModel
/// MVVMの要として、Viewからのアクションを受け取り、Model（MediaPipeManager/SwingAnalyzer）と連携する
@MainActor
class VideoViewModel: ObservableObject {

    // MARK: - SwiftData Context

    /// SwiftDataのModelContext（履歴保存用）
    /// - Note: 外部から設定する必要があります
    var modelContext: ModelContext?

    // MARK: - UI Binding Properties

    /// 選択された動画アイテム
    @Published var selectedItem: PhotosPickerItem? = nil {
        didSet { if let selectedItem { loadVideo(from: selectedItem) } }
    }

    /// 動画プレーヤー
    @Published var player: AVPlayer?

    /// 再生状態
    @Published var isPlaying: Bool = false

    /// 動画のアスペクト比（表示調整用）
    @Published var videoAspectRatio: CGFloat = 9/16

    /// エラーメッセージ（UI表示用）
    @Published var errorMessage: String?
    @Published var showError: Bool = false

    // MARK: - Analysis State

    /// 解析の進行状況
    enum AnalysisStatus {
        case analyzing      // AI解析中（ローディング）
        case setting        // ユーザー設定待機中（アドレス・インパクト指定）
        case complete       // 診断完了（結果表示）
    }

    @Published var status: AnalysisStatus = .analyzing

    // ユーザー設定値（ミリ秒単位）
    @Published var addressTime: Int?
    @Published var impactTime: Int?

    // ゴースト機能用（アドレス・インパクト時の姿勢を重ねて表示）
    @Published var showGhosts: Bool = true
    @Published var showTrajectory: Bool = false // 軌道表示 (デフォルトOFF)
    @Published var addressLandmarks: [NormalizedLandmark]?
    @Published var impactLandmarks: [NormalizedLandmark]?

    // 診断結果
    @Published var analysisResults: [SwingAnalyzer.AnalysisResult] = []

    // AI診断関連
    @Published var coachMode: CoachPersona = CoachPersona.standard
    @Published var isAnalyzingAI: Bool = false
    @Published var diagnosisReport: DiagnosisReport?

    // 現在フレームの骨格データ
    @Published var currentFrameLandmarks: [NormalizedLandmark]? = nil

    /// 診断実行が可能かどうか（アドレスとインパクトが両方設定されているか）
    var canAnalyze: Bool {
        return addressTime != nil && impactTime != nil
    }

    // MARK: - Playback Control

    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 0.0
    @Published var playbackRate: Float = 1.0
    @Published var isSeeking: Bool = false

    // MARK: - Infrastructure

    /// 解析済み骨格データのキャッシュ [タイムスタンプ(ms): ランドマーク]
    var landmarkCache: [Int: [NormalizedLandmark]] = [:]

    private var videoOrientation: UIImage.Orientation = .up
    private var mediaPipeManager = MediaPipeManager()
    private var videoOutput: AVPlayerItemVideoOutput?
    private var displayLink: CADisplayLink?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var asset: AVAsset?
    private var loadingTask: Task<Void, Never>?

    // MARK: - User Actions (Settings)

    /// 現在の再生位置を「アドレス（構え）」として設定する
    /// - Note: ユーザーが「Address」ボタンをタップした際に呼ばれます
    /// - Important: キャッシュに近い時刻のデータがあればそれを使用し、なければ現在フレームのデータを使用します
    func setAddress() {
        guard let player = player else {
            print("⚠️ setAddress: プレーヤーが初期化されていません")
            return
        }
        let ms = Int(player.currentTime().seconds * 1000)

        self.addressTime = ms

        // ゴースト表示用の骨格データを取得
        // 50ms以内にキャッシュされたデータがあればそれを使用（精度向上のため）
        if let cached = getCachedLandmarks(near: ms, tolerance: 50) {
            self.addressLandmarks = cached
        } else {
            // キャッシュにない場合は現在表示中のフレームデータを使用
            self.addressLandmarks = self.currentFrameLandmarks
        }
    }

    /// 現在の再生位置を「インパクト」として設定する
    /// - Note: ユーザーが「Impact」ボタンをタップした際に呼ばれます
    /// - Important: キャッシュに近い時刻のデータがあればそれを使用し、なければ現在フレームのデータを使用します
    func setImpact() {
        guard let player = player else {
            print("⚠️ setImpact: プレーヤーが初期化されていません")
            return
        }
        let ms = Int(player.currentTime().seconds * 1000)
        self.impactTime = ms

        // ゴースト表示用の骨格データを取得
        // 50ms以内にキャッシュされたデータがあればそれを使用（精度向上のため）
        if let cached = getCachedLandmarks(near: ms, tolerance: 50) {
            self.impactLandmarks = cached
        } else {
            // キャッシュにない場合は現在表示中のフレームデータを使用
            self.impactLandmarks = self.currentFrameLandmarks
        }
    }

    /// スイング診断を実行する
    /// - Note: アドレスとインパクトの両方が設定されている場合のみ実行可能
    /// - Important: ルールベース解析とAI解析の両方を実行します
    func runDiagnosis() {
        guard let address = addressTime, let impact = impactTime else {
            print("⚠️ runDiagnosis: アドレスまたはインパクトが設定されていません")
            return
        }

        let phases = SwingAnalyzer.SwingPhases(address: address, impact: impact)
        self.status = .complete

        // SwingAnalyzerを使って診断ロジックを実行（従来のルールベース解析）
        self.analysisResults = SwingAnalyzer.analyzeSwing(phases: phases, cache: landmarkCache)

        // AI診断を非同期で実行（Gemini APIを使用）
        Task {
            await runAIDiagnosis(phases: phases)
        }

        // 結果を見やすくするため、インパクトの瞬間にシークして停止する
        seek(to: Double(impact) / 1000.0)
        pause()
    }

    /// AIによる詳細診断を実行する（Google Gemini APIを使用）
    /// - Parameter phases: スイングのフェーズ情報（アドレスとインパクトの時刻）
    /// - Note: この処理は非同期で実行され、完了までに数秒かかる場合があります
    /// - Important: API呼び出しが失敗した場合は、エラーメッセージを表示します
    private func runAIDiagnosis(phases: SwingAnalyzer.SwingPhases) async {
        self.isAnalyzingAI = true
        self.diagnosisReport = nil

        // 解析用メトリクス（数値データ）の計算
        let metrics = SwingAnalyzer.calculateMetrics(phases: phases, cache: landmarkCache)

        // ユーザープロファイル（TODO: 実際のユーザーデータに置き換える）
        let userProfile: [String: Any] = [
            "average_score": 110,
            "worry": "スライス"
        ]

        do {
            // Gemini APIによる診断を実行（V2: 3ブロック構造プロンプト）
            let report = try await GeminiManager.shared.generateDiagnosisV2(
                metrics: metrics,
                coachPersona: self.coachMode
            )

            await MainActor.run {
                // V2レポートをV1型に変換して保存（既存のDiagnosisViewと互換性維持）
                self.diagnosisReport = report.toDiagnosisReport()
                self.isAnalyzingAI = false
                self.status = .complete
                print("✅ AI Diagnosis V2 completed")

                // 自動保存: 履歴に保存
                if let context = self.modelContext {
                    self.saveAnalysis(to: context)
                } else {
                    print("⚠️ modelContextが設定されていないため、履歴に保存されませんでした")
                }
            }
        } catch {
            // エラーハンドリング: ネットワークエラー、APIキー不正、パースエラーなど
            print("❌ AI診断エラー: \(error)")
            await MainActor.run {
                self.errorMessage = "AI診断に失敗しました: \(error.localizedDescription)"
                self.showError = true
                self.isAnalyzingAI = false
            }
        }
    }

    /// 解析結果をSwiftDataに保存する
    /// - Parameter context: SwiftDataのModelContext
    /// - Note: 動画ファイル自体は別途Documentsディレクトリに保存する必要があります（TODO）
    /// - Important: アドレスとインパクトが設定されている場合のみ保存できます
    func saveAnalysis(to context: ModelContext) {
        guard let address = addressTime, let impact = impactTime else {
            print("⚠️ saveAnalysis: アドレスまたはインパクトが設定されていません")
            return
        }

        // 動画パスの生成（TODO: 実際には動画ファイルをDocumentsにコピーする処理が必要）
        let videoPath = "swing_\(UUID().uuidString).mov"

        // スイングメトリクスの計算
        let phases = SwingAnalyzer.SwingPhases(address: address, impact: impact)
        let metrics = SwingAnalyzer.calculateMetrics(phases: phases, cache: landmarkCache)

        // SwiftDataモデルの作成
        let analysis = SwingAnalysis(
            date: Date(),
            videoPath: videoPath,
            duration: duration,
            addressTime: Double(address),
            impactTime: Double(impact),
            metrics: metrics,
            diagnosisReport: diagnosisReport
        )

        context.insert(analysis)

        // データベースに永続化
        do {
            try context.save()
            print("✅ 解析結果を保存しました")
        } catch {
            print("❌ 解析結果の保存に失敗: \(error.localizedDescription)")
            // TODO: ユーザーにエラーを通知する
        }
    }

    /// 設定をリセットし、再設定モードに戻る（動画は維持）
    func resetSettings() {
        status = .setting
        addressTime = nil
        impactTime = nil
        addressLandmarks = nil
        impactLandmarks = nil
        analysisResults = []
    }

    /// ゴーストの表示/非表示を切り替える
    func toggleGhost() {
        showGhosts.toggle()
    }

    /// 軌道の表示/非表示を切り替える
    func toggleTrajectory() {
        showTrajectory.toggle()
    }

    // MARK: - Playback Actions

    /// 再生/一時停止のトグル
    func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    private func play() {
        guard let player = player else { return }
        // 最後まで再生されていたら最初に戻す
        if player.currentTime().seconds >= duration - 0.1 {
            player.seek(to: .zero)
        }
        player.rate = playbackRate // rateを設定することで再生開始される（play()はrate=1.0にするため不要、あるいはplay()の後に設定する）
        startDisplayLink() // 画面更新同期を開始
        isPlaying = true
    }

    private func pause() {
        player?.pause()
        stopDisplayLink()
        isPlaying = false
    }

    /// 再生速度を変更する
    func setPlaybackRate(_ rate: Float) {
        self.playbackRate = rate
        if isPlaying { player?.rate = rate }
    }

    /// コマ送り/コマ戻し
    /// - Parameter count: フレーム数（正: 進む, 負: 戻る）
    func stepFrame(count: Int) {
        guard let player = player else { return }
        pause()

        let currentS = player.currentTime().seconds
        let frameDuration = 1.0 / 30.0 // 30fpsと仮定
        let newTime = currentS + (Double(count) * frameDuration)
        seek(to: newTime)
    }

    /// 指定した時間へシークする
    func seek(to time: Double) {
        guard let player = player else { return }
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        // スムーズなシークのためにtoleranceを無限大に設定（正確性優先）
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        self.currentTime = time
        updateAnalysisForCurrentTime()
    }

    /// シーク開始（スライダー操作開始時）
    func startSeeking() {
        isSeeking = true
        pause()
    }

    /// シーク終了（スライダー操作終了時）
    func endSeeking() {
        isSeeking = false
        updateAnalysisForCurrentTime()
    }

    // MARK: - Video Loading & Analysis Logic

    /// 動画をロードし、初期設定と解析を開始する
    private func loadVideo(from item: PhotosPickerItem) {
        reset() // 既存の状態をクリア

        loadingTask = Task {
            do {
                // 1. 動画データの取得
                guard let movie = try await item.loadTransferable(type: MovieTransferable.self) else {
                    throw NSError(domain: "VideoViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "動画の読み込みに失敗しました"])
                }

                if Task.isCancelled { return }

                let asset = AVURLAsset(url: movie.url)
                self.asset = asset

                // 動画の長さチェック (2分制限)
                let duration = try await asset.load(.duration).seconds
                if duration > 120 {
                    throw NSError(domain: "VideoViewModel", code: -2, userInfo: [NSLocalizedDescriptionKey: "error_video_too_long".localized])
                }

                // 2. プレーヤーと出力の準備
                setupPlayer(with: asset)

                // 3. メタデータ（向き、サイズ、長さ）の取得
                await setupVideoMetadata(asset: asset)

                // 4. 監視設定
                setupObservers()

                // 5. バックグラウンドでAI解析を実行
                await analyzeVideo(asset: asset)

            } catch {
                if Task.isCancelled { return }
                print("Error loading video: \(error)")
                await MainActor.run {
                    self.errorMessage = "動画を読み込めませんでした: \(error.localizedDescription)"
                    self.showError = true
                    self.status = .setting
                }
            }
        }
    }

    /// プレーヤーとVideoOutputの初期化
    private func setupPlayer(with asset: AVURLAsset) {
        let playerItem = AVPlayerItem(asset: asset)
        setupVideoOutput(for: playerItem)
        self.player = AVPlayer(playerItem: playerItem)
    }

    /// 各種オブザーバーの設定
    private func setupObservers() {
        setupTimeObserver()
        setupEndObserver()
    }

    /// 動画全体をフレームごとに解析し、骨格データをキャッシュする
    private func analyzeVideo(asset: AVAsset) async {
        self.status = .analyzing

        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        // 高速化のため許容誤差を設定（解析精度には影響しないよう注意）
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero

        guard let durationSeconds = try? await asset.load(.duration).seconds else { return }

        // 解析するタイムスタンプのリストを作成（0.1秒間隔）
        // ※ 本番では全フレーム解析が理想だが、MVPでは間引き処理で高速化
        var times: [CMTime] = []
        let step = 0.1
        for t in stride(from: 0.0, to: durationSeconds, by: step) {
            times.append(CMTime(seconds: t, preferredTimescale: 600))
        }

        var tempCache: [Int: [NormalizedLandmark]] = [:]

        // 非同期でフレーム画像を取得して解析
        for await result in imageGenerator.images(for: times) {
            if Task.isCancelled { return }
            switch result {
            case .success(let imageRecord):
                await processImageRecord(cgImage: imageRecord.image, actualTime: imageRecord.actualTime, into: &tempCache)
            case .failure(let error):
                print("Frame generation failed: \(error)")
                continue
            }
        }

        if Task.isCancelled { return }

        // 解析完了後の処理
        // エラーチェック: 骨格検出がほとんどできていない場合（10フレーム未満）
        if tempCache.count < 10 {
            print("❌ Skeleton extraction failed: too few frames detected (\(tempCache.count))")
            await MainActor.run {
                self.errorMessage = "error_skeleton_extraction_failed".localized
                self.showError = true
                // 解析失敗時は設定モードには移行せず、エラー表示のみ（あるいはリセット）
                // ここではユーザーが別の動画を選べるようにする
                self.status = .setting
            }
            return
        }

        self.landmarkCache = tempCache
        self.status = .setting

        // AIによるフェーズ自動提案（アドレス・インパクト位置の初期値設定）
        if let phases = SwingAnalyzer.suggestPhases(from: tempCache) {
            // ユーザー要望により自動設定は無効化（手動設定のみ）
            // applySuggestedPhases(phases)
        }
    }

    /// 1フレーム分の画像をMediaPipeで処理する
    private func processImageRecord(cgImage: CGImage, actualTime: CMTime, into cache: inout [Int: [NormalizedLandmark]]) async {
        let uiImage = UIImage(cgImage: cgImage)
        do {
            // MediaPipe用画像への変換
            let mpImage = try MPImage(uiImage: uiImage, orientation: .up) // ImageGeneratorは回転済み画像を返すため.upでOK
            let ms = Int(actualTime.seconds * 1000)

            // 骨格検出実行
            let res = try mediaPipeManager.detect(image: mpImage, timestamp: ms)
            if let landmarks = res.landmarks.first {
                cache[ms] = landmarks
            }
        } catch {
            print("Detection failed at \(actualTime.seconds): \(error)")
        }
    }

    /// AI提案フェーズを適用する
    private func applySuggestedPhases(_ phases: SwingAnalyzer.SwingPhases) {
        self.addressTime = phases.address
        self.addressLandmarks = landmarkCache[phases.address]

        // ユーザーの利便性のため、アドレス位置にシークしておく
        self.seek(to: Double(phases.address) / 1000.0)

        // インパクトは誤検知の可能性があるため、あえて自動設定せずユーザーに確認させるか、
        // 提案値として保持だけしておく（今回はシンプルにアドレスのみ適用）
    }

    // MARK: - Internal Helpers (Video Infrastructure)

    private func setupVideoMetadata(asset: AVAsset) async {
        // 動画の向きとアスペクト比を取得
        if let track = try? await asset.loadTracks(withMediaType: .video).first {
            if let transform = try? await track.load(.preferredTransform) {
                self.videoOrientation = getVideoOrientation(from: transform)
            }
            if let size = try? await track.load(.naturalSize) {
                // 縦向き動画の場合はアスペクト比を反転させる
                let isPortrait = (videoOrientation == .right || videoOrientation == .left)
                let ratio = isPortrait ? size.height / size.width : size.width / size.height
                self.videoAspectRatio = ratio
            }
        }
        if let d = try? await asset.load(.duration) { self.duration = d.seconds }
    }

    /// リアルタイム処理用のVideoOutputを設定
    private func setupVideoOutput(for item: AVPlayerItem) {
        let attr = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: attr)
        item.add(output)
        self.videoOutput = output
    }

    /// 再生時間の監視（スライダー同期用）
    private func setupTimeObserver() {
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.05, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self = self, !self.isSeeking else { return }
            self.currentTime = time.seconds
            self.updateAnalysisForCurrentTime()
        }
    }

    /// 再生終了時の監視
    private func setupEndObserver() {
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink { [weak self] _ in
                self?.pause()
            }
            .store(in: &cancellables)
    }

    /// DisplayLink（画面更新ごとの処理）の開始
    private func startDisplayLink() {
        stopDisplayLink()
        displayLink = CADisplayLink(target: self, selector: #selector(processFrame))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func processFrame() {
        updateAnalysisForCurrentTime()
    }

    /// 現在の再生時間に合わせて解析結果（骨格）を更新する
    private func updateAnalysisForCurrentTime() {
        guard let player = player else { return }
        let cTime = player.currentTime()
        let ms = Int(cTime.seconds * 1000)

        // 1. キャッシュにあればそれを使う（高速）
        if let cached = getCachedLandmarks(near: ms, tolerance: 80) {
            self.currentFrameLandmarks = cached
            return
        }

        // 2. キャッシュになければリアルタイム解析（VideoOutputから画像取得）
        guard let output = videoOutput, output.hasNewPixelBuffer(forItemTime: cTime) else { return }
        if let pixelBuffer = output.copyPixelBuffer(forItemTime: cTime, itemTimeForDisplay: nil) {
            performRealtimeAnalysis(pixelBuffer: pixelBuffer, timestamp: ms)
        }
    }

    /// キャッシュから近似時間のランドマークを取得する
    private func getCachedLandmarks(near timestamp: Int, tolerance: Int) -> [NormalizedLandmark]? {
        return landmarkCache.first(where: { abs($0.key - timestamp) < tolerance })?.value
    }

    /// リアルタイム解析を実行（非同期）
    private func performRealtimeAnalysis(pixelBuffer: CVPixelBuffer, timestamp: Int) {
        Task {
            let uiImage = UIImage(ciImage: CIImage(cvPixelBuffer: pixelBuffer))
            // 注意: ここでのorientationはVideoOutputからの生データに対するものなので調整が必要な場合がある
            if let mpImage = try? MPImage(uiImage: uiImage, orientation: self.videoOrientation),
               let result = try? self.mediaPipeManager.detect(image: mpImage, timestamp: timestamp),
               let landmarks = result.landmarks.first {
                await MainActor.run {
                    self.currentFrameLandmarks = landmarks
                }
            }
        }
    }

    /// Transformから動画の向き（Orientation）を判定する
    private func getVideoOrientation(from transform: CGAffineTransform) -> UIImage.Orientation {
        let angle = atan2(transform.b, transform.a) * 180 / .pi
        let normalized = angle < 0 ? angle + 360 : angle
        if normalized >= 85 && normalized <= 95 { return .right }
        if normalized >= 175 && normalized <= 185 { return .down }
        if normalized >= 265 && normalized <= 275 { return .left }
        return .up
    }

    /// 状態を完全にリセットする
    /// 状態を完全にリセットする
    func reset() {
        // ロード中のタスクがあればキャンセル
        loadingTask?.cancel()
        loadingTask = nil

        // DisplayLinkを確実に停止
        stopDisplayLink()

        // 再生を停止
        pause()

        // TimeObserverを確実に削除
        if let player = player, let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
        timeObserver = nil

        // PlayerItemからVideoOutputを削除
        if let currentItem = player?.currentItem {
            if let output = videoOutput {
                currentItem.remove(output)
            }
        }

        // AVPlayerのリソースを解放
        player?.replaceCurrentItem(with: nil)
        player = nil
        videoOutput = nil
        asset = nil

        // MediaPipeManagerを再生成して状態をクリア（重要：2回目以降の読み込み不具合対策）
        mediaPipeManager = MediaPipeManager()

        // 状態をリセット
        status = .analyzing
        addressTime = nil
        impactTime = nil
        addressLandmarks = nil
        impactLandmarks = nil
        analysisResults = []
        currentFrameLandmarks = nil
        landmarkCache.removeAll()
        duration = 0.0
        currentTime = 0.0
        isPlaying = false
        playbackRate = 1.0
        isSeeking = false
        diagnosisReport = nil
        isAnalyzingAI = false

        // Combineサブスクリプションをクリーンアップ
        cancellables.removeAll()

        // エラー状態をクリア
        errorMessage = nil
        showError = false

        // デフォルトのコーチ設定を読み込む
        if let savedId = UserDefaults.standard.string(forKey: "coachModeId") {
            // 現在の言語で利用可能なペルソナからIDが一致するものを探す
            let availablePersonas = CoachPersona.availablePersonas(for: LanguageManager.shared.currentLanguage)
            if let matchedPersona = availablePersonas.first(where: { $0.id == savedId }) {
                self.coachMode = matchedPersona
            } else {
                // IDが見つからない場合（言語切り替え時など）は標準に戻す
                self.coachMode = CoachPersona.standard
            }
        } else {
            self.coachMode = CoachPersona.standard
        }

        // メモリ解放を促進（デバッグ用）
        print("🔄 VideoViewModel reset completed")
    }

    // ViewModelが破棄される際の最終クリーンアップ
    deinit {
        print("🗑️ VideoViewModel deallocating")
        // Note: deinitはメインアクター外で実行される可能性があるため、
        // @MainActorのメソッドは呼び出せません。
        // stopDisplayLink()はreset()で確実に呼ばれるため、ここでは不要です。
        cancellables.removeAll()
    }
}

