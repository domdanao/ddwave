#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GGWaveEngine : NSObject

- (instancetype)initWithSampleRate:(int)sampleRate;
- (nullable NSArray<NSNumber *> *)encodeText:(NSString *)text
                                     protocol:(int)protocolId
                                       volume:(float)volume
                                        error:(NSError * _Nullable * _Nullable)error;
- (nullable NSString *)decodeAudio:(const float *)samples
                            length:(int)length;
- (NSArray<NSNumber *> *)availableProtocols;

@end

NS_ASSUME_NONNULL_END
