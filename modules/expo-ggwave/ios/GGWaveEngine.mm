#import "GGWaveEngine.h"
#include "../cpp/ggwave/ggwave.h"
#include <vector>
#include <string>
#include <memory>

@implementation GGWaveEngine {
    std::unique_ptr<GGWave> _ggwaveInstance;
    int _sampleRate;
}

- (instancetype)initWithSampleRate:(int)sampleRate {
    self = [super init];
    if (self) {
        _sampleRate = sampleRate;

        // Get default parameters and configure
        GGWave::Parameters params = GGWave::getDefaultParameters();

        // CRITICAL: Set sampleRateInp to the device sample rate
        // ggwave will internally resample from device rate to its internal 48kHz
        // This matches the working ggwave-objc implementation pattern
        params.sampleRateInp = sampleRate;  // Device sample rate (44.1kHz or 48kHz)
        params.sampleRateOut = sampleRate;  // Output at same rate for playback
        // params.sampleRate is the INTERNAL rate (defaults to 48kHz) - don't override it!

        params.sampleFormatInp = GGWAVE_SAMPLE_FORMAT_F32;  // Input audio is Float32
        params.sampleFormatOut = GGWAVE_SAMPLE_FORMAT_F32;  // Output audio is Float32
        params.operatingMode = GGWAVE_OPERATING_MODE_RX_AND_TX;

        NSLog(@"[GGWave] Creating ggwave instance with:");
        NSLog(@"[GGWave]   - sampleRateInp: %d Hz (device rate - will be resampled internally)", sampleRate);
        NSLog(@"[GGWave]   - sampleRateOut: %d Hz", sampleRate);
        NSLog(@"[GGWave]   - internal sampleRate: %.0f Hz (ggwave default)", params.sampleRate);
        NSLog(@"[GGWave]   - sampleFormatInp: F32");
        NSLog(@"[GGWave]   - sampleFormatOut: F32");
        NSLog(@"[GGWave]   - operatingMode: RX_AND_TX");
        NSLog(@"[GGWave]   - samplesPerFrame: %d", params.samplesPerFrame);

        // Create ggwave instance
        _ggwaveInstance = std::make_unique<GGWave>(params);

        // Verify the instance was created correctly
        int samplesPerFrame = _ggwaveInstance->samplesPerFrame();

        NSLog(@"[GGWave] ✅ Initialized for RX and TX");
        NSLog(@"[GGWave]   samplesPerFrame: %d", samplesPerFrame);
        NSLog(@"[GGWave]   Resampling enabled: device %d Hz -> internal 48kHz", sampleRate);
    }
    return self;
}

- (NSArray<NSNumber *> *)encodeText:(NSString *)text
                           protocol:(int)protocolId
                             volume:(float)volume
                              error:(NSError **)error {
    NSLog(@"[GGWave] encodeText called - text=%@, protocol=%d, volume=%.2f", text, protocolId, volume);

    if (!_ggwaveInstance) {
        NSLog(@"[GGWave] ERROR: ggwaveInstance is nil");
        if (error) {
            *error = [NSError errorWithDomain:@"GGWaveEngine"
                                        code:1
                                    userInfo:@{NSLocalizedDescriptionKey: @"GGWave not initialized"}];
        }
        return nil;
    }

    // Validate text parameter
    if (!text || text.length == 0) {
        NSLog(@"[GGWave] ERROR: Text is nil or empty");
        if (error) {
            *error = [NSError errorWithDomain:@"GGWaveEngine"
                                        code:4
                                    userInfo:@{NSLocalizedDescriptionKey: @"Text cannot be empty"}];
        }
        return nil;
    }

    NSLog(@"[GGWave] Text validation passed, length=%lu", (unsigned long)text.length);

    // Convert NSString to C++ string
    const char *cStr = [text UTF8String];
    NSLog(@"[GGWave] UTF8String conversion done, cStr=%p", cStr);

    if (!cStr) {
        NSLog(@"[GGWave] ERROR: UTF8String returned nil");
        if (error) {
            *error = [NSError errorWithDomain:@"GGWaveEngine"
                                        code:5
                                    userInfo:@{NSLocalizedDescriptionKey: @"Failed to convert text to UTF8"}];
        }
        return nil;
    }

    int textLen = (int)strlen(cStr);
    NSLog(@"[GGWave] Text length calculated: %d", textLen);
    NSLog(@"[GGWave] About to call GGWave::init with textLen=%d, cStr=%p, protocol=%d, volume=%d", textLen, cStr, protocolId, (int)volume);

    // Initialize transmission
    GGWave::TxProtocolId txProtocolId = static_cast<GGWave::TxProtocolId>(protocolId);
    bool initResult = _ggwaveInstance->init(textLen, cStr, txProtocolId, (int)volume);

    NSLog(@"[GGWave] GGWave::init returned: %d", initResult);

    if (!initResult) {
        if (error) {
            *error = [NSError errorWithDomain:@"GGWaveEngine"
                                        code:2
                                    userInfo:@{NSLocalizedDescriptionKey: @"Failed to initialize encoding"}];
        }
        return nil;
    }

    // Generate waveform
    uint32_t waveformSizeBytes = _ggwaveInstance->encode();

    if (waveformSizeBytes == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"GGWaveEngine"
                                        code:3
                                    userInfo:@{NSLocalizedDescriptionKey: @"Failed to generate waveform"}];
        }
        return nil;
    }

    // Get the waveform as float samples
    const float *waveformData = (const float *)_ggwaveInstance->txWaveform();
    int numSamples = waveformSizeBytes / sizeof(float);

    // Convert to NSArray
    NSMutableArray<NSNumber *> *samples = [NSMutableArray arrayWithCapacity:numSamples];
    for (int i = 0; i < numSamples; ++i) {
        [samples addObject:@(waveformData[i])];
    }

    NSLog(@"[GGWave] Encoded text: '%@' (protocol: %d, volume: %.2f) -> %d samples",
          text, protocolId, volume, numSamples);

    return samples;
}

- (nullable NSString *)decodeAudio:(const float *)samples length:(int)length {
    if (!_ggwaveInstance) {
        NSLog(@"[GGWave] decodeAudio: ggwaveInstance is nil");
        return nil;
    }

    // Decode using ggwave - provide samples and byte count
    uint32_t nBytes = length * sizeof(float);

    // Track decode calls
    static int callCount = 0;
    static bool wasReceiving = false;
    static bool wasAnalyzing = false;
    callCount++;

    // Step 1: Feed audio frame to ggwave decoder
    bool decodeResult = _ggwaveInstance->decode(samples, nBytes);

    if (!decodeResult) {
        // decode returns false only if Rx is disabled or currently transmitting (error condition)
        static int errorLogCount = 0;
        if (errorLogCount++ % 100 == 0) {
            NSLog(@"[GGWave] ⚠️ decode() returned false - Rx might be disabled or currently transmitting");
        }
        return nil;
    }

    // Track protocol marker detection
    bool isReceiving = _ggwaveInstance->rxReceiving();
    bool isAnalyzing = _ggwaveInstance->rxAnalyzing();

    // DIAGNOSTIC: Log state every 50 calls to see if we're EVER getting markers
    if (callCount % 50 == 0) {
        // Calculate RMS and find peak to verify we're getting real audio
        float rms = 0;
        float peak = 0;
        float minVal = 1.0f;
        float maxVal = -1.0f;
        for (int i = 0; i < length; i++) {
            float sample = samples[i];
            rms += sample * sample;
            float absSample = fabs(sample);
            if (absSample > peak) peak = absSample;
            if (sample < minVal) minVal = sample;
            if (sample > maxVal) maxVal = sample;
        }
        rms = sqrt(rms / length);

        NSLog(@"[GGWave] 🔍 DECODE STATUS #%d: decode=%s, rxReceiving=%s, rxAnalyzing=%s",
              callCount,
              decodeResult ? "OK" : "FAIL",
              isReceiving ? "YES" : "no",
              isAnalyzing ? "YES" : "no");
        NSLog(@"[GGWave]     samples=%d, rms=%.6f, peak=%.6f, range=[%.6f, %.6f]",
              length, rms, peak, minVal, maxVal);

        // Log first few samples to verify data integrity
        NSLog(@"[GGWave]     first 10 samples: %.6f, %.6f, %.6f, %.6f, %.6f, %.6f, %.6f, %.6f, %.6f, %.6f",
              samples[0], samples[1], samples[2], samples[3], samples[4],
              samples[5], samples[6], samples[7], samples[8], samples[9]);
    }

    // DETECT START MARKER (HEADER)
    if (isReceiving && !wasReceiving) {
        NSLog(@"[GGWave] ══════════════════════════════════════════");
        NSLog(@"[GGWave] 📡 START MARKER DETECTED - Receiving data...");
        NSLog(@"[GGWave] ══════════════════════════════════════════");
        printf("[GGWave] 📡 START MARKER DETECTED\n");  // Also print to stdout
        fflush(stdout);
        wasReceiving = true;
    }

    // DETECT END MARKER (FOOTER) - when analysis begins
    if (isAnalyzing && !wasAnalyzing) {
        NSLog(@"[GGWave] 🔍 END MARKER DETECTED - Analyzing data...");
        printf("[GGWave] 🔍 END MARKER DETECTED\n");
        fflush(stdout);
        wasAnalyzing = true;
    }

    // Step 2: Immediately check for complete message using rxTakeData()
    // This is the CORRECT pattern used in all ggwave examples
    uint8_t dataBuffer[256];  // kMaxDataSize from ggwave
    GGWave::TxRxData rxData(dataBuffer, 256);
    int dataLength = _ggwaveInstance->rxTakeData(rxData);

    if (dataLength > 0) {
        // SUCCESS - Complete message decoded!
        NSLog(@"[GGWave] ══════════════════════════════════════════");
        NSLog(@"[GGWave] ✅ DECODE SUCCESS: %d bytes received", dataLength);
        NSLog(@"[GGWave] ══════════════════════════════════════════");
        printf("[GGWave] ✅ DECODE SUCCESS\n");  // Also print to stdout
        fflush(stdout);

        // Reset state tracking
        wasReceiving = false;
        wasAnalyzing = false;

        // Convert to NSString (data is NOT null-terminated)
        std::string cppString(reinterpret_cast<const char*>(rxData.data()), dataLength);
        NSString *result = [NSString stringWithUTF8String:cppString.c_str()];

        if (result) {
            return result;
        } else {
            NSLog(@"[GGWave] ❌ ERROR: Failed to convert to NSString");
        }
    } else if (dataLength == -1) {
        // ERROR - Decode failed (corrupted data)
        NSLog(@"[GGWave] ❌ Decode FAILED - data corrupted or Reed-Solomon error");
        printf("[GGWave] ❌ DECODE FAILED\n");
        fflush(stdout);
        wasReceiving = false;
        wasAnalyzing = false;
    }
    // dataLength == 0: No data yet (still listening or receiving)

    // Log when receiving ends without producing data
    if (!isReceiving && wasReceiving && dataLength == 0) {
        NSLog(@"[GGWave] ⚠️ Receiving ended but no data produced");
        wasReceiving = false;
        wasAnalyzing = false;
    }

    // No data decoded yet (normal - still accumulating audio)
    return nil;
}

- (BOOL)isRxReceiving {
    if (!_ggwaveInstance) {
        return NO;
    }
    return _ggwaveInstance->rxReceiving();
}

- (BOOL)isRxAnalyzing {
    if (!_ggwaveInstance) {
        return NO;
    }
    return _ggwaveInstance->rxAnalyzing();
}

- (NSArray<NSNumber *> *)availableProtocols {
    // Return all standard protocols
    return @[
        @(GGWAVE_PROTOCOL_AUDIBLE_NORMAL),
        @(GGWAVE_PROTOCOL_AUDIBLE_FAST),
        @(GGWAVE_PROTOCOL_AUDIBLE_FASTEST),
        @(GGWAVE_PROTOCOL_ULTRASOUND_NORMAL),
        @(GGWAVE_PROTOCOL_ULTRASOUND_FAST),
        @(GGWAVE_PROTOCOL_ULTRASOUND_FASTEST)
    ];
}

- (void)dealloc {
    NSLog(@"[GGWave] Engine deallocated");
}

@end
