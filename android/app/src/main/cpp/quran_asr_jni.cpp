#include <jni.h>
#include <android/log.h>
#include <unistd.h>

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <mutex>
#include <string>
#include <vector>

#include "whisper.h"

namespace {

constexpr const char *kLogTag = "QuranASR";

std::atomic<int64_t> g_active_cancel_token{0};
std::atomic<bool> g_cancel_requested{false};

uint16_t ReadLe16(const uint8_t *bytes) {
  return static_cast<uint16_t>(bytes[0]) |
         (static_cast<uint16_t>(bytes[1]) << 8);
}

uint32_t ReadLe32(const uint8_t *bytes) {
  return static_cast<uint32_t>(bytes[0]) |
         (static_cast<uint32_t>(bytes[1]) << 8) |
         (static_cast<uint32_t>(bytes[2]) << 16) |
         (static_cast<uint32_t>(bytes[3]) << 24);
}

bool ReadMono16kWav(const std::string &path, std::vector<float> *samples) {
  std::ifstream input(path, std::ios::binary | std::ios::ate);
  if (!input) {
    return false;
  }
  const std::streamsize size = input.tellg();
  if (size < 44 || size > 48 * 1024 * 1024) {
    return false;
  }
  std::vector<uint8_t> data(static_cast<size_t>(size));
  input.seekg(0, std::ios::beg);
  if (!input.read(reinterpret_cast<char *>(data.data()), size)) {
    return false;
  }
  if (std::memcmp(data.data(), "RIFF", 4) != 0 ||
      std::memcmp(data.data() + 8, "WAVE", 4) != 0) {
    return false;
  }

  uint16_t format = 0;
  uint16_t channels = 0;
  uint32_t sample_rate = 0;
  uint16_t bits_per_sample = 0;
  const uint8_t *pcm = nullptr;
  uint32_t pcm_size = 0;

  size_t offset = 12;
  while (offset + 8 <= data.size()) {
    const uint8_t *chunk = data.data() + offset;
    const uint32_t chunk_size = ReadLe32(chunk + 4);
    offset += 8;
    if (offset + chunk_size > data.size()) {
      return false;
    }
    if (std::memcmp(chunk, "fmt ", 4) == 0 && chunk_size >= 16) {
      format = ReadLe16(data.data() + offset);
      channels = ReadLe16(data.data() + offset + 2);
      sample_rate = ReadLe32(data.data() + offset + 4);
      bits_per_sample = ReadLe16(data.data() + offset + 14);
    } else if (std::memcmp(chunk, "data", 4) == 0) {
      pcm = data.data() + offset;
      pcm_size = chunk_size;
      break;
    }
    offset += chunk_size + (chunk_size % 2);
  }

  if (format != 1 || channels != 1 || sample_rate != 16000 ||
      bits_per_sample != 16 || pcm == nullptr || pcm_size < 3200) {
    return false;
  }

  const size_t count = pcm_size / sizeof(int16_t);
  samples->resize(count);
  for (size_t i = 0; i < count; ++i) {
    const int16_t sample = static_cast<int16_t>(ReadLe16(pcm + i * 2));
    (*samples)[i] = static_cast<float>(sample) / 32768.0f;
  }
  return true;
}

struct SharedWhisperContext {
  std::mutex mutex;
  std::string model_path;
  whisper_context *ctx = nullptr;
  bool using_gpu = false;
  bool force_cpu_sticky = false;

  whisper_context *get(const std::string &path, bool force_cpu = false) {
    if (force_cpu) {
      force_cpu_sticky = true;
    }
    const bool use_cpu = force_cpu || force_cpu_sticky;
    if (ctx != nullptr && model_path == path && (!use_cpu || !using_gpu)) {
      return ctx;
    }
    if (ctx != nullptr) {
      whisper_free(ctx);
      ctx = nullptr;
      model_path.clear();
      using_gpu = false;
    }
    whisper_context *loaded = nullptr;
    if (!use_cpu) {
      try {
        whisper_context_params options = whisper_context_default_params();
        options.use_gpu = true;
        loaded = whisper_init_from_file_with_params(path.c_str(), options);
        if (loaded != nullptr) {
          using_gpu = true;
          __android_log_print(
              ANDROID_LOG_INFO, kLogTag,
              "Initialized whisper.cpp context with GPU acceleration.");
        }
      } catch (const std::exception &e) {
        __android_log_print(ANDROID_LOG_WARN, kLogTag,
                            "Vulkan GPU init exception (%s); falling back to CPU.",
                            e.what());
        loaded = nullptr;
      } catch (...) {
        __android_log_print(ANDROID_LOG_WARN, kLogTag,
                            "Vulkan GPU init unknown exception; falling back to CPU.");
        loaded = nullptr;
      }
    }
    if (loaded == nullptr) {
      try {
        whisper_context_params options = whisper_context_default_params();
        options.use_gpu = false;
        loaded = whisper_init_from_file_with_params(path.c_str(), options);
        using_gpu = false;
        if (loaded != nullptr) {
          __android_log_print(
              ANDROID_LOG_WARN, kLogTag,
              "Using ARMv8.2 FP16/dotprod CPU backend for whisper.cpp.");
        }
      } catch (...) {
        loaded = nullptr;
      }
    }
    if (loaded != nullptr) {
      ctx = loaded;
      model_path = path;
    }
    return ctx;
  }
};

SharedWhisperContext &SharedContext() {
  static auto *shared = new SharedWhisperContext();
  return *shared;
}

struct AbortCallbackState {
  int64_t token;
};

bool WhisperAbortCallback(void *data) {
  if (data == nullptr) {
    return false;
  }
  const auto *state = static_cast<AbortCallbackState *>(data);
  return state->token != 0 &&
         g_active_cancel_token.load(std::memory_order_relaxed) == state->token &&
         g_cancel_requested.load(std::memory_order_relaxed);
}

}  // namespace

extern "C" JNIEXPORT void JNICALL
Java_com_ebaidllc_tajweed_1practice_QuranASRChannel_nativeCancelToken(
    JNIEnv * /*env*/, jobject /*thiz*/, jlong token) {
  if (token != 0 &&
      g_active_cancel_token.load(std::memory_order_relaxed) == token) {
    g_cancel_requested.store(true, std::memory_order_relaxed);
  }
}

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_ebaidllc_tajweed_1practice_QuranASRChannel_nativeTranscribe(
    JNIEnv *env, jobject /*thiz*/, jstring modelPathJ, jstring wavPathJ,
    jboolean provisionalJ, jlong cancelTokenJ, jdoubleArray metricsOutJ) {
  const auto fill_metrics = [&](double status, double duration_sec,
                                double inference_sec, double gpu) {
    if (metricsOutJ != nullptr && env->GetArrayLength(metricsOutJ) >= 4) {
      jdouble values[4] = {status, duration_sec, inference_sec, gpu};
      env->SetDoubleArrayRegion(metricsOutJ, 0, 4, values);
    }
  };

  if (modelPathJ == nullptr || wavPathJ == nullptr) {
    fill_metrics(1.0, 0.0, 0.0, 0.0);
    return nullptr;
  }

  const char *model_chars = env->GetStringUTFChars(modelPathJ, nullptr);
  const char *wav_chars = env->GetStringUTFChars(wavPathJ, nullptr);
  const std::string model_path(model_chars ? model_chars : "");
  const std::string wav_path(wav_chars ? wav_chars : "");
  if (model_chars) env->ReleaseStringUTFChars(modelPathJ, model_chars);
  if (wav_chars) env->ReleaseStringUTFChars(wavPathJ, wav_chars);

  const bool provisional = provisionalJ == JNI_TRUE;
  const int64_t token = static_cast<int64_t>(cancelTokenJ);
  if (token != 0) {
    g_active_cancel_token.store(token, std::memory_order_relaxed);
    g_cancel_requested.store(false, std::memory_order_relaxed);
  }

  std::vector<float> raw_samples;
  if (!ReadMono16kWav(wav_path, &raw_samples)) {
    fill_metrics(2.0, 0.0, 0.0, 0.0);
    return nullptr;
  }
  const double duration_seconds =
      static_cast<double>(raw_samples.size()) / 16000.0;

  double energy = 0.0;
  float peak = 0.0f;
  size_t voiced = 0;
  for (size_t i = 0; i < raw_samples.size(); ++i) {
    const float s = raw_samples[i];
    if (!std::isfinite(s)) {
      fill_metrics(2.0, duration_seconds, 0.0, 0.0);
      return nullptr;
    }
    energy += static_cast<double>(s) * static_cast<double>(s);
    const float level = std::fabs(s);
    peak = std::max(peak, level);
    if (level >= 0.008f) {
      voiced += 1;
    }
  }
  const double rms = std::sqrt(energy / static_cast<double>(raw_samples.size()));
  const bool has_speech =
      rms >= 0.0005 && peak >= 0.012f && voiced >= 800;
  if (!has_speech) {
    fill_metrics(4.0, duration_seconds, 0.0, 0.0);
    return nullptr;
  }
  std::vector<float> samples = std::move(raw_samples);
  if (token != 0 && g_cancel_requested.load(std::memory_order_relaxed)) {
    fill_metrics(5.0, duration_seconds, 0.0, 0.0);
    return nullptr;
  }

  SharedWhisperContext &shared = SharedContext();
  std::lock_guard<std::mutex> lock(shared.mutex);
  if (token != 0 && g_cancel_requested.load(std::memory_order_relaxed)) {
    fill_metrics(5.0, duration_seconds, 0.0, 0.0);
    return nullptr;
  }

  whisper_context *ctx = shared.get(model_path);
  if (ctx == nullptr) {
    fill_metrics(1.0, duration_seconds, 0.0, 0.0);
    return nullptr;
  }

  whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
  const long cores = sysconf(_SC_NPROCESSORS_ONLN);
  const int processor_count = cores > 1 ? static_cast<int>(cores) - 1 : 2;
  params.n_threads = std::max(2, std::min(4, processor_count));
  params.language = "ar";
  params.translate = false;
  params.no_context = true;
  params.no_timestamps = true;
  params.single_segment = true;
  params.print_special = false;
  params.print_progress = false;
  params.print_realtime = false;
  params.print_timestamps = false;
  const int duration_tokens =
      static_cast<int>(std::ceil(duration_seconds * 14.0)) + 12;
  params.max_tokens = std::max(36, std::min(192, duration_tokens));
  params.greedy.best_of = 1;
  params.beam_search.beam_size = 1;
  params.temperature = 0.0f;
  params.temperature_inc = 0.0f;

  AbortCallbackState abort_state{token};
  if (token != 0) {
    params.abort_callback = WhisperAbortCallback;
    params.abort_callback_user_data = &abort_state;
  }

  auto started = std::chrono::steady_clock::now();
  int status = -1;
  try {
    status = whisper_full(
        ctx, params, samples.data(), static_cast<int>(samples.size()));
  } catch (const std::exception &e) {
    __android_log_print(ANDROID_LOG_WARN, kLogTag,
                        "whisper_full exception (%s); retrying on CPU if GPU was active.",
                        e.what());
    status = -1;
  } catch (...) {
    status = -1;
  }
  if (status != 0 && shared.using_gpu &&
      !(token != 0 && g_cancel_requested.load(std::memory_order_relaxed))) {
    ctx = shared.get(model_path, /*force_cpu=*/true);
    if (ctx != nullptr) {
      started = std::chrono::steady_clock::now();
      try {
        status = whisper_full(
            ctx, params, samples.data(), static_cast<int>(samples.size()));
      } catch (...) {
        status = -1;
      }
    }
  }
  const auto finished = std::chrono::steady_clock::now();
  const double inference_seconds =
      std::chrono::duration<double>(finished - started).count();

  if (shared.using_gpu && duration_seconds <= 3.5 && inference_seconds > 1.5 &&
      !(token != 0 && g_cancel_requested.load(std::memory_order_relaxed))) {
    __android_log_print(
        ANDROID_LOG_WARN, kLogTag,
        "Vulkan GPU inference took %.2fs for %.2fs audio; switching to CPU.",
        inference_seconds, duration_seconds);
    shared.force_cpu_sticky = true;
  }

  if (token != 0 && g_cancel_requested.load(std::memory_order_relaxed)) {
    fill_metrics(5.0, duration_seconds, inference_seconds,
                 shared.using_gpu ? 1.0 : 0.0);
    return nullptr;
  }
  if (status != 0) {
    fill_metrics(3.0, duration_seconds, inference_seconds,
                 shared.using_gpu ? 1.0 : 0.0);
    return nullptr;
  }

  std::string transcript;
  const int segments = whisper_full_n_segments(ctx);
  for (int i = 0; i < segments; ++i) {
    const char *piece = whisper_full_get_segment_text(ctx, i);
    if (piece != nullptr) {
      if (!transcript.empty()) {
        transcript.push_back(' ');
      }
      transcript.append(piece);
    }
  }

  fill_metrics(0.0, duration_seconds, inference_seconds,
               shared.using_gpu ? 1.0 : 0.0);
  jbyteArray out = env->NewByteArray(static_cast<jsize>(transcript.size()));
  if (out != nullptr && !transcript.empty()) {
    env->SetByteArrayRegion(
        out, 0, static_cast<jsize>(transcript.size()),
        reinterpret_cast<const jbyte *>(transcript.data()));
  }
  return out;
}
