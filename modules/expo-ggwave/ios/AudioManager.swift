import AVFoundation
import Foundation
import os.log

class AudioManager: NSObject {
    private let logger = Logger(subsystem: "com.ddwave.ggwave", category: "AudioManager")

    // Check and request microphone permission
    private func checkMicrophonePermission() async throws {
        let status = AVAudioSession.sharedInstance().recordPermission

        logger.info("[AudioManager] Current microphone permission status: \(status.rawValue)")

        switch status {
        case .granted:
            logger.info("[AudioManager] ✅ Microphone permission already granted")
            return
        case .denied:
            logger.error("[AudioManager] ❌ Microphone permission DENIED")
            throw NSError(domain: "AudioManager", code: 100,
                         userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"])
        case .undetermined:
            logger.info("[AudioManager] Requesting microphone permission...")
            let granted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            logger.info("[AudioManager] Permission request result: \(granted ? "GRANTED" : "DENIED")")
            if !granted {
                throw NSError(domain: "AudioManager", code: 100,
                             userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"])
            }
        @unknown default:
            logger.warning("[AudioManager] Unknown permission status")
        }
    }
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var isRecording = false
    private var recordingCallback: (([Float]) -> Void)?
    private let sampleRate: Double = 48000.0

    // Keep strong reference to audio player
    private var audioPlayer: AVAudioPlayer?

    override init() {
        super.init()
        setupAudioEngine()
    }

    // MARK: - Setup

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
        logger.info("[AudioManager] Audio engine initialized for recording")
    }

    func setupAudioSession() throws {
        logger.info("========================================")
        logger.info("[AudioManager] setupAudioSession called")
        logger.info("========================================")
        let audioSession = AVAudioSession.sharedInstance()

        logger.info("[AudioManager] Setting category to playAndRecord with .videoRecording mode...")
        // Use .videoRecording mode to get raw unprocessed audio with proper gain
        // .default mode may still apply AGC/noise reduction that corrupts ggwave signals
        // .measurement mode has too low gain
        try audioSession.setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker, .allowBluetoothA2DP])
        logger.info("[AudioManager] ✓ Category set successfully")

        // Verify the mode that was actually set
        let actualMode = audioSession.mode
        logger.info("[AudioManager] VERIFIED AUDIO MODE: \(actualMode.rawValue)")
        if actualMode == .videoRecording {
            logger.info("[AudioManager] ✓✓✓ CONFIRMED: Using .videoRecording mode (raw audio)")
        } else {
            logger.error("[AudioManager] ❌❌❌ ERROR: Expected .videoRecording but got \(actualMode.rawValue)")
        }

        // Request 48kHz sample rate to match GGWave initialization
        logger.info("[AudioManager] Setting preferred sample rate to 48000 Hz...")
        try audioSession.setPreferredSampleRate(sampleRate)
        logger.info("[AudioManager] ✓ Preferred sample rate set")

        logger.info("[AudioManager] Activating audio session...")
        try audioSession.setActive(true)
        logger.info("[AudioManager] ✓ Audio session configured and active")

        // Log the actual sample rate we got
        let actualSampleRate = audioSession.sampleRate
        logger.info("[AudioManager] Actual audio session sample rate: \(actualSampleRate) Hz")

        if abs(actualSampleRate - sampleRate) > 1.0 {
            logger.warning("[AudioManager] ⚠️ WARNING: Sample rate mismatch! Requested: \(sampleRate), Got: \(actualSampleRate)")
        }
        logger.info("========================================")
    }

    // MARK: - Recording

    func startRecording(callback: @escaping ([Float]) -> Void) async throws {
        logger.info("[AudioManager] startRecording called")

        // Check microphone permission first
        try await checkMicrophonePermission()

        guard let audioEngine = audioEngine, let inputNode = inputNode else {
            logger.error("[AudioManager] ERROR: Audio engine or input node not initialized")
            throw NSError(domain: "AudioManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Audio engine not initialized"])
        }
        logger.info("[AudioManager] Audio engine and input node verified")

        // Configure audio session for recording
        try setupAudioSession()

        recordingCallback = callback
        logger.info("[AudioManager] Recording callback set")

        // Log native format for debugging
        let nativeFormat = inputNode.outputFormat(forBus: 0)
        logger.info("[AudioManager] Native input format: \(nativeFormat)")

        // Force 48kHz mono Float32 to match GGWave initialization
        // This is critical - GGWave was initialized with 48000 Hz
        let recordingFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                           sampleRate: sampleRate,
                                           channels: 1,
                                           interleaved: false)

        guard let format = recordingFormat else {
            logger.error("[AudioManager] ERROR: Failed to create audio format")
            throw NSError(domain: "AudioManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio format"])
        }
        logger.info("[AudioManager] Using format: \(format)")

        // Install tap on input node using 48kHz format
        // iOS will automatically convert from native rate to 48kHz
        // Use 1024 samples to match ggwave's samplesPerFrame
        logger.info("[AudioManager] Installing tap on input node (buffer: 1024 samples to match ggwave SPF)...")

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }
        logger.info("[AudioManager] Tap installed successfully")

        // Start the engine
        logger.info("[AudioManager] Audio engine running status: \(audioEngine.isRunning)")
        if !audioEngine.isRunning {
            logger.info("[AudioManager] Starting audio engine...")
            try audioEngine.start()
            logger.info("[AudioManager] Audio engine started")
        } else {
            logger.info("[AudioManager] Audio engine already running")
        }

        isRecording = true
        logger.info("[AudioManager] Recording state set to true")
        logger.info("[AudioManager] ✅ Started recording at \(sampleRate) Hz - waiting for audio callbacks...")
    }

    func stopRecording() {
        guard let audioEngine = audioEngine, let inputNode = inputNode else {
            return
        }

        inputNode.removeTap(onBus: 0)

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        isRecording = false
        recordingCallback = nil
        bufferCallbackCount = 0

        logger.info("[AudioManager] Stopped recording")
    }

    private var bufferCallbackCount = 0
    private let expectedSamplesPerFrame = 1024  // Must match ggwave's samplesPerFrame

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        bufferCallbackCount += 1

        guard let floatChannelData = buffer.floatChannelData else {
            logger.error("[AudioManager] ERROR: No float channel data in buffer")
            return
        }

        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: floatChannelData[0], count: frameLength))

        // Calculate audio level (RMS) and frequency content every 50 buffers
        if bufferCallbackCount % 50 == 0 {
            let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))
            let peak = samples.map { abs($0) }.max() ?? 0

            // Count samples above noise floor to detect if we're capturing anything
            let noiseFloor: Float = 0.001
            let activeSamples = samples.filter { abs($0) > noiseFloor }.count
            let activePercent = Float(activeSamples) / Float(samples.count) * 100

            logger.info("[AudioManager] 🎤 Buffer #\(bufferCallbackCount): Received \(frameLength) samples, RMS: \(String(format: "%.4f", rms)), Peak: \(String(format: "%.4f", peak)), Active: \(String(format: "%.1f", activePercent))%%")

            // If RMS is very low, microphone might not be working
            if rms < 0.0001 {
                logger.warning("[AudioManager] ⚠️ WARNING: Audio level extremely low - mic may not be working!")
            }
        }

        // Pass buffer directly to ggwave - don't re-chunk to avoid dropping samples
        // GGWave can handle variable buffer sizes (samplesPerFrame is just optimal, not required)
        guard let callback = recordingCallback else {
            if bufferCallbackCount == 1 {
                logger.warning("[AudioManager] WARNING: recordingCallback is nil!")
            }
            return
        }

        // Log buffer size every 50 buffers to verify we're not dropping samples
        if bufferCallbackCount % 50 == 0 {
            logger.info("[AudioManager] Passing \(frameLength) samples directly to ggwave (no chunking)")
        }

        // Pass entire buffer to ggwave decode
        callback(samples)
    }

    func isCurrentlyRecording() -> Bool {
        return isRecording
    }

    // MARK: - Playback

    func playWaveform(_ samples: [Float], sampleRate: Int) throws {
        guard samples.count > 0 else {
            logger.error("[AudioManager] ERROR: Empty samples array")
            throw NSError(domain: "AudioManager", code: 7, userInfo: [NSLocalizedDescriptionKey: "Empty samples array"])
        }

        logger.info("[AudioManager] Starting playback of \(samples.count) samples at \(sampleRate) Hz")

        // Just call the main implementation directly - Expo handles threading
        try playWaveformImpl(samples, sampleRate: sampleRate)
    }

    private func playWaveformImpl(_ samples: [Float], sampleRate: Int) throws {
        logger.info("[AudioManager] Starting playback implementation")

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .default)
        try audioSession.setActive(true)
        logger.info("[AudioManager] Audio session configured")

        // Convert Float32 samples to Int16 WAV format
        let bytesPerSample = 2
        let numChannels = 1
        let byteRate = sampleRate * numChannels * bytesPerSample
        let dataSize = samples.count * bytesPerSample

        var wavData = Data()

        // WAV header
        wavData.append("RIFF".data(using: .ascii)!)
        withUnsafeBytes(of: UInt32(36 + dataSize).littleEndian) { wavData.append(contentsOf: $0) }
        wavData.append("WAVE".data(using: .ascii)!)
        wavData.append("fmt ".data(using: .ascii)!)
        withUnsafeBytes(of: UInt32(16).littleEndian) { wavData.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt16(1).littleEndian) { wavData.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt16(numChannels).littleEndian) { wavData.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { wavData.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt32(byteRate).littleEndian) { wavData.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt16(numChannels * bytesPerSample).littleEndian) { wavData.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt16(16).littleEndian) { wavData.append(contentsOf: $0) }
        wavData.append("data".data(using: .ascii)!)
        withUnsafeBytes(of: UInt32(dataSize).littleEndian) { wavData.append(contentsOf: $0) }

        // Convert Float32 samples to Int16
        for sample in samples {
            let intSample = Int16(max(-1.0, min(1.0, sample)) * 32767.0)
            withUnsafeBytes(of: intSample.littleEndian) { wavData.append(contentsOf: $0) }
        }

        logger.info("[AudioManager] Created WAV data: \(wavData.count) bytes")

        // Play using AVAudioPlayer - keep strong reference
        audioPlayer = try AVAudioPlayer(data: wavData)
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()

        logger.info("[AudioManager] Started playback with AVAudioPlayer")
    }

    // MARK: - Cleanup

    deinit {
        stopRecording()
        audioEngine?.stop()
        logger.info("[AudioManager] Audio manager deallocated")
    }
}
