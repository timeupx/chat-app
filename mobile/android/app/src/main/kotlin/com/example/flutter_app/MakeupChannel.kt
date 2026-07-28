package com.example.flutter_app

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.cloudwebrtc.webrtc.FlutterWebRTCPlugin
import com.cloudwebrtc.webrtc.video.LocalVideoTrack
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Dart entry point for the AR makeup processor.
 */
class MakeupChannel(context: Context, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val channel = MethodChannel(messenger, "app/makeup").also {
        it.setMethodCallHandler(this)
    }
    private val tracker = FaceLandmarkTracker(context)
    private val processor = MakeupProcessor(tracker).also { proc ->
        proc.onLowLight = {
            mainHandler.post {
                channel.invokeMethod("lowLight", null)
            }
        }
        proc.onLightRestored = {
            mainHandler.post {
                channel.invokeMethod("lightRestored", null)
            }
        }
    }
    private var attachedTrack: LocalVideoTrack? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "attach" -> {
                val trackId = call.argument<String>("trackId")
                if (trackId == null) {
                    result.error("no_track_id", "trackId is required", null)
                    return
                }
                result.success(attach(trackId))
            }
            "detach" -> {
                detach()
                result.success(true)
            }
            "setLipstick" -> {
                val on = call.argument<Boolean>("enabled") ?: false
                processor.setLipstick(
                    (call.argument<Double>("red") ?: 0.0).toFloat(),
                    (call.argument<Double>("green") ?: 0.0).toFloat(),
                    (call.argument<Double>("blue") ?: 0.0).toFloat(),
                    (call.argument<Double>("strength") ?: 0.55).toFloat(),
                )
                processor.lipstickEnabled = on
                result.success(true)
            }
            "setBlush" -> {
                val on = call.argument<Boolean>("enabled") ?: false
                processor.setBlush(
                    (call.argument<Double>("red") ?: 0.0).toFloat(),
                    (call.argument<Double>("green") ?: 0.0).toFloat(),
                    (call.argument<Double>("blue") ?: 0.0).toFloat(),
                    (call.argument<Double>("strength") ?: 0.24).toFloat(),
                )
                processor.blushEnabled = on
                result.success(true)
            }
            "setUnderEye" -> {
                val on = call.argument<Boolean>("enabled") ?: false
                processor.setUnderEye(
                    (call.argument<Double>("red") ?: 0.0).toFloat(),
                    (call.argument<Double>("green") ?: 0.0).toFloat(),
                    (call.argument<Double>("blue") ?: 0.0).toFloat(),
                    (call.argument<Double>("strength") ?: 0.28).toFloat(),
                )
                processor.underEyeEnabled = on
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun attach(trackId: String): Boolean {
        val plugin = FlutterWebRTCPlugin.sharedSingleton ?: return false
        val track = plugin.getLocalTrack(trackId) as? LocalVideoTrack ?: return false
        if (attachedTrack === track) return true
        detach()
        track.addProcessor(processor)
        attachedTrack = track
        return true
    }

    private fun detach() {
        attachedTrack?.removeProcessor(processor)
        attachedTrack = null
        processor.lipstickEnabled = false
        processor.blushEnabled = false
        processor.underEyeEnabled = false
        processor.resetLowLightPause()
    }

    fun dispose() {
        detach()
        processor.onLowLight = null
        processor.onLightRestored = null
        channel.setMethodCallHandler(null)
        tracker.release()
    }
}
