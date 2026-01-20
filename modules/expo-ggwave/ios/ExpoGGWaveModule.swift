import ExpoModulesCore
import AVFoundation

public class ExpoGGWaveModule: Module {
    private var ggwaveEngine: GGWaveEngine?
    private var audioManager: AudioManager?
    private var audioCallbackCount = 0
    private var wasReceiving = false
    private var wasAnalyzing = false

    public func definition() -> ModuleDefinition {
        Name("ExpoGGWave")

        // Initialize the ggwave engine
        Function("initialize") { (requestedSampleRate: Int) in
            NSLog("[ExpoGGWaveModule] initialize called with requested sampleRate: \(requestedSampleRate)")

            // Query the actual device sample rate instead of using the requested rate
            // This is critical for proper resampling!
            let audioSession = AVAudioSession.sharedInstance()
            let actualSampleRate = audioSession.sampleRate

            NSLog("[ExpoGGWaveModule] Device actual sample rate: \(actualSampleRate) Hz")

            // Initialize GGWaveEngine with actual device sample rate
            // This matches the working ggwave-objc implementation
            self.ggwaveEngine = GGWaveEngine(sampleRate: Int32(actualSampleRate))
            NSLog("[ExpoGGWaveModule] GGWaveEngine created with device sample rate: \(actualSampleRate) Hz")

            self.audioManager = AudioManager()
            NSLog("[ExpoGGWaveModule] AudioManager created")
            NSLog("[ExpoGGWaveModule] ✅ Initialized successfully with device-native sample rate")
        }

        // Encode text to audio waveform
        AsyncFunction("encode") { (text: String, `protocol`: Int, volume: Float) -> [Float] in
            guard let engine = self.ggwaveEngine else {
                throw NSError(domain: "ExpoGGWaveModule", code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "GGWave not initialized"])
            }

            // Swift auto-converts NSError** to throwing methods
            // The method will throw if encoding fails
            let samples = try engine.encodeText(text, protocol: Int32(`protocol`), volume: volume)

            // Convert NSArray<NSNumber> to [Float]
            let floatSamples = samples.compactMap { $0.floatValue }
            return floatSamples
        }

        // Play waveform through speaker
        AsyncFunction("playWaveform") { (samples: [Float], sampleRate: Int) -> Void in
            guard let manager = self.audioManager else {
                NSLog("[ExpoGGWaveModule] ERROR: AudioManager not initialized")
                throw NSError(domain: "ExpoGGWaveModule", code: 3,
                            userInfo: [NSLocalizedDescriptionKey: "AudioManager not initialized"])
            }

            NSLog("[ExpoGGWaveModule] Received \(samples.count) samples for playback")

            do {
                try manager.playWaveform(samples, sampleRate: sampleRate)
                NSLog("[ExpoGGWaveModule] Playback completed successfully")
            } catch {
                NSLog("[ExpoGGWaveModule] ERROR during playback: \(error.localizedDescription)")
                throw error
            }
        }

        // Start listening for data
        AsyncFunction("startListening") {
            guard let manager = self.audioManager else {
                NSLog("[ExpoGGWaveModule] ERROR: AudioManager not initialized")
                throw NSError(domain: "ExpoGGWaveModule", code: 4,
                            userInfo: [NSLocalizedDescriptionKey: "AudioManager not initialized"])
            }

            guard let engine = self.ggwaveEngine else {
                NSLog("[ExpoGGWaveModule] ERROR: GGWave engine not initialized")
                throw NSError(domain: "ExpoGGWaveModule", code: 5,
                            userInfo: [NSLocalizedDescriptionKey: "GGWave not initialized"])
            }

            NSLog("[ExpoGGWaveModule] About to call manager.startRecording...")
            self.audioCallbackCount = 0

            try await manager.startRecording { [weak self] samples in
                guard let self = self else { return }

                self.audioCallbackCount += 1

                // Log first 10 callbacks AND every 50th callback to verify audio is flowing
                if self.audioCallbackCount <= 10 || self.audioCallbackCount % 50 == 0 {
                    let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))
                    let peak = samples.map { abs($0) }.max() ?? 0
                    NSLog("[ExpoGGWaveModule] 🎤 Callback #\(self.audioCallbackCount): \(samples.count) samples, RMS=\(String(format: "%.4f", rms)), Peak=\(String(format: "%.4f", peak))")
                    print("[ExpoGGWaveModule] 🎤 Callback #\(self.audioCallbackCount): \(samples.count) samples")  // Use print() for Xcode console
                }

                // Send audio levels every 20 callbacks for visual feedback
                if self.audioCallbackCount % 20 == 0 {
                    let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))
                    let peak = samples.map { abs($0) }.max() ?? 0

                    // Send audio level event to JavaScript for visualization
                    self.sendEvent("onAudioLevel", [
                        "rms": rms,
                        "peak": peak
                    ])
                }

                // Call decode on EVERY buffer (like the working ggwave-objc implementation)

                // Log decode calls for first few callbacks
                if self.audioCallbackCount <= 5 {
                    NSLog("[ExpoGGWaveModule] About to call decode with \(samples.count) samples")
                }

                samples.withUnsafeBufferPointer { bufferPointer in
                    if let baseAddress = bufferPointer.baseAddress {
                        // Log pointer info for first callback
                        if self.audioCallbackCount == 1 {
                            NSLog("[ExpoGGWaveModule] Decode pointer: \(baseAddress), samples: \(samples.count)")
                        }

                        // Decode the audio
                        if let decoded = engine.decodeAudio(baseAddress, length: Int32(samples.count)) {
                            NSLog("[ExpoGGWaveModule] ═══════════════════════════════════════")
                            NSLog("[ExpoGGWaveModule] 🎉 🎉 🎉 DECODED MESSAGE: '\(decoded)'")
                            NSLog("[ExpoGGWaveModule] ═══════════════════════════════════════")
                            print("[ExpoGGWaveModule] 🎉 DECODED: '\(decoded)'")  // Also print to Xcode console

                            // Send event to JavaScript
                            self.sendEvent("onDataReceived", [
                                "text": decoded
                            ])
                            NSLog("[ExpoGGWaveModule] ✅ Event sent to JavaScript")

                            // Send decode success event
                            self.sendEvent("onDecodeEvent", [
                                "type": "decode_success",
                                "message": decoded
                            ])
                        }

                        // Check for protocol marker state changes
                        let isReceiving = engine.isRxReceiving()
                        let isAnalyzing = engine.isRxAnalyzing()

                        // Detect START MARKER
                        if isReceiving && !self.wasReceiving {
                            self.sendEvent("onDecodeEvent", [
                                "type": "start_marker",
                                "message": "Protocol start marker detected"
                            ])
                            self.wasReceiving = true
                        }

                        // Detect END MARKER
                        if isAnalyzing && !self.wasAnalyzing {
                            self.sendEvent("onDecodeEvent", [
                                "type": "end_marker",
                                "message": "Protocol end marker detected"
                            ])
                            self.wasAnalyzing = true
                        }

                        // Reset state when transmission ends
                        if !isReceiving && self.wasReceiving {
                            self.wasReceiving = false
                            self.wasAnalyzing = false
                        }
                    }
                }
            }
            NSLog("[ExpoGGWaveModule] manager.startRecording returned successfully")
        }

        // Stop listening
        AsyncFunction("stopListening") {
            guard let manager = self.audioManager else {
                throw NSError(domain: "ExpoGGWaveModule", code: 6,
                            userInfo: [NSLocalizedDescriptionKey: "AudioManager not initialized"])
            }

            manager.stopRecording()
        }

        // Check if currently listening
        Function("isListening") { () -> Bool in
            return self.audioManager?.isCurrentlyRecording() ?? false
        }

        // Save recorded audio to WAV file
        Function("saveRecordedAudio") { () -> String in
            guard let manager = self.audioManager else {
                NSLog("[ExpoGGWaveModule] ERROR: AudioManager not initialized")
                return ""
            }
            return manager.saveRecordedAudio()
        }

        // Clear recorded audio buffer
        Function("clearRecordedAudio") {
            self.audioManager?.clearRecordedAudio()
        }

        // Play recorded audio
        Function("playRecordedAudio") {
            guard let manager = self.audioManager else {
                NSLog("[ExpoGGWaveModule] ERROR: AudioManager not initialized")
                throw NSError(domain: "ExpoGGWaveModule", code: 9,
                            userInfo: [NSLocalizedDescriptionKey: "AudioManager not initialized"])
            }
            try manager.playRecordedAudio()
        }

        // Get available protocols
        Function("getAvailableProtocols") { () -> [Int] in
            guard let engine = self.ggwaveEngine else {
                return []
            }

            return engine.availableProtocols().compactMap { $0.intValue }
        }

        // Event definitions
        Events("onDataReceived", "onAudioLevel", "onDecodeEvent")

        // Module lifecycle
        OnCreate {
            NSLog("[ExpoGGWaveModule] Module created")
        }

        OnDestroy {
            self.audioManager?.stopRecording()
            self.audioManager = nil
            self.ggwaveEngine = nil
            NSLog("[ExpoGGWaveModule] Module destroyed")
        }
    }
}
