package expo.modules.ggwave

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.util.Log
import kotlinx.coroutines.*

class AudioManager(private val sampleRate: Int) {
    private var audioRecord: AudioRecord? = null
    private var audioTrack: AudioTrack? = null
    private var recordingJob: Job? = null
    private var isCurrentlyRecording = false

    companion object {
        private const val TAG = "AudioManager"
        private const val CHANNEL_CONFIG_IN = AudioFormat.CHANNEL_IN_MONO
        private const val CHANNEL_CONFIG_OUT = AudioFormat.CHANNEL_OUT_MONO
        private const val ENCODING = AudioFormat.ENCODING_PCM_FLOAT
    }

    /**
     * Start recording audio from microphone
     * @param callback Called with audio samples as they are recorded
     */
    fun startRecording(callback: (FloatArray) -> Unit) {
        if (isCurrentlyRecording) {
            Log.w(TAG, "Already recording")
            return
        }

        try {
            val bufferSize = AudioRecord.getMinBufferSize(
                sampleRate,
                CHANNEL_CONFIG_IN,
                ENCODING
            )

            if (bufferSize == AudioRecord.ERROR || bufferSize == AudioRecord.ERROR_BAD_VALUE) {
                throw RuntimeException("Invalid buffer size: $bufferSize")
            }

            // Create AudioRecord instance
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate,
                CHANNEL_CONFIG_IN,
                ENCODING,
                bufferSize * 2 // Use 2x buffer size for safety
            )

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                throw RuntimeException("AudioRecord not initialized properly")
            }

            // Start recording
            audioRecord?.startRecording()
            isCurrentlyRecording = true

            Log.i(TAG, "Started recording at $sampleRate Hz (buffer: $bufferSize samples)")

            // Launch coroutine for reading audio data
            recordingJob = CoroutineScope(Dispatchers.IO).launch {
                val buffer = FloatArray(bufferSize)

                while (isActive && isCurrentlyRecording) {
                    val read = audioRecord?.read(
                        buffer,
                        0,
                        bufferSize,
                        AudioRecord.READ_BLOCKING
                    ) ?: 0

                    if (read > 0) {
                        // Copy only the read samples and pass to callback
                        val samples = buffer.copyOf(read)
                        withContext(Dispatchers.Main) {
                            callback(samples)
                        }
                    } else if (read < 0) {
                        Log.e(TAG, "AudioRecord read error: $read")
                        break
                    }
                }

                Log.d(TAG, "Recording loop ended")
            }

        } catch (e: Exception) {
            Log.e(TAG, "Failed to start recording", e)
            stopRecording()
            throw e
        }
    }

    /**
     * Stop recording audio
     */
    fun stopRecording() {
        if (!isCurrentlyRecording) {
            return
        }

        Log.i(TAG, "Stopping recording")

        isCurrentlyRecording = false

        // Cancel recording job
        recordingJob?.cancel()
        recordingJob = null

        // Stop and release AudioRecord
        try {
            audioRecord?.stop()
        } catch (e: IllegalStateException) {
            Log.w(TAG, "AudioRecord already stopped")
        }

        audioRecord?.release()
        audioRecord = null

        Log.i(TAG, "Recording stopped")
    }

    /**
     * Play audio waveform through speaker
     * @param samples Float array of audio samples
     */
    fun playWaveform(samples: FloatArray) {
        if (samples.isEmpty()) {
            Log.w(TAG, "Cannot play empty waveform")
            return
        }

        try {
            val bufferSize = samples.size * 4 // 4 bytes per float

            // Create AudioTrack instance
            audioTrack = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setSampleRate(sampleRate)
                        .setEncoding(ENCODING)
                        .setChannelMask(CHANNEL_CONFIG_OUT)
                        .build()
                )
                .setBufferSizeInBytes(bufferSize)
                .setTransferMode(AudioTrack.MODE_STATIC)
                .build()

            if (audioTrack?.state != AudioTrack.STATE_INITIALIZED) {
                throw RuntimeException("AudioTrack not initialized properly")
            }

            // Write samples to AudioTrack
            val written = audioTrack?.write(
                samples,
                0,
                samples.size,
                AudioTrack.WRITE_BLOCKING
            ) ?: 0

            if (written != samples.size) {
                Log.w(TAG, "Not all samples written: $written / ${samples.size}")
            }

            // Play the audio
            audioTrack?.play()

            Log.i(TAG, "Playing waveform (${samples.size} samples at $sampleRate Hz)")

            // Wait for playback to complete (blocking)
            val durationMs = (samples.size * 1000L) / sampleRate
            Thread.sleep(durationMs + 100) // Add 100ms buffer

            // Stop and release
            audioTrack?.stop()
            audioTrack?.release()
            audioTrack = null

            Log.d(TAG, "Finished playing waveform")

        } catch (e: Exception) {
            Log.e(TAG, "Failed to play waveform", e)
            audioTrack?.release()
            audioTrack = null
            throw e
        }
    }

    /**
     * Check if currently recording
     */
    fun isRecording(): Boolean {
        return isCurrentlyRecording
    }

    /**
     * Clean up resources
     */
    fun cleanup() {
        stopRecording()
        audioTrack?.release()
        audioTrack = null
        Log.i(TAG, "AudioManager cleaned up")
    }
}
