package com.ebaidllc.tajweed_practice

import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestIntegrityToken" -> requestIntegrityToken(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Performs a Play Integrity *classic* request. Classic is the right fit here
     * because it accepts a caller-supplied nonce, which lets the server bind the
     * token to a single-use challenge exactly like App Attest does on iOS.
     */
    private fun requestIntegrityToken(call: MethodCall, result: MethodChannel.Result) {
        val nonce = call.argument<String>("nonce")
        if (nonce.isNullOrEmpty()) {
            result.error("invalid_argument", "A nonce is required.", null)
            return
        }

        val request = IntegrityTokenRequest.builder().setNonce(nonce)
        // Google Play cannot link the app to a Cloud project when the build is
        // not distributed by Play, so the project number must be supplied here.
        cloudProjectNumber(call)?.let(request::setCloudProjectNumber)

        IntegrityManagerFactory.create(applicationContext)
            .requestIntegrityToken(request.build())
            .addOnSuccessListener { response -> result.success(response.token()) }
            .addOnFailureListener { error ->
                result.error(
                    "play_integrity_unavailable",
                    error.message ?: "Play Integrity request failed.",
                    null,
                )
            }
    }

    private fun cloudProjectNumber(call: MethodCall): Long? {
        val value = when (val raw = call.argument<Any>("cloudProjectNumber")) {
            is Number -> raw.toLong()
            is String -> raw.toLongOrNull()
            else -> null
        }
        return value?.takeIf { it > 0 }
    }

    private companion object {
        const val CHANNEL = "com.ebaidllc.tajweed_practice/play_integrity"
    }
}