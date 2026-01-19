import ExpoModulesCore
import AVFoundation
import os.log

public class ExpoGGWaveModule: Module {
    private let logger = Logger(subsystem: "com.ddwave.ggwave", category: "ExpoGGWaveModule")
    private var ggwaveEngine: GGWaveEngine?
    private var audioManager: AudioManager?
    private var audioCallbackCount = 0

    public func definition() -> ModuleDefinition {
        Name("ExpoGGWave")

        // Initialize the ggwave engine
        Function("initialize") { (sampleRate: Int) in
            logger.info("[ExpoGGWaveModule] initialize called with sampleRate: \(sampleRate)")
            self.ggwaveEngine = GGWaveEngine(sampleRate: Int32(sampleRate))
            logger.info("[ExpoGGWaveModule] GGWaveEngine created")
            self.audioManager = AudioManager()
            logger.info("[ExpoGGWaveModule] AudioManager created")
            logger.info("[ExpoGGWaveModule] Initialized successfully")
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
                logger.error("[ExpoGGWaveModule] ERROR: AudioManager not initialized")
                throw NSError(domain: "ExpoGGWaveModule", code: 3,
                            userInfo: [NSLocalizedDescriptionKey: "AudioManager not initialized"])
            }

            logger.info("[ExpoGGWaveModule] Received \(samples.count) samples for playback")

            do {
                try manager.playWaveform(samples, sampleRate: sampleRate)
                logger.info("[ExpoGGWaveModule] Playback completed successfully")
            } catch {
                logger.error("[ExpoGGWaveModule] ERROR during playback: \(error.localizedDescription)")
                throw error
            }
        }

        // Start listening for data
        AsyncFunction("startListening") {
            logger.info("=========================================")
            logger.info("[ExpoGGWaveModule] startListening called")
            logger.info("=========================================")

            guard let manager = self.audioManager else {
                logger.error("[ExpoGGWaveModule] ERROR: AudioManager not initialized")
                throw NSError(domain: "ExpoGGWaveModule", code: 4,
                            userInfo: [NSLocalizedDescriptionKey: "AudioManager not initialized"])
            }

            guard let engine = self.ggwaveEngine else {
                logger.error("[ExpoGGWaveModule] ERROR: GGWave engine not initialized")
                throw NSError(domain: "ExpoGGWaveModule", code: 5,
                            userInfo: [NSLocalizedDescriptionKey: "GGWave not initialized"])
            }

            logger.info("[ExpoGGWaveModule] About to call manager.startRecording...")
            self.audioCallbackCount = 0

            try await manager.startRecording { [weak self] samples in
                guard let self = self else { return }

                self.audioCallbackCount += 1

                // Log first few callbacks to verify audio is flowing
                if self.audioCallbackCount <= 5 {
                    self.logger.info("[ExpoGGWaveModule] Audio callback #\(self.audioCallbackCount): received \(samples.count) samples")
                }

                // Calculate and send audio levels every 10 callbacks for visual feedback
                if self.audioCallbackCount % 10 == 0 {
                    let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))
                    let peak = samples.map { abs($0) }.max() ?? 0

                    // Send audio level event to JavaScript for visualization
                    self.sendEvent("onAudioLevel", [
                        "rms": rms,
                        "peak": peak
                    ])
                }

                // Convert [Float] to UnsafePointer<Float>
                samples.withUnsafeBufferPointer { bufferPointer in
                    if let baseAddress = bufferPointer.baseAddress {
                        if let decoded = engine.decodeAudio(baseAddress, length: Int32(samples.count)) {
                            self.logger.info("[ExpoGGWaveModule] 🎉 🎉 🎉 DECODED MESSAGE: '\(decoded)'")
                            // Send event to JavaScript
                            self.sendEvent("onDataReceived", [
                                "text": decoded
                            ])
                            self.logger.info("[ExpoGGWaveModule] ✅ Event sent to JavaScript: onDataReceived with text=\(decoded)")
                        }
                    }
                }
            }
            logger.info("[ExpoGGWaveModule] manager.startRecording returned successfully")
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

        // Get available protocols
        Function("getAvailableProtocols") { () -> [Int] in
            guard let engine = self.ggwaveEngine else {
                return []
            }

            return engine.availableProtocols().compactMap { $0.intValue }
        }

        // Event definitions
        Events("onDataReceived", "onAudioLevel")

        // Module lifecycle
        OnCreate {
            logger.info("[ExpoGGWaveModule] Module created")
        }

        OnDestroy {
            self.audioManager?.stopRecording()
            self.audioManager = nil
            self.ggwaveEngine = nil
            logger.info("[ExpoGGWaveModule] Module destroyed")
        }
    }
}
