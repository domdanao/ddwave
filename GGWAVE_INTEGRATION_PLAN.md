# ggwave Integration Plan for ddwave Expo App

## Executive Summary

This document outlines the plan to integrate the ggwave data-over-sound library into the ddwave Expo app, recreating the functionality of ggwave's Waver app. The goal is to demonstrate all capabilities of ggwave: encoding data to sound, transmitting it, receiving it, and decoding back to the original text.

---

## Table of Contents

1. [ggwave Overview](#ggwave-overview)
2. [Integration Options](#integration-options)
3. [Recommended Approach](#recommended-approach)
4. [Implementation Steps](#implementation-steps)
5. [Technical Architecture](#technical-architecture)
6. [Challenges & Solutions](#challenges--solutions)
7. [Testing Strategy](#testing-strategy)
8. [Success Metrics](#success-metrics)

---

## ggwave Overview

### What is ggwave?

ggwave is a C++ library for data transmission over sound waves. It's designed to be:

- **Lightweight**: Only 71KB of C++ source code
- **Zero dependencies**: STL-free, custom FFT implementation
- **Efficient**: Zero runtime allocations, all memory allocated upfront
- **Versatile**: Works on microcontrollers, mobile, desktop, and web

### Key Specifications

- **Sample Rates**: 1kHz - 96kHz (default 48kHz)
- **Payload Size**: 1-140 bytes (variable length) or 1-64 bytes (fixed length)
- **Bandwidth**: 8-16 bytes/second
- **Latency**: 0.3-1 second per transmission (protocol dependent)
- **Channels**: Mono (1 channel)
- **Error Correction**: Reed-Solomon ECC for robust transmission

### Available Protocols

#### Audible Protocols (1875-5625 Hz)

- `GGWAVE_PROTOCOL_AUDIBLE_NORMAL` - 9 frames/tx, ~1 sec
- `GGWAVE_PROTOCOL_AUDIBLE_FAST` - 6 frames/tx, ~0.7 sec
- `GGWAVE_PROTOCOL_AUDIBLE_FASTEST` - 3 frames/tx, ~0.3 sec

#### Ultrasound Protocols (15000-19500 Hz)

- `GGWAVE_PROTOCOL_ULTRASOUND_NORMAL`
- `GGWAVE_PROTOCOL_ULTRASOUND_FAST`
- `GGWAVE_PROTOCOL_ULTRASOUND_FASTEST`

#### Low-Frequency Protocols (for microcontrollers)

- `GGWAVE_PROTOCOL_DT_*` (Dual Tone)
- `GGWAVE_PROTOCOL_MT_*` (Mono Tone)

### Waver App Features (Target Functionality)

The official Waver app includes:

- Send/receive text messages (1-140 bytes)
- Real-time frequency spectrum visualization
- Multiple protocol support (audible + ultrasound)
- File sharing via sound-initiated TCP/IP connections
- Volume control and protocol selection
- Cross-platform support (iOS, Android, Web, Desktop)

---

## Integration Options

### ⚠️ CRITICAL UPDATE: expo-audio Limitations

**expo-audio (SDK 53+) has fundamental limitations that prevent WASM/JavaScript integration:**

1. **No real-time PCM access during recording** - AudioRecorder only saves to files, doesn't provide continuous audio samples needed for ggwave decoding
2. **No raw buffer playback** - AudioPlayer only accepts file URIs, can't play programmatically-generated waveforms from ggwave
3. **File-based workarounds introduce unacceptable latency** - Recording → file → read → process → write → file → play chain is too slow for real-time data transmission
4. **expo-av is deprecated** - Removed in SDK 55, no longer maintained

**Conclusion**: ggwave requires bidirectional real-time raw audio I/O. expo-audio cannot provide this. **Native modules are the only viable path.**

---

### Option 1: Native Module Integration ⭐ (REQUIRED - ONLY VIABLE OPTION)

#### Description

Create native modules for iOS and Android that directly integrate the ggwave C++ source code and platform audio APIs. This is now the **only viable option** given expo-audio's architectural limitations.

#### Pros

- ✅ Best performance (~0.3-1s latency)
- ✅ Real-time audio processing capability
- ✅ Smallest footprint (71KB + minimal audio framework overhead)
- ✅ Full protocol support (audible + ultrasound)
- ✅ Direct access to AVAudioEngine (iOS) and AudioRecord/AudioTrack (Android)
- ✅ Production-ready solution
- ✅ Works with Expo's new architecture
- ✅ **Only option that provides raw PCM I/O required by ggwave**
- ✅ Complete control over audio pipeline

#### Cons

- ❌ Requires native development knowledge (Objective-C++/Swift/Kotlin/JNI)
- ❌ More complex initial setup
- ❌ Can't use Expo Go (needs dev build)
- ❌ Platform-specific code to maintain

#### Complexity

**Medium-High**

#### Time Investment

**3-6 days** for full implementation (no POC phase possible)

#### Reference Implementations

- iOS: `/examples/ggwave-objc` in ggwave repo
- Android: `/examples/ggwave-java` in ggwave repo
- KMM: `https://github.com/wooram-yang/ggwave-kmm`
- Expo Modules API: https://docs.expo.dev/modules/overview/

---

### ~~Option 2: WASM/JavaScript Bindings~~ ❌ (NOT VIABLE)

#### Description

~~Use the official ggwave npm package (WASM-based) combined with Expo's audio APIs.~~

#### Why This Doesn't Work

- ❌ **expo-av is deprecated** (removed in SDK 55)
- ❌ **expo-audio doesn't provide real-time recording access** - AudioRecorder only writes to files, no callback-based PCM data stream
- ❌ **expo-audio doesn't accept raw audio buffers** - AudioPlayer only accepts file URIs (local/remote), cannot play Float32Array waveforms
- ❌ **File-based workarounds are too slow** - 500ms+ latency makes real-time data transmission impractical
- ❌ **No third-party Expo-compatible libraries** provide the necessary raw audio APIs without ejecting
- ❌ **WASM overhead compounds the problem** - Even if audio APIs existed, JS/WASM bridge adds latency

#### Technical Deep-Dive

The ggwave WASM library (`npm install ggwave`) works perfectly and provides:
- `encode(text, protocol)` → `Float32Array` waveform
- `decode(Float32Array)` → `text | null`

However, Expo's audio infrastructure cannot:
1. **Playback**: Feed Float32Array to speaker (needs file URI)
2. **Recording**: Stream PCM data in real-time (only file-based recording)

This fundamental architectural mismatch makes WASM integration impossible without native audio bridge.

#### Conclusion

**This option is technically not viable for ggwave integration.** The ggwave WASM library is excellent, but Expo's current audio APIs cannot support its requirements.

---

## Recommended Approach

### Native Modules from Day 1 (Only Viable Path)

#### Rationale

1. **Technical Necessity**: expo-audio cannot provide the real-time raw audio I/O that ggwave requires
2. **No POC Phase Possible**: Without proper audio APIs, a JavaScript POC would fail to demonstrate core functionality
3. **Direct Path to Production**: Skip exploration and go straight to the solution that will work
4. **Reference Implementations Available**: ggwave provides battle-tested iOS and Android examples
5. **Expo Module API**: Modern Expo modules (SDK 50+) make native development more approachable with better TypeScript integration

#### Implementation Strategy

```
Setup Dev Environment (Expo prebuild)
     ↓
Implement iOS Native Module
  - AVAudioEngine for real-time I/O
  - ggwave C++ integration
  - Expo Module API wrapper
     ↓
Implement Android Native Module
  - AudioRecord/AudioTrack for real-time I/O
  - ggwave C++ integration via JNI
  - Expo Module API wrapper
     ↓
Create Unified JavaScript API
  - TypeScript definitions
  - Hooks (useGGWave)
  - Event emitters for receive
     ↓
Build UI/UX Layer
  - Transmit/Receive/Settings screens
  - React Native components
     ↓
Test & Optimize
  - Device-to-device testing
  - Performance profiling
     ↓
Production-ready app ✅
```

---

## Implementation Steps

### Phase 1: Development Environment Setup

#### 1.1 Initialize Expo Project with Native Modules

```bash
# If starting fresh
npx create-expo-app ddwave --template blank-typescript

# Prebuild to generate native projects
npx expo prebuild

# Install Expo Modules API
npx expo install expo-modules-core
```

#### 1.2 Download ggwave Source Code

```bash
# Clone ggwave repository
git clone https://github.com/ggerganov/ggwave.git

# Copy C++ source to your project
mkdir -p modules/expo-ggwave/cpp
cp -r ggwave/src/* modules/expo-ggwave/cpp/
cp -r ggwave/include/* modules/expo-ggwave/cpp/
```

#### 1.3 Create Expo Module Structure

```bash
# Create module directory
mkdir -p modules/expo-ggwave

# Initialize Expo module
cd modules/expo-ggwave
npx create-expo-module@latest --local
```

#### 1.4 Configure Permissions

Update `app.json`:

```json
{
  "expo": {
    "plugins": [
      [
        "./modules/expo-ggwave/app.plugin.js",
        {
          "microphonePermission": "Allow $(PRODUCT_NAME) to access your microphone for sound-based data transmission.",
          "speechRecognitionPermission": "This app does not use speech recognition."
        }
      ]
    ],
    "ios": {
      "infoPlist": {
        "NSMicrophoneUsageDescription": "Allow $(PRODUCT_NAME) to access your microphone for sound-based data transmission.",
        "UIBackgroundModes": ["audio"]
      }
    },
    "android": {
      "permissions": [
        "android.permission.RECORD_AUDIO",
        "android.permission.MODIFY_AUDIO_SETTINGS"
      ]
    }
  }
}
```

---

### Phase 2: iOS Native Module Implementation

#### 2.1 Setup iOS Native Files

**File Structure**:

```
modules/expo-ggwave/
├── ios/
│   ├── ExpoGGWaveModule.swift       # Expo Module API wrapper
│   ├── GGWaveEngine.mm              # Objective-C++ bridge to ggwave
│   ├── AudioManager.swift           # AVAudioEngine wrapper
│   └── ExpoGGWave.podspec          # CocoaPods specification
├── cpp/
│   ├── ggwave.h
│   ├── ggwave.cpp
│   └── reed-solomon/
└── expo-module.config.json
```

#### 2.2 Implement GGWave Engine (iOS)

**File**: `modules/expo-ggwave/ios/GGWaveEngine.mm`

**Key Responsibilities**:
- Initialize ggwave instance with C++ API
- Encode text to audio waveform
- Decode audio samples to text
- Protocol management

**Core Methods**:

```objc
@interface GGWaveEngine : NSObject
- (instancetype)initWithSampleRate:(int)sampleRate;
- (NSData *)encodeText:(NSString *)text
              protocol:(int)protocolId
                volume:(float)volume;
- (NSString *)decodeAudio:(float *)samples
                   length:(int)length;
- (NSArray<NSNumber *> *)availableProtocols;
@end
```

#### 2.3 Implement Audio Manager (iOS)

**File**: `modules/expo-ggwave/ios/AudioManager.swift`

**Key Responsibilities**:
- Configure AVAudioEngine for real-time I/O
- Manage audio session
- Stream audio from microphone to decoder
- Play generated waveforms

**Core Methods**:

```swift
class AudioManager {
    func setupAudioSession() throws
    func startRecording(callback: @escaping ([Float]) -> Void) throws
    func stopRecording()
    func playWaveform(_ samples: [Float], sampleRate: Int)
    func isRecording() -> Bool
}
```

#### 2.4 Expo Module Wrapper (iOS)

**File**: `modules/expo-ggwave/ios/ExpoGGWaveModule.swift`

```swift
import ExpoModulesCore

public class ExpoGGWaveModule: Module {
  private var ggwaveEngine: GGWaveEngine?
  private var audioManager: AudioManager?

  public func definition() -> ModuleDefinition {
    Name("ExpoGGWave")

    Function("initialize") { (sampleRate: Int) in
      self.ggwaveEngine = GGWaveEngine(sampleRate: sampleRate)
      self.audioManager = AudioManager()
    }

    AsyncFunction("encode") { (text: String, protocol: Int, volume: Float) -> [Float] in
      guard let engine = self.ggwaveEngine else {
        throw EncodingError.notInitialized
      }
      return try engine.encode(text: text, protocol: protocol, volume: volume)
    }

    AsyncFunction("playWaveform") { (samples: [Float], sampleRate: Int) in
      try self.audioManager?.playWaveform(samples, sampleRate: sampleRate)
    }

    AsyncFunction("startListening") {
      try self.audioManager?.startRecording { samples in
        if let decoded = self.ggwaveEngine?.decode(samples) {
          self.sendEvent("onDataReceived", ["text": decoded])
        }
      }
    }

    AsyncFunction("stopListening") {
      self.audioManager?.stopRecording()
    }

    Events("onDataReceived")
  }
}
```

---

### Phase 3: Android Native Module Implementation

#### 3.1 Setup Android Native Files

**File Structure**:

```
modules/expo-ggwave/
├── android/
│   ├── src/main/
│   │   ├── java/expo/modules/ggwave/
│   │   │   ├── ExpoGGWaveModule.kt      # Expo Module API wrapper
│   │   │   ├── AudioManager.kt          # AudioRecord/AudioTrack wrapper
│   │   │   └── GGWaveEngine.kt          # JNI bridge
│   │   └── cpp/
│   │       └── ggwave-jni.cpp           # JNI C++ implementation
│   └── build.gradle
└── cpp/ (shared with iOS)
```

#### 3.2 Implement JNI Bridge (Android)

**File**: `modules/expo-ggwave/android/src/main/cpp/ggwave-jni.cpp`

```cpp
#include <jni.h>
#include "ggwave/ggwave.h"

extern "C" {

JNIEXPORT jlong JNICALL
Java_expo_modules_ggwave_GGWaveEngine_nativeInit(
    JNIEnv *env, jobject thiz, jint sampleRate) {
    auto params = ggwave_getDefaultParameters();
    params.sampleRateInp = sampleRate;
    params.sampleRateOut = sampleRate;

    auto* instance = new ggwave_Instance(params);
    return reinterpret_cast<jlong>(instance);
}

JNIEXPORT jfloatArray JNICALL
Java_expo_modules_ggwave_GGWaveEngine_nativeEncode(
    JNIEnv *env, jobject thiz, jlong handle,
    jstring text, jint protocol, jfloat volume) {

    auto* instance = reinterpret_cast<ggwave_Instance*>(handle);
    const char* textCStr = env->GetStringUTFChars(text, nullptr);

    // Encode using ggwave
    auto waveform = instance->encode(textCStr, protocol, volume);

    env->ReleaseStringUTFChars(text, textCStr);

    // Convert to jfloatArray
    jfloatArray result = env->NewFloatArray(waveform.size());
    env->SetFloatArrayRegion(result, 0, waveform.size(), waveform.data());

    return result;
}

JNIEXPORT jstring JNICALL
Java_expo_modules_ggwave_GGWaveEngine_nativeDecode(
    JNIEnv *env, jobject thiz, jlong handle,
    jfloatArray samples, jint length) {

    auto* instance = reinterpret_cast<ggwave_Instance*>(handle);

    jfloat* sampleData = env->GetFloatArrayElements(samples, nullptr);
    auto decoded = instance->decode(sampleData, length);
    env->ReleaseFloatArrayElements(samples, sampleData, JNI_ABORT);

    if (decoded.empty()) {
        return nullptr;
    }

    return env->NewStringUTF(decoded.c_str());
}

} // extern "C"
```

#### 3.3 Implement Audio Manager (Android)

**File**: `modules/expo-ggwave/android/src/main/java/expo/modules/ggwave/AudioManager.kt`

```kotlin
package expo.modules.ggwave

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import kotlinx.coroutines.*

class AudioManager(private val sampleRate: Int) {
    private var audioRecord: AudioRecord? = null
    private var audioTrack: AudioTrack? = null
    private var recordingJob: Job? = null

    fun startRecording(callback: (FloatArray) -> Unit) {
        val bufferSize = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_FLOAT
        )

        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_FLOAT,
            bufferSize
        )

        audioRecord?.startRecording()

        recordingJob = CoroutineScope(Dispatchers.IO).launch {
            val buffer = FloatArray(bufferSize)
            while (isActive) {
                val read = audioRecord?.read(buffer, 0, bufferSize, AudioRecord.READ_BLOCKING) ?: 0
                if (read > 0) {
                    callback(buffer.copyOf(read))
                }
            }
        }
    }

    fun stopRecording() {
        recordingJob?.cancel()
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
    }

    fun playWaveform(samples: FloatArray) {
        val bufferSize = samples.size

        audioTrack = AudioTrack.Builder()
            .setAudioFormat(AudioFormat.Builder()
                .setSampleRate(sampleRate)
                .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                .build())
            .setBufferSizeInBytes(bufferSize * 4) // 4 bytes per float
            .build()

        audioTrack?.play()
        audioTrack?.write(samples, 0, samples.size, AudioTrack.WRITE_BLOCKING)
        audioTrack?.stop()
        audioTrack?.release()
    }
}
```

#### 3.4 Expo Module Wrapper (Android)

**File**: `modules/expo-ggwave/android/src/main/java/expo/modules/ggwave/ExpoGGWaveModule.kt`

```kotlin
package expo.modules.ggwave

import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

class ExpoGGWaveModule : Module() {
  private var ggwaveEngine: GGWaveEngine? = null
  private var audioManager: AudioManager? = null

  override fun definition() = ModuleDefinition {
    Name("ExpoGGWave")

    Function("initialize") { sampleRate: Int ->
      ggwaveEngine = GGWaveEngine(sampleRate)
      audioManager = AudioManager(sampleRate)
    }

    AsyncFunction("encode") { text: String, protocol: Int, volume: Float ->
      ggwaveEngine?.encode(text, protocol, volume)
        ?: throw Exception("Not initialized")
    }

    AsyncFunction("playWaveform") { samples: FloatArray, sampleRate: Int ->
      audioManager?.playWaveform(samples)
    }

    AsyncFunction("startListening") {
      audioManager?.startRecording { samples ->
        ggwaveEngine?.decode(samples)?.let { decoded ->
          sendEvent("onDataReceived", mapOf("text" to decoded))
        }
      }
    }

    AsyncFunction("stopListening") {
      audioManager?.stopRecording()
    }

    Events("onDataReceived")
  }
}
```

---

### Phase 4: JavaScript/TypeScript API Layer

#### 4.1 Create TypeScript Definitions

**File**: `modules/expo-ggwave/src/ExpoGGWave.types.ts`

```typescript
export enum GGWaveProtocol {
  AUDIBLE_NORMAL = 1,
  AUDIBLE_FAST = 2,
  AUDIBLE_FASTEST = 3,
  ULTRASOUND_NORMAL = 4,
  ULTRASOUND_FAST = 5,
  ULTRASOUND_FASTEST = 6,
}

export interface GGWaveConfig {
  sampleRate?: number; // Default: 48000
  protocol?: GGWaveProtocol;
  volume?: number; // 0-100, default: 50
}

export interface GGWaveDataReceivedEvent {
  text: string;
}
```

#### 4.2 Create JavaScript Module

**File**: `modules/expo-ggwave/src/ExpoGGWaveModule.ts`

```typescript
import { NativeModulesProxy, EventEmitter } from 'expo-modules-core';
import ExpoGGWaveModule from './ExpoGGWaveModule';
import { GGWaveProtocol, GGWaveConfig, GGWaveDataReceivedEvent } from './ExpoGGWave.types';

const emitter = new EventEmitter(ExpoGGWaveModule);

class GGWave {
  private initialized = false;
  private config: Required<GGWaveConfig> = {
    sampleRate: 48000,
    protocol: GGWaveProtocol.AUDIBLE_FAST,
    volume: 50,
  };

  async initialize(config?: GGWaveConfig): Promise<void> {
    if (config) {
      this.config = { ...this.config, ...config };
    }

    await ExpoGGWaveModule.initialize(this.config.sampleRate);
    this.initialized = true;
  }

  async transmit(text: string, protocol?: GGWaveProtocol, volume?: number): Promise<void> {
    if (!this.initialized) {
      throw new Error('GGWave not initialized. Call initialize() first.');
    }

    const useProtocol = protocol ?? this.config.protocol;
    const useVolume = (volume ?? this.config.volume) / 100;

    const waveform = await ExpoGGWaveModule.encode(text, useProtocol, useVolume);
    await ExpoGGWaveModule.playWaveform(waveform, this.config.sampleRate);
  }

  async startListening(callback: (text: string) => void): Promise<void> {
    if (!this.initialized) {
      throw new Error('GGWave not initialized. Call initialize() first.');
    }

    const subscription = emitter.addListener<GGWaveDataReceivedEvent>(
      'onDataReceived',
      (event) => callback(event.text)
    );

    await ExpoGGWaveModule.startListening();

    return subscription;
  }

  async stopListening(): Promise<void> {
    await ExpoGGWaveModule.stopListening();
  }
}

export default new GGWave();
export { GGWaveProtocol };
```

#### 4.3 Create React Hook

**File**: `modules/expo-ggwave/src/useGGWave.ts`

```typescript
import { useState, useEffect, useCallback } from 'react';
import GGWave, { GGWaveProtocol } from './ExpoGGWaveModule';

export function useGGWave() {
  const [isInitialized, setIsInitialized] = useState(false);
  const [isListening, setIsListening] = useState(false);
  const [receivedMessages, setReceivedMessages] = useState<string[]>([]);

  useEffect(() => {
    GGWave.initialize().then(() => setIsInitialized(true));
  }, []);

  const transmit = useCallback(async (
    text: string,
    protocol?: GGWaveProtocol,
    volume?: number
  ) => {
    await GGWave.transmit(text, protocol, volume);
  }, []);

  const startListening = useCallback(async () => {
    await GGWave.startListening((text) => {
      setReceivedMessages(prev => [...prev, text]);
    });
    setIsListening(true);
  }, []);

  const stopListening = useCallback(async () => {
    await GGWave.stopListening();
    setIsListening(false);
  }, []);

  const clearMessages = useCallback(() => {
    setReceivedMessages([]);
  }, []);

  return {
    isInitialized,
    isListening,
    receivedMessages,
    transmit,
    startListening,
    stopListening,
    clearMessages,
  };
}
```

---

### Phase 5: UI Implementation

#### 5.1 Transmit Screen

**File**: `app/(tabs)/transmit.tsx`

**Features**:

- Text input field (max 140 characters)
- Protocol selector dropdown
  - Audible Normal/Fast/Fastest
  - Ultrasound Normal/Fast/Fastest
- Volume slider (0-100, recommended 10-50)
- "Transmit" button
- Status indicator (idle, encoding, transmitting, complete)
- Transmission history

**User Flow**:

1. User enters text message
2. Selects protocol (defaults to Audible Fast)
3. Adjusts volume if needed
4. Taps "Transmit"
5. App encodes text and plays audio
6. Success feedback shown

#### 5.2 Receive Screen

**File**: `app/(tabs)/receive.tsx`

**Features**:

- "Start Listening" / "Stop Listening" toggle button
- Real-time status indicator
  - Listening (animated)
  - Decoding (when data detected)
  - Received (success state)
- Received messages list (with timestamps)
- Clear history button
- Frequency spectrum visualization (optional)

**User Flow**:

1. User taps "Start Listening"
2. App begins recording audio
3. Audio continuously fed to decoder
4. When valid data detected, message appears
5. User can copy or share received message

#### 5.3 Settings Screen

**File**: `app/(tabs)/settings.tsx`

**Features**:

- Default protocol selection
- Default volume setting
- Sample rate selection (6kHz, 24kHz, 48kHz, 96kHz)
- Operating mode selection
  - Transmit only
  - Receive only
  - Transmit & Receive (default)
- About section
  - ggwave version
  - Links to documentation
  - Test mode

---

### Phase 6: Advanced Features (Optional)

#### 6.1 Waveform Visualization

**Library Options**:

- `react-native-svg` for custom drawing
- `expo-gl` for WebGL rendering
- `react-native-reanimated` for smooth animations

**Display**:

- Real-time amplitude visualization during transmit
- Frequency spectrum during receive
- Similar to Waver app's visualizer

#### 6.2 Protocol Comparison Tool

**Feature**: Side-by-side protocol testing

- Test same message on all protocols
- Measure transmission time
- Success rate statistics
- Distance testing mode

#### 6.3 File Sharing (Advanced)

**Implementation**: Similar to Waver app

- Sound-initiated connection
- Establish TCP/IP connection between devices
- Transfer files over network (not sound)
- Sound used only for handshake/discovery

---

### Phase 7: Testing & Optimization

#### 7.1 Unit Tests

**File**: `__tests__/GGWaveService.test.ts`

**Test Cases**:

- Encode/decode round-trip with all protocols
- Audio format conversion accuracy
- Protocol switching
- Volume scaling
- Error handling (invalid input, audio failures)

#### 7.2 Integration Tests

**Scenarios**:

- Same device loopback test
- Two devices at various distances (0.5m, 2m, 5m, 10m)
- Different protocol comparison
- Background noise tolerance
- Simultaneous transmissions (interference testing)

#### 7.3 Performance Profiling

**Metrics to Track**:

- Encode time (target: <100ms)
- Decode latency (target: <500ms)
- Memory usage
- CPU usage during listening
- Battery impact
- Bundle size impact

---

## Technical Architecture

### Component Hierarchy

```text
App Root
├── app/(tabs)/
│   ├── transmit.tsx              # Transmit screen UI
│   │   └── Components
│   │       ├── TextInput
│   │       ├── ProtocolSelector
│   │       ├── VolumeSlider
│   │       └── TransmitButton
│   ├── receive.tsx               # Receive screen UI
│   │   └── Components
│   │       ├── ListenButton
│   │       ├── StatusIndicator
│   │       └── MessageList
│   └── settings.tsx              # Settings screen UI
│       └── SettingsForm
│
├── modules/expo-ggwave/          # Native module (local)
│   ├── ios/
│   │   ├── ExpoGGWaveModule.swift
│   │   ├── GGWaveEngine.mm
│   │   └── AudioManager.swift
│   ├── android/
│   │   ├── ExpoGGWaveModule.kt
│   │   ├── GGWaveEngine.kt
│   │   ├── AudioManager.kt
│   │   └── cpp/ggwave-jni.cpp
│   ├── cpp/                      # Shared ggwave C++ source
│   │   ├── ggwave.h
│   │   ├── ggwave.cpp
│   │   └── reed-solomon/
│   └── src/                      # TypeScript/JavaScript API
│       ├── ExpoGGWaveModule.ts
│       ├── ExpoGGWave.types.ts
│       └── useGGWave.ts
│
└── utils/
    └── permissions.ts
```

### Data Flow

#### Transmit Flow

```text
User Input (Text)
    ↓
React Native UI
    ↓
useGGWave.transmit()
    ↓
ExpoGGWaveModule.encode() (JavaScript)
    ↓
Native Bridge (iOS/Android)
    ↓
GGWaveEngine.encode() (Native)
    ↓
ggwave C++ encode() → Float32Array waveform
    ↓
AudioManager.playWaveform() (Native)
    ↓
iOS: AVAudioEngine / Android: AudioTrack
    ↓
Speaker Output 🔊
```

#### Receive Flow

```text
Microphone Input 🎤
    ↓
iOS: AVAudioEngine / Android: AudioRecord
    ↓
Real-time PCM Float32 samples
    ↓
AudioManager callback (Native)
    ↓
GGWaveEngine.decode() (Native)
    ↓
ggwave C++ decode() → text or null
    ↓
Native Bridge Event (onDataReceived)
    ↓
ExpoGGWaveModule EventEmitter (JavaScript)
    ↓
useGGWave hook
    ↓
React Native UI update
    ↓
Display received message to user
```

---

## Challenges & Solutions

### Challenge 1: Native Module Build Configuration

**Problem**: Integrating ggwave C++ source into iOS and Android builds requires proper build system configuration.

**Solution**:

**iOS (CocoaPods)**:
- Create proper `.podspec` file that includes C++ sources
- Set `CLANG_CXX_LANGUAGE_STANDARD = "c++17"` in build settings
- Ensure Objective-C++ bridging files use `.mm` extension
- Link against `AVFoundation` framework

**Android (CMake/Gradle)**:
- Create `CMakeLists.txt` for C++ compilation
- Configure JNI bindings in `build.gradle`
- Set `externalNativeBuild` correctly
- Enable C++17 standard: `cppFlags "-std=c++17"`

---

### Challenge 2: Real-time Audio Thread Management

**Problem**: Audio processing must happen on dedicated threads to avoid UI blocking and maintain low latency.

**Solution**:

**iOS**:
- Use AVAudioEngine with installTap on input node for recording
- Process audio in real-time callback (high priority thread)
- Avoid blocking operations in audio callback
- Use dispatch queues for event emission to JavaScript

**Android**:
- Use Kotlin coroutines with `Dispatchers.IO` for recording loop
- AudioRecord in blocking mode with dedicated thread
- Keep decode operations off UI thread
- Buffer audio samples for smooth processing

**Code Pattern**:

```kotlin
recordingJob = CoroutineScope(Dispatchers.IO).launch {
    val buffer = FloatArray(BUFFER_SIZE)
    while (isActive) {
        val read = audioRecord?.read(buffer, 0, BUFFER_SIZE, READ_BLOCKING)
        if (read > 0) {
            // Process on background thread
            val decoded = ggwaveEngine?.decode(buffer.copyOf(read))
            // Emit to JS on main thread
            withContext(Dispatchers.Main) {
                if (decoded != null) sendEvent("onDataReceived", decoded)
            }
        }
    }
}
```

---

### Challenge 3: Audio Session Management (iOS)

**Problem**: iOS audio session must be configured correctly for recording/playback, and can be interrupted by system events.

**Solution**:

- Configure audio session category appropriately:
  - `AVAudioSessionCategoryPlayAndRecord` for full duplex
  - `AVAudioSessionCategoryPlayback` for transmit only
  - `AVAudioSessionCategoryRecord` for receive only
- Handle audio interruptions (phone calls, other apps)
- Request microphone permissions before recording
- Configure audio session for background audio if needed

**Implementation**:

```swift
let audioSession = AVAudioSession.sharedInstance()
try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
try audioSession.setActive(true)

// Handle interruptions
NotificationCenter.default.addObserver(
    forName: AVAudioSession.interruptionNotification,
    object: audioSession,
    queue: nil
) { notification in
    // Handle interruption, pause/resume audio
}
```

---

### Challenge 4: Cross-platform API Consistency

**Problem**: iOS and Android have different audio APIs with different behaviors and capabilities.

**Solution**:

- Design unified JavaScript API that abstracts platform differences
- Use Expo Module API's cross-platform abstractions
- Handle platform-specific edge cases in native code
- Ensure consistent sample rates and formats across platforms
- Test extensively on both platforms

**Unified API Example**:

```typescript
// Same API works on iOS and Android
await GGWave.initialize({ sampleRate: 48000 });
await GGWave.transmit("Hello World", GGWaveProtocol.AUDIBLE_FAST, 50);
await GGWave.startListening((text) => console.log(text));
```

---

### Challenge 5: Memory Management in Native Code

**Problem**: C++ ggwave instance and audio buffers must be properly managed to avoid leaks.

**Solution**:

**iOS (ARC + Manual C++)**:
- Wrap ggwave instance in Objective-C++ class with proper destructor
- Use smart pointers (`std::unique_ptr`) for C++ objects
- Ensure proper cleanup in `deinit` / `dealloc`

**Android (JNI)**:
- Store ggwave instance pointer as `jlong` handle
- Implement explicit `destroy()` method for cleanup
- Release JNI local/global references properly
- Use RAII patterns in C++ layer

**Example**:

```cpp
// Android JNI
JNIEXPORT void JNICALL
Java_expo_modules_ggwave_GGWaveEngine_nativeDestroy(
    JNIEnv *env, jobject thiz, jlong handle) {
    auto* instance = reinterpret_cast<ggwave_Instance*>(handle);
    delete instance; // Proper cleanup
}
```

---

### Challenge 6: Audio Playback/Recording Conflicts

**Problem**: Many mobile devices can't record and play audio simultaneously at full duplex.

**Solution**:

- Implement separate Transmit/Receive modes (like Waver app)
- Stop listening before transmitting
- Reconfigure audio session when switching modes
- Provide clear UI feedback about current mode
- Auto-switch modes based on user action

---

### Challenge 7: Ultrasound Protocol Support

**Problem**: Not all devices support ultrasound frequencies (15-19.5 kHz). Some hardware may filter them out.

**Solution**:

- Default to audible protocols
- Provide protocol testing tool in settings
- Warn users if ultrasound not supported on device
- Test ultrasound capability on app startup
- Graceful degradation to audible protocols

**Detection Method**:

- Play ultrasound test tone
- Attempt to record and decode it
- Mark protocol as supported/unsupported
- Save results to device storage

---

### Challenge 8: Debugging Native Code

**Problem**: Debugging crashes and issues in native modules is more complex than JavaScript debugging.

**Solution**:

**iOS**:
- Use Xcode debugger with breakpoints in Objective-C++/Swift code
- Enable address sanitizer for memory issues
- Use `NSLog` for logging from native code
- Check crash logs in Console.app

**Android**:
- Use Android Studio debugger with C++ breakpoints
- Enable AddressSanitizer in `build.gradle`
- Use `Log.d()` in Kotlin and `__android_log_print()` in C++
- Use `adb logcat` for real-time logs

**Logging Pattern**:

```swift
// iOS
print("[GGWave] Encoding text: \(text), protocol: \(protocol)")

// Android
Log.d("GGWave", "Encoding text: $text, protocol: $protocol")
```

---

## Testing Strategy

### Test Phases

#### Phase 1: Unit Testing

**Focus**: Individual function correctness

**Test Cases**:

- ✅ Encode "Hello World" and verify waveform generation
- ✅ Decode known waveform and verify text output
- ✅ Round-trip test: encode → decode same message
- ✅ All protocol switches work correctly
- ✅ Volume scaling (0-100) produces valid waveforms
- ✅ Audio format conversion accuracy
- ✅ Error handling (null inputs, invalid protocols)
- ✅ Memory leaks during encode/decode cycles

#### Phase 2: Integration Testing

**Focus**: Component interaction

**Test Cases**:

- ✅ Microphone permission flow
- ✅ Audio recording starts/stops correctly
- ✅ Audio playback completes successfully
- ✅ UI state transitions (idle → encoding → transmitting → complete)
- ✅ Message history persistence
- ✅ Settings persistence across app restarts

#### Phase 3: Device-to-Device Testing

**Focus**: Real-world transmission

**Test Scenarios**:

| Distance | Environment  | Protocol        | Expected Result             |
| -------- | ------------ | --------------- | --------------------------- |
| 0.5m     | Quiet room   | Audible Fast    | 100% success                |
| 2m       | Quiet room   | Audible Normal  | >95% success                |
| 5m       | Quiet room   | Audible Normal  | >80% success                |
| 2m       | Noisy (café) | Audible Normal  | >70% success                |
| 0.5m     | Quiet room   | Ultrasound Fast | 100% success (if supported) |

**Test Matrix**:

- iPhone → iPhone
- iPhone → Android
- Android → Android
- Same message, all 6 protocols
- Variable message lengths (1, 10, 50, 140 bytes)

#### Phase 4: Stress Testing

**Focus**: Edge cases and reliability

**Test Cases**:

- ✅ Continuous listening for 30 minutes (memory stability)
- ✅ 100 consecutive transmissions (no degradation)
- ✅ Simultaneous transmissions from multiple devices (interference)
- ✅ Very long messages (140 bytes)
- ✅ Special characters (emoji, unicode)
- ✅ Background/foreground transitions
- ✅ Incoming call interruption
- ✅ Low battery scenarios

#### Phase 5: Platform-Specific Testing

**iOS-Specific**:

- Audio session interruptions
- Silent mode switch behavior
- AirPods/Bluetooth headphone compatibility
- Permission prompt flows

**Android-Specific**:

- Various audio hardware (Samsung, Pixel, OnePlus)
- Audio focus handling
- Permission flows (Android 11+)
- Background restrictions

---

## Success Metrics

### Functional Requirements

- ✅ **Text Transmission**: Successfully transmit arbitrary text (1-140 bytes) between devices
- ✅ **Protocol Support**: All 6 main protocols work (3 audible + 3 ultrasound)
- ✅ **Bidirectional**: Both devices can send and receive
- ✅ **Range**: Reliable transmission at 2-3 meters in quiet environment
- ✅ **Special Characters**: Handle emoji and unicode correctly

### Performance Requirements

- ✅ **Latency**: <1 second end-to-end for Audible Fast protocol
- ✅ **Success Rate**: >95% in ideal conditions (quiet, 2m distance)
- ✅ **Encode Speed**: <100ms to encode 140 byte message
- ✅ **Battery**: <5% battery drain per hour of continuous listening
- ✅ **Bundle Size**: <2MB addition to base app size

### User Experience Requirements

- ✅ **Simple UI**: 3-tab interface (Transmit, Receive, Settings)
- ✅ **Clear Feedback**: Visual/haptic feedback for all states
- ✅ **Error Handling**: Graceful error messages for failures
- ✅ **Permissions**: Clear permission request flow
- ✅ **Documentation**: In-app help/tutorial for first-time users

### Quality Metrics

- ✅ **Crash Rate**: <0.1% across all sessions
- ✅ **ANR Rate**: 0% (Android)
- ✅ **App Store Rating**: Target 4.5+ stars
- ✅ **Code Coverage**: >80% for core ggwave service

---

## Migration Path to Native (If Needed)

### When to Consider Migration

Migrate to native modules (Option 1) if you observe:

- ⚠️ Decode latency >1 second consistently
- ⚠️ Success rate <80% in ideal conditions
- ⚠️ High CPU usage (>50% during listening)
- ⚠️ Excessive battery drain (>10%/hour)
- ⚠️ Audio dropout/glitches during playback
- ⚠️ User feedback indicating performance issues

### Migration Steps

#### Step 1: Convert to Bare Workflow

```bash
npx expo prebuild
```

#### Step 2: iOS Native Module

1. Create `ios/GGWaveModule/` directory
2. Copy ggwave C++ source files:
   - `ggwave.cpp`, `ggwave.h`, `fft.h`, `reed-solomon/`
3. Create Objective-C++ bridge: `RCTGGWave.mm`
4. Implement audio I/O using AVAudioEngine
5. Expose React Native methods via `RCT_EXPORT_METHOD`

#### Step 3: Android Native Module

1. Create `android/app/src/main/cpp/` directory
2. Copy ggwave C++ source files
3. Create JNI bridge: `GGWaveModule.cpp`
4. Implement audio I/O using android.media.AudioRecord/AudioTrack
5. Create Java/Kotlin wrapper class
6. Update `CMakeLists.txt` or `Android.mk`

#### Step 4: JavaScript API (Keep Same Interface)

```typescript
// Same API as WASM version - no app code changes needed!
import { NativeModules } from "react-native";
const { GGWave } = NativeModules;

// Methods remain identical
await GGWave.encode(text, protocol, volume);
await GGWave.startListening(callback);
```

#### Step 5: Testing & Validation

- Run same test suite as Phase 1
- Compare performance metrics
- Validate success rates improved
- Check battery usage decreased

---

## Resources & References

### ggwave Repository

- **GitHub**: https://github.com/ggerganov/ggwave
- **Documentation**: `/README.md`, `/include/ggwave/ggwave.h`
- **Examples**: `/examples/` directory

### Implementations to Reference

- **ggwave-objc** (iOS minimal): https://github.com/ggerganov/ggwave-objc
- **ggwave-java** (Android minimal): https://github.com/ggerganov/ggwave-java
- **ggwave-kmm** (Kotlin Multiplatform): https://github.com/wooram-yang/ggwave-kmm
- **Waver App** (full implementation): `/examples/waver/` in ggwave repo

### NPM Package

- **Package**: https://www.npmjs.com/package/ggwave
- **Version**: 0.4.2
- **Size**: ~150KB (WASM included)

### Live Demos

- **Waver Web App**: https://waver.ggerganov.com
- **ggwave Browser Demo**: https://ggwave.ggerganov.com
- **HTTP Service**: https://ggwave-to-file.ggerganov.com/

### Expo Documentation

- **expo-av**: https://docs.expo.dev/versions/latest/sdk/audio/
- **Native Modules**: https://docs.expo.dev/modules/overview/
- **Config Plugins**: https://docs.expo.dev/config-plugins/introduction/

---

## Timeline Estimate

### Native Module Implementation (Only Viable Approach)

| Phase       | Tasks                                                         | Duration    |
| ----------- | ------------------------------------------------------------- | ----------- |
| **Phase 1** | Development environment setup, Expo prebuild, module scaffold | 2-4 hours   |
| **Phase 2** | iOS native implementation (GGWaveEngine + AudioManager)       | 8-12 hours  |
| **Phase 3** | Android native implementation (JNI + AudioManager)            | 8-12 hours  |
| **Phase 4** | JavaScript/TypeScript API layer and hooks                     | 4-6 hours   |
| **Phase 5** | UI implementation (Transmit/Receive/Settings screens)         | 8-10 hours  |
| **Phase 6** | Advanced features (visualization, protocol testing)           | 6-8 hours   |
| **Phase 7** | Testing, debugging, optimization                              | 8-12 hours  |
| **Total**   | **44-64 hours (5.5-8 working days)**                          |             |

### Breakdown by Platform

**iOS Development**: 12-16 hours
- Objective-C++/Swift module setup: 2-3 hours
- GGWaveEngine implementation: 3-4 hours
- AudioManager with AVAudioEngine: 4-6 hours
- Testing and debugging: 3-4 hours

**Android Development**: 12-16 hours
- Kotlin/JNI module setup: 2-3 hours
- JNI bridge implementation: 3-4 hours
- AudioManager with AudioRecord/AudioTrack: 4-6 hours
- Testing and debugging: 3-4 hours

**Cross-platform Development**: 20-32 hours
- TypeScript API and hooks: 4-6 hours
- React Native UI components: 8-10 hours
- Advanced features: 6-8 hours
- Cross-platform testing: 4-8 hours
- Bug fixes and optimization: 4-8 hours

### Minimum Viable Product (MVP) Timeline

If focusing on core functionality only (transmit/receive, basic UI):

| Phase       | Tasks                                  | Duration   |
| ----------- | -------------------------------------- | ---------- |
| **Phase 1** | Environment setup                      | 2-4 hours  |
| **Phase 2** | iOS native module (minimal)            | 6-8 hours  |
| **Phase 3** | Android native module (minimal)        | 6-8 hours  |
| **Phase 4** | JavaScript API                         | 3-4 hours  |
| **Phase 5** | Basic UI (transmit + receive only)    | 4-6 hours  |
| **Phase 6** | Testing and bug fixes                  | 4-6 hours  |
| **Total**   | **25-36 hours (3-4.5 working days)**   |            |

---

## Conclusion

Due to fundamental limitations in Expo's audio APIs, **native module development is the only viable path** for integrating ggwave into the ddwave Expo app:

### Key Findings

1. **expo-audio limitations are architectural**: The new expo-audio library (SDK 53+) does not provide real-time raw PCM access for recording or buffer-based playback, making JavaScript/WASM integration impossible.

2. **expo-av is deprecated**: The older expo-av library that might have worked is being removed in SDK 55 and is no longer maintained.

3. **No JavaScript-only solution exists**: ggwave requires bidirectional real-time audio I/O that only native platform APIs can provide (AVAudioEngine on iOS, AudioRecord/AudioTrack on Android).

### The Path Forward

The implementation requires:

- **Native development skills**: Objective-C++/Swift for iOS, Kotlin/JNI for Android
- **Expo modules API**: Modern tooling makes native module development more approachable
- **Development time**: 5.5-8 working days for full implementation, 3-4.5 days for MVP
- **Reference implementations**: ggwave provides battle-tested iOS and Android examples

### Benefits of Native Implementation

Despite the increased complexity, native modules provide:

- ✅ **Best performance**: 0.3-1s latency, matching the official Waver app
- ✅ **Full protocol support**: All 6 protocols (audible + ultrasound) work correctly
- ✅ **Production-ready**: No performance compromises or workarounds
- ✅ **Small footprint**: Only 71KB of C++ code + minimal native framework overhead
- ✅ **Future-proof**: Not dependent on Expo's audio API evolution

### What This Means

This is not a "nice to have" optimization—it's a **technical necessity**. The good news: ggwave is well-designed with excellent documentation, and Expo's module API makes native development more accessible than traditional React Native modules.

The ddwave app will successfully replicate all Waver app capabilities with proper native integration, providing a clean, modern Expo/React Native experience on top of proven audio-over-sound technology.

---

## Next Steps

### Immediate Actions

1. **Environment Setup**
   - Ensure you have Xcode (for iOS) and Android Studio (for Android) installed
   - Run `npx expo prebuild` to generate native projects
   - Clone the ggwave repository to access source code and examples

2. **Choose Initial Platform**
   - Start with iOS if you have macOS (AVAudioEngine is slightly easier)
   - Start with Android if iOS development isn't available
   - Both platforms are required for production, but can be developed sequentially

3. **Reference Materials**
   - Study `/examples/ggwave-objc` (iOS) or `/examples/ggwave-java` (Android) in ggwave repo
   - Review Expo Modules API documentation: <https://docs.expo.dev/modules/overview/>
   - Familiarize with AVAudioEngine (iOS) or AudioRecord/AudioTrack (Android)

### Development Sequence

Follow this plan phase-by-phase:

**Week 1: Foundation**
- Phase 1: Environment setup and module scaffolding
- Phase 2: iOS native module implementation
- Phase 3: Android native module implementation

**Week 2: Integration & Polish**
- Phase 4: JavaScript/TypeScript API layer
- Phase 5: UI implementation
- Phase 6: Advanced features (optional)
- Phase 7: Testing and optimization

### Questions to Address Before Starting

1. **Do you have native development experience?** If not, budget extra time for learning curve
2. **Which platform is your primary target?** Start with that one first
3. **MVP or full feature set?** Decide if you want basic functionality first or complete implementation
4. **Testing devices available?** You'll need physical devices for audio testing (simulators/emulators don't work well for audio)

### Getting Help

- **ggwave GitHub Issues**: <https://github.com/ggerganov/ggwave/issues>
- **Expo Modules API Docs**: <https://docs.expo.dev/modules/>
- **Reference the examples**: ggwave-objc, ggwave-java, ggwave-kmm implementations
- **Community**: Expo Discord, React Native forums

**Ready to begin?** Start with Phase 1: Development Environment Setup.
