import AVFoundation
import Foundation

class AudioManager: NSObject {

    // Check and request microphone permission
    private func checkMicrophonePermission() async throws {
        let status = AVAudioSession.sharedInstance().recordPermission

        NSLog("[AudioManager] Current microphone permission status: \(status.rawValue)")

        switch status {
        case .granted:
            NSLog("[AudioManager] ✅ Microphone permission already granted")
            return
        case .denied:
            NSLog("[AudioManager] ❌ Microphone permission DENIED")
            throw NSError(domain: "AudioManager", code: 100,
                         userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"])
        case .undetermined:
            NSLog("[AudioManager] Requesting microphone permission...")
            let granted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            NSLog("[AudioManager] Permission request result: \(granted ? "GRANTED" : "DENIED")")
            if !granted {
                throw NSError(domain: "AudioManager", code: 100,
                             userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"])
            }
        @unknown default:
            NSLog("[AudioManager] Unknown permission status")
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
        NSLog("[AudioManager] Audio engine initialized for recording")
    }

    func setupAudioSession() throws {
        NSLog("[AudioManager] setupAudioSession called")
        let audioSession = AVAudioSession.sharedInstance()

        NSLog("[AudioManager] Setting category to playAndRecord with measurement mode...")
        // Use .measurement mode to disable voice processing, AGC, and echo cancellation
        // This gives us raw audio needed for GGWave data transmission
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothA2DP])
        NSLog("[AudioManager] Category set successfully")

        // Request 48kHz sample rate to match GGWave initialization
        NSLog("[AudioManager] Setting preferred sample rate to 48000 Hz...")
        try audioSession.setPreferredSampleRate(sampleRate)
        NSLog("[AudioManager] Preferred sample rate set")

        NSLog("[AudioManager] Activating audio session...")
        try audioSession.setActive(true)
        NSLog("[AudioManager] Audio session configured and active")

        // Log the actual sample rate we got
        let actualSampleRate = audioSession.sampleRate
        NSLog("[AudioManager] Actual audio session sample rate: \(actualSampleRate) Hz")

        if abs(actualSampleRate - sampleRate) > 1.0 {
            NSLog("[AudioManager] ⚠️ WARNING: Sample rate mismatch! Requested: \(sampleRate), Got: \(actualSampleRate)")
        }
    }

    // MARK: - Recording

    func startRecording(callback: @escaping ([Float]) -> Void) async throws {
        NSLog("[AudioManager] startRecording called")

        // Check microphone permission first
        try await checkMicrophonePermission()

        guard let audioEngine = audioEngine, let inputNode = inputNode else {
            NSLog("[AudioManager] ERROR: Audio engine or input node not initialized")
            throw NSError(domain: "AudioManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Audio engine not initialized"])
        }
        NSLog("[AudioManager] Audio engine and input node verified")

        // Configure audio session for recording
        try setupAudioSession()

        recordingCallback = callback
        NSLog("[AudioManager] Recording callback set")

        // Log native format for debugging
        let nativeFormat = inputNode.outputFormat(forBus: 0)
        NSLog("[AudioManager] Native input format: \(nativeFormat)")

        // Force 48kHz mono Float32 to match GGWave initialization
        // This is critical - GGWave was initialized with 48000 Hz
        let recordingFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                           sampleRate: sampleRate,
                                           channels: 1,
                                           interleaved: false)

        guard let format = recordingFormat else {
            NSLog("[AudioManager] ERROR: Failed to create audio format")
            throw NSError(domain: "AudioManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio format"])
        }
        NSLog("[AudioManager] Using format: \(format)")

        // Install tap on input node using 48kHz format
        // iOS will automatically convert from native rate to 48kHz
        // Use 1024 samples to match ggwave's samplesPerFrame
        NSLog("[AudioManager] Installing tap on input node (buffer: 1024 samples to match ggwave SPF)...")

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }
        NSLog("[AudioManager] Tap installed successfully")

        // Start the engine
        NSLog("[AudioManager] Audio engine running status: \(audioEngine.isRunning)")
        if !audioEngine.isRunning {
            NSLog("[AudioManager] Starting audio engine...")
            try audioEngine.start()
            NSLog("[AudioManager] Audio engine started")
        } else {
            NSLog("[AudioManager] Audio engine already running")
        }

        isRecording = true
        NSLog("[AudioManager] Recording state set to true")
        NSLog("[AudioManager] ✅ Started recording at \(sampleRate) Hz - waiting for audio callbacks...")
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

        NSLog("[AudioManager] Stopped recording")
    }

    private var bufferCallbackCount = 0
    private let expectedSamplesPerFrame = 1024  // Must match ggwave's samplesPerFrame

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        bufferCallbackCount += 1

        guard let floatChannelData = buffer.floatChannelData else {
            NSLog("[AudioManager] ERROR: No float channel data in buffer")
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

            NSLog("[AudioManager] 🎤 Buffer #\(bufferCallbackCount): Received \(frameLength) samples, RMS: \(String(format: "%.4f", rms)), Peak: \(String(format: "%.4f", peak)), Active: \(String(format: "%.1f", activePercent))%%")

            // If RMS is very low, microphone might not be working
            if rms < 0.0001 {
                NSLog("[AudioManager] ⚠️ WARNING: Audio level extremely low - mic may not be working!")
            }
        }

        // iOS often ignores our buffer size request and gives us larger buffers
        // We need to split the buffer into 1024-sample chunks for ggwave
        guard let callback = recordingCallback else {
            if bufferCallbackCount == 1 {
                NSLog("[AudioManager] WARNING: recordingCallback is nil!")
            }
            return
        }

        // Split buffer into 1024-sample chunks
        var offset = 0
        while offset + expectedSamplesPerFrame <= samples.count {
            let chunk = Array(samples[offset..<(offset + expectedSamplesPerFrame)])
            callback(chunk)
            offset += expectedSamplesPerFrame
        }

        // Log chunk processing every 50 buffers
        if bufferCallbackCount % 50 == 0 {
            let numChunks = samples.count / expectedSamplesPerFrame
            NSLog("[AudioManager] Split \(samples.count) samples into \(numChunks) chunks of 1024 samples")
        }
    }

    func isCurrentlyRecording() -> Bool {
        return isRecording
    }

    // MARK: - Playback

    func playWaveform(_ samples: [Float], sampleRate: Int) throws {
        guard samples.count > 0 else {
            NSLog("[AudioManager] ERROR: Empty samples array")
            throw NSError(domain: "AudioManager", code: 7, userInfo: [NSLocalizedDescriptionKey: "Empty samples array"])
        }

        NSLog("[AudioManager] Starting playback of \(samples.count) samples at \(sampleRate) Hz")

        // Just call the main implementation directly - Expo handles threading
        try playWaveformImpl(samples, sampleRate: sampleRate)
    }

    private func playWaveformImpl(_ samples: [Float], sampleRate: Int) throws {
        NSLog("[AudioManager] Starting playback implementation")

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .default)
        try audioSession.setActive(true)
        NSLog("[AudioManager] Audio session configured")

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

        NSLog("[AudioManager] Created WAV data: \(wavData.count) bytes")

        // Play using AVAudioPlayer - keep strong reference
        audioPlayer = try AVAudioPlayer(data: wavData)
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()

        NSLog("[AudioManager] Started playback with AVAudioPlayer")
    }

    // MARK: - Cleanup

    deinit {
        stopRecording()
        audioEngine?.stop()
        NSLog("[AudioManager] Audio manager deallocated")
    }
}
