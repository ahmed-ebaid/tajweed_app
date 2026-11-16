#import <Foundation/Foundation.h>

#if QURAN_ASR_NATIVE && (DEBUG || QURAN_ASR_PROFILE || QURAN_ASR_TESTFLIGHT)
NS_ASSUME_NONNULL_BEGIN
@interface QuranASRCancellation : NSObject
- (void)cancel;
- (BOOL)isCancelled;
@end

#ifdef __cplusplus
extern "C" {
#endif
NSDictionary * _Nullable QuranASRTranscribe(NSString *modelPath, NSString *audioPath, NSError **error);
NSDictionary * _Nullable QuranASRTranscribeCancellable(
    NSString *modelPath, NSString *audioPath, QuranASRCancellation * _Nullable cancellation,
    NSError **error);
#ifdef __cplusplus
}
#endif
NS_ASSUME_NONNULL_END
#endif
