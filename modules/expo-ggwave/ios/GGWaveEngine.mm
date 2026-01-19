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
        params.sampleRateInp = sampleRate;
        params.sampleRateOut = sampleRate;
        params.sampleRate = sampleRate;
        params.sampleFormatInp = GGWAVE_SAMPLE_FORMAT_F32;  // Input audio is Float32
        params.sampleFormatOut = GGWAVE_SAMPLE_FORMAT_F32;  // Output audio is Float32
        params.operatingMode = GGWAVE_OPERATING_MODE_RX_AND_TX;

        NSLog(@"[GGWave] Creating ggwave instance with:");
        NSLog(@"[GGWave]   - sampleRate: %d Hz", sampleRate);
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
        NSLog(@"[GGWave]   Note: rxReceiving starts at 0 and becomes 1 when actively decoding");
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

    // Log audio statistics every 50 calls for debugging
    static int callCount = 0;
    static bool wasReceiving = false;
    static bool wasAnalyzing = false;
    callCount++;

    if (callCount % 50 == 0) {
        // Calculate RMS to see if we're getting valid audio
        float rms = 0;
        float peak = 0;
        for (int i = 0; i < length; i++) {
            float sample = samples[i];
            rms += sample * sample;
            if (fabs(sample) > peak) peak = fabs(sample);
        }
        rms = sqrt(rms / length);

        // Check ggwave's receiving state
        bool isReceiving = _ggwaveInstance->rxReceiving();
        int samplesPerFrame = _ggwaveInstance->samplesPerFrame();

        NSLog(@"[GGWave] decode #%d - samples:%d bytes:%u RMS:%.6f Peak:%.6f isRx:%d SPF:%d",
              callCount, length, nBytes, rms, peak, isReceiving, samplesPerFrame);
    }

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

    // DETECT START MARKER (HEADER)
    if (isReceiving && !wasReceiving) {
        NSLog(@"[GGWave] ====== START MARKER (HEADER) DETECTED ======");
        wasReceiving = true;
    }

    // DETECT END MARKER (FOOTER) - when analysis begins
    if (isAnalyzing && !wasAnalyzing) {
        NSLog(@"[GGWave] ====== END MARKER (FOOTER) DETECTED - Analysis starting ======");
        wasAnalyzing = true;
    }

    // Step 2: Immediately check for complete message using rxTakeData()
    // This is the CORRECT pattern used in all ggwave examples
    uint8_t dataBuffer[256];  // kMaxDataSize from ggwave
    GGWave::TxRxData rxData(dataBuffer, 256);
    int dataLength = _ggwaveInstance->rxTakeData(rxData);

    // Log ggwave's internal state on EVERY call when receiving (no emoji, no filtering)
    if (isReceiving || wasReceiving) {
        int rxDataLen = _ggwaveInstance->rxDataLength();
        NSLog(@"[GGWave] RX_STATE isRx=%d wasRx=%d analyzing=%d wasAnalyzing=%d rxDataLen=%d takeDataResult=%d",
              isReceiving, wasReceiving, isAnalyzing, wasAnalyzing, rxDataLen, dataLength);
    }

    if (dataLength > 0) {
        // SUCCESS - Complete message decoded!
        NSLog(@"[GGWave] ====== DECODE COMPLETE: %d bytes received ======", dataLength);

        // Reset state tracking
        wasReceiving = false;
        wasAnalyzing = false;

        // Convert to NSString (data is NOT null-terminated)
        std::string cppString(reinterpret_cast<const char*>(rxData.data()), dataLength);
        NSLog(@"[GGWave] SUCCESS: C++ string: '%s' (%zu bytes)", cppString.c_str(), cppString.length());

        NSString *result = [NSString stringWithUTF8String:cppString.c_str()];

        if (result) {
            NSLog(@"[GGWave] SUCCESS: Successfully decoded: '%@' (%lu chars)",
                  result, (unsigned long)[result length]);
            return result;
        } else {
            NSLog(@"[GGWave] ERROR: Failed to convert to NSString - string may contain non-UTF8 data");
            NSLog(@"[GGWave] ERROR: Raw C++ string was: '%s'", cppString.c_str());
        }
    } else if (dataLength == -1) {
        // ERROR - Decode failed (corrupted data)
        NSLog(@"[GGWave] ERROR: Decode FAILED - data corrupted or Reed-Solomon error");
        wasReceiving = false;
        wasAnalyzing = false;
    }
    // dataLength == 0: No data yet (still listening or receiving)

    // Log when receiving ends without producing data (shouldn't happen normally)
    if (!isReceiving && wasReceiving && dataLength == 0) {
        NSLog(@"[GGWave] WARNING: Receiving ended but no data produced (dataLength=0)");
        wasReceiving = false;
        wasAnalyzing = false;
    }

    // No data decoded yet (normal - still accumulating audio)
    return nil;
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
