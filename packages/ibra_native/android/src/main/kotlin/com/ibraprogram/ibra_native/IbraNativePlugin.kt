package com.ibraprogram.ibra_native

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.TimeZone
import java.util.concurrent.Executors

/**
 * IBRA BOOKING — التكاملات الأصلية على أندرويد:
 * تحويل الأصوات إلى WAV مع القص (MediaCodec)، تسجيلها كأصوات إشعارات (MediaStore)،
 * المعاينة (MediaPlayer)، المنطقة الزمنية، وإعدادات البطارية.
 */
class IbraNativePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private var stopRunnable: Runnable? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.ibraprogram/ibra_native")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        stopPlayer()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "timeZone" -> result.success(TimeZone.getDefault().id)
            "decodeToWav" -> background(result) {
                decodeToWav(
                    call.argument<String>("input")!!,
                    call.argument<String>("output")!!,
                    (call.argument<Number>("startMs") ?: 0).toLong(),
                    (call.argument<Number>("endMs") ?: 0).toLong(),
                    (call.argument<Number>("maxMs") ?: 29000).toLong(),
                ).toInt()
            }
            "durationMs" -> background(result) { durationOf(call.argument<String>("path")!!).toInt() }
            "registerSound" -> background(result) {
                registerSound(call.argument<String>("path")!!, call.argument<String>("title") ?: "IBRA")
            }
            "unregisterSound" -> background(result) {
                val uri = Uri.parse(call.argument<String>("uri")!!)
                if (uri.authority == MediaStore.AUTHORITY) {
                    try { context.contentResolver.delete(uri, null, null) } catch (_: Exception) {}
                }
                null
            }
            "play" -> {
                try {
                    play(
                        call.argument<String>("path")!!,
                        (call.argument<Number>("volume") ?: 1.0).toFloat(),
                        (call.argument<Number>("startMs") ?: 0).toInt(),
                        (call.argument<Number>("endMs") ?: 0).toInt(),
                        call.argument<Boolean>("loop") ?: false,
                    )
                    result.success(null)
                } catch (e: Exception) {
                    result.error("play_failed", e.message, null)
                }
            }
            "stop" -> { stopPlayer(); result.success(null) }
            "isIgnoringBatteryOptimizations" -> {
                val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                result.success(pm.isIgnoringBatteryOptimizations(context.packageName))
            }
            "openBatterySettings" -> {
                try {
                    val i = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                    i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(i)
                } catch (_: Exception) {}
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        executor.execute {
            try {
                val v = work()
                main.post { result.success(v) }
            } catch (e: Exception) {
                main.post { result.error("native_error", e.message ?: e.toString(), null) }
            }
        }
    }

    // ---------------- تحويل الصوت ----------------

    private fun decodeToWav(input: String, output: String, startMs: Long, endMs: Long, maxMs: Long): Long {
        val extractor = MediaExtractor()
        extractor.setDataSource(input)
        var trackIndex = -1
        var format: MediaFormat? = null
        for (i in 0 until extractor.trackCount) {
            val f = extractor.getTrackFormat(i)
            val mime = f.getString(MediaFormat.KEY_MIME) ?: ""
            if (mime.startsWith("audio/")) {
                trackIndex = i
                format = f
                break
            }
        }
        if (trackIndex < 0 || format == null) {
            extractor.release()
            throw IllegalArgumentException("لا يحتوي الملف على مسار صوتي")
        }
        extractor.selectTrack(trackIndex)
        val mime = format.getString(MediaFormat.KEY_MIME)!!
        var sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        var pcmEncoding = AudioFormat.ENCODING_PCM_16BIT

        val startUs = startMs * 1000
        val endUs = if (endMs > startMs) endMs * 1000 else Long.MAX_VALUE
        val stopUs = minOf(endUs, startUs + maxMs * 1000)
        if (startUs > 0) extractor.seekTo(startUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)

        val codec = MediaCodec.createDecoderByType(mime)
        codec.configure(format, null, null, 0)
        codec.start()
        val pcm = ByteArrayOutputStream()
        val info = MediaCodec.BufferInfo()
        var inputDone = false
        var outputDone = false
        var guard = 0
        while (!outputDone && guard < 2_000_000) {
            guard++
            if (!inputDone) {
                val inIdx = codec.dequeueInputBuffer(10_000)
                if (inIdx >= 0) {
                    val buf = codec.getInputBuffer(inIdx)!!
                    val size = extractor.readSampleData(buf, 0)
                    if (size < 0 || extractor.sampleTime > stopUs) {
                        codec.queueInputBuffer(inIdx, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        inputDone = true
                    } else {
                        codec.queueInputBuffer(inIdx, 0, size, extractor.sampleTime, 0)
                        extractor.advance()
                    }
                }
            }
            val outIdx = codec.dequeueOutputBuffer(info, 10_000)
            if (outIdx >= 0) {
                val out = codec.getOutputBuffer(outIdx)
                if (out != null && info.size > 0 && info.presentationTimeUs >= startUs && info.presentationTimeUs < stopUs) {
                    val chunk = ByteArray(info.size)
                    out.position(info.offset)
                    out.get(chunk)
                    if (pcmEncoding == AudioFormat.ENCODING_PCM_FLOAT) {
                        pcm.write(floatToPcm16(chunk))
                    } else {
                        pcm.write(chunk)
                    }
                }
                codec.releaseOutputBuffer(outIdx, false)
                if ((info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) outputDone = true
            } else if (outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                val nf = codec.outputFormat
                sampleRate = nf.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                channels = nf.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                if (Build.VERSION.SDK_INT >= 24 && nf.containsKey(MediaFormat.KEY_PCM_ENCODING)) {
                    pcmEncoding = nf.getInteger(MediaFormat.KEY_PCM_ENCODING)
                }
            }
        }
        codec.stop()
        codec.release()
        extractor.release()

        val data = pcm.toByteArray()
        val outFile = File(output)
        outFile.parentFile?.mkdirs()
        FileOutputStream(outFile).use { fos ->
            fos.write(wavHeader(data.size, sampleRate, channels))
            fos.write(data)
        }
        val bytesPerSec = sampleRate.toLong() * channels * 2
        return if (bytesPerSec > 0) data.size * 1000L / bytesPerSec else 0L
    }

    private fun floatToPcm16(src: ByteArray): ByteArray {
        val fb = ByteBuffer.wrap(src).order(ByteOrder.nativeOrder()).asFloatBuffer()
        val out = ByteBuffer.allocate(fb.remaining() * 2).order(ByteOrder.LITTLE_ENDIAN)
        while (fb.hasRemaining()) {
            val v = fb.get().coerceIn(-1f, 1f)
            out.putShort((v * 32767f).toInt().toShort())
        }
        return out.array()
    }

    private fun wavHeader(dataLen: Int, sampleRate: Int, channels: Int): ByteArray {
        val b = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
        val byteRate = sampleRate * channels * 2
        b.put("RIFF".toByteArray(Charsets.US_ASCII))
        b.putInt(36 + dataLen)
        b.put("WAVE".toByteArray(Charsets.US_ASCII))
        b.put("fmt ".toByteArray(Charsets.US_ASCII))
        b.putInt(16)
        b.putShort(1)
        b.putShort(channels.toShort())
        b.putInt(sampleRate)
        b.putInt(byteRate)
        b.putShort((channels * 2).toShort())
        b.putShort(16)
        b.put("data".toByteArray(Charsets.US_ASCII))
        b.putInt(dataLen)
        return b.array()
    }

    private fun durationOf(path: String): Long {
        val r = MediaMetadataRetriever()
        return try {
            r.setDataSource(path)
            r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
        } catch (_: Exception) {
            0L
        } finally {
            try { r.release() } catch (_: Exception) {}
        }
    }

    // ---------------- تسجيل صوت الإشعار ----------------

    private fun registerSound(path: String, title: String): String {
        val src = File(path)
        if (!src.exists()) throw IllegalArgumentException("الملف غير موجود")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = context.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.Audio.Media.DISPLAY_NAME, "${title.replace(Regex("[\\\\/:*?\"<>|]"), "_")}_${System.currentTimeMillis()}.wav")
                put(MediaStore.Audio.Media.TITLE, title)
                put(MediaStore.Audio.Media.MIME_TYPE, "audio/x-wav")
                put(MediaStore.Audio.Media.RELATIVE_PATH, Environment.DIRECTORY_NOTIFICATIONS + "/IBRA Booking")
                put(MediaStore.Audio.Media.IS_NOTIFICATION, 1)
                put(MediaStore.Audio.Media.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("تعذر حفظ الصوت")
            resolver.openOutputStream(uri)?.use { os -> FileInputStream(src).use { it.copyTo(os) } }
            values.clear()
            values.put(MediaStore.Audio.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return uri.toString()
        }
        // أندرويد 9 وأقدم: FileProvider مع منح صلاحية القراءة لواجهة النظام
        val uri = FileProvider.getUriForFile(context, context.packageName + ".ibra_native.fileprovider", src)
        context.grantUriPermission("com.android.systemui", uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        context.grantUriPermission("android", uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        return uri.toString()
    }

    // ---------------- المعاينة ----------------

    private fun play(path: String, volume: Float, startMs: Int, endMs: Int, loop: Boolean) {
        stopPlayer()
        val mp = MediaPlayer()
        mp.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        )
        mp.setDataSource(path)
        mp.isLooping = loop && endMs <= startMs
        mp.setVolume(volume, volume)
        mp.setOnCompletionListener { stopPlayer() }
        mp.prepare()
        if (startMs > 0) mp.seekTo(startMs)
        mp.start()
        player = mp
        if (endMs > startMs) {
            val r = Runnable { stopPlayer() }
            stopRunnable = r
            main.postDelayed(r, (endMs - startMs).toLong())
        }
    }

    private fun stopPlayer() {
        stopRunnable?.let { main.removeCallbacks(it) }
        stopRunnable = null
        player?.let {
            try { if (it.isPlaying) it.stop() } catch (_: Exception) {}
            it.release()
        }
        player = null
    }
}
