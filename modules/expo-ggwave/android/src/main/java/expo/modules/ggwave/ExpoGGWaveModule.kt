package expo.modules.ggwave

import android.util.Log
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

class ExpoGGWaveModule : Module() {
    private var ggwaveEngine: GGWaveEngine? = null
    private var audioManager: AudioManager? = null

    companion object {
        private const val TAG = "ExpoGGWaveModule"
    }

    override fun definition() = ModuleDefinition {
        Name("ExpoGGWave")

        // Initialize the ggwave engine
        Function("initialize") { sampleRate: Int ->
            try {
                ggwaveEngine = GGWaveEngine(sampleRate)
                audioManager = AudioManager(sampleRate)
                Log.i(TAG, "Initialized with sample rate: $sampleRate")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize", e)
                throw e
            }
        }

        // Encode text to audio waveform
        AsyncFunction("encode") { text: String, protocol: Int, volume: Float ->
            val engine = ggwaveEngine
                ?: throw IllegalStateException("GGWave not initialized")

            val samples = engine.encode(text, protocol, volume)
                ?: throw RuntimeException("Failed to encode text")

            // Convert FloatArray to List<Float> for JavaScript
            samples.toList()
        }

        // Play waveform through speaker
        AsyncFunction("playWaveform") { samples: List<Float>, sampleRate: Int ->
            val manager = audioManager
                ?: throw IllegalStateException("AudioManager not initialized")

            // Convert List<Float> to FloatArray
            val samplesArray = samples.toFloatArray()
            manager.playWaveform(samplesArray)
        }

        // Start listening for data
        AsyncFunction("startListening") {
            val manager = audioManager
                ?: throw IllegalStateException("AudioManager not initialized")

            val engine = ggwaveEngine
                ?: throw IllegalStateException("GGWave not initialized")

            manager.startRecording { samples ->
                // Try to decode the audio samples
                val decoded = engine.decode(samples)
                if (decoded != null) {
                    // Send event to JavaScript
                    this@ExpoGGWaveModule.sendEvent("onDataReceived", mapOf(
                        "text" to decoded
                    ))
                }
            }

            Log.i(TAG, "Started listening")
        }

        // Stop listening
        AsyncFunction("stopListening") {
            val manager = audioManager
                ?: throw IllegalStateException("AudioManager not initialized")

            manager.stopRecording()
            Log.i(TAG, "Stopped listening")
        }

        // Check if currently listening
        Function("isListening") {
            audioManager?.isRecording() ?: false
        }

        // Get available protocols
        Function("getAvailableProtocols") {
            val engine = ggwaveEngine
                ?: return@Function emptyList<Int>()

            engine.getAvailableProtocols()
        }

        // Event definition
        Events("onDataReceived")

        // Module lifecycle
        OnCreate {
            Log.i(TAG, "Module created")
        }

        OnDestroy {
            audioManager?.cleanup()
            ggwaveEngine?.destroy()
            audioManager = null
            ggwaveEngine = null
            Log.i(TAG, "Module destroyed")
        }
    }
}
