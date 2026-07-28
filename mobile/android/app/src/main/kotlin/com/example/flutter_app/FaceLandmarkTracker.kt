package com.example.flutter_app

import android.content.Context
import android.graphics.Bitmap
import android.opengl.GLES20
import android.util.Log
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import org.webrtc.GlRectDrawer
import org.webrtc.GlTextureFrameBuffer
import java.nio.ByteBuffer
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

/** Result of one capture-thread detect pass. */
data class DetectFrame(
    val meshes: FaceMeshes?,
    /** True when the frame is too dark for makeup to look natural. */
    val tooDark: Boolean,
)

/** Lip / cheek / under-eye meshes from one face detect. */
data class FaceMeshes(
    val lips: FloatArray?,
    val leftCheek: FloatArray?,
    val rightCheek: FloatArray?,
    val leftUnderEye: FloatArray?,
    val rightUnderEye: FloatArray?,
)

/**
 * Frame-accurate face tracker for lipstick and cheek blush.
 * MediaPipe runs on the same framebuffer we are about to publish.
 */
class FaceLandmarkTracker(private val context: Context) {

    private var landmarker: FaceLandmarker? = null
    private var landmarkerFailed = false
    private var videoTimestampMs = 0L

    private var readDrawer: GlRectDrawer? = null
    private var readBuffer: GlTextureFrameBuffer? = null
    private var pixels: ByteBuffer? = null
    private var bitmap: Bitmap? = null

    private var smoothedLips: FloatArray? = null
    private var smoothedLeftCheek: FloatArray? = null
    private var smoothedRightCheek: FloatArray? = null
    private var smoothedLeftUnder: FloatArray? = null
    private var smoothedRightUnder: FloatArray? = null
    private var missFrames = 0

    fun detectForFrame(source: GlTextureFrameBuffer, width: Int, height: Int): DetectFrame {
        if (landmarkerFailed) return DetectFrame(null, tooDark = false)
        val detector = landmarker ?: createLandmarker() ?: return DetectFrame(null, false)

        val smallHeight = (DETECT_WIDTH * height / width).coerceAtLeast(1)
        val fbo = readBuffer ?: GlTextureFrameBuffer(GLES20.GL_RGBA).also { readBuffer = it }
        fbo.setSize(DETECT_WIDTH, smallHeight)
        val drawer = readDrawer ?: GlRectDrawer().also { readDrawer = it }

        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fbo.frameBufferId)
        GLES20.glViewport(0, 0, DETECT_WIDTH, smallHeight)
        drawer.drawRgb(
            source.textureId, FLIP_Y, DETECT_WIDTH, smallHeight,
            0, 0, DETECT_WIDTH, smallHeight,
        )

        val byteCount = DETECT_WIDTH * smallHeight * 4
        val buffer = pixels?.takeIf { it.capacity() == byteCount }
            ?: ByteBuffer.allocateDirect(byteCount).also { pixels = it }
        buffer.rewind()
        GLES20.glReadPixels(
            0, 0, DETECT_WIDTH, smallHeight,
            GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, buffer,
        )

        val bmp = bitmap?.takeIf {
            it.width == DETECT_WIDTH && it.height == smallHeight
        } ?: Bitmap.createBitmap(DETECT_WIDTH, smallHeight, Bitmap.Config.ARGB_8888)
            .also { bitmap = it }
        buffer.rewind()
        bmp.copyPixelsFromBuffer(buffer)

        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, source.frameBufferId)
        GLES20.glViewport(0, 0, width, height)

        val luma = sampleLuma(buffer, DETECT_WIDTH, smallHeight)
        if (luma < DARK_LUMA) {
            // Skip MediaPipe — makeup would look wrong in this light anyway.
            return DetectFrame(null, tooDark = true)
        }

        // ~24fps while makeup capture profile is active.
        videoTimestampMs += 42L
        return try {
            val result = detector.detectForVideo(
                BitmapImageBuilder(bmp).build(),
                videoTimestampMs,
            )
            val faces = result.faceLandmarks()
            if (faces.isEmpty()) {
                missFrames++
                val held = if (missFrames <= 2) {
                    FaceMeshes(
                        smoothedLips,
                        smoothedLeftCheek,
                        smoothedRightCheek,
                        smoothedLeftUnder,
                        smoothedRightUnder,
                    )
                } else {
                    smoothedLips = null
                    smoothedLeftCheek = null
                    smoothedRightCheek = null
                    smoothedLeftUnder = null
                    smoothedRightUnder = null
                    null
                }
                return DetectFrame(held, tooDark = false)
            }
            missFrames = 0
            val points = faces[0]
            val lips = blendOrReplace(smoothedLips, buildLipBand(points))
            val left = blendOrReplace(smoothedLeftCheek, buildCheekFan(points, LEFT_CHEEK))
            val right = blendOrReplace(smoothedRightCheek, buildCheekFan(points, RIGHT_CHEEK))
            val leftUnder = blendOrReplace(
                smoothedLeftUnder,
                buildUnderEyeFan(points, LEFT_UNDER_EYE),
            )
            val rightUnder = blendOrReplace(
                smoothedRightUnder,
                buildUnderEyeFan(points, RIGHT_UNDER_EYE),
            )
            smoothedLips = lips
            smoothedLeftCheek = left
            smoothedRightCheek = right
            smoothedLeftUnder = leftUnder
            smoothedRightUnder = rightUnder
            DetectFrame(
                FaceMeshes(lips, left, right, leftUnder, rightUnder),
                tooDark = false,
            )
        } catch (e: Throwable) {
            Log.e(TAG, "detect failed", e)
            DetectFrame(null, tooDark = false)
        }
    }

    /** Mean luma 0…255 from an RGBA buffer (samples every 4th pixel). */
    private fun sampleLuma(buffer: ByteBuffer, width: Int, height: Int): Float {
        buffer.rewind()
        var sum = 0.0
        var count = 0
        val step = 4 // pixel stride in samples
        val total = width * height
        var i = 0
        while (i < total) {
            val base = i * 4
            if (base + 2 >= buffer.capacity()) break
            val r = buffer.get(base).toInt() and 0xff
            val g = buffer.get(base + 1).toInt() and 0xff
            val b = buffer.get(base + 2).toInt() and 0xff
            sum += 0.299 * r + 0.587 * g + 0.114 * b
            count++
            i += step
        }
        return if (count == 0) 255f else (sum / count).toFloat()
    }

    private fun blendOrReplace(previous: FloatArray?, next: FloatArray): FloatArray {
        return if (previous != null && previous.size == next.size) {
            blend(previous, next, SMOOTH)
        } else {
            next
        }
    }

    private fun buildLipBand(points: List<NormalizedLandmark>): FloatArray {
        val n = OUTER_LIP.size
        val strip = FloatArray((n + 1) * 4)
        var i = 0
        for (step in 0..n) {
            val index = step % n
            val ox = points[OUTER_LIP[index]].x()
            val oy = points[OUTER_LIP[index]].y()
            val ix = points[INNER_LIP[index]].x()
            val iy = points[INNER_LIP[index]].y()

            val outerX = ox + (ox - ix) * OUTER_EXPAND
            val outerY = oy + (oy - iy) * OUTER_EXPAND
            val innerX = ox + (ix - ox) * INNER_INSET
            val innerY = oy + (iy - oy) * INNER_INSET

            strip[i++] = outerX.coerceIn(0f, 1f)
            strip[i++] = outerY.coerceIn(0f, 1f)
            strip[i++] = innerX.coerceIn(0f, 1f)
            strip[i++] = innerY.coerceIn(0f, 1f)
        }
        return strip
    }

    /**
     * Soft-edged oval as a triangle fan: [cx, cy, a,  rimX, rimY, 0, …].
     * Centre alpha is kept moderate so bright patches do not glow in dim light.
     */
    private fun buildSoftOval(
        cx: Float,
        cy: Float,
        rx: Float,
        ry: Float,
        centerAlpha: Float,
    ): FloatArray {
        val fan = FloatArray((CHEEK_SEGMENTS + 2) * 3)
        var i = 0
        fan[i++] = cx.coerceIn(0f, 1f)
        fan[i++] = cy.coerceIn(0f, 1f)
        fan[i++] = centerAlpha
        for (s in 0..CHEEK_SEGMENTS) {
            val t = (s.toFloat() / CHEEK_SEGMENTS) * (Math.PI * 2.0).toFloat()
            fan[i++] = (cx + cos(t) * rx).coerceIn(0f, 1f)
            fan[i++] = (cy + sin(t) * ry).coerceIn(0f, 1f)
            fan[i++] = 0f
        }
        return fan
    }

    /** Bounding-box oval over a landmark cluster, expanded to cover the region. */
    private fun buildClusterOval(
        points: List<NormalizedLandmark>,
        indices: IntArray,
        expandX: Float,
        expandY: Float,
        centerAlpha: Float,
        shiftY: Float = 0f,
    ): FloatArray {
        var minX = 1f
        var maxX = 0f
        var minY = 1f
        var maxY = 0f
        var sx = 0f
        var sy = 0f
        for (idx in indices) {
            val x = points[idx].x()
            val y = points[idx].y()
            sx += x
            sy += y
            if (x < minX) minX = x
            if (x > maxX) maxX = x
            if (y < minY) minY = y
            if (y > maxY) maxY = y
        }
        val cx = sx / indices.size
        val cy = sy / indices.size + shiftY
        val rx = ((maxX - minX) * 0.5f * expandX).coerceAtLeast(0.02f)
        val ry = ((maxY - minY) * 0.5f * expandY).coerceAtLeast(0.015f)
        return buildSoftOval(cx, cy, rx, ry, centerAlpha)
    }

    private fun buildCheekFan(points: List<NormalizedLandmark>, cheekIdx: IntArray): FloatArray {
        return buildClusterOval(
            points,
            cheekIdx,
            expandX = 1.85f,
            expandY = 1.75f,
            centerAlpha = 0.55f,
        )
    }

    /** Soft patch covering the infraorbital / dark-circle zone under each eye. */
    private fun buildUnderEyeFan(
        points: List<NormalizedLandmark>,
        underIdx: IntArray,
    ): FloatArray {
        val faceW = abs(points[454].x() - points[234].x()).coerceAtLeast(0.08f)
        return buildClusterOval(
            points,
            underIdx,
            expandX = 1.55f,
            expandY = 2.1f,
            centerAlpha = 0.5f,
            shiftY = faceW * 0.012f,
        )
    }

    private fun blend(previous: FloatArray, next: FloatArray, amount: Float): FloatArray {
        val out = FloatArray(next.size)
        val keep = 1f - amount
        for (i in next.indices) {
            out[i] = previous[i] * keep + next[i] * amount
        }
        return out
    }

    private fun createLandmarker(): FaceLandmarker? {
        return try {
            val base = try {
                BaseOptions.builder()
                    .setModelAssetPath(MODEL_ASSET)
                    .setDelegate(Delegate.GPU)
                    .build()
            } catch (_: Throwable) {
                BaseOptions.builder().setModelAssetPath(MODEL_ASSET).build()
            }
            val options = FaceLandmarker.FaceLandmarkerOptions.builder()
                .setBaseOptions(base)
                .setRunningMode(RunningMode.VIDEO)
                .setNumFaces(1)
                .setMinFaceDetectionConfidence(0.5f)
                .setMinFacePresenceConfidence(0.5f)
                .setMinTrackingConfidence(0.5f)
                .build()
            FaceLandmarker.createFromOptions(context, options).also { landmarker = it }
        } catch (e: Throwable) {
            Log.e(TAG, "could not load $MODEL_ASSET", e)
            landmarkerFailed = true
            null
        }
    }

    fun release() {
        landmarker?.close()
        landmarker = null
        readDrawer?.release()
        readDrawer = null
        readBuffer?.release()
        readBuffer = null
        bitmap?.recycle()
        bitmap = null
        smoothedLips = null
        smoothedLeftCheek = null
        smoothedRightCheek = null
        smoothedLeftUnder = null
        smoothedRightUnder = null
    }

    private companion object {
        const val TAG = "FaceLandmarkTracker"
        const val MODEL_ASSET = "face_landmarker.task"
        const val DETECT_WIDTH = 176
        const val SMOOTH = 0.8f
        /** Mean luma below this → treat scene as too dark for makeup. */
        const val DARK_LUMA = 48f
        const val OUTER_EXPAND = 0.12f
        const val INNER_INSET = 0.94f
        const val CHEEK_SEGMENTS = 24

        val FLIP_Y = floatArrayOf(
            1f, 0f, 0f, 0f,
            0f, -1f, 0f, 0f,
            0f, 0f, 1f, 0f,
            0f, 1f, 0f, 1f,
        )

        val OUTER_LIP = intArrayOf(
            61, 185, 40, 39, 37, 0, 267, 269, 270, 409,
            291, 375, 321, 405, 314, 17, 84, 181, 91, 146,
        )
        val INNER_LIP = intArrayOf(
            78, 191, 80, 81, 82, 13, 312, 311, 310, 415,
            308, 324, 318, 402, 317, 14, 87, 178, 88, 95,
        )

        /** Wider apple + mid-cheek cluster so blush covers more of the cheek. */
        val LEFT_CHEEK = intArrayOf(50, 101, 118, 205, 187, 147, 213, 192, 214, 135, 136)
        val RIGHT_CHEEK = intArrayOf(280, 330, 347, 425, 411, 376, 433, 416, 434, 364, 365)

        /** Infraorbital landmarks under each eye (dark-circle zone). */
        val LEFT_UNDER_EYE = intArrayOf(111, 117, 118, 119, 100, 142, 126, 209, 49, 64)
        val RIGHT_UNDER_EYE = intArrayOf(340, 346, 347, 348, 329, 371, 355, 429, 279, 294)
    }
}
