import SwiftUI
import PhotosUI
import AVKit
import AVFoundation
import Combine
import MediaPipeTasksVision
import SwiftData

@MainActor
class VideoViewModel: ObservableObject {
    
    // MARK: - SwiftData Context
    var modelContext: ModelContext?
    
    // MARK: - UI Binding Properties
    @Published var selectedItem: PhotosPickerItem? = nil {
        didSet { if let selectedItem { loadVideo(from: selectedItem) } }
    }
    @Published var player: AVPlayer?
    @Published var isPlaying: Bool = false
    @Published var videoAspectRatio: CGFloat = 9/16
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // MARK: - Analysis State
    enum AnalysisStatus {
        case analyzing, setting, complete
    }
    @Published var status: AnalysisStatus = .analyzing
    @Published var addressTime: Int?
    @Published var impactTime: Int?
    @Published var showGhosts: Bool = true
    @Published var showTrajectory: Bool = false
    @Published var addressLandmarks: [NormalizedLandmark]?
    @Published var impactLandmarks: [NormalizedLandmark]?
    @Published var analysisResults: [SwingAnalyzer.AnalysisResult] = []
    @Published var coachMode: CoachPersona = CoachPersona.standard
    @Published var isAnalyzingAI: Bool = false
    @Published var diagnosisReport: DiagnosisReport?
    @Published var currentFrameLandmarks: [NormalizedLandmark]? = nil
    
    var canAnalyze: Bool { addressTime != nil && impactTime != nil }
    
    // MARK: - Playback Control
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 0.0
    @Published var playbackRate: Float = 1.0
    @Published var isSeeking: Bool = false
    
    // MARK: - Infrastructure
    var landmarkCache: [Int: [NormalizedLandmark]] = [:]
    private var videoOrientation: UIImage.Orientation = .up
    private var mediaPipeManager = MediaPipeManager()
    private var videoOutput: AVPlayerItemVideoOutput?
    private var displayLink: CADisplayLink?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var asset: AVAsset?
    private var loadingTask: Task<Void, Never>?
    
    // MARK: - User Actions
    
    func setAddress() {
        guard let player = player else { return }
        let ms = Int(player.currentTime().seconds * 1000)
        self.addressTime = ms
        if let cached = getCachedLandmarks(near: ms, tolerance: 50) {
            self.addressLandmarks = cached
        } else {
            self.addressLandmarks = self.currentFrameLandmarks
        }
    }
    
    func setImpact() {
        guard let player = player else { return }
        let ms = Int(player.currentTime().seconds * 1000)
        self.impactTime = ms
        if let cached = getCachedLandmarks(near: ms, tolerance: 50) {
            self.impactLandmarks = cached
        } else {
            self.impactLandmarks = self.currentFrameLandmarks
        }
    }
    
    func runDiagnosis() {
        guard let address = addressTime, let impact = impactTime else { return }
        let phases = SwingAnalyzer.SwingPhases(address: address, impact: impact)
        self.status = .complete
        self.analysisResults = SwingAnalyzer.analyzeSwing(phases: phases, cache: landmarkCache)
        Task { await runAIDiagnosis(phases: phases) }
        seek(to: Double(impact) / 1000.0)
        pause()
    }
    
    private func runAIDiagnosis(phases: SwingAnalyzer.SwingPhases) async {
        self.isAnalyzingAI = true
        self.diagnosisReport = nil
        let metrics = SwingAnalyzer.calculateMetrics(phases: phases, cache: landmarkCache)
        do {
            let report = try await GeminiManager.shared.generateDiagnosisV2(metrics: metrics, coachPersona: self.coachMode)
            await MainActor.run {
                self.diagnosisReport = report.toDiagnosisReport()
                self.isAnalyzingAI = false
                self.status = .complete
                if let context = self.modelContext { self.saveAnalysis(to: context) }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "AI\u{8A3A}\u{65AD}\u{306B}\u{5931}\u{6557}\u{3057}\u{307E}\u{3057}\u{305F}: \(error.localizedDescription)"
                self.showError = true
                self.isAnalyzingAI = false
            }
        }
    }
    
    func saveAnalysis(to context: ModelContext) {
        guard let address = addressTime, let impact = impactTime else { return }
        let videoPath = "swing_\(UUID().uuidString).mov"
        let phases = SwingAnalyzer.SwingPhases(address: address, impact: impact)
        let metrics = SwingAnalyzer.calculateMetrics(phases: phases, cache: landmarkCache)
        let analysis = SwingAnalysis(date: Date(), videoPath: videoPath, duration: duration,
                                    addressTime: Double(address), impactTime: Double(impact),
                                    metrics: metrics, diagnosisReport: diagnosisReport)
        context.insert(analysis)
        do { try context.save() } catch { print("\u{274C} \u{89E3}\u{6790}\u{7D50}\u{679C}\u{306E}\u{4FDD}\u{5B58}\u{306B}\u{5931}\u{6557}: \(error.localizedDescription)") }
    }
    
    func resetSettings() {
        status = .setting; addressTime = nil; impactTime = nil
        addressLandmarks = nil; impactLandmarks = nil; analysisResults = []
    }
    
    func toggleGhost() { showGhosts.toggle() }
    func toggleTrajectory() { showTrajectory.toggle() }
    
    // MARK: - Playback Actions
    
    func togglePlayPause() {
        guard player != nil else { return }
        if isPlaying { pause() } else { play() }
    }
    
    private func play() {
        guard let player = player else { return }
        if player.currentTime().seconds >= duration - 0.1 { player.seek(to: .zero) }
        player.rate = playbackRate
        startDisplayLink()
        isPlaying = true
    }
    
    private func pause() {
        player?.pause(); stopDisplayLink(); isPlaying = false
    }
    
    func setPlaybackRate(_ rate: Float) {
        self.playbackRate = rate
        if isPlaying { player?.rate = rate }
    }
    
    func stepFrame(count: Int) {
        guard player != nil else { return }
        pause()
        let currentS = player!.currentTime().seconds
        let newTime = currentS + (Double(count) * (1.0 / 30.0))
        seek(to: newTime)
    }
    
    func seek(to time: Double) {
        guard let player = player else { return }
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        self.currentTime = time
        updateAnalysisForCurrentTime()
    }
    
    func startSeeking() { isSeeking = true; pause() }
    func endSeeking() { isSeeking = false; updateAnalysisForCurrentTime() }
    
    // MARK: - Video Loading & Analysis
    
    private func loadVideo(from item: PhotosPickerItem) {
        reset()
        loadingTask = Task {
            do {
                guard let movie = try await item.loadTransferable(type: MovieTransferable.self) else {
                    throw NSError(domain: "VideoViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "\u{52D5}\u{753B}\u{306E}\u{8AAD}\u{307F}\u{8FBC}\u{307F}\u{306B}\u{5931}\u{6557}\u{3057}\u{307E}\u{3057}\u{305F}"])
                }
                if Task.isCancelled { return }
                let asset = AVURLAsset(url: movie.url); self.asset = asset
                let duration = try await asset.load(.duration).seconds
                if duration > 120 {
                    throw NSError(domain: "VideoViewModel", code: -2, userInfo: [NSLocalizedDescriptionKey: "error_video_too_long".localized])
                }
                setupPlayer(with: asset)
                await setupVideoMetadata(asset: asset)
                setupObservers()
                await analyzeVideo(asset: asset)
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    self.errorMessage = "\u{52D5}\u{753B}\u{3092}\u{8AAD}\u{307F}\u{8FBC}\u{3081}\u{307E}\u{305B}\u{3093}\u{3067}\u{3057}\u{305F}: \(error.localizedDescription)"
                    self.showError = true; self.status = .setting
                }
            }
        }
    }
    
    private func setupPlayer(with asset: AVURLAsset) {
        let playerItem = AVPlayerItem(asset: asset)
        setupVideoOutput(for: playerItem)
        self.player = AVPlayer(playerItem: playerItem)
    }
    
    private func setupObservers() { setupTimeObserver(); setupEndObserver() }
    
    private func analyzeVideo(asset: AVAsset) async {
        self.status = .analyzing
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero
        guard let durationSeconds = try? await asset.load(.duration).seconds else { return }
        var times: [CMTime] = []
        for t in stride(from: 0.0, to: durationSeconds, by: 0.1) {
            times.append(CMTime(seconds: t, preferredTimescale: 600))
        }
        var tempCache: [Int: [NormalizedLandmark]] = [:]
        for await result in imageGenerator.images(for: times) {
            if Task.isCancelled { return }
            switch result {
            case .success(let imageRecord):
                await processImageRecord(cgImage: imageRecord.image, actualTime: imageRecord.actualTime, into: &tempCache)
            case .failure: continue
            }
        }
        if Task.isCancelled { return }
        if tempCache.count < 10 {
            await MainActor.run {
                self.errorMessage = "error_skeleton_extraction_failed".localized
                self.showError = true; self.status = .setting
            }
            return
        }
        self.landmarkCache = tempCache
        self.status = .setting
        if let _ = SwingAnalyzer.suggestPhases(from: tempCache) { /* Manual mode only */ }
    }
    
    private func processImageRecord(cgImage: CGImage, actualTime: CMTime, into cache: inout [Int: [NormalizedLandmark]]) async {
        let uiImage = UIImage(cgImage: cgImage)
        do {
            let mpImage = try MPImage(uiImage: uiImage, orientation: .up)
            let ms = Int(actualTime.seconds * 1000)
            let res = try mediaPipeManager.detect(image: mpImage, timestamp: ms)
            if let landmarks = res.landmarks.first { cache[ms] = landmarks }
        } catch { }
    }
    
    private func applySuggestedPhases(_ phases: SwingAnalyzer.SwingPhases) {
        self.addressTime = phases.address
        self.addressLandmarks = landmarkCache[phases.address]
        self.seek(to: Double(phases.address) / 1000.0)
    }
    
    // MARK: - Internal Helpers
    
    private func setupVideoMetadata(asset: AVAsset) async {
        if let track = try? await asset.loadTracks(withMediaType: .video).first {
            if let transform = try? await track.load(.preferredTransform) {
                self.videoOrientation = getVideoOrientation(from: transform)
            }
            if let size = try? await track.load(.naturalSize) {
                let isPortrait = (videoOrientation == .right || videoOrientation == .left)
                self.videoAspectRatio = isPortrait ? size.height / size.width : size.width / size.height
            }
        }
        if let d = try? await asset.load(.duration) { self.duration = d.seconds }
    }
    
    private func setupVideoOutput(for item: AVPlayerItem) {
        let attr = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: attr)
        item.add(output); self.videoOutput = output
    }
    
    private func setupTimeObserver() {
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.05, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self = self, !self.isSeeking else { return }
            self.currentTime = time.seconds
            self.updateAnalysisForCurrentTime()
        }
    }
    
    private func setupEndObserver() {
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink { [weak self] _ in self?.pause() }
            .store(in: &cancellables)
    }
    
    private func startDisplayLink() {
        stopDisplayLink()
        displayLink = CADisplayLink(target: self, selector: #selector(processFrame))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopDisplayLink() { displayLink?.invalidate(); displayLink = nil }
    
    @objc private func processFrame() { updateAnalysisForCurrentTime() }
    
    private func updateAnalysisForCurrentTime() {
        guard let player = player else { return }
        let ms = Int(player.currentTime().seconds * 1000)
        if let cached = getCachedLandmarks(near: ms, tolerance: 80) {
            self.currentFrameLandmarks = cached; return
        }
        let cTime = player.currentTime()
        guard let output = videoOutput, output.hasNewPixelBuffer(forItemTime: cTime) else { return }
        if let pixelBuffer = output.copyPixelBuffer(forItemTime: cTime, itemTimeForDisplay: nil) {
            performRealtimeAnalysis(pixelBuffer: pixelBuffer, timestamp: ms)
        }
    }
    
    private func getCachedLandmarks(near timestamp: Int, tolerance: Int) -> [NormalizedLandmark]? {
        return landmarkCache.first(where: { abs($0.key - timestamp) < tolerance })?.value
    }
    
    private func performRealtimeAnalysis(pixelBuffer: CVPixelBuffer, timestamp: Int) {
        Task {
            let uiImage = UIImage(ciImage: CIImage(cvPixelBuffer: pixelBuffer))
            if let mpImage = try? MPImage(uiImage: uiImage, orientation: self.videoOrientation),
               let result = try? self.mediaPipeManager.detect(image: mpImage, timestamp: timestamp),
               let landmarks = result.landmarks.first {
                await MainActor.run { self.currentFrameLandmarks = landmarks }
            }
        }
    }
    
    private func getVideoOrientation(from transform: CGAffineTransform) -> UIImage.Orientation {
        let angle = atan2(transform.b, transform.a) * 180 / .pi
        let normalized = angle < 0 ? angle + 360 : angle
        if normalized >= 85 && normalized <= 95 { return .right }
        if normalized >= 175 && normalized <= 185 { return .down }
        if normalized >= 265 && normalized <= 275 { return .left }
        return .up
    }
    
    func reset() {
        loadingTask?.cancel(); loadingTask = nil
        stopDisplayLink(); pause()
        if let player = player, let observer = timeObserver { player.removeTimeObserver(observer) }
        timeObserver = nil
        if let currentItem = player?.currentItem, let output = videoOutput { currentItem.remove(output) }
        player?.replaceCurrentItem(with: nil); player = nil
        videoOutput = nil; asset = nil
        mediaPipeManager = MediaPipeManager()
        status = .analyzing; addressTime = nil; impactTime = nil
        addressLandmarks = nil; impactLandmarks = nil; analysisResults = []
        currentFrameLandmarks = nil; landmarkCache.removeAll()
        duration = 0.0; currentTime = 0.0; isPlaying = false
        playbackRate = 1.0; isSeeking = false
        diagnosisReport = nil; isAnalyzingAI = false
        cancellables.removeAll()
        errorMessage = nil; showError = false
        if let savedId = UserDefaults.standard.string(forKey: "coachModeId") {
            let availablePersonas = CoachPersona.availablePersonas(for: LanguageManager.shared.currentLanguage)
            self.coachMode = availablePersonas.first(where: { $0.id == savedId }) ?? CoachPersona.standard
        } else {
            self.coachMode = CoachPersona.standard
        }
    }
    
    deinit { cancellables.removeAll() }
}
