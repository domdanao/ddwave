#include <jni.h>
#include <android/log.h>
#include <string>
#include <vector>
#include <memory>
#include "ggwave/ggwave.h"

#define LOG_TAG "GGWave-JNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

extern "C" {

JNIEXPORT jlong JNICALL
Java_expo_modules_ggwave_GGWaveEngine_nativeInit(
    JNIEnv *env, jobject thiz, jint sampleRate) {

    LOGI("Initializing ggwave with sample rate: %d", sampleRate);

    try {
        // Create ggwave parameters
        GGWave::Parameters params;
        params.sampleRateInp = sampleRate;
        params.sampleRateOut = sampleRate;
        params.sampleRate = sampleRate;

        // Create ggwave instance
        auto* instance = new GGWave(params);

        LOGI("GGWave instance created successfully");
        return reinterpret_cast<jlong>(instance);
    } catch (const std::exception& e) {
        LOGE("Failed to initialize ggwave: %s", e.what());
        return 0;
    }
}

JNIEXPORT jfloatArray JNICALL
Java_expo_modules_ggwave_GGWaveEngine_nativeEncode(
    JNIEnv *env, jobject thiz, jlong handle,
    jstring text, jint protocol, jfloat volume) {

    if (handle == 0) {
        LOGE("Invalid ggwave handle");
        return nullptr;
    }

    auto* instance = reinterpret_cast<GGWave*>(handle);

    // Convert Java string to C++ string
    const char* textCStr = env->GetStringUTFChars(text, nullptr);
    if (!textCStr) {
        LOGE("Failed to get string UTF chars");
        return nullptr;
    }

    std::string cppText(textCStr);
    env->ReleaseStringUTFChars(text, textCStr);

    LOGI("Encoding text: '%s' (protocol: %d, volume: %.2f)", cppText.c_str(), protocol, volume);

    try {
        // Initialize encoding
        GGWave::TxProtocolId txProtocol = static_cast<GGWave::TxProtocolId>(protocol);
        int result = instance->init(cppText.size(), cppText.data(), txProtocol, volume);

        if (result == 0) {
            LOGE("Failed to initialize encoding");
            return nullptr;
        }

        // Generate waveform
        int waveformSize = instance->encode();
        if (waveformSize <= 0) {
            LOGE("Failed to generate waveform");
            return nullptr;
        }

        // Get output data
        GGWave::TxRxData outputData;
        instance->getOutput(outputData);

        // Convert to jfloatArray
        jfloatArray result_array = env->NewFloatArray(outputData.size());
        if (!result_array) {
            LOGE("Failed to allocate float array");
            return nullptr;
        }

        env->SetFloatArrayRegion(result_array, 0, outputData.size(), outputData.data());

        LOGI("Encoded successfully: %zu samples", outputData.size());
        return result_array;

    } catch (const std::exception& e) {
        LOGE("Exception during encoding: %s", e.what());
        return nullptr;
    }
}

JNIEXPORT jstring JNICALL
Java_expo_modules_ggwave_GGWaveEngine_nativeDecode(
    JNIEnv *env, jobject thiz, jlong handle,
    jfloatArray samples, jint length) {

    if (handle == 0) {
        LOGE("Invalid ggwave handle");
        return nullptr;
    }

    auto* instance = reinterpret_cast<GGWave*>(handle);

    // Get float array data
    jfloat* sampleData = env->GetFloatArrayElements(samples, nullptr);
    if (!sampleData) {
        LOGE("Failed to get float array elements");
        return nullptr;
    }

    try {
        // Prepare input data
        GGWave::TxRxData inputData(sampleData, sampleData + length);

        // Decode
        int decodedBytes = instance->decode(inputData);

        env->ReleaseFloatArrayElements(samples, sampleData, JNI_ABORT);

        if (decodedBytes > 0) {
            // Get decoded data
            GGWave::TxRxData decodedData;
            instance->takeRxData(decodedData);

            // Convert to string
            std::string decodedString(reinterpret_cast<const char*>(decodedData.data()),
                                     decodedData.size());

            LOGI("Decoded: '%s' (%d bytes)", decodedString.c_str(), decodedBytes);

            return env->NewStringUTF(decodedString.c_str());
        }

        return nullptr;

    } catch (const std::exception& e) {
        env->ReleaseFloatArrayElements(samples, sampleData, JNI_ABORT);
        LOGE("Exception during decoding: %s", e.what());
        return nullptr;
    }
}

JNIEXPORT void JNICALL
Java_expo_modules_ggwave_GGWaveEngine_nativeDestroy(
    JNIEnv *env, jobject thiz, jlong handle) {

    if (handle != 0) {
        auto* instance = reinterpret_cast<GGWave*>(handle);
        delete instance;
        LOGI("GGWave instance destroyed");
    }
}

} // extern "C"
