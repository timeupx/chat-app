package com.example.flutter_app

import android.graphics.Matrix
import android.opengl.GLES20
import com.cloudwebrtc.webrtc.video.LocalVideoTrack
import org.webrtc.GlRectDrawer
import org.webrtc.GlTextureFrameBuffer
import org.webrtc.RendererCommon
import org.webrtc.TextureBufferImpl
import org.webrtc.VideoFrame
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * Draws AR makeup (lipstick, blush, under-eye brightening) into published frames.
 */
class MakeupProcessor(
    private val landmarks: FaceLandmarkTracker,
) : LocalVideoTrack.ExternalVideoFrameProcessing {

    @Volatile
    var lipstickEnabled: Boolean = false

    @Volatile
    var blushEnabled: Boolean = false

    @Volatile
    var underEyeEnabled: Boolean = false

    val enabled: Boolean
        get() = lipstickEnabled || blushEnabled || underEyeEnabled

    @Volatile
    private var lipColor: FloatArray = floatArrayOf(0.78f, 0.09f, 0.25f)

    @Volatile
    private var lipStrength: Float = 0.55f

    @Volatile
    private var blushColor: FloatArray = floatArrayOf(0.86f, 0.48f, 0.52f)

    @Volatile
    private var blushStrength: Float = 0.24f

    /** Warm mid-tone — pure cream looks like a flashlight patch in dim rooms. */
    @Volatile
    private var underEyeColor: FloatArray = floatArrayOf(0.88f, 0.74f, 0.68f)

    @Volatile
    private var underEyeStrength: Float = 0.28f

    /** Fired on the capturer thread when darkness is sustained — channel posts to UI. */
    var onLowLight: (() -> Unit)? = null

    /** Fired when light is good again after a low-light pause — resume drawing. */
    var onLightRestored: (() -> Unit)? = null

    private var darkStreak = 0
    private var brightStreak = 0
    /** Makeup stays selected but is not drawn until light returns. */
    @Volatile
    private var pausedByLowLight = false

    private var drawer: GlRectDrawer? = null
    private val frameBuffers = arrayOfNulls<GlTextureFrameBuffer>(FRAME_BUFFER_COUNT)
    private var frameBufferIndex = 0

    private var meshProgram: Int = 0
    private var meshPositionHandle: Int = 0
    private var meshAlphaHandle: Int = 0
    private var meshColorHandle: Int = 0
    private var vertexBuffer: FloatBuffer =
        ByteBuffer.allocateDirect(MAX_MESH_VERTICES * 3 * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()

    fun setLipstick(red: Float, green: Float, blue: Float, strength: Float) {
        lipColor = floatArrayOf(red, green, blue)
        lipStrength = strength
    }

    fun setBlush(red: Float, green: Float, blue: Float, strength: Float) {
        blushColor = floatArrayOf(red, green, blue)
        blushStrength = strength
    }

    fun setUnderEye(red: Float, green: Float, blue: Float, strength: Float) {
        underEyeColor = floatArrayOf(red, green, blue)
        underEyeStrength = strength
    }

    fun resetLowLightPause() {
        pausedByLowLight = false
        darkStreak = 0
        brightStreak = 0
    }

    override fun onFrame(frame: VideoFrame): VideoFrame {
        val buffer = frame.buffer
        if (!enabled || buffer !is VideoFrame.TextureBuffer) return frame

        return try {
            renderFrame(frame, buffer)
        } catch (e: Throwable) {
            android.util.Log.e(TAG, "makeup render failed", e)
            frame
        }
    }

    private fun renderFrame(frame: VideoFrame, buffer: VideoFrame.TextureBuffer): VideoFrame {
        val rotation = ((frame.rotation % 360) + 360) % 360
        val swap = rotation == 90 || rotation == 270
        val outWidth = if (swap) buffer.height else buffer.width
        val outHeight = if (swap) buffer.width else buffer.height

        frameBufferIndex = (frameBufferIndex + 1) % FRAME_BUFFER_COUNT
        val fbo = frameBuffers[frameBufferIndex]
            ?: GlTextureFrameBuffer(GLES20.GL_RGBA).also { frameBuffers[frameBufferIndex] = it }
        fbo.setSize(outWidth, outHeight)
        val rectDrawer = drawer ?: GlRectDrawer().also { drawer = it }

        val texMatrix = Matrix(buffer.transformMatrix).apply {
            preTranslate(0.5f, 0.5f)
            preRotate(rotation.toFloat())
            preTranslate(-0.5f, -0.5f)
        }
        val glMatrix = RendererCommon.convertMatrixFromAndroidGraphicsMatrix(texMatrix)

        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fbo.frameBufferId)
        GLES20.glViewport(0, 0, outWidth, outHeight)
        GLES20.glDisable(GLES20.GL_BLEND)

        when (buffer.type) {
            VideoFrame.TextureBuffer.Type.OES -> rectDrawer.drawOes(
                buffer.textureId, glMatrix, outWidth, outHeight, 0, 0, outWidth, outHeight,
            )
            else -> rectDrawer.drawRgb(
                buffer.textureId, glMatrix, outWidth, outHeight, 0, 0, outWidth, outHeight,
            )
        }

        val detected = landmarks.detectForFrame(fbo, outWidth, outHeight)
        if (detected.tooDark) {
            brightStreak = 0
            darkStreak++
            // ~3 frames at 24fps ≈ 125ms — pause drawing (keep selections).
            if (darkStreak >= 3 && !pausedByLowLight) {
                pausedByLowLight = true
                onLowLight?.invoke()
            }
        } else {
            darkStreak = 0
            if (pausedByLowLight) {
                brightStreak++
                // Need a short bright streak so flicker does not thrash on/off.
                if (brightStreak >= 5) {
                    pausedByLowLight = false
                    brightStreak = 0
                    onLightRestored?.invoke()
                }
            } else {
                brightStreak = 0
            }
            val meshes = detected.meshes
            if (!pausedByLowLight && meshes != null) {
                if (underEyeEnabled) {
                    drawSoftFan(meshes.leftUnderEye, underEyeColor, underEyeStrength)
                    drawSoftFan(meshes.rightUnderEye, underEyeColor, underEyeStrength)
                }
                if (blushEnabled) {
                    drawSoftFan(meshes.leftCheek, blushColor, blushStrength)
                    drawSoftFan(meshes.rightCheek, blushColor, blushStrength)
                }
                if (lipstickEnabled) {
                    drawLipStrip(meshes.lips, lipColor, lipStrength)
                }
            }
        }

        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)

        val source = buffer as TextureBufferImpl
        val outBuffer = TextureBufferImpl(
            outWidth,
            outHeight,
            VideoFrame.TextureBuffer.Type.RGB,
            fbo.textureId,
            Matrix(),
            source.toI420Handler,
            source.yuvConverter,
            Runnable {},
        )
        return VideoFrame(outBuffer, 0, frame.timestampNs)
    }

    /** Lip triangle strip: packed as x,y pairs (alpha forced to 1). */
    private fun drawLipStrip(mesh: FloatArray?, color: FloatArray, strength: Float) {
        if (mesh == null || mesh.size < 8) return
        val vertexCount = minOf(mesh.size / 2, MAX_MESH_VERTICES)
        vertexBuffer.clear()
        for (i in 0 until vertexCount) {
            vertexBuffer.put(mesh[i * 2] * 2f - 1f)
            vertexBuffer.put(1f - mesh[i * 2 + 1] * 2f)
            vertexBuffer.put(1f)
        }
        vertexBuffer.position(0)
        drawVertices(vertexCount, GLES20.GL_TRIANGLE_STRIP, color, strength)
    }

    /** Cheek fan: packed as x,y,alpha triples. */
    private fun drawSoftFan(mesh: FloatArray?, color: FloatArray, strength: Float) {
        if (mesh == null || mesh.size < 9) return
        val vertexCount = minOf(mesh.size / 3, MAX_MESH_VERTICES)
        vertexBuffer.clear()
        for (i in 0 until vertexCount) {
            val x = mesh[i * 3]
            val y = mesh[i * 3 + 1]
            val a = mesh[i * 3 + 2]
            vertexBuffer.put(x * 2f - 1f)
            vertexBuffer.put(1f - y * 2f)
            vertexBuffer.put(a)
        }
        vertexBuffer.position(0)
        drawVertices(vertexCount, GLES20.GL_TRIANGLE_FAN, color, strength)
    }

    private fun drawVertices(
        vertexCount: Int,
        mode: Int,
        color: FloatArray,
        strength: Float,
    ) {
        val program = meshProgram.takeIf { it != 0 } ?: createMeshProgram()
        GLES20.glUseProgram(program)
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        GLES20.glUniform4f(meshColorHandle, color[0], color[1], color[2], strength)
        GLES20.glEnableVertexAttribArray(meshPositionHandle)
        GLES20.glEnableVertexAttribArray(meshAlphaHandle)
        GLES20.glVertexAttribPointer(
            meshPositionHandle, 2, GLES20.GL_FLOAT, false, 12, vertexBuffer,
        )
        vertexBuffer.position(2)
        GLES20.glVertexAttribPointer(
            meshAlphaHandle, 1, GLES20.GL_FLOAT, false, 12, vertexBuffer,
        )
        vertexBuffer.position(0)
        GLES20.glDrawArrays(mode, 0, vertexCount)
        GLES20.glDisableVertexAttribArray(meshPositionHandle)
        GLES20.glDisableVertexAttribArray(meshAlphaHandle)
        GLES20.glDisable(GLES20.GL_BLEND)
    }

    private fun createMeshProgram(): Int {
        val vertex = compile(GLES20.GL_VERTEX_SHADER, VERTEX_SHADER)
        val fragment = compile(GLES20.GL_FRAGMENT_SHADER, FRAGMENT_SHADER)
        val program = GLES20.glCreateProgram()
        GLES20.glAttachShader(program, vertex)
        GLES20.glAttachShader(program, fragment)
        GLES20.glLinkProgram(program)
        val status = IntArray(1)
        GLES20.glGetProgramiv(program, GLES20.GL_LINK_STATUS, status, 0)
        check(status[0] == GLES20.GL_TRUE) {
            "makeup shader link failed: ${GLES20.glGetProgramInfoLog(program)}"
        }
        meshProgram = program
        meshPositionHandle = GLES20.glGetAttribLocation(program, "aPosition")
        meshAlphaHandle = GLES20.glGetAttribLocation(program, "aAlpha")
        meshColorHandle = GLES20.glGetUniformLocation(program, "uColor")
        return program
    }

    private fun compile(type: Int, source: String): Int {
        val shader = GLES20.glCreateShader(type)
        GLES20.glShaderSource(shader, source)
        GLES20.glCompileShader(shader)
        val status = IntArray(1)
        GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, status, 0)
        check(status[0] == GLES20.GL_TRUE) {
            "makeup shader compile failed: ${GLES20.glGetShaderInfoLog(shader)}"
        }
        return shader
    }

    fun release() {
        drawer?.release()
        drawer = null
        for (i in frameBuffers.indices) {
            frameBuffers[i]?.release()
            frameBuffers[i] = null
        }
        if (meshProgram != 0) {
            GLES20.glDeleteProgram(meshProgram)
            meshProgram = 0
        }
    }

    private companion object {
        const val TAG = "MakeupProcessor"
        const val MAX_MESH_VERTICES = 512
        const val FRAME_BUFFER_COUNT = 3

        const val VERTEX_SHADER = """
            attribute vec2 aPosition;
            attribute float aAlpha;
            varying float vAlpha;
            void main() {
              vAlpha = aAlpha;
              gl_Position = vec4(aPosition, 0.0, 1.0);
            }
        """

        const val FRAGMENT_SHADER = """
            precision mediump float;
            uniform vec4 uColor;
            varying float vAlpha;
            void main() {
              // Squared falloff softens the rim and avoids a hard glow in dim light.
              float a = vAlpha * vAlpha;
              gl_FragColor = vec4(uColor.rgb, uColor.a * a);
            }
        """
    }
}
