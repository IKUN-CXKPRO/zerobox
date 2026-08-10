package org.zxor.oronbox

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.app.Dialog
import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Environment
import android.provider.MediaStore
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.ViewGroup
import android.view.Window
import android.webkit.CookieManager
import android.webkit.JavascriptInterface
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference

class MainActivity : FlutterActivity() {
    @Volatile
    private var sppSocket: BluetoothSocket? = null
    @Volatile
    private var connectingSocket: BluetoothSocket? = null
    private var readThread: Thread? = null
    private var eventSink: EventChannel.EventSink? = null
    private var scanEventSink: EventChannel.EventSink? = null
    private val scanResults = linkedMapOf<String, Map<String, Any?>>()
    private var scanReceiver: BroadcastReceiver? = null
    private var scanStopRunnable: Runnable? = null
    private var scanGeneration: Long = 0
    private val mainHandler = Handler(Looper.getMainLooper())
    private val sppUuid: UUID = UUID.fromString("00001101-0000-1000-8000-00805f9b34fb")
    private val sendLock = Object()
    private val sendExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val connectGeneration = AtomicLong(0)
    private val backgroundTaskIds = mutableSetOf<Int>()
    private var nextBackgroundTaskId = 0
    private var connectionLabel: String? = null
    private var lastTaskLabel: String? = null
    private var zeppSettingsContainer: ViewGroup? = null
    private var zeppSettingsWebView: WebView? = null
    private var zeppSettingsAppId: Long? = null
    private var zeppSettingsChannel: MethodChannel? = null
    private var xmsWearableChannel: MethodChannel? = null
    private var fileOpenChannel: MethodChannel? = null
    private var pendingOpenFilePath: String? = null

    private fun startBackgroundService(label: String, mode: String) {
        val intent = Intent(this, BackgroundTaskService::class.java).apply {
            putExtra(BackgroundTaskService.EXTRA_LABEL, label)
            putExtra(BackgroundTaskService.EXTRA_MODE, mode)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopBackgroundServiceIfIdle() {
        if (backgroundTaskIds.isEmpty() && connectionLabel == null) {
            stopService(Intent(this, BackgroundTaskService::class.java))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        fileOpenChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "oronbox/file_open",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialFile" -> result.success(pendingOpenFilePath)
                    else -> result.notImplemented()
                }
            }
            resolveOpenIntent(intent)?.let { path ->
                pendingOpenFilePath = path
                channel.invokeMethod("openFile", path)
            }
        }
        xmsWearableChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "oronbox/xms_wearable",
        ).also(XmsWearableBridge::attach)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "oronbox/background_tasks",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "begin" -> {
                    val id = ++nextBackgroundTaskId
                    backgroundTaskIds.add(id)
                    lastTaskLabel = call.argument<String>("label") ?: "Installing resources"
                    startBackgroundService(
                        lastTaskLabel!!,
                        BackgroundTaskService.MODE_TASK,
                    )
                    result.success(id)
                }
                "end" -> {
                    call.argument<Int>("id")?.let(backgroundTaskIds::remove)
                    if (backgroundTaskIds.isEmpty()) {
                        lastTaskLabel = null
                        connectionLabel?.let {
                            startBackgroundService(
                                it,
                                BackgroundTaskService.MODE_CONNECTION,
                            )
                        }
                    }
                    stopBackgroundServiceIfIdle()
                    result.success(null)
                }
                // Keeps the process (and the BLE link) alive while a device
                // is connected; task labels take precedence while both run.
                "beginConnection" -> {
                    connectionLabel = call.argument<String>("label") ?: "Device connected"
                    startBackgroundService(
                        lastTaskLabel ?: connectionLabel!!,
                        if (lastTaskLabel == null) {
                            BackgroundTaskService.MODE_CONNECTION
                        } else {
                            BackgroundTaskService.MODE_TASK
                        },
                    )
                    result.success(null)
                }
                "endConnection" -> {
                    connectionLabel = null
                    lastTaskLabel?.let {
                        startBackgroundService(it, BackgroundTaskService.MODE_TASK)
                    }
                    stopBackgroundServiceIfIdle()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "oronbox/logs",
        ).setMethodCallHandler { call, result ->
            val authority = "${applicationContext.packageName}.logs"
            when (call.method) {
                "open" -> {
                    val rootUri = android.provider.DocumentsContract.buildRootUri(authority, "logs")
                    val browse = Intent("android.provider.action.BROWSE").apply {
                        setDataAndType(rootUri, android.provider.DocumentsContract.Root.MIME_TYPE_ITEM)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    try {
                        startActivity(browse)
                        result.success(true)
                    } catch (_: Exception) {
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, rootUri))
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("OPEN_LOGS_FAILED", error.message, null)
                        }
                    }
                }
                "share" -> {
                    val name = call.argument<String>("name")
                    val file = name?.takeIf {
                        !it.contains('/') && !it.contains('\\') &&
                            (it.endsWith(".log") || it.endsWith(".zip"))
                    }?.let { java.io.File(filesDir, "logs/$it") }
                    if (file == null || !file.isFile) {
                        result.error("LOG_NOT_FOUND", name, null)
                    } else {
                        val uri = android.provider.DocumentsContract.buildDocumentUri(authority, file.name)
                        val share = Intent(Intent.ACTION_SEND).apply {
                            type = if (file.extension == "zip") "application/zip" else "text/plain"
                            putExtra(Intent.EXTRA_STREAM, uri)
                            clipData = ClipData.newRawUri(file.name, uri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        try {
                            startActivity(Intent.createChooser(share, file.name))
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("SHARE_LOG_FAILED", error.message, null)
                        }
                    }
                }
                "export" -> {
                    val name = call.argument<String>("name")
                    val source = name?.takeIf {
                        !it.contains('/') && !it.contains('\\') && it.endsWith(".zip")
                    }?.let { java.io.File(filesDir, "logs/$it") }
                    if (source == null || !source.isFile) {
                        result.error("LOG_EXPORT_NOT_FOUND", name, null)
                    } else if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                        result.error("LOG_EXPORT_UNSUPPORTED", "Android 10 or newer is required", null)
                    } else {
                        val values = ContentValues().apply {
                            put(MediaStore.MediaColumns.DISPLAY_NAME, source.name)
                            put(MediaStore.MediaColumns.MIME_TYPE, "application/zip")
                            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOCUMENTS)
                            put(MediaStore.MediaColumns.IS_PENDING, 1)
                        }
                        var uri: android.net.Uri? = null
                        try {
                            uri = contentResolver.insert(
                                MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY),
                                values,
                            ) ?: throw java.io.IOException("Unable to create exported log file")
                            contentResolver.openOutputStream(uri, "w").use { output ->
                                if (output == null) throw java.io.IOException("Unable to open exported log file")
                                source.inputStream().use { input -> input.copyTo(output) }
                            }
                            values.clear()
                            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                            contentResolver.update(uri, values, null, null)
                            result.success("${Environment.getExternalStorageDirectory().path}/${Environment.DIRECTORY_DOCUMENTS}/${source.name}")
                        } catch (error: Exception) {
                            if (uri != null) contentResolver.delete(uri, null, null)
                            result.error("LOG_EXPORT_FAILED", error.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "oronbox/installer",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSupportedAbi" -> {
                    result.success(Build.SUPPORTED_ABIS.firstOrNull())
                }
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("INVALID_ARGUMENT", "path is required", null)
                        return@setMethodCallHandler
                    }
                    val file = File(path)
                    if (!file.isFile) {
                        result.error("APK_NOT_FOUND", path, null)
                        return@setMethodCallHandler
                    }
                    val uri = FileProvider.getUriForFile(
                        this,
                        "${packageName}.apk",
                        file,
                    )
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "application/vnd.android.package-archive")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    try {
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "oronbox/classic_spp",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermissions" -> {
                    requestBluetoothPermissionsIfNeeded()
                    result.success(null)
                }
                "startScan" -> startSppScan(call, result)
                "stopScan" -> {
                    val results = stopSppScan()
                    result.success(results)
                }
                "connect" -> connect(call, result)
                "send" -> send(call, result)
                "disconnect" -> {
                    disconnect()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "oronbox/classic_spp/events",
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "oronbox/classic_spp/scan_events",
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                scanEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                scanEventSink = null
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "oronbox/mi_account_2fa",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "resolve" -> resolveMiAccountTwoFactor(call, result)
                else -> result.notImplemented()
            }
        }
        zeppSettingsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "oronbox/zeppos_app_settings",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "open" -> openZeppSettings(call, result)
                    "close" -> {
                        closeZeppSettings(notify = false)
                        result.success(null)
                    }
                    "settingsChanged" -> {
                        val appId = call.argument<Number>("appId")?.toLong()
                        val settingsJson = call.argument<String>("settingsJson")
                        if (appId == zeppSettingsAppId && settingsJson != null) {
                            zeppSettingsWebView?.evaluateJavascript(
                                "globalThis.__oronboxSettingsChanged($settingsJson)",
                                null,
                            )
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        requestBluetoothPermissionsIfNeeded()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val path = resolveOpenIntent(intent) ?: return
        pendingOpenFilePath = path
        // Warm start: the Dart handler is already listening; push directly.
        fileOpenChannel?.invokeMethod("openFile", path)
    }

    /** Copies an "open with" content/file URI into the cache and returns the
     *  local path, or null when the intent carries no openable file. */
    private fun resolveOpenIntent(intent: Intent?): String? {
        val uri = intent?.data ?: return null
        val scheme = uri.scheme
        if (scheme != "content" && scheme != "file") return null
        return try {
            val name = uri.lastPathSegment?.takeIf { it.isNotBlank() } ?: "opened-file"
            val dir = java.io.File(cacheDir, "file_open").apply { mkdirs() }
            val target = java.io.File(dir, name)
            contentResolver.openInputStream(uri)?.use { input ->
                target.outputStream().use { output -> input.copyTo(output) }
            }
            target.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun openZeppSettings(call: MethodCall, result: MethodChannel.Result) {
        val appId = call.argument<Number>("appId")?.toLong()
        val html = call.argument<String>("html")
        val contentTop = call.argument<Number>("contentTop")?.toFloat() ?: 0f
        if (appId == null || html == null) {
            result.error("INVALID_ARGUMENT", "appId and html are required", null)
            return
        }
        mainHandler.post {
            closeZeppSettings(notify = false)
            val density = resources.displayMetrics.density
            val container = FrameLayout(this).apply {
                isClickable = true
                isFocusable = true
                elevation = 1f * density
            }
            val webView = WebView(this)
            webView.settings.javaScriptEnabled = true
            webView.settings.domStorageEnabled = false
            webView.settings.allowFileAccess = false
            webView.settings.allowContentAccess = false
            webView.webChromeClient = WebChromeClient()
            webView.webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean {
                    if (url == null || url == "about:blank") return false
                    runCatching { startActivity(Intent(Intent.ACTION_VIEW, android.net.Uri.parse(url))) }
                    return true
                }
            }
            webView.addJavascriptInterface(object {
                @JavascriptInterface
                fun postMessage(message: String) {
                    val value = runCatching { org.json.JSONObject(message) }.getOrNull() ?: return
                    val type = value.optString("type")
                    val args = mutableMapOf<String, Any?>("appId" to appId)
                    value.keys().forEach { key -> if (key != "type") args[key] = value.opt(key) }
                    mainHandler.post { zeppSettingsChannel?.invokeMethod(type, args) }
                }
            }, "ZeppSettingsBridge")
            container.addView(
                webView,
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                ),
            )
            findViewById<ViewGroup>(android.R.id.content).addView(
                container,
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                ).apply { topMargin = (contentTop * density).toInt() },
            )
            zeppSettingsContainer = container
            zeppSettingsWebView = webView
            zeppSettingsAppId = appId
            webView.loadDataWithBaseURL(null, html, "text/html", "UTF-8", null)
            result.success(null)
        }
    }

    private fun closeZeppSettings(notify: Boolean = true) {
        val appId = zeppSettingsAppId
        val webView = zeppSettingsWebView
        val container = zeppSettingsContainer
        zeppSettingsContainer = null
        zeppSettingsWebView = null
        zeppSettingsAppId = null
        (container?.parent as? ViewGroup)?.removeView(container)
        webView?.removeJavascriptInterface("ZeppSettingsBridge")
        webView?.stopLoading()
        webView?.loadUrl("about:blank")
        webView?.destroy()
        if (notify && appId != null) {
            zeppSettingsChannel?.invokeMethod("closed", mapOf("appId" to appId))
        }
    }

    @SuppressLint("MissingPermission")
    private fun startSppScan(call: MethodCall, result: MethodChannel.Result) {
        if (!hasBluetoothScanPermission() || !hasBluetoothConnectPermission()) {
            requestBluetoothPermissionsIfNeeded()
            result.error("MISSING_PERMISSION", "Bluetooth permission is required", null)
            return
        }
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null) {
            result.error("ADAPTER_UNAVAILABLE", "BluetoothAdapter is unavailable", null)
            return
        }

        stopSppScan()
        val generation = ++scanGeneration
        scanResults.clear()

        adapter.bondedDevices?.forEach { device ->
            emitSppScanDevice(device)
        }

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    BluetoothDevice.ACTION_FOUND -> {
                        val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            intent.getParcelableExtra(
                                BluetoothDevice.EXTRA_DEVICE,
                                BluetoothDevice::class.java,
                            )
                        } else {
                            @Suppress("DEPRECATION")
                            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                        }
                        if (device != null) emitSppScanDevice(device)
                    }
                    BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> {
                        mainHandler.postDelayed({
                            if (scanReceiver != null) {
                                runCatching { adapter.startDiscovery() }
                            }
                        }, 800)
                    }
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_FOUND)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, RECEIVER_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(receiver, filter)
        }
        scanReceiver = receiver
        if (adapter.isDiscovering) adapter.cancelDiscovery()
        if (!adapter.startDiscovery()) {
            stopSppScan()
            result.error("SCAN_FAILED", "startDiscovery() failed", null)
            return
        }

        val timeoutMs = call.argument<Int>("timeoutMs") ?: 15_000
        val stopRunnable = Runnable {
            if (scanGeneration == generation) {
                stopSppScan()
            }
        }
        scanStopRunnable = stopRunnable
        mainHandler.postDelayed(stopRunnable, timeoutMs.toLong())
        result.success(null)
    }

    @SuppressLint("MissingPermission")
    private fun emitSppScanDevice(device: BluetoothDevice) {
        val addr = device.address ?: return
        val item = mapOf(
            "name" to (device.name ?: "Unknown device"),
            "addr" to addr,
            "connectType" to "spp",
        )
        if (scanResults.containsKey(addr)) return
        scanResults[addr] = item
        mainHandler.post { scanEventSink?.success(item) }
    }

    @SuppressLint("MissingPermission")
    private fun stopSppScan(): List<Map<String, Any?>> {
        scanStopRunnable?.let { mainHandler.removeCallbacks(it) }
        scanStopRunnable = null
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter?.isDiscovering == true) {
            adapter.cancelDiscovery()
        }
        scanReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: IllegalArgumentException) {
            }
        }
        scanReceiver = null
        return scanResults.values.toList()
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun resolveMiAccountTwoFactor(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        if (url.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "url is required", null)
            return
        }

        mainHandler.post {
            val dialog = Dialog(this)
            dialog.requestWindowFeature(Window.FEATURE_NO_TITLE)
            val webView = WebView(this)
            var completed = false
            val cookieManager = CookieManager.getInstance()
            cookieManager.setAcceptCookie(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                cookieManager.setAcceptThirdPartyCookies(webView, true)
            }

            fun cookieHeaderFor(currentUrl: String?): String {
                val values = linkedMapOf<String, String>()
                listOf(
                    currentUrl,
                    "https://account.xiaomi.com",
                    "https://mi.com",
                    "https://xiaomi.com",
                ).filterNotNull().forEach { cookieUrl ->
                    cookieManager.getCookie(cookieUrl)
                        ?.split(";")
                        ?.map { it.trim() }
                        ?.filter { it.contains("=") }
                        ?.forEach { pair ->
                            val index = pair.indexOf("=")
                            val name = pair.substring(0, index).trim()
                            val value = pair.substring(index + 1).trim()
                            if (name.isNotEmpty() && value.isNotEmpty()) {
                                values[name] = value
                            }
                        }
                }
                return values.entries.joinToString("; ") { "${it.key}=${it.value}" }
            }

            fun hasSessionCookie(header: String): Boolean {
                val names = header.split(";")
                    .mapNotNull { pair ->
                        val index = pair.indexOf("=")
                        if (index <= 0) null else pair.substring(0, index).trim()
                    }
                    .toSet()
                return names.contains("passToken") ||
                    names.contains("cUserId") ||
                    names.contains("userId")
            }

            fun completeIfReady(currentUrl: String?) {
                if (completed) return
                val header = cookieHeaderFor(currentUrl)
                if (!hasSessionCookie(header)) return
                completed = true
                cookieManager.flush()
                dialog.dismiss()
                result.success(header)
            }

            fun failIfOpen(code: String, message: String) {
                if (completed) return
                completed = true
                dialog.dismiss()
                result.error(code, message, null)
            }

            val poller = object : Runnable {
                override fun run() {
                    if (completed) return
                    completeIfReady(webView.url)
                    mainHandler.postDelayed(this, 750)
                }
            }

            webView.settings.javaScriptEnabled = true
            webView.settings.domStorageEnabled = true
            webView.webChromeClient = WebChromeClient()
            webView.webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView?, finishedUrl: String?) {
                    super.onPageFinished(view, finishedUrl)
                    val currentUrl = finishedUrl ?: view?.url
                    completeIfReady(currentUrl)
                    view?.evaluateJavascript(
                        "(document.body && document.body.innerText || '').trim()",
                        ValueCallback { body ->
                            val text = body
                                ?.trim()
                                ?.trim('"')
                                ?.replace("\\n", "\n")
                                ?.trim()
                                ?.lowercase()
                            if (text == "ok" || text?.endsWith("\nok") == true) {
                                completeIfReady(currentUrl)
                            }
                        },
                    )
                }
            }

            dialog.setContentView(
                webView,
                ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                ),
            )
            dialog.window?.setLayout(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            dialog.setOnCancelListener {
                failIfOpen("CANCELLED", "Xiaomi 2FA WebView was cancelled")
            }
            dialog.setOnDismissListener {
                mainHandler.removeCallbacks(poller)
                webView.stopLoading()
                webView.destroy()
                if (!completed) {
                    completed = true
                    result.error("CANCELLED", "Xiaomi 2FA WebView was closed", null)
                }
            }
            dialog.show()
            dialog.window?.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            dialog.window?.setLayout(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            webView.loadUrl(url)
            mainHandler.postDelayed(poller, 750)
        }
    }

    @SuppressLint("MissingPermission")
    private fun connect(call: MethodCall, result: MethodChannel.Result) {
        val addr = call.argument<String>("addr")
        if (addr.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "addr is required", null)
            return
        }
        val serviceUuid = call.argument<String>("serviceUuid")
            ?.takeIf { it.isNotBlank() }
            ?.let { runCatching { UUID.fromString(it) }.getOrNull() }
        val fallbackChannels = call.argument<List<Int>>("fallbackChannels")
            ?.mapNotNull { it.takeIf { channel -> channel in 1..30 } }
            ?.distinct()
            ?: listOf(5, 1)
        if (!hasBluetoothConnectPermission()) {
            requestBluetoothPermissionsIfNeeded()
            result.error("MISSING_PERMISSION", "Bluetooth permission is required", null)
            return
        }

        Thread {
            disconnect()
            val generation = connectGeneration.incrementAndGet()
            try {
                val adapter = BluetoothAdapter.getDefaultAdapter()
                    ?: throw IOException("BluetoothAdapter is unavailable")
                val device = adapter.getRemoteDevice(addr)

                if (adapter.isDiscovering) adapter.cancelDiscovery()
                ensureBonded(device)

                val connected = serviceUuid?.let { tryUuid(device, it, generation) }
                    ?: fallbackChannels.firstNotNullOfOrNull { channel ->
                        tryChannel(device, channel, generation)
                    }
                    ?: trySdpUuid(device, serviceUuid, generation)
                    ?: throw IOException("No SPP channel/UUID available")

                if (generation != connectGeneration.get()) {
                    connected.socket.close()
                    throw IOException("SPP connect was cancelled")
                }
                sppSocket = connected.socket
                startReadThread()
                mainHandler.post {
                    result.success(mapOf("channel" to connected.channel))
                }
            } catch (e: Exception) {
                disconnect(cancelConnect = false)
                mainHandler.post {
                    result.error("CONNECT_FAILED", e.message ?: e.toString(), null)
                }
            }
        }.start()
    }

    private fun send(call: MethodCall, result: MethodChannel.Result) {
        val data = call.argument<ByteArray>("data")
        if (data == null) {
            result.error("INVALID_ARGUMENT", "data is required", null)
            return
        }
        val socket = sppSocket
        if (socket == null || !socket.isConnected) {
            result.error("NOT_CONNECTED", "SPP socket is not connected", null)
            return
        }

        sendExecutor.execute {
            try {
                val out = socket.outputStream
                synchronized(sendLock) {
                    var offset = 0
                    while (offset < data.size) {
                        val length = minOf(512, data.size - offset)
                        out.write(data, offset, length)
                        offset += length
                    }
                    out.flush()
                }
                mainHandler.post { result.success(null) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("SEND_FAILED", e.message ?: e.toString(), null)
                }
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun ensureBonded(device: BluetoothDevice) {
        if (device.bondState == BluetoothDevice.BOND_BONDED) return
        val latch = CountDownLatch(1)
        val error = AtomicReference<Exception?>()
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != BluetoothDevice.ACTION_BOND_STATE_CHANGED) return
                val changed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(
                        BluetoothDevice.EXTRA_DEVICE,
                        BluetoothDevice::class.java,
                    )
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                }
                if (changed?.address != device.address) return
                when (changed.bondState) {
                    BluetoothDevice.BOND_BONDED -> latch.countDown()
                    BluetoothDevice.BOND_NONE -> {
                        error.set(IOException("Bonding failed"))
                        latch.countDown()
                    }
                }
            }
        }

        registerReceiver(receiver, IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED))
        try {
            if (!device.createBond()) {
                throw IOException("createBond() failed")
            }
            if (!latch.await(15, TimeUnit.SECONDS)) {
                throw IOException("Bonding timed out")
            }
            error.get()?.let { throw it }
        } finally {
            try {
                unregisterReceiver(receiver)
            } catch (_: IllegalArgumentException) {
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun tryUuid(
        device: BluetoothDevice,
        uuid: UUID,
        generation: Long,
    ): ConnectedSocket? {
        runCatching {
            val socket = device.createInsecureRfcommSocketToServiceRecord(uuid)
            if (connectSocket(socket, 6_000, generation)) {
                return ConnectedSocket(socket, -1)
            }
        }
        runCatching {
            val socket = device.createRfcommSocketToServiceRecord(uuid)
            if (connectSocket(socket, 6_000, generation)) {
                return ConnectedSocket(socket, -1)
            }
        }
        return null
    }

    @SuppressLint("MissingPermission")
    private fun tryChannel(
        device: BluetoothDevice,
        channel: Int,
        generation: Long,
    ): ConnectedSocket? {
        val methods = listOf("createInsecureRfcommSocket", "createRfcommSocket")
        for (name in methods) {
            val socket = runCatching {
                val method = device.javaClass.getMethod(name, Int::class.javaPrimitiveType)
                method.invoke(device, channel) as BluetoothSocket
            }.getOrNull() ?: continue
            if (connectSocket(socket, 3_000, generation)) {
                return ConnectedSocket(socket, channel)
            }
        }
        return null
    }

    @SuppressLint("MissingPermission")
    private fun trySdpUuid(
        device: BluetoothDevice,
        preferredUuid: UUID?,
        generation: Long,
    ): ConnectedSocket? {
        if (!device.fetchUuidsWithSdp()) {
            return null
        }
        if (generation != connectGeneration.get()) return null
        repeat(20) {
            if (generation != connectGeneration.get()) return null
            device.uuids
                ?.firstOrNull {
                    if (preferredUuid != null) {
                        it.uuid == preferredUuid
                    } else {
                        it.uuid.toString().startsWith("00001101", ignoreCase = true)
                    }
                }
                ?.let { parcel ->
                    tryUuid(device, parcel.uuid, generation)?.let { return it }
                }
            Thread.sleep(100)
        }
        return null
    }

    private fun connectSocket(
        socket: BluetoothSocket,
        timeoutMs: Long,
        generation: Long,
    ): Boolean {
        if (generation != connectGeneration.get()) {
            socket.close()
            return false
        }
        connectingSocket = socket
        val latch = CountDownLatch(1)
        val connected = AtomicReference(false)
        val connector = Thread {
            try {
                socket.connect()
                connected.set(true)
            } catch (_: IOException) {
            } finally {
                latch.countDown()
            }
        }
        connector.start()
        val ok = latch.await(timeoutMs, TimeUnit.MILLISECONDS) &&
            connected.get() &&
            generation == connectGeneration.get()
        if (!ok) {
            try {
                socket.close()
            } catch (_: IOException) {
            }
            return false
        }
        if (connectingSocket == socket) {
            connectingSocket = null
        }
        return true
    }

    private fun startReadThread() {
        val socket = sppSocket ?: return
        val thread = Thread {
            val buffer = ByteArray(1024)
            try {
                val input = socket.inputStream
                while (!Thread.currentThread().isInterrupted) {
                    val length = input.read(buffer)
                    if (length <= 0) break
                    val packet = buffer.copyOf(length)
                    mainHandler.post { eventSink?.success(packet) }
                }
            } catch (e: IOException) {
                mainHandler.post { eventSink?.error("READ_FAILED", e.message, null) }
            } finally {
                if (readThread == Thread.currentThread()) {
                    disconnect()
                }
            }
        }.also { it.start() }
        readThread = thread
    }

    private fun disconnect(cancelConnect: Boolean = true) {
        if (cancelConnect) {
            connectGeneration.incrementAndGet()
        }
        val thread = readThread
        readThread = null
        if (thread != null && thread != Thread.currentThread()) {
            thread.interrupt()
        }
        try {
            connectingSocket?.close()
        } catch (_: IOException) {
        }
        connectingSocket = null
        try {
            sppSocket?.close()
        } catch (_: IOException) {
        }
        sppSocket = null
    }

    private fun hasBluetoothConnectPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        return checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requestBluetoothPermissionsIfNeeded() {
        val required = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            listOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
            )
        } else {
            listOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        val missing = required.filter {
            checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isNotEmpty()) {
            requestPermissions(missing.toTypedArray(), 0x5A10)
        }
    }

    private fun hasBluetoothScanPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED
        }
    }

    private data class ConnectedSocket(
        val socket: BluetoothSocket,
        val channel: Int,
    )

    override fun onDestroy() {
        XmsWearableBridge.detach(xmsWearableChannel)
        xmsWearableChannel = null
        closeZeppSettings(notify = false)
        stopSppScan()
        sendExecutor.shutdownNow()
        super.onDestroy()
    }
}
