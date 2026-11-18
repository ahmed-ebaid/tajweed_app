#import "../../ios/Runner/QuranASRBridge.h"
#include "whisper.h"
#include <cstdio>
#include <cstring>
#include <vector>

struct whisper_context {};
static std::vector<std::vector<const char *>> gAttempts;
static std::vector<int> gStatuses;
static int gCalls = 0;
static int gCancelOnCall = 0;
static bool gParametersValid = true;
static QuranASRCancellation *gCancellation = nil;

struct whisper_context_params whisper_context_default_params(void) {
  return {};
}

struct whisper_full_params whisper_full_default_params(enum whisper_sampling_strategy strategy) {
  struct whisper_full_params params = {};
  params.strategy = strategy;
  return params;
}

struct whisper_context *whisper_init_from_file_with_params(
    const char *, struct whisper_context_params) {
  static whisper_context context;
  return &context;
}

void whisper_free(struct whisper_context *) {}

int whisper_full(struct whisper_context *, struct whisper_full_params params,
                 const float *, int) {
  gCalls++;
  gParametersValid = gParametersValid &&
      params.strategy == (gCalls == 1 ? WHISPER_SAMPLING_GREEDY : WHISPER_SAMPLING_BEAM_SEARCH) &&
      params.beam_search.beam_size == (gCalls == 1 ? 1 : 3) &&
      params.greedy.best_of == 1 && params.temperature_inc == 0 &&
      params.no_context && params.n_threads == 4 &&
      params.language && std::strcmp(params.language, "ar") == 0;
  if (gCancellation) {
    gParametersValid = gParametersValid && params.abort_callback &&
        params.abort_callback_user_data == (__bridge void *)gCancellation;
  }
  if (gCalls > (int)gAttempts.size() || gCalls > (int)gStatuses.size()) {
    gParametersValid = false;
    return -1;
  }
  if (gCalls == gCancelOnCall) [gCancellation cancel];
  return gStatuses[gCalls - 1];
}

int whisper_full_n_segments(struct whisper_context *) {
  return (int)gAttempts[gCalls - 1].size();
}

const char *whisper_full_get_segment_text(struct whisper_context *, int index) {
  return gAttempts[gCalls - 1][index];
}

#import <AVFoundation/AVFoundation.h>

static bool WriteAudio(NSURL *url) {
  NSError *error = nil;
  AVAudioFile *file = [[AVAudioFile alloc] initForWriting:url
      settings:@{
        AVFormatIDKey: @(kAudioFormatLinearPCM),
        AVSampleRateKey: @16000,
        AVNumberOfChannelsKey: @1,
        AVLinearPCMBitDepthKey: @16,
        AVLinearPCMIsFloatKey: @NO,
        AVLinearPCMIsBigEndianKey: @NO,
      }
      error:&error];
  if (!file) return false;
  AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc]
      initWithPCMFormat:file.processingFormat frameCapacity:1600];
  buffer.frameLength = 1600;
  if (!buffer.floatChannelData) return false;
  for (int i = 0; i < 1600; i++) buffer.floatChannelData[0][i] = 0.1f;
  return [file writeFromBuffer:buffer error:&error];
}

static void Configure(std::vector<std::vector<const char *>> attempts,
                      std::vector<int> statuses = {0, 0}, int cancelOnCall = 0) {
  gAttempts = attempts;
  gStatuses = statuses;
  gCalls = 0;
  gCancelOnCall = cancelOnCall;
  gParametersValid = true;
  gCancellation = cancelOnCall ? [QuranASRCancellation new] : nil;
}

static bool CheckSuccess(NSString *audioPath, NSString *transcript, int calls) {
  NSError *error = nil;
  NSDictionary *result = QuranASRTranscribeCancellable(
      @"stub-model", audioPath, gCancellation, &error);
  return result && !error && [result[@"transcript"] isEqualToString:transcript] &&
      [result[@"invalidTextRetries"] intValue] == calls - 1 &&
      gCalls == calls && gParametersValid;
}

static bool CheckFailure(NSString *audioPath, NSString *message, int calls,
                         NSInteger code = 1) {
  NSError *error = nil;
  NSDictionary *result = QuranASRTranscribeCancellable(
      @"stub-model", audioPath, gCancellation, &error);
  return !result && [error.domain isEqualToString:@"QuranASR"] &&
      error.code == code && [error.localizedDescription containsString:message] &&
      gCalls == calls && gParametersValid;
}

static bool CheckSegments(NSString *audioPath) {
  const char *valid = "\xD8\xA7\xD9\x84\xD9\x84\xD9\x87";
  // A real corpus preview emitted an unpaired 0xb8 byte after Arabic text.
  const char *invalid = "\xD8\xAA\xD9\x8E\xB8";
  Configure({{valid}});
  if (!CheckSuccess(audioPath, @"الله", 1)) return false;
  Configure({{invalid}, {valid}});
  if (!CheckSuccess(audioPath, @"الله", 2)) return false;
  Configure({{valid, invalid}, {valid}});
  if (!CheckSuccess(audioPath, @"الله", 2)) return false;
  Configure({{nullptr}, {valid}});
  if (!CheckSuccess(audioPath, @"الله", 2)) return false;
  Configure({{invalid}, {invalid}});
  if (!CheckFailure(audioPath, @"invalid text", 2)) return false;
  Configure({{nullptr}, {nullptr}});
  if (!CheckFailure(audioPath, @"invalid text", 2)) return false;
  Configure({{valid}}, {-1});
  if (!CheckFailure(audioPath, @"recognition failed", 1)) return false;
  Configure({{invalid}, {valid}}, {0, -1});
  if (!CheckFailure(audioPath, @"recognition failed", 2)) return false;
  Configure({{invalid}}, {0}, 1);
  if (!CheckFailure(audioPath, @"cancelled", 1, 5)) return false;
  Configure({{invalid}, {valid}}, {0, 0}, 2);
  if (!CheckFailure(audioPath, @"cancelled", 2, 5)) return false;
  Configure({{""}});
  if (!CheckFailure(audioPath, @"No words recognized", 1)) return false;
  return true;
}

int main() {
  @autoreleasepool {
    NSString *name = [NSString stringWithFormat:@"quran-asr-utf8-%@.wav", NSUUID.UUID.UUIDString];
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
    const bool success = WriteAudio(url) && CheckSegments(url.path);
    NSError *cleanupError = nil;
    if (![[NSFileManager defaultManager] removeItemAtURL:url error:&cleanupError]) {
      fprintf(stderr, "Could not remove native audio fixture: %s\n",
              cleanupError.localizedDescription.UTF8String);
      return 1;
    }
    if (!success) {
      fprintf(stderr, "Native ASR UTF-8 regression failed\n");
      return 1;
    }
    puts("Native ASR UTF-8 retry: 11 cases passed, including failure and cancellation.");
  }
  return 0;
}
