#import "QuranASRBridge.h"

#if QURAN_ASR_NATIVE && (DEBUG || QURAN_ASR_PROFILE || QURAN_ASR_TESTFLIGHT)
#import <AVFoundation/AVFoundation.h>
#import <Metal/Metal.h>
#import <TargetConditionals.h>
#include "whisper.h"
#include <algorithm>
#include <atomic>
#include <cmath>
#include <mutex>
#include <string>
#include <vector>

namespace {
std::mutex gWhisperMutex;
whisper_context *gWhisperContext = nullptr;
std::string gWhisperModelPath;
bool gWhisperUseGpu = false;
bool gWhisperForceCpu = false;

bool SupportsFastMetalWhisper() {
#if QURAN_ASR_USE_METAL && !TARGET_OS_SIMULATOR
  id<MTLDevice> device = MTLCreateSystemDefaultDevice();
  if (!device) return false;
  if (@available(iOS 14.0, *)) {
    // ggml-metal requires MTLGPUFamilyApple7 (A14/M1+) for simdgroup reduction
    // and matrix multiplication; older GPUs ping-pong ops between CPU and GPU.
    return [device supportsFamily:MTLGPUFamilyApple7];
  }
#endif
  return false;
}

whisper_context * SharedWhisperContext(NSString *modelPath,
                                       whisper_context_params options) {
  const std::string path = modelPath ? modelPath.UTF8String : "";
  if (path.empty()) return nullptr;
  if (gWhisperContext && gWhisperModelPath == path &&
      gWhisperUseGpu == options.use_gpu) {
    return gWhisperContext;
  }
  if (gWhisperContext) {
    whisper_free(gWhisperContext);
    gWhisperContext = nullptr;
    gWhisperModelPath.clear();
  }
  gWhisperContext = whisper_init_from_file_with_params(path.c_str(), options);
  if (gWhisperContext) {
    gWhisperModelPath = path;
    gWhisperUseGpu = options.use_gpu;
  }
  return gWhisperContext;
}
}  // namespace

@implementation QuranASRCancellation {
  std::atomic<bool> _cancelled;
}

- (instancetype)init {
  if ((self = [super init])) _cancelled.store(false);
  return self;
}

- (void)cancel { _cancelled.store(true); }
- (BOOL)isCancelled { return _cancelled.load(); }
@end

NSDictionary *QuranASRTranscribe(NSString *modelPath, NSString *audioPath, NSError **error) {
  return QuranASRTranscribeCancellable(modelPath, audioPath, nil, error);
}

NSDictionary *QuranASRTranscribeCancellable(NSString *modelPath, NSString *audioPath,
                                          QuranASRCancellation *cancellation, NSError **error) {
  auto fail = [&](NSString *message, NSInteger code = 1) -> NSDictionary * {
    if (error) *error = [NSError errorWithDomain:@"QuranASR" code:code
                                      userInfo:@{NSLocalizedDescriptionKey: message}];
    return nil;
  };
  if (cancellation.isCancelled) return fail(@"Recognition was cancelled.", 5);
  AVAudioFile *file = [[AVAudioFile alloc] initForReading:[NSURL fileURLWithPath:audioPath]
                                                  error:error];
  if (!file) return nil;
  auto format = file.processingFormat;
  const AudioStreamBasicDescription *source = file.fileFormat.streamDescription;
  if (source->mFormatID != kAudioFormatLinearPCM || source->mBitsPerChannel != 16 ||
      format.channelCount != 1 || format.sampleRate != 16000 ||
      file.length <= 0 || file.length > 480000) {
    return fail(@"Supply mono PCM16 16 kHz audio of at most 30 seconds.");
  }
  AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:format
                                                       frameCapacity:(AVAudioFrameCount)file.length];
  if (![file readIntoBuffer:buffer error:error]) return nil;
  if (!buffer.floatChannelData || buffer.frameLength == 0 ||
      buffer.frameLength != file.length) {
    return fail(@"Could not decode audio samples.");
  }
  const float *samples = buffer.floatChannelData[0];
  double energy = 0;
  for (uint32_t i = 0; i < buffer.frameLength; i++) {
    if (!std::isfinite(samples[i])) return fail(@"Invalid audio samples.");
    energy += samples[i] * samples[i];
  }
  const double rms = std::sqrt(energy / buffer.frameLength);
  if (rms < 0.0001) {
    if (error) *error = [NSError errorWithDomain:@"QuranASR" code:4
                                      userInfo:@{NSLocalizedDescriptionKey: @"No audible input. Please record again."}];
    return nil;
  }
  auto options = whisper_context_default_params();
  std::lock_guard<std::mutex> lock(gWhisperMutex);
  options.use_gpu = !gWhisperForceCpu && SupportsFastMetalWhisper();
  if (cancellation.isCancelled) return fail(@"Recognition was cancelled.", 5);
  whisper_context *ctx = SharedWhisperContext(modelPath, options);
  if (!ctx && options.use_gpu) {
    gWhisperForceCpu = true;
    options.use_gpu = false;
    ctx = SharedWhisperContext(modelPath, options);
  }
  if (!ctx) return fail(@"Could not load the experimental Quran model.");
  auto params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
  params.greedy.best_of = 1;
  params.beam_search.beam_size = 1;
  params.temperature_inc = 0.0f;
  params.language = "ar";
  params.translate = false;
  params.no_context = true;
  params.no_timestamps = true;
  params.single_segment = true;
  const double durationSec = (double)buffer.frameLength / 16000.0;
  const int durationTokens = (int)std::ceil(durationSec * 14.0) + 12;
  params.max_tokens = std::max(36, std::min(192, durationTokens));
  params.print_progress = false;
  params.print_realtime = false;
  params.print_timestamps = false;
  params.print_special = false;
  params.n_threads = 4;
  if (cancellation) {
    params.abort_callback = [](void *userData) -> bool {
      return [(__bridge QuranASRCancellation *)userData isCancelled];
    };
    params.abort_callback_user_data = (__bridge void *)cancellation;
  }
  const auto started = [NSDate timeIntervalSinceReferenceDate];
  int status = 0;
  NSUInteger invalidTextRetries = 0;
  NSMutableString *text = [NSMutableString string];
  for (int attempt = 0; attempt < 2; attempt++) {
    if (cancellation.isCancelled) return fail(@"Recognition was cancelled.", 5);
    status = whisper_full(ctx, params, samples, (int)buffer.frameLength);
    if (cancellation.isCancelled) return fail(@"Recognition was cancelled.", 5);
    if (status != 0) break;
    [text setString:@""];
    bool validText = true;
    for (int i = 0; i < whisper_full_n_segments(ctx); i++) {
      const char *segment = whisper_full_get_segment_text(ctx, i);
      NSString *decoded = segment ? [NSString stringWithUTF8String:segment] : nil;
      if (!decoded && segment) {
        size_t len = strlen(segment);
        for (size_t trim = 1; trim <= 3 && trim < len && !decoded; trim++) {
          std::string prefix(segment, len - trim);
          decoded = [NSString stringWithUTF8String:prefix.c_str()];
        }
      }
      if (!decoded) {
        validText = false;
        break;
      }
      [text appendString:decoded];
    }
    if (validText) break;
    if (attempt != 0) {
      return fail(@"Experimental recognition returned invalid text. Please record again.");
    }
    NSLog(@"QuranASR: invalid native text; retrying once with beam size 3.");
    params.strategy = WHISPER_SAMPLING_BEAM_SEARCH;
    params.beam_search.beam_size = 3;
    invalidTextRetries++;
  }
  if (status != 0) {
    whisper_free(gWhisperContext);
    gWhisperContext = nullptr;
    gWhisperModelPath.clear();
    return fail(@"Experimental recognition failed.");
  }
  const double inferenceSeconds = [NSDate timeIntervalSinceReferenceDate] - started;
  if (gWhisperUseGpu && durationSec <= 3.5 && inferenceSeconds > 1.5) {
    NSLog(@"QuranASR: Metal GPU inference took %.2fs for %.2fs audio; switching to CPU.",
          inferenceSeconds, durationSec);
    gWhisperForceCpu = true;
  }
  NSString *transcript = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (transcript.length == 0) return fail(@"No words recognized. Please record again.");
  return @{
    @"transcript": transcript,
    @"durationSeconds": @(buffer.frameLength / 16000.0),
    @"inferenceSeconds": @(inferenceSeconds),
    @"invalidTextRetries": @(invalidTextRetries)
  };
}
#endif
