#if QURAN_ASR_NATIVE && DEBUG
#import <XCTest/XCTest.h>
#import <AVFoundation/AVFoundation.h>
#import "../Runner/QuranASRBridge.h"

@interface QuranASRTests : XCTestCase
@end

@implementation QuranASRTests
- (void)testCancelledInferenceDoesNotProduceAReport {
  NSString *model = [NSBundle.mainBundle pathForResource:@"quran-tiny" ofType:@"bin"];
  NSString *audio = [NSBundle.mainBundle pathForResource:@"quran-asr-reference" ofType:@"wav"];
  XCTAssertNotNil(model);
  XCTAssertNotNil(audio);
  if (!model || !audio) return;

  QuranASRCancellation *cancelled = [[QuranASRCancellation alloc] init];
  [cancelled cancel];
  NSError *error = nil;
  XCTAssertNil(QuranASRTranscribeCancellable(model, audio, cancelled, &error));
  XCTAssertEqualObjects(error.domain, @"QuranASR");
  XCTAssertEqual(error.code, 5);

  QuranASRCancellation *pending = [[QuranASRCancellation alloc] init];
  XCTestExpectation *finished = [self expectationWithDescription:@"Inference observes cancellation"];
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    NSError *inferenceError = nil;
    NSDictionary *report = QuranASRTranscribeCancellable(model, audio, pending, &inferenceError);
    XCTAssertNil(report);
    XCTAssertEqualObjects(inferenceError.domain, @"QuranASR");
    XCTAssertEqual(inferenceError.code, 5);
    [finished fulfill];
  });
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 50 * NSEC_PER_MSEC),
                 dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    [pending cancel];
  });
  [self waitForExpectations:@[finished] timeout:30];
}

- (void)testBundledQuranReference {
  NSString *model = [NSBundle.mainBundle pathForResource:@"quran-tiny" ofType:@"bin"];
  NSString *audio = [NSBundle.mainBundle pathForResource:@"quran-asr-reference" ofType:@"wav"];
  XCTAssertNotNil(model);
  XCTAssertNotNil(audio, @"Supply QURAN_ASR_REFERENCE_WAV when building this opt-in test.");
  if (!model || !audio) return;
  NSError *error = nil;
  NSDictionary *report = QuranASRTranscribe(model, audio, &error);
  XCTAssertNil(error);
  XCTAssertNotNil(report);
  NSString *text = report[@"transcript"];
  NSRegularExpression *marks = [NSRegularExpression regularExpressionWithPattern:@"[\\u064B-\\u065F\\u0670]" options:0 error:nil];
  NSString *plain = [marks stringByReplacingMatchesInString:text ?: @"" options:0
                                                    range:NSMakeRange(0, text.length) withTemplate:@""];
  XCTAssertEqualObjects(plain, @"بسم الله الرحمن الرحيم");
  XCTAssertGreaterThan([report[@"durationSeconds"] doubleValue], 0);
  XCTAssertLessThanOrEqual([report[@"durationSeconds"] doubleValue], 30);
  XCTAssertGreaterThan([report[@"inferenceSeconds"] doubleValue], 0);
}

- (void)testSilentAndInvalidAudio {
  for (NSNumber *rate in @[@16000, @8000]) {
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory()
        stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingString:@".wav"]]];
    AVAudioFormat *format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:rate.doubleValue channels:1];
    NSError *error = nil;
    AVAudioFile *file = [[AVAudioFile alloc] initForWriting:url settings:@{
      AVFormatIDKey: @(kAudioFormatLinearPCM),
      AVSampleRateKey: rate,
      AVNumberOfChannelsKey: @1,
      AVLinearPCMBitDepthKey: @16,
      AVLinearPCMIsFloatKey: @NO,
      AVLinearPCMIsBigEndianKey: @NO
    } error:&error];
    XCTAssertNil(error);
    AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:1600];
    buffer.frameLength = 1600;
    memset(buffer.floatChannelData[0], 0, 1600 * sizeof(float));
    XCTAssertTrue([file writeFromBuffer:buffer error:&error]);
    file = nil;
    NSDictionary *report = QuranASRTranscribe(@"unused-model", url.path, &error);
    XCTAssertNil(report);
    XCTAssertNotNil(error);
    if (rate.intValue == 16000) {
      XCTAssertTrue([error.localizedDescription containsString:@"No audible input"]);
    } else {
      XCTAssertTrue([error.localizedDescription containsString:@"PCM16 16 kHz"]);
    }
    XCTAssertTrue([NSFileManager.defaultManager removeItemAtURL:url error:nil]);
  }
}
@end
#endif
