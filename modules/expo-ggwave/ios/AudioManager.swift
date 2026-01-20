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
    // Use 44.1kHz instead of 48kHz - it's more widely supported on iOS devices
    private let sampleRate: Double = 44100.0

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
        NSLog("========================================")
        NSLog("[AudioManager] setupAudioSession called")
        NSLog("========================================")
        let audioSession = AVAudioSession.sharedInstance()

        NSLog("[AudioManager] Setting category to playAndRecord with .default mode...")
        // Use .default mode - simpler and matches working ggwave-objc implementation
        // Let the audio engine handle the signal processing
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
        NSLog("[AudioManager] ✓ Category set successfully")

        // Request 44.1kHz sample rate (more widely supported than 48kHz on iOS)
        NSLog("[AudioManager] Setting preferred sample rate to \(Int(sampleRate)) Hz...")
        try audioSession.setPreferredSampleRate(sampleRate)
        NSLog("[AudioManager] ✓ Preferred sample rate set")

        NSLog("[AudioManager] Activating audio session...")
        try audioSession.setActive(true)
        NSLog("[AudioManager] ✓ Audio session configured and active")

        // Log the actual sample rate we got
        let actualSampleRate = audioSession.sampleRate
        NSLog("[AudioManager] Actual audio session sample rate: \(actualSampleRate) Hz")

        if abs(actualSampleRate - self.sampleRate) > 1.0 {
            NSLog("[AudioManager] ⚠️ Sample rate mismatch - Requested: \(self.sampleRate), Got: \(actualSampleRate)")
            NSLog("[AudioManager] This is OK - ggwave will resample internally if configured correctly")
        }
        NSLog("========================================")
    }

    // MARK: - Recording

    func startRecording(callback: @escaping ([Float]) -> Void) async throws {
        NSLog("[AudioManager] startRecording called")
        print("[AudioManager] 🎙️ startRecording called")  // Print to Xcode console

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

        // Get the actual device sample rate and create format
        let audioSession = AVAudioSession.sharedInstance()
        let actualDeviceSampleRate = audioSession.sampleRate
        NSLog("[AudioManager] Device is actually running at: \(actualDeviceSampleRate) Hz")

        // Use the actual device sample rate for the format - let ggwave handle resampling
        // This is critical: ggwave should be initialized with the DEVICE sample rate, not a forced rate
        let recordingFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                           sampleRate: actualDeviceSampleRate,
                                           channels: 1,
                                           interleaved: false)

        guard let format = recordingFormat else {
            NSLog("[AudioManager] ERROR: Failed to create audio format")
            throw NSError(domain: "AudioManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio format"])
        }
        NSLog("[AudioManager] Using format: \(format)")

        // Install tap with larger buffer size (4096 samples = 16KB for Float32)
        // This matches the working ggwave-objc implementation's buffer size
        NSLog("[AudioManager] Installing tap on input node (buffer: 4096 samples, ~16KB)...")

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, time in
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
        NSLog("[AudioManager] ✅ Started recording - waiting for audio callbacks...")
        print("[AudioManager] ✅ Started recording - waiting for audio callbacks...")
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
    private var recordedSamples: [Float] = []  // Store all samples for WAV export
    private var recordingStartTime: Date?

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        bufferCallbackCount += 1

        // Print to Xcode console for first few buffers to verify callback is working
        if bufferCallbackCount <= 3 {
            print("[AudioManager] 🔊 processAudioBuffer called - buffer #\(bufferCallbackCount)")
        }

        guard let floatChannelData = buffer.floatChannelData else {
            NSLog("[AudioManager] ERROR: No float channel data in buffer")
            return
        }

        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: floatChannelData[0], count: frameLength))

        // Save to buffer for WAV export (limit to 30 seconds = ~1.3M samples at 44.1kHz)
        if recordedSamples.count < 1_500_000 {
            recordedSamples.append(contentsOf: samples)
        }

        // Calculate audio level (RMS) and frequency content every 50 buffers
        if bufferCallbackCount % 50 == 0 {
            let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))
            let peak = samples.map { abs($0) }.max() ?? 0

            // Count samples above noise floor to detect if we're capturing anything
            let noiseFloor: Float = 0.001
            let activeSamples = samples.filter { abs($0) > noiseFloor }.count
            let activePercent = Float(activeSamples) / Float(samples.count) * 100

            NSLog("[AudioManager] 🎤 Buffer #\(self.bufferCallbackCount): Received \(frameLength) samples, RMS: \(String(format: "%.4f", rms)), Peak: \(String(format: "%.4f", peak)), Active: \(String(format: "%.1f", activePercent))%%")

            // If RMS is very low, microphone might not be working
            if rms < 0.0001 {
                NSLog("[AudioManager] ⚠️ WARNING: Audio level extremely low - mic may not be working!")
            }
        }

        // Pass buffer directly to ggwave - don't re-chunk to avoid dropping samples
        // GGWave can handle variable buffer sizes (samplesPerFrame is just optimal, not required)
        guard let callback = recordingCallback else {
            if bufferCallbackCount == 1 {
                NSLog("[AudioManager] WARNING: recordingCallback is nil!")
            }
            return
        }

        // Log buffer size every 50 buffers to verify we're not dropping samples
        if bufferCallbackCount % 50 == 0 {
            NSLog("[AudioManager] Passing \(frameLength) samples directly to ggwave (no chunking)")
        }

        // Pass entire buffer to ggwave decode
        callback(samples)
    }

    func isCurrentlyRecording() -> Bool {
        return isRecording
    }

    func saveRecordedAudio() -> String {
        NSLog("[AudioManager] saveRecordedAudio called, have \(recordedSamples.count) samples")

        guard !recordedSamples.isEmpty else {
            NSLog("[AudioManager] ERROR: No recorded samples to save")
            return ""
        }

        // Get documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "recorded_audio_\(timestamp).wav"
        let filePath = documentsPath.appendingPathComponent(fileName)

        NSLog("[AudioManager] Saving to: \(filePath.path)")

        // Get actual device sample rate
        let audioSession = AVAudioSession.sharedInstance()
        let sampleRate = Int(audioSession.sampleRate)

        // Create WAV file
        let bytesPerSample = 2
        let numChannels = 1
        let byteRate = sampleRate * numChannels * bytesPerSample
        let dataSize = recordedSamples.count * bytesPerSample

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
        for sample in recordedSamples {
            let intSample = Int16(max(-1.0, min(1.0, sample)) * 32767.0)
            withUnsafeBytes(of: intSample.littleEndian) { wavData.append(contentsOf: $0) }
        }

        do {
            try wavData.write(to: filePath)
            NSLog("[AudioManager] ✅ Saved \(recordedSamples.count) samples (\(wavData.count) bytes) to \(fileName)")
            NSLog("[AudioManager] Duration: \(Float(recordedSamples.count) / Float(sampleRate)) seconds at \(sampleRate) Hz")
            return filePath.path
        } catch {
            NSLog("[AudioManager] ❌ ERROR saving WAV: \(error.localizedDescription)")
            return ""
        }
    }

    func clearRecordedAudio() {
        recordedSamples.removeAll()
        NSLog("[AudioManager] Cleared recorded audio buffer")
    }

    func playRecordedAudio() throws {
        NSLog("[AudioManager] playRecordedAudio called, have \(recordedSamples.count) samples")

        guard !recordedSamples.isEmpty else {
            NSLog("[AudioManager] ERROR: No recorded samples to play")
            throw NSError(domain: "AudioManager", code: 8, userInfo: [NSLocalizedDescriptionKey: "No recorded audio to play"])
        }

        // Get actual device sample rate
        let audioSession = AVAudioSession.sharedInstance()
        let sampleRate = Int(audioSession.sampleRate)

        NSLog("[AudioManager] Playing \(recordedSamples.count) samples at \(sampleRate) Hz")

        // Use the existing playWaveform implementation
        try playWaveform(recordedSamples, sampleRate: sampleRate)
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
