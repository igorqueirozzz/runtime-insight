package dev.queiroz.runtime_insight

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.Debug
import android.os.Handler
import android.os.HandlerThread
import android.os.Process
import android.os.Looper
import android.os.SystemClock
import android.net.TrafficStats
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.File
import java.io.FileReader

class DeviceSpecsPlugin : FlutterPlugin {

    private lateinit var deviceSpecsChannel: MethodChannel
    private lateinit var metricsMethodChannel: MethodChannel
    private lateinit var metricsEventChannel: EventChannel
    private lateinit var applicationContext: Context
    private var metricsEventSink: EventChannel.EventSink? = null
    private var metricsHandlerThread: HandlerThread? = null
    private var metricsHandler: Handler? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var metricsRunnable: Runnable? = null
    private var metricsConfig = MetricsConfig()
    private val cpuTracker = CpuUsageTracker()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        deviceSpecsChannel =
            MethodChannel(binding.binaryMessenger, "runtime_insight/device_specs")
        metricsMethodChannel =
            MethodChannel(binding.binaryMessenger, "runtime_insight/app_metrics")
        metricsEventChannel =
            EventChannel(binding.binaryMessenger, "runtime_insight/app_metrics_stream")

        applicationContext = binding.applicationContext

        deviceSpecsChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "collect" -> {
                    try {
                        result.success(collectSpecs())
                    } catch (e: Exception) {
                        result.error("DEVICE_SPECS_ERROR", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }

        metricsMethodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startMonitoring" -> {
                    val args = call.arguments as? Map<*, *>
                    metricsConfig = MetricsConfig.fromMap(args)
                    startMetrics()
                    result.success(null)
                }
                "updateMonitoring" -> {
                    val args = call.arguments as? Map<*, *>
                    metricsConfig = MetricsConfig.fromMap(args)
                    startMetrics()
                    result.success(null)
                }
                "pauseMonitoring" -> {
                    stopMetrics()
                    result.success(null)
                }
                "resumeMonitoring" -> {
                    startMetrics()
                    result.success(null)
                }
                "stopMonitoring" -> {
                    stopMetrics()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        metricsEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                metricsEventSink = events
                startMetrics()
            }

            override fun onCancel(arguments: Any?) {
                metricsEventSink = null
                stopMetrics()
            }
        })

    }

    private fun collectSpecs(): Map<String, Any?> {
        val cpuCores = Runtime.getRuntime().availableProcessors()
        val ramMb = getTotalRamMb()
        val isEmulator = isEmulator()
        val osVersion = Build.VERSION.RELEASE
        val performanceClass = getPerformanceClass()

        return mapOf(
            "cpuCores" to cpuCores,
            "ramMb" to ramMb,
            "osVersion" to osVersion,
            "performanceClass" to performanceClass,
            "isEmulator" to isEmulator
        )
    }

    private fun getTotalRamMb(): Long {
        val activityManager =
            applicationContext.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager

        val memoryInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memoryInfo)

        return memoryInfo.totalMem / (1024 * 1024)
    }

    private fun getPerformanceClass(): Int? {
        if (Build.VERSION.SDK_INT < 31) return null
        return try {
            val config = applicationContext.resources.configuration
            val method = config.javaClass.getMethod("getDevicePerformanceClass")
            val value = method.invoke(config) as? Number
            value?.toInt()
        } catch (e: Exception) {
            null
        }
    }

    private fun isEmulator(): Boolean {
        return (
                Build.FINGERPRINT.startsWith("generic") ||
                        Build.FINGERPRINT.lowercase().contains("emulator") ||
                        Build.MODEL.contains("Emulator") ||
                        Build.MODEL.contains("Android SDK built for") ||
                        Build.BRAND.startsWith("generic") ||
                        Build.DEVICE.startsWith("generic") ||
                        Build.PRODUCT.contains("sdk") ||
                        Build.HARDWARE.contains("goldfish") ||
                        Build.HARDWARE.contains("ranchu")
                )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        deviceSpecsChannel.setMethodCallHandler(null)
        metricsMethodChannel.setMethodCallHandler(null)
        metricsEventChannel.setStreamHandler(null)
        stopMetrics()
    }

    private fun startMetrics() {
        if (metricsEventSink == null) return
        if (metricsHandlerThread == null) {
            metricsHandlerThread = HandlerThread("RuntimeInsightMetrics").apply { start() }
            metricsHandler = Handler(metricsHandlerThread!!.looper)
        }

        val intervalMs = metricsConfig.intervalMs
        metricsRunnable?.let { metricsHandler?.removeCallbacks(it) }
        metricsRunnable = Runnable {
            val payload = collectAppMetrics()
            mainHandler.post {
                metricsEventSink?.success(payload)
            }
            metricsHandler?.postDelayed(metricsRunnable!!, intervalMs)
        }
        metricsHandler?.post(metricsRunnable!!)
    }

    private fun stopMetrics() {
        metricsRunnable?.let { metricsHandler?.removeCallbacks(it) }
        metricsRunnable = null
        metricsHandlerThread?.quitSafely()
        metricsHandlerThread = null
        metricsHandler = null
    }

    private fun collectAppMetrics(): Map<String, Any> {
        val payload = mutableMapOf<String, Any>()
        payload["timestampMs"] = System.currentTimeMillis()

        if (metricsConfig.cpu) {
            payload["cpuPercent"] = cpuTracker.getCpuPercent() ?: 0.0
        }

        if (metricsConfig.memory) {
            payload["memoryMb"] = getAppMemoryMb()
        }

        if (metricsConfig.network) {
            val uid = applicationContext.applicationInfo.uid
            val rx = TrafficStats.getUidRxBytes(uid)
            val tx = TrafficStats.getUidTxBytes(uid)
            if (rx != TrafficStats.UNSUPPORTED.toLong()) {
                payload["networkRxBytes"] = rx
            }
            if (tx != TrafficStats.UNSUPPORTED.toLong()) {
                payload["networkTxBytes"] = tx
            }
        }

        if (metricsConfig.disk) {
            val io = readProcessIoBytes()
            if (io.first != null) {
                payload["diskReadBytes"] = io.first as Long
            }
            if (io.second != null) {
                payload["diskWriteBytes"] = io.second as Long
            }
        }

        return payload
    }

    private fun getAppMemoryMb(): Double {
        val memoryInfo = Debug.MemoryInfo()
        Debug.getMemoryInfo(memoryInfo)
        return memoryInfo.totalPss / 1024.0
    }

    private fun readProcessIoBytes(): Pair<Long?, Long?> {
        return try {
            var readBytes: Long? = null
            var writeBytes: Long? = null
            File("/proc/self/io").forEachLine { line ->
                when {
                    line.startsWith("read_bytes:") ->
                        readBytes = line.substringAfter(":").trim().toLongOrNull()
                    line.startsWith("write_bytes:") ->
                        writeBytes = line.substringAfter(":").trim().toLongOrNull()
                }
            }
            Pair(readBytes, writeBytes)
        } catch (e: Exception) {
            Pair(null, null)
        }
    }

    private data class MetricsConfig(
        val cpu: Boolean = true,
        val memory: Boolean = true,
        val network: Boolean = true,
        val disk: Boolean = true,
        val intervalMs: Long = 1000L
    ) {
        companion object {
            fun fromMap(map: Map<*, *>?): MetricsConfig {
                if (map == null) return MetricsConfig()
                return MetricsConfig(
                    cpu = map["cpu"] as? Boolean ?: true,
                    memory = map["memory"] as? Boolean ?: true,
                    network = map["network"] as? Boolean ?: true,
                    disk = map["disk"] as? Boolean ?: true,
                    intervalMs = (map["intervalMs"] as? Number)?.toLong() ?: 1000L
                )
            }
        }
    }

    private class CpuUsageTracker {
        private var lastTotal: Long? = null
        private var lastProcess: Long? = null
        private var lastWallMs: Long? = null
        private var lastProcessMs: Long? = null

        fun getCpuPercent(): Double? {
            val stats = readCpuStats()
            if (stats != null) {
                val total = stats.first
                val process = stats.second
                if (lastTotal == null || lastProcess == null) {
                    lastTotal = total
                    lastProcess = process
                    return null
                }

                val totalDelta = total - lastTotal!!
                val processDelta = process - lastProcess!!
                lastTotal = total
                lastProcess = process

                if (totalDelta <= 0L) return null
                val cores = Runtime.getRuntime().availableProcessors().coerceAtLeast(1)
                return (processDelta.toDouble() / totalDelta.toDouble()) * 100.0 / cores
            }

            return getCpuPercentFallback()
        }

        private fun getCpuPercentFallback(): Double? {
            val processMs = Process.getElapsedCpuTime().toLong()
            val wallMs = SystemClock.elapsedRealtime()
            if (lastWallMs == null || lastProcessMs == null) {
                lastWallMs = wallMs
                lastProcessMs = processMs
                return null
            }
            val deltaWall = wallMs - lastWallMs!!
            val deltaProcess = processMs - lastProcessMs!!
            lastWallMs = wallMs
            lastProcessMs = processMs
            if (deltaWall <= 0L) return null
            val cores = Runtime.getRuntime().availableProcessors().coerceAtLeast(1)
            return (deltaProcess.toDouble() / deltaWall.toDouble()) * 100.0 / cores
        }

        private fun readCpuStats(): Pair<Long, Long>? {
            return try {
                val total = readTotalCpuTime()
                val process = readProcessCpuTime()
                if (total == null || process == null) null else Pair(total, process)
            } catch (e: Exception) {
                null
            }
        }

        private fun readTotalCpuTime(): Long? {
            val line = BufferedReader(FileReader("/proc/stat")).use { it.readLine() } ?: return null
            val parts = line.split(Regex("\\s+")).drop(1)
            return parts.mapNotNull { it.toLongOrNull() }.sum()
        }

        private fun readProcessCpuTime(): Long? {
            val line = BufferedReader(FileReader("/proc/self/stat")).use { it.readLine() } ?: return null
            // The second field is the process name in parentheses, which may include spaces.
            val endNameIndex = line.lastIndexOf(')')
            if (endNameIndex < 0 || endNameIndex + 2 >= line.length) return null
            val rest = line.substring(endNameIndex + 2)
            val parts = rest.split(" ")
            if (parts.size < 15) return null
            val utime = parts[11].toLongOrNull() ?: return null
            val stime = parts[12].toLongOrNull() ?: return null
            return utime + stime
        }
    }

}