package com.ebaidllc.tajweed_practice

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.roundToLong

private class QuranASRDiagnostics(private val context: Context) {
    private val lock = Any()
    private val maximumBytes = 768 * 1024
    private val logFile = File(context.cacheDir, "quran-asr-diagnostics.jsonl")
    private val snapshotRoot = File(context.cacheDir, "quran-asr-debug")
    private var recordingID: String? = null
    private var debugCaptureID: String? = null
    private var retainDebugTranscripts = false
    private var snapshotSequence = 0
    private val completeSlots = mutableSetOf<Int>()

    private val buildVersionString: String by lazy {
        try {
            val info = context.packageManager.getPackageInfo(context.packageName, 0)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                info.longVersionCode.toString()
            } else {
                @Suppress("DEPRECATION")
                info.versionCode.toString()
            }
        } catch (_: Throwable) {
            ""
        }
    }

    fun beginCapture(retainDebugAudio: Boolean, retainDebugTranscripts: Boolean): String? {
        synchronized(lock) {
            val id = UUID.randomUUID().toString()
            try {
                logFile.writeBytes(ByteArray(0))
                recordingID = id
            } catch (_: Throwable) {
                recordingID = null
            }
            debugCaptureID = if (retainDebugAudio) recordingID else null
            this.retainDebugTranscripts = retainDebugTranscripts
            snapshotSequence = 0
            completeSlots.clear()
            try {
                if (snapshotRoot.exists()) {
                    snapshotRoot.deleteRecursively()
                }
            } catch (_: Throwable) {
            }
            return debugCaptureID
        }
    }

    fun record(
        event: String,
        metrics: Map<String, Double> = emptyMap(),
        transcript: String? = null
    ) {
        synchronized(lock) {
            try {
                val entry = JSONObject()
                entry.put("time", System.currentTimeMillis().toDouble() / 1000.0)
                entry.put("event", event)
                val metricsJson = JSONObject()
                for ((key, value) in metrics) {
                    if (value.isFinite()) {
                        metricsJson.put(key, value)
                    }
                }
                entry.put("metrics", metricsJson)
                if (retainDebugTranscripts && recordingID != null && transcript != null) {
                    entry.put("transcript", transcript)
                }
                appendLine(entry.toString() + "\n")
            } catch (_: Throwable) {
            }
        }
    }

    fun retainSnapshot(
        wavFile: File,
        report: Map<String, Any>?,
        provisional: Boolean,
        windowStart: Double,
        requested: Long,
        errorCode: Int,
        captureID: String
    ) {
        val savedSlot: Int
        val requestedSec = requested.toDouble() / 1000.0
        try {
            synchronized(lock) {
                if (debugCaptureID != captureID) return
                val audio = wavFile.readBytes()
                if (audio.size > 960_044) {
                    throw IllegalStateException("Snapshot exceeds size limit")
                }
                val directory = File(snapshotRoot, captureID)
                if (!directory.exists()) {
                    directory.mkdirs()
                }
                val slot = snapshotSequence % 6
                snapshotSequence += 1
                val metadata = JSONObject()
                metadata.put("requested", requestedSec)
                metadata.put("returned", System.currentTimeMillis().toDouble() / 1000.0)
                metadata.put("preview", provisional)
                metadata.put("windowStart", windowStart)
                metadata.put("errorCode", errorCode)
                val reportJson = JSONObject()
                if (report != null) {
                    for ((k, v) in report) {
                        reportJson.put(k, v)
                    }
                }
                metadata.put("report", reportJson)
                val jsonBytes = metadata.toString().toByteArray(Charsets.UTF_8)
                if (jsonBytes.size > 65_536) {
                    throw IllegalStateException("Snapshot metadata exceeds size limit")
                }
                completeSlots.remove(slot)
                File(directory, "snapshot-$slot.wav").writeBytes(audio)
                File(directory, "snapshot-$slot.json").writeBytes(jsonBytes)
                completeSlots.add(slot)
                savedSlot = slot
            }
        } catch (_: Throwable) {
            record("debug_snapshot_failed")
            return
        }
        record(
            "debug_snapshot_saved",
            metrics = mapOf(
                "slot" to savedSlot.toDouble(),
                "requested" to requestedSec
            )
        )
    }

    fun exportedFilePaths(includeSnapshots: Boolean = true): List<String> {
        synchronized(lock) {
            if (recordingID == null || !logFile.exists()) return emptyList()
            val paths = mutableListOf(logFile.absolutePath)
            if (includeSnapshots) {
                paths.addAll(snapshotPathsLocked())
            }
            return paths
        }
    }

    fun cloudDiagnostics(includeSnapshots: Boolean = true): Map<String, Any>? {
        synchronized(lock) {
            val id = recordingID ?: return null
            if (!logFile.exists()) return null
            val log = String(logFile.readBytes(), Charsets.UTF_8)
            return mapOf(
                "id" to id.lowercase(Locale.US),
                "build" to buildVersionString,
                "log" to log,
                "snapshotPaths" to if (includeSnapshots) snapshotPathsLocked() else emptyList<String>()
            )
        }
    }

    private fun snapshotPathsLocked(): List<String> {
        val captureID = debugCaptureID ?: return emptyList()
        val directory = File(snapshotRoot, captureID)
        val paths = mutableListOf<String>()
        for (slot in completeSlots.sorted()) {
            val json = File(directory, "snapshot-$slot.json")
            val wav = File(directory, "snapshot-$slot.wav")
            if (json.exists() && wav.exists()) {
                paths.add(json.absolutePath)
                paths.add(wav.absolutePath)
            }
        }
        return paths
    }

    private fun appendLine(line: String) {
        try {
            val data = line.toByteArray(Charsets.UTF_8)
            val existing = if (logFile.exists()) logFile.readBytes() else ByteArray(0)
            var combined = existing + data
            if (combined.size > maximumBytes) {
                val overflow = combined.size - maximumBytes
                var newlineIndex = -1
                for (i in overflow until combined.size) {
                    if (combined[i] == '\n'.code.toByte()) {
                        newlineIndex = i
                        break
                    }
                }
                combined = if (newlineIndex >= 0 && newlineIndex + 1 < combined.size) {
                    combined.copyOfRange(newlineIndex + 1, combined.size)
                } else {
                    ByteArray(0)
                }
            }
            logFile.writeBytes(combined)
        } catch (_: Throwable) {
        }
    }
}

private class QuranASRCapture {
    data class Snapshot(val wav: ByteArray, val startSeconds: Double)

    private val lock = Any()
    private val maxBufferBytes = 16_000 * 2 * 30 // 30s of 16 kHz mono PCM16
    private val checkWindowBytes = 16_000 * 2 * 4 // 4s check window
    private val previewWindowBytes = 16_000 * 2 * 3 // 3s preview window
    private var pcmBuffer = ByteArray(0)
    private var capturedSamplesCount: Long = 0
    private val running = AtomicBoolean(false)
    private var audioRecord: AudioRecord? = null
    private var readerThread: Thread? = null

    val capturedSeconds: Double
        get() = synchronized(lock) { capturedSamplesCount.toDouble() / 16_000.0 }

    fun start() {
        val minBuf = AudioRecord.getMinBufferSize(
            16_000,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        val bufferSize = maxOf(minBuf, 16_000 * 2)
        var record = createAudioRecord(MediaRecorder.AudioSource.VOICE_RECOGNITION, bufferSize)
        if (record == null || record.state != AudioRecord.STATE_INITIALIZED) {
            record?.release()
            record = createAudioRecord(MediaRecorder.AudioSource.MIC, bufferSize)
        }
        if (record == null || record.state != AudioRecord.STATE_INITIALIZED) {
            record?.release()
            throw IllegalStateException("Unable to initialize 16 kHz AudioRecord.")
        }
        audioRecord = record
        running.set(true)
        record.startRecording()
        if (record.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
            running.set(false)
            record.release()
            audioRecord = null
            throw IllegalStateException("AudioRecord failed to start recording.")
        }
        readerThread = Thread({
            val chunk = ByteArray(4096)
            while (running.get()) {
                val read = record.read(chunk, 0, chunk.size)
                if (read > 0) {
                    val evenBytes = read - (read % 2)
                    if (evenBytes > 0) {
                        appendPcm(chunk, evenBytes)
                    }
                } else if (read < 0) {
                    break
                }
            }
        }, "quran-asr-audio-reader").apply {
            priority = Thread.MAX_PRIORITY
            start()
        }
    }

    fun stop() {
        if (!running.getAndSet(false)) return
        try {
            audioRecord?.stop()
        } catch (_: Throwable) {
        }
        try {
            readerThread?.join(300)
        } catch (_: Throwable) {
        }
        readerThread = null
        try {
            audioRecord?.release()
        } catch (_: Throwable) {
        }
        audioRecord = null
    }

    private fun createAudioRecord(source: Int, bufferSize: Int): AudioRecord? {
        return try {
            AudioRecord(
                source,
                16_000,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferSize
            )
        } catch (_: Throwable) {
            null
        }
    }

    private fun appendPcm(chunk: ByteArray, length: Int) {
        synchronized(lock) {
            capturedSamplesCount += (length / 2).toLong()
            val combinedSize = pcmBuffer.size + length
            if (combinedSize <= maxBufferBytes) {
                val next = ByteArray(combinedSize)
                System.arraycopy(pcmBuffer, 0, next, 0, pcmBuffer.size)
                System.arraycopy(chunk, 0, next, pcmBuffer.size, length)
                pcmBuffer = next
            } else {
                val keepFromExisting = maxOf(0, maxBufferBytes - length)
                val existingStart = pcmBuffer.size - keepFromExisting
                val next = ByteArray(maxBufferBytes)
                if (keepFromExisting > 0) {
                    System.arraycopy(pcmBuffer, existingStart, next, 0, keepFromExisting)
                }
                val copyFromChunk = minOf(length, maxBufferBytes)
                val chunkStart = length - copyFromChunk
                System.arraycopy(chunk, chunkStart, next, keepFromExisting, copyFromChunk)
                pcmBuffer = next
            }
        }
    }

    fun snapshot(forPreview: Boolean = false, recoveryContextSeconds: Int? = null): Snapshot? {
        val audio: ByteArray
        val totalSamples: Long
        synchronized(lock) {
            val minimumBytes = if (forPreview) 16_000 * 2 else 2
            if (pcmBuffer.size < minimumBytes) return null
            val windowBytes = if (forPreview) {
                if (recoveryContextSeconds != null) {
                    16_000 * 2 * recoveryContextSeconds
                } else {
                    previewWindowBytes
                }
            } else {
                checkWindowBytes
            }
            val sliceLen = minOf(pcmBuffer.size, windowBytes)
            audio = pcmBuffer.copyOfRange(pcmBuffer.size - sliceLen, pcmBuffer.size)
            totalSamples = capturedSamplesCount
        }
        val wav = buildWav(audio)
        val startSeconds = (totalSamples - (audio.size / 2).toLong()).toDouble() / 16_000.0
        return Snapshot(wav = wav, startSeconds = startSeconds)
    }

    private fun buildWav(pcm: ByteArray): ByteArray {
        val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
        header.put("RIFF".toByteArray(Charsets.US_ASCII))
        header.putInt(36 + pcm.size)
        header.put("WAVE".toByteArray(Charsets.US_ASCII))
        header.put("fmt ".toByteArray(Charsets.US_ASCII))
        header.putInt(16)
        header.putShort(1) // PCM
        header.putShort(1) // Mono
        header.putInt(16_000) // Sample rate
        header.putInt(16_000 * 2) // Byte rate
        header.putShort(2) // Block align
        header.putShort(16) // Bits per sample
        header.put("data".toByteArray(Charsets.US_ASCII))
        header.putInt(pcm.size)
        val out = ByteArray(44 + pcm.size)
        System.arraycopy(header.array(), 0, out, 0, 44)
        System.arraycopy(pcm, 0, out, 44, pcm.size)
        return out
    }
}

class QuranASRChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL_NAME = "com.ebaidllc.tajweed_practice/quran_asr"
        private const val MODEL_ASSET_NAME = "quran-tiny.bin"
        const val REQUEST_RECORD_AUDIO = 49152

        private val nativeLoaded: Boolean = try {
            System.loadLibrary("quran_asr_jni")
            true
        } catch (_: Throwable) {
            false
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val diagnostics = QuranASRDiagnostics(activity.applicationContext)
    private val tokenCounter = AtomicLong(1L)

    private var channel: MethodChannel? = null
    private var capture: QuranASRCapture? = null
    private var isRecording = false
    private var audioFile: File? = null
    private var processing = false
    private var activePreviewCancelToken: Long = 0L
    private var starting = false
    private var debugCaptureID: String? = null
    private var generation = 0
    private var cachedModelPath: String? = null

    private var pendingStartCallback: ((Boolean) -> Unit)? = null

    private external fun nativeTranscribe(
        modelPath: String,
        wavPath: String,
        provisional: Boolean,
        cancelToken: Long,
        metricsOut: DoubleArray
    ): ByteArray?

    private external fun nativeCancelToken(token: Long)

    fun register(messenger: BinaryMessenger) {
        val allowedPackages = setOf(
            "com.ebaidllc.tajweed_practice",
            "com.ebaidllc.tajweedpractice",
            "com.ebaidllc.tajweedpractice.quranailab"
        )
        if (!allowedPackages.contains(activity.packageName)) {
            return
        }
        val methodChannel = MethodChannel(messenger, CHANNEL_NAME)
        methodChannel.setMethodCallHandler(this)
        channel = methodChannel
        if (nativeLoaded && hasModelAsset()) {
            worker.execute {
                try {
                    ensureModelFile()
                } catch (_: Throwable) {
                }
            }
        }
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        grantResults: IntArray
    ): Boolean {
        if (requestCode != REQUEST_RECORD_AUDIO) return false
        val callback = pendingStartCallback ?: return true
        pendingStartCallback = null
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        mainHandler.post { callback(granted) }
        return true
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "available" -> {
                result.success(nativeLoaded && hasModelAsset())
            }
            "start" -> {
                val args = call.arguments as? Map<*, *>
                val retainDebugAudio = args?.get("retainDebugAudio") as? Boolean == true
                val retainDebugTranscripts = args?.get("retainDebugTranscripts") as? Boolean == true
                start(result, retainDebugAudio, retainDebugTranscripts)
            }
            "check" -> check(result)
            "preview" -> {
                val args = call.arguments
                if (args != null) {
                    val fields = args as? Map<*, *>
                    val recovery = fields?.get("recovery") as? Boolean == true
                    val contextSeconds = (fields?.get("contextSeconds") as? Number)?.toInt()
                    if (fields == null || fields.size != 2 || !recovery ||
                        (contextSeconds != 12 && contextSeconds != 28)
                    ) {
                        result.error(
                            "invalid_preview",
                            "Expected explicit 12s or 28s recovery.",
                            null
                        )
                        return
                    }
                    preview(result, recoveryContextSeconds = contextSeconds)
                } else {
                    preview(result, recoveryContextSeconds = null)
                }
            }
            "tailPreview" -> {
                val fields = call.arguments as? Map<*, *>
                val after = (fields?.get("afterSeconds") as? Number)?.toDouble()
                if (fields == null || fields.size != 1 || after == null ||
                    !after.isFinite() || after < 0.0
                ) {
                    result.error("invalid_preview", "Expected afterSeconds.", null)
                    return
                }
                tailPreview(result, afterSeconds = after)
            }
            "finishCapture" -> {
                diagnostics.record("pause", metrics = mapOf("processing" to if (processing) 1.0 else 0.0))
                cancelActivePreview()
                stopCapture()
                result.success(null)
            }
            "cancel" -> {
                if (capture != null || audioFile != null || processing) {
                    diagnostics.record("cancel")
                }
                generation += 1
                cancelActivePreview()
                clearRecording()
                result.success(null)
            }
            "traceProgress" -> {
                val allowed = setOf(
                    "expectedIndex", "rawWords", "visibleWords", "final", "contradiction",
                    "generation", "active", "stopping", "schemaVersion", "recordingIndex",
                    "cursorIndex", "cursorWords", "displayedBefore", "rawCompleted",
                    "rawWordIndex", "rawMismatch", "combinedPrefix", "cursorRawPrefix",
                    "cursorTailPrefix"
                )
                val rawMap = call.arguments as? Map<*, *>
                if (rawMap == null) {
                    result.error("invalid_diagnostics", "Expected numeric progress counters.", null)
                    return
                }
                val metrics = mutableMapOf<String, Double>()
                for ((k, v) in rawMap) {
                    val key = k as? String
                    val num = (v as? Number)?.toDouble()
                    if (key == null || !allowed.contains(key) || num == null || !num.isFinite() || num < 0.0) {
                        result.error("invalid_diagnostics", "Expected numeric progress counters.", null)
                        return
                    }
                    metrics[key] = num
                }
                diagnostics.record("progress", metrics = metrics)
                result.success(null)
            }
            "tracePreviewReveal" -> {
                val required = setOf(
                    "generation", "audioEndSeconds", "newVisibleWords", "visibleWords", "snapshotToRevealMs"
                )
                val rawMap = call.arguments as? Map<*, *>
                if (rawMap == null || rawMap.keys.mapNotNull { it as? String }.toSet() != required) {
                    result.error("invalid_diagnostics", "Expected numeric preview reveal metrics.", null)
                    return
                }
                val metrics = mutableMapOf<String, Double>()
                for ((k, v) in rawMap) {
                    val key = k as String
                    val num = (v as? Number)?.toDouble()
                    if (num == null || !num.isFinite() || num < 0.0) {
                        result.error("invalid_diagnostics", "Expected numeric preview reveal metrics.", null)
                        return
                    }
                    metrics[key] = num
                }
                if ((metrics["newVisibleWords"] ?: 0.0) <= 0.0) {
                    result.error("invalid_diagnostics", "Expected numeric preview reveal metrics.", null)
                    return
                }
                diagnostics.record("preview_reveal", metrics = metrics)
                result.success(null)
            }
            "exportDiagnostics" -> {
                result.success(diagnostics.exportedFilePaths(includeSnapshots = !isRecording))
            }
            "exportCloudDiagnostics" -> {
                try {
                    result.success(diagnostics.cloudDiagnostics(includeSnapshots = !isRecording))
                } catch (e: Throwable) {
                    result.error("diagnostics_export_failed", e.message, null)
                }
            }
            "checkWav" -> {
                val bytes = call.arguments as? ByteArray
                if (processing || starting || isRecording || audioFile != null ||
                    bytes == null || bytes.size > 960_044
                ) {
                    result.error("invalid_audio", "Invalid or busy audio input.", null)
                    return
                }
                try {
                    val file = File(activity.cacheDir, UUID.randomUUID().toString() + ".wav")
                    file.writeBytes(bytes)
                    audioFile = file
                    check(result)
                } catch (e: Throwable) {
                    result.error("quran_asr_failed", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun hasModelAsset(): Boolean {
        if (cachedModelPath != null && File(cachedModelPath!!).exists()) return true
        return try {
            activity.assets.openFd(MODEL_ASSET_NAME).use { it.length > 0 }
        } catch (_: Throwable) {
            try {
                activity.assets.open(MODEL_ASSET_NAME).use { true }
            } catch (_: Throwable) {
                false
            }
        }
    }

    @Synchronized
    private fun ensureModelFile(): String? {
        cachedModelPath?.let { path ->
            val f = File(path)
            if (f.exists() && f.length() > 30_000_000L) return path
        }
        val target = File(activity.filesDir, MODEL_ASSET_NAME)
        if (target.exists() && target.length() > 30_000_000L) {
            cachedModelPath = target.absolutePath
            return cachedModelPath
        }
        return try {
            val tmp = File(activity.filesDir, "$MODEL_ASSET_NAME.tmp")
            if (tmp.exists()) tmp.delete()
            activity.assets.open(MODEL_ASSET_NAME).use { input ->
                tmp.outputStream().use { output ->
                    val buffer = ByteArray(256 * 1024)
                    while (true) {
                        val read = input.read(buffer)
                        if (read <= 0) break
                        output.write(buffer, 0, read)
                    }
                    output.flush()
                }
            }
            if (target.exists()) target.delete()
            if (!tmp.renameTo(target)) {
                tmp.copyTo(target, overwrite = true)
                tmp.delete()
            }
            cachedModelPath = target.absolutePath
            cachedModelPath
        } catch (_: Throwable) {
            null
        }
    }

    private fun start(
        result: MethodChannel.Result,
        retainDebugAudio: Boolean,
        retainDebugTranscripts: Boolean
    ) {
        if (processing || starting || isRecording || audioFile != null) {
            result.error("busy", "Recognition is already active.", null)
            return
        }
        if (!nativeLoaded || !hasModelAsset()) {
            result.error("unavailable", "Experimental model is not installed.", null)
            return
        }
        starting = true
        val requestGeneration = generation
        val proceedWithPermission: (Boolean) -> Unit = { allowed ->
            starting = false
            if (requestGeneration != generation) {
                result.error("cancelled", "Recording was cancelled.", null)
            } else if (!allowed) {
                result.error("permission_denied", "Microphone permission is required.", null)
            } else {
                try {
                    val newCapture = QuranASRCapture()
                    newCapture.start()
                    capture = newCapture
                    isRecording = true
                    debugCaptureID = diagnostics.beginCapture(
                        retainDebugAudio = retainDebugAudio,
                        retainDebugTranscripts = retainDebugTranscripts
                    )
                    diagnostics.record("capture_started")
                    result.success(null)
                } catch (e: Throwable) {
                    clearRecording()
                    result.error("quran_asr_failed", e.message, null)
                }
            }
        }

        val hasPermission = ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
        if (hasPermission) {
            proceedWithPermission(true)
        } else {
            pendingStartCallback = proceedWithPermission
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.RECORD_AUDIO),
                REQUEST_RECORD_AUDIO
            )
        }
    }

    private fun stopCapture() {
        if (isRecording) {
            capture?.stop()
            isRecording = false
        }
    }

    private fun clearRecording() {
        stopCapture()
        capture = null
        audioFile?.let { file ->
            try {
                if (file.exists()) file.delete()
            } catch (_: Throwable) {
            }
        }
        audioFile = null
    }

    private fun cancelActivePreview() {
        val token = activePreviewCancelToken
        if (token != 0L && nativeLoaded) {
            try {
                nativeCancelToken(token)
            } catch (_: Throwable) {
            }
        }
    }

    private fun preview(result: MethodChannel.Result, recoveryContextSeconds: Int? = null) {
        val currentCapture = capture
        if (processing || starting || !isRecording || currentCapture == null || !nativeLoaded) {
            result.error("busy", "No available live recording.", null)
            return
        }
        try {
            val snapshot = currentCapture.snapshot(
                forPreview = true,
                recoveryContextSeconds = recoveryContextSeconds
            )
            if (snapshot == null || snapshot.wav.size < 32_044) {
                result.success(null)
                return
            }
            val wavFile = File(activity.cacheDir, UUID.randomUUID().toString() + ".wav")
            wavFile.writeBytes(snapshot.wav)
            transcribe(
                wavFile = wavFile,
                provisional = true,
                windowStartSeconds = snapshot.startSeconds,
                debugCaptureID = debugCaptureID,
                recoveryContextSeconds = recoveryContextSeconds,
                result = result
            )
        } catch (e: Throwable) {
            result.error("quran_asr_failed", e.message, null)
        }
    }

    private fun tailPreview(result: MethodChannel.Result, afterSeconds: Double) {
        val currentCapture = capture
        if (processing || starting || isRecording || currentCapture == null || !nativeLoaded) {
            result.error("busy", "No stopped recording.", null)
            return
        }
        if (currentCapture.capturedSeconds - afterSeconds < 0.25) {
            result.success(null)
            return
        }
        try {
            val snapshot = currentCapture.snapshot(forPreview = true)
            if (snapshot == null || snapshot.wav.size < 32_044) {
                result.success(null)
                return
            }
            val wavFile = File(activity.cacheDir, UUID.randomUUID().toString() + ".wav")
            wavFile.writeBytes(snapshot.wav)
            transcribe(
                wavFile = wavFile,
                provisional = true,
                windowStartSeconds = snapshot.startSeconds,
                debugCaptureID = debugCaptureID,
                recoveryContextSeconds = null,
                result = result
            )
        } catch (e: Throwable) {
            result.error("quran_asr_failed", e.message, null)
        }
    }

    private fun check(result: MethodChannel.Result) {
        if (processing) {
            result.error("busy", "Recognition is already active.", null)
            return
        }
        var windowStartSeconds = 0.0
        val snapshotCaptureID = if (capture == null) null else debugCaptureID
        try {
            stopCapture()
            capture?.let { activeCapture ->
                val snapshot = activeCapture.snapshot(forPreview = false)
                if (snapshot != null) {
                    val wavFile = File(activity.cacheDir, UUID.randomUUID().toString() + ".wav")
                    wavFile.writeBytes(snapshot.wav)
                    windowStartSeconds = snapshot.startSeconds
                    audioFile = wavFile
                }
                capture = null
            }
        } catch (e: Throwable) {
            clearRecording()
            result.error("quran_asr_failed", e.message, null)
            return
        }
        val targetWav = audioFile
        if (targetWav == null || !nativeLoaded || !hasModelAsset()) {
            clearRecording()
            result.error("unavailable", "Audio or the experimental model is unavailable.", null)
            return
        }
        audioFile = null
        transcribe(
            wavFile = targetWav,
            provisional = false,
            windowStartSeconds = windowStartSeconds,
            debugCaptureID = snapshotCaptureID,
            recoveryContextSeconds = null,
            result = result
        )
    }

    private fun transcribe(
        wavFile: File,
        provisional: Boolean,
        windowStartSeconds: Double,
        debugCaptureID: String?,
        recoveryContextSeconds: Int?,
        result: MethodChannel.Result
    ) {
        processing = true
        val cancelToken = if (provisional) tokenCounter.getAndIncrement() else 0L
        activePreviewCancelToken = cancelToken
        val currentGen = generation
        val requestedMs = System.currentTimeMillis()
        val requestMetrics = mutableMapOf(
            "preview" to if (provisional) 1.0 else 0.0,
            "windowStart" to windowStartSeconds
        )
        if (recoveryContextSeconds != null) {
            requestMetrics["recovery"] = 1.0
            requestMetrics["contextSeconds"] = recoveryContextSeconds.toDouble()
        }
        diagnostics.record("inference_requested", metrics = requestMetrics)

        worker.execute {
            val modelPath = ensureModelFile()
            val metricsOut = DoubleArray(4)
            var transcriptBytes: ByteArray? = null
            if (modelPath != null) {
                try {
                    transcriptBytes = nativeTranscribe(
                        modelPath,
                        wavFile.absolutePath,
                        provisional,
                        cancelToken,
                        metricsOut
                    )
                } catch (_: Throwable) {
                    metricsOut[0] = 3.0
                }
            } else {
                metricsOut[0] = 1.0
            }

            val statusCode = metricsOut[0].toInt()
            val durationSeconds = metricsOut[1]
            val inferenceSeconds = metricsOut[2]
            val transcript = transcriptBytes?.let { String(it, Charsets.UTF_8) }
            val report: Map<String, Any>? = if (statusCode == 0 && transcript != null) {
                mapOf(
                    "transcript" to transcript,
                    "durationSeconds" to durationSeconds,
                    "inferenceSeconds" to inferenceSeconds
                )
            } else {
                null
            }

            if (debugCaptureID != null) {
                diagnostics.retainSnapshot(
                    wavFile = wavFile,
                    report = report,
                    provisional = provisional,
                    windowStart = windowStartSeconds,
                    requested = requestedMs,
                    errorCode = statusCode,
                    captureID = debugCaptureID
                )
            }
            try {
                if (wavFile.exists()) wavFile.delete()
            } catch (_: Throwable) {
            }

            mainHandler.post {
                processing = false
                activePreviewCancelToken = 0L
                val elapsedSeconds = (System.currentTimeMillis() - requestedMs).toDouble() / 1000.0
                diagnostics.record(
                    "inference_returned",
                    metrics = mapOf(
                        "preview" to if (provisional) 1.0 else 0.0,
                        "elapsedSeconds" to elapsedSeconds,
                        "inferenceSeconds" to inferenceSeconds,
                        "durationSeconds" to durationSeconds,
                        "characters" to (transcript?.length ?: 0).toDouble(),
                        "errorCode" to statusCode.toDouble(),
                        "cancelled" to if (currentGen != generation) 1.0 else 0.0
                    ),
                    transcript = transcript
                )
                if (currentGen != generation) {
                    result.error("cancelled", "Recognition was cancelled.", null)
                } else if (provisional && statusCode == 5) {
                    result.error(
                        "preview_cancelled",
                        "Preview was cancelled for final recognition.",
                        null
                    )
                } else if (provisional && statusCode == 4) {
                    result.success(null)
                } else if (report != null) {
                    val response = HashMap<String, Any>(report)
                    response["windowStartSeconds"] = windowStartSeconds
                    if (provisional) {
                        response["snapshotRequestedAtUnixMs"] = requestedMs.toDouble()
                    }
                    if (recoveryContextSeconds != null) {
                        response["recovery"] = true
                        response["contextSeconds"] = recoveryContextSeconds
                    }
                    result.success(response)
                } else {
                    result.error(
                        "quran_asr_failed",
                        "Quran ASR native status $statusCode",
                        null
                    )
                }
            }
        }
    }
}
