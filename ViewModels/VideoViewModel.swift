import SwiftUI
import PhotosUI
import AVKit
import AVFoundation
import Combine
import MediaPipeTasksVision
import SwiftData

/// 動画ロード時のエラー種別
enum VideoLoadError: LocalizedError {
    case failedToLoad  // 動画の読み込み失敗
    case tooLong       // 動画が長すぎる（2分超過）
    
    var errorDescription: String? {
        switch self {
        case .failedToLoad:
            return "動画の読み込みに失敗しました"
        case .tooLong:
            return "動画が長すぎます（2分以内にしてください）"
        }
    }
}

/// 動画の再生・解析・状態管理を行うViewModel
/// MVVMの要として、Viewからのアクションを受け取り、Model（MediaPipeManager/SwingAnalyzer）と連携する
@MainActor
class VideoViewModel: ObservableObject {
    
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
    
    // SwiftData Context
    var modelContext: ModelContext?
    
    // 現在解析中のSwingAnalysis ID（更新用）
    private var currentAnalysisID: UUID?

    
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
        
        // 解析開始時に初期レコードを保存（「解析中」として表示するため）
        if let context = self.modelContext {
            await MainActor.run {
                self.currentAnalysisID = self.saveInitialAnalysis(phases: phases, context: context)
            }
        }
        
        // 解析用メトリクス（数値データ）の計算
        let metrics = SwingAnalyzer.calculateMetrics(phases: phases, cache: landmarkCache)
        
        // ユーザープロファイル（TODO: 実際のユーザーデータに置き換える）
        let userProfile: [String: Any] = [
            "average_score": 110,
            "worry": "スライス"
        ]
        
        do {
            // Gemini APIによる診断を実行
            let report = try await GeminiManager.shared.generateDiagnosis(
                metrics: metrics,
                coachPersona: self.coachMode // Refactored to pass CoachPersona
            )
            
            await MainActor.run {
                self.diagnosisReport = report
                self.isAnalyzingAI = false
                self.status = .complete
                print("✅ AI Diagnosis completed")
                
                // Update existing record in SwiftData
                if let context = self.modelContext, let analysisID = self.currentAnalysisID {
                    self.updateAnalysis(id: analysisID, report: report, context: context)
                } else if let context = self.modelContext {
                    // Fallback: create new if ID missing (shouldn't happen)
                    self.saveAnalysis(to: context)
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
    
    // MARK: - Data Persistence (データ永続化)
    
    /// 解析結果をSwiftDataに保存する
    ///
    /// アドレスとインパクトが設定されており、
    /// AI診断が完了している場合にのみ保存できます。
    ///
    /// 注意: 現在の実装では動画ファイル自体は保存されません。
    /// 将来的にはDocumentsディレクトリへのコピーが必要です。
    ///
    /// - Parameter context: SwiftDataのModelContext
    func saveAnalysis(to context: ModelContext) {
        // アドレスとインパクトの設定を確認
        guard let address = addressTime, let impact = impactTime else {
            print("⚠️ saveAnalysis: アドレスまたはインパクトが設定されていません")
            return
        }
        
        // 診断レポートが存在するか確認
        guard diagnosisReport != nil else {
            print("⚠️ saveAnalysis: 診断レポートがまだ生成されていません")
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
        
        // データベースに挿入
        context.insert(analysis)
        
        // データベースに永続化
        do {
            try context.save()
            print("✅ 解析結果を保存しました (ID: \(analysis.id))")
        } catch {
            print("❌ 解析結果の保存に失敗: \(error.localizedDescription)")
            
            // ユーザーにエラーを通知
            Task { @MainActor in
                self.errorMessage = "結果の保存に失敗しました。もう一度お試しください。"
                self.showError = true
            }
        }
    }
    
    /// 解析開始時に初期レコードを保存する
    private func saveInitialAnalysis(phases: SwingAnalyzer.SwingPhases, context: ModelContext) -> UUID? {
        let videoPath = "swing_\(UUID().uuidString).mov" // TODO: 実装時は実際のパス
        let metrics = SwingAnalyzer.calculateMetrics(phases: phases, cache: landmarkCache)
        
        let analysis = SwingAnalysis(
            date: Date(),
            videoPath: videoPath,
            duration: duration,
            addressTime: Double(phases.address),
            impactTime: Double(phases.impact),
            metrics: metrics,
            diagnosisReport: nil // レポートなし＝解析中
        )
        
        context.insert(analysis)
        
        do {
            try context.save()
            print("✅ 初期解析レコードを保存しました (ID: \(analysis.id))")
            return analysis.id
        } catch {
            print("❌ 初期保存失敗: \(error)")
            return nil
        }
    }
    
    /// 解析完了時にレコードを更新する
    private func updateAnalysis(id: UUID, report: DiagnosisReport, context: ModelContext) {
        // IDで検索して更新（SwiftDataのFetchDescriptorを使用するか、メモリ上のオブジェクトを更新）
        // ここでは簡易的に、contextに既にあるはずのオブジェクトを探すか、クエリする
        // 注: SwiftDataでID検索は少し手間なので、FetchDescriptorを使う
        
        let descriptor = FetchDescriptor<SwingAnalysis>(predicate: #Predicate { $0.id == id })
        
        do {
            if let analysis = try context.fetch(descriptor).first {
                analysis.diagnosisReport = report
                try context.save()
                print("✅ 解析レコードを更新しました (ID: \(id))")
            } else {
                print("⚠️ 更新対象のレコードが見つかりません (ID: \(id))")
                // 見つからない場合は新規保存
                saveAnalysis(to: context)
            }
        } catch {
            print("❌ 更新失敗: \(error)")
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
    
    // MARK: - Video Loading & Setup (動画ロードと設定)
    
    /// 動画をロードし、初期設定と解析を開始する
    ///
    /// このメソッドは以下の手順で動画を処理します：
    /// 1. 既存の状態をクリア（reset）
    /// 2. PhotosPickerItemから動画データを取得
    /// 3. 動画の長さを検証（2分以内の制限）
    /// 4. AVPlayerとVideoOutputを設定
    /// 5. 動画のメタデータ（向き、サイズ、長さ）を取得
    /// 6. 監視者（Observer）を設定
    /// 7. 骨格検出解析を実行
    ///
    /// - Parameter item: ユーザーが選択したPhotosPickerアイテム
    private func loadVideo(from item: PhotosPickerItem) {
        reset() // 既存の状態を完全にクリア
        
        loadingTask = Task {
            do {
                // 1. 動画データの取得
                guard let movie = try await item.loadTransferable(type: MovieTransferable.self) else {
                    throw VideoLoadError.failedToLoad
                }
                
                // キャンセルチェック
                if Task.isCancelled { return }
                
                let asset = AVURLAsset(url: movie.url)
                self.asset = asset
                
                // 2. 動画の長さを検証（2分以内の制限）
                let duration = try await asset.load(.duration).seconds
                guard duration <= 120 else {
                    throw VideoLoadError.tooLong
                }
                
                // 3. プレーヤーと出力の準備
                setupPlayer(with: asset)
                
                // 4. メタデータ（向き、サイズ、長さ）の取得
                await setupVideoMetadata(asset: asset)
                
                // 5. 監視設定（再生時間、再生終了）
                setupObservers()
                
                // 6. バックグラウンドで骨格検出解析を実行
                await analyzeVideo(asset: asset)
                
            } catch {
                // キャンセルされた場合はエラー処理をスキップ
                if Task.isCancelled { return }
                
                // エラーメッセージの生成
                let errorMessage = generateVideoLoadErrorMessage(from: error)
                
                print("❌ 動画ロードエラー: \(error.localizedDescription)")
                await MainActor.run {
                    self.errorMessage = errorMessage
                    self.showError = true
                    self.status = .setting
                }
            }
        }
    }
    
    /// 動画ロードエラーのメッセージを生成する
    /// - Parameter error: 発生したエラー
    /// - Returns: ユーザーに表示するエラーメッセージ
    private func generateVideoLoadErrorMessage(from error: Error) -> String {
        if let videoError = error as? VideoLoadError {
            switch videoError {
            case .failedToLoad:
                return "動画の読み込みに失敗しました。別の動画をお試しください。"
            case .tooLong:
                return "error_video_too_long".localized
            }
        }
        return "動画を読み込めませんでした: \(error.localizedDescription)"
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
    
    // MARK: - Video Analysis (動画解析)
    
    /// 動画全体をフレームごとに解析し、骨格データをキャッシュする
    ///
    /// このメソッドは以下の処理を順番に実行します：
    /// 1. 動画の長さを取得
    /// 2. 解析するタイムスタンプ（0.1秒間隔）のリストを生成
    /// 3. 各フレームから骨格データを抽出
    /// 4. 抽出結果を検証（最小フレーム数チェック）
    private func analyzeVideo(asset: AVAsset) async {
        self.status = .analyzing
        
        // 動画の長さを取得
        guard let durationSeconds = try? await asset.load(.duration).seconds else {
            await handleAnalysisError(message: "動画の長さを取得できませんでした")
            return
        }
        
        // ImageGeneratorの設定
        let imageGenerator = configureImageGenerator(for: asset)
        
        // 解析するタイムスタンプのリストを生成
        let times = generateAnalysisTimestamps(duration: durationSeconds)
        
        // 各フレームから骨格データを抽出
        let tempCache = await extractLandmarksFromFrames(using: imageGenerator, times: times)
        
        // キャンセルチェック
        if Task.isCancelled { return }
        
        // 抽出結果を検証
        guard validateExtractionResults(cache: tempCache) else {
            return
        }
        
        // キャッシュを更新して設定モードに移行
        self.landmarkCache = tempCache
        self.status = .setting
        
        // 注: AIによるフェーズ自動提案は現在無効化されています
        // ユーザーが手動でアドレスとインパクトを設定する必要があります
    }
    
    /// ImageGeneratorを設定する
    /// - Parameter asset: 設定対象のAVAsset
    /// - Returns: 設定済みのAVAssetImageGenerator
    private func configureImageGenerator(for asset: AVAsset) -> AVAssetImageGenerator {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        // 正確なタイムスタンプでフレームを取得するため、許容誤差をゼロに設定
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        return generator
    }
    
    /// 解析するタイムスタンプのリストを生成する
    ///
    /// 0.1秒間隔で動画全体をカバーするタイムスタンプを生成します。
    /// 理想的には全フレーム（30fps = 0.033秒間隔）を解析すべきですが、
    /// パフォーマンスのため間引いています。
    ///
    /// - Parameter duration: 動画の長さ（秒）
    /// - Returns: CMTimeの配列
    private func generateAnalysisTimestamps(duration: Double) -> [CMTime] {
        let samplingInterval = 0.1  // サンプリング間隔（秒）
        let timescale: Int32 = 600  // CMTimeの精度
        
        var timestamps: [CMTime] = []
        for time in stride(from: 0.0, to: duration, by: samplingInterval) {
            timestamps.append(CMTime(seconds: time, preferredTimescale: timescale))
        }
        
        return timestamps
    }
    
    /// 各フレームから骨格データを抽出する
    ///
    /// ImageGeneratorを使用して各タイムスタンプのフレーム画像を取得し、
    /// MediaPipeで骨格検出を実行します。
    ///
    /// - Parameters:
    ///   - imageGenerator: 画像生成器
    ///   - times: 解析するタイムスタンプの配列
    /// - Returns: タイムスタンプ（ミリ秒）をキーとした骨格データの辞書
    private func extractLandmarksFromFrames(
        using imageGenerator: AVAssetImageGenerator,
        times: [CMTime]
    ) async -> [Int: [NormalizedLandmark]] {
        var landmarkCache: [Int: [NormalizedLandmark]] = [:]
        
        // 非同期でフレーム画像を取得して解析
        for await result in imageGenerator.images(for: times) {
            // キャンセルチェック
            if Task.isCancelled { break }
            
            switch result {
            case let .success(requestedTime: _, image: cgImage, actualTime: actualTime):
                // 骨格データを抽出してキャッシュに追加
                await processImageRecord(
                    cgImage: cgImage,
                    actualTime: actualTime,
                    into: &landmarkCache
                )
            case let .failure(requestedTime: _, error: error):
                // フレーム生成失敗は警告のみ（その他のフレームは処理続行）
                print("⚠️ フレーム生成失敗: \(error.localizedDescription)")
                continue
            }
        }
        
        return landmarkCache
    }
    
    /// 骨格抽出結果を検証する
    ///
    /// 検出された骨格データが十分な数あるかチェックします。
    /// 最低10フレーム分の骨格データが必要です。
    ///
    /// - Parameter cache: 検証する骨格データのキャッシュ
    /// - Returns: 検証に合格した場合true、失敗した場合false
    private func validateExtractionResults(cache: [Int: [NormalizedLandmark]]) -> Bool {
        let minimumRequiredFrames = 10
        
        if cache.count < minimumRequiredFrames {
            print("❌ 骨格抽出失敗: 検出フレーム数が不足 (\(cache.count)/\(minimumRequiredFrames))")
            
            Task { @MainActor in
                self.errorMessage = "error_skeleton_extraction_failed".localized
                self.showError = true
                self.status = .setting
            }
            
            return false
        }
        
        return true
    }
    
    /// 解析エラーをハンドリングする
    ///
    /// エラーメッセージをユーザーに表示し、設定モードに戻します。
    ///
    /// - Parameter message: エラーメッセージ
    private func handleAnalysisError(message: String) async {
        await MainActor.run {
            self.errorMessage = message
            self.showError = true
            self.status = .setting
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

