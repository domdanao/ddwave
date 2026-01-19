package expo.modules.ggwave

import android.util.Log

class GGWaveEngine(private val sampleRate: Int) {
    private var nativeHandle: Long = 0

    companion object {
        private const val TAG = "GGWaveEngine"

        init {
            try {
                System.loadLibrary("expo-ggwave")
                Log.i(TAG, "Loaded native library: expo-ggwave")
            } catch (e: UnsatisfiedLinkError) {
                Log.e(TAG, "Failed to load native library", e)
                throw e
            }
        }

        // Protocol constants matching ggwave C++ enums
        const val PROTOCOL_AUDIBLE_NORMAL = 1
        const val PROTOCOL_AUDIBLE_FAST = 2
        const val PROTOCOL_AUDIBLE_FASTEST = 3
        const val PROTOCOL_ULTRASOUND_NORMAL = 4
        const val PROTOCOL_ULTRASOUND_FAST = 5
        const val PROTOCOL_ULTRASOUND_FASTEST = 6
    }

    init {
        nativeHandle = nativeInit(sampleRate)
        if (nativeHandle == 0L) {
            throw RuntimeException("Failed to initialize GGWave native instance")
        }
        Log.i(TAG, "GGWaveEngine initialized with sample rate: $sampleRate")
    }

    /**
     * Encode text to audio waveform
     * @param text The text to encode
     * @param protocol The protocol to use (1-6)
     * @param volume The volume level (0.0 - 1.0)
     * @return Float array of audio samples, or null if encoding fails
     */
    fun encode(text: String, protocol: Int, volume: Float): FloatArray? {
        if (nativeHandle == 0L) {
            Log.e(TAG, "Cannot encode: native handle is null")
            return null
        }

        if (text.isEmpty()) {
            Log.w(TAG, "Cannot encode empty text")
            return null
        }

        val samples = nativeEncode(nativeHandle, text, protocol, volume)
        if (samples != null) {
            Log.d(TAG, "Encoded '$text' -> ${samples.size} samples (protocol: $protocol, volume: $volume)")
        } else {
            Log.e(TAG, "Failed to encode text: $text")
        }
        return samples
    }

    /**
     * Decode audio samples to text
     * @param samples Float array of audio samples
     * @return Decoded text, or null if no valid data found
     */
    fun decode(samples: FloatArray): String? {
        if (nativeHandle == 0L) {
            Log.e(TAG, "Cannot decode: native handle is null")
            return null
        }

        if (samples.isEmpty()) {
            return null
        }

        val decoded = nativeDecode(nativeHandle, samples, samples.size)
        if (decoded != null) {
            Log.d(TAG, "Decoded: '$decoded' (${samples.size} samples processed)")
        }
        return decoded
    }

    /**
     * Get list of available protocols
     */
    fun getAvailableProtocols(): List<Int> {
        return listOf(
            PROTOCOL_AUDIBLE_NORMAL,
            PROTOCOL_AUDIBLE_FAST,
            PROTOCOL_AUDIBLE_FASTEST,
            PROTOCOL_ULTRASOUND_NORMAL,
            PROTOCOL_ULTRASOUND_FAST,
            PROTOCOL_ULTRASOUND_FASTEST
        )
    }

    /**
     * Clean up native resources
     */
    fun destroy() {
        if (nativeHandle != 0L) {
            nativeDestroy(nativeHandle)
            nativeHandle = 0
            Log.i(TAG, "GGWaveEngine destroyed")
        }
    }

    @Throws(Throwable::class)
    protected fun finalize() {
        destroy()
    }

    // Native methods
    private external fun nativeInit(sampleRate: Int): Long
    private external fun nativeEncode(handle: Long, text: String, protocol: Int, volume: Float): FloatArray?
    private external fun nativeDecode(handle: Long, samples: FloatArray, length: Int): String?
    private external fun nativeDestroy(handle: Long)
}
