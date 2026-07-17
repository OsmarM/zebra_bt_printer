package com.soriana.zebra_bt_printer

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.os.Build
import android.util.Base64
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

import com.zebra.sdk.comm.BluetoothConnection
import com.zebra.sdk.comm.TcpConnection
import com.zebra.sdk.graphics.internal.ZebraImageAndroid
import com.zebra.sdk.printer.ZebraPrinterFactory

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

class ZebraBtPrinterPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var appContext: Context? = null

    private val PERMISSION_REQUEST_CODE = 2001
    private var pendingPermissionsResult: Result? = null

    // Número de reintentos y espera entre intentos cuando la impresora
    // está ocupada con otro dispositivo.
    private val MAX_RETRIES    = 3
    private val RETRY_DELAY_MS = 1500L

    // Conexiones BT persistentes, indexadas por MAC.
    // Permiten reutilizar la misma sesión SPP entre impresiones consecutivas
    // eliminando el overhead de open/close (~4-6 s por etiqueta).
    private val persistentConnections = mutableMapOf<String, BluetoothConnection>()

    private val BLUETOOTH_PERMISSIONS_S = arrayOf(
        Manifest.permission.BLUETOOTH_CONNECT,
        Manifest.permission.BLUETOOTH_SCAN,
        Manifest.permission.ACCESS_FINE_LOCATION,
    )
    private val BLUETOOTH_PERMISSIONS_LEGACY = arrayOf(
        Manifest.permission.BLUETOOTH,
        Manifest.permission.BLUETOOTH_ADMIN,
        Manifest.permission.ACCESS_COARSE_LOCATION,
    )

    // ─────────────────────────── FlutterPlugin ───────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel   = MethodChannel(binding.binaryMessenger, "zebra_bt_printer")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        appContext = null
        closeAllPersistentConnections()
    }

    // ─────────────────────────── ActivityAware ───────────────────────────────

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        attachActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() { detachActivity() }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        attachActivity(binding)
    }
    override fun onDetachedFromActivity() { detachActivity() }

    private fun attachActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        activity = binding.activity
        // Sin este listener, requestPermissions() nunca recibe la respuesta
        // del diálogo y su Future queda colgado para siempre.
        binding.addRequestPermissionsResultListener(this)
    }

    private fun detachActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        activity = null
    }

    // ─────────────────────────── MethodCallHandler ───────────────────────────

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "connectBluetooth"    -> handleConnectBluetooth(call, result)
            "disconnectBluetooth" -> handleDisconnectBluetooth(call, result)
            "calibratePrinter"    -> handleCalibratePrinter(call, result)
            "printImageBluetooth" -> handlePrintImageBluetooth(call, result)
            "printImageIP"        -> handlePrintImageIP(call, result)
            "printLabelBluetooth" -> handlePrintLabelBluetooth(call, result)
            "requestPermissions"  -> handleRequestPermissions(result)
            "isBluetoothEnabled"  -> handleIsBluetoothEnabled(result)
            else                  -> result.notImplemented()
        }
    }

    // ─────────────────────────── Handlers ────────────────────────────────────

    private fun handleConnectBluetooth(call: MethodCall, result: Result) {
        val mac = call.argument<String>("mac") ?: return result.error("INVALID_ARGS", "mac es requerido", null)

        if (!hasBluetoothPermissions()) {
            return result.error(
                "PERMISSION_DENIED",
                "Faltan permisos Bluetooth. Llama a requestPermissions() primero.",
                null,
            )
        }

        runInBackground {
            try {
                getOrOpenConnection(mac)
                runOnUiThread(result) { it.success(true) }
            } catch (e: Exception) {
                runOnUiThread(result) { it.error("CONNECT_ERROR", e.message, null) }
            }
        }
    }

    private fun handleCalibratePrinter(call: MethodCall, result: Result) {
        val mac = call.argument<String>("mac") ?: return result.error("INVALID_ARGS", "mac es requerido", null)
        if (!hasBluetoothPermissions()) {
            return result.error("PERMISSION_DENIED", "Faltan permisos Bluetooth.", null)
        }
        runInBackground {
            try {
                val conn = getOrOpenConnection(mac)
                conn.write("~JC".toByteArray())
                Thread.sleep(3000)
                runOnUiThread(result) { it.success(true) }
            } catch (e: Exception) {
                runOnUiThread(result) { it.error("CALIBRATE_ERROR", e.message, null) }
            }
        }
    }

    private fun handleDisconnectBluetooth(call: MethodCall, result: Result) {
        val mac = call.argument<String>("mac") ?: return result.error("INVALID_ARGS", "mac es requerido", null)

        runInBackground {
            try {
                synchronized(persistentConnections) {
                    persistentConnections.remove(mac)?.let { safeClose(it) }
                }
                runOnUiThread(result) { it.success(true) }
            } catch (e: Exception) {
                runOnUiThread(result) { it.error("DISCONNECT_ERROR", e.message, null) }
            }
        }
    }

    private fun handlePrintImageBluetooth(call: MethodCall, result: Result) {
        val mac         = call.argument<String>("mac")         ?: return result.error("INVALID_ARGS", "mac es requerido", null)
        val imageBase64 = call.argument<String>("imageBase64") ?: return result.error("INVALID_ARGS", "imageBase64 es requerido", null)
        val config      = PrintConfig.fromCall(call)
        val copies      = (call.argument<Int>("copies") ?: 1).coerceIn(1, 999)

        if (!hasBluetoothPermissions()) {
            return result.error(
                "PERMISSION_DENIED",
                "Faltan permisos Bluetooth (BLUETOOTH_CONNECT/BLUETOOTH_SCAN). " +
                    "Llama a requestPermissions() y acéptalos antes de imprimir.",
                null,
            )
        }

        runInBackground {
            try {
                withRetry(MAX_RETRIES) { printImageViaBluetooth(mac, imageBase64, config, copies) }
                runOnUiThread(result) { it.success(true) }
            } catch (e: Exception) {
                runOnUiThread(result) { it.error("PRINT_ERROR", e.message, null) }
            }
        }
    }

    private fun handlePrintImageIP(call: MethodCall, result: Result) {
        val ip          = call.argument<String>("ip")          ?: return result.error("INVALID_ARGS", "ip es requerido", null)
        val imageBase64 = call.argument<String>("imageBase64") ?: return result.error("INVALID_ARGS", "imageBase64 es requerido", null)
        val config      = PrintConfig.fromCall(call)

        runInBackground {
            try {
                printImageViaTCP(ip, imageBase64, config)
                runOnUiThread(result) { it.success(true) }
            } catch (e: Exception) {
                runOnUiThread(result) { it.error("PRINT_ERROR", e.message, null) }
            }
        }
    }

    private fun handlePrintLabelBluetooth(call: MethodCall, result: Result) {
        val mac     = call.argument<String>("mac")     ?: return result.error("INVALID_ARGS", "mac es requerido", null)
        val zplText = call.argument<String>("zplText") ?: return result.error("INVALID_ARGS", "zplText es requerido", null)

        if (!hasBluetoothPermissions()) {
            return result.error(
                "PERMISSION_DENIED",
                "Faltan permisos Bluetooth (BLUETOOTH_CONNECT/BLUETOOTH_SCAN). " +
                    "Llama a requestPermissions() y acéptalos antes de imprimir.",
                null,
            )
        }

        runInBackground {
            try {
                withRetry(MAX_RETRIES) { printZplViaBluetooth(mac, zplText) }
                runOnUiThread(result) { it.success(true) }
            } catch (e: Exception) {
                runOnUiThread(result) { it.error("PRINT_ERROR", e.message, null) }
            }
        }
    }

    private fun handleRequestPermissions(result: Result) {
        val act = activity ?: return result.error("NO_ACTIVITY", "Activity no disponible", null)

        val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
            BLUETOOTH_PERMISSIONS_S else BLUETOOTH_PERMISSIONS_LEGACY

        val missing = permissions.filter {
            ContextCompat.checkSelfPermission(act, it) != PackageManager.PERMISSION_GRANTED
        }

        if (missing.isEmpty()) {
            result.success(true)
            return
        }

        if (pendingPermissionsResult != null) {
            return result.error(
                "PERMISSION_REQUEST_IN_PROGRESS",
                "Ya hay una solicitud de permisos en curso",
                null,
            )
        }

        pendingPermissionsResult = result
        ActivityCompat.requestPermissions(act, missing.toTypedArray(), PERMISSION_REQUEST_CODE)
    }

    /**
     * Entrega el resultado del diálogo de permisos al Future de Dart.
     * Sin esto, requestPermissions() nunca se resuelve en Android 12+.
     */
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false

        val result = pendingPermissionsResult ?: return false
        pendingPermissionsResult = null

        val allGranted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        result.success(allGranted)
        return true
    }

    private fun handleIsBluetoothEnabled(result: Result) {
        val adapter = BluetoothAdapter.getDefaultAdapter()
        result.success(adapter?.isEnabled == true)
    }

    /**
     * ¿Tenemos los permisos necesarios para abrir una conexión Bluetooth?
     *
     * En Android 12+ el SDK de Zebra requiere BLUETOOTH_CONNECT (para abrir el
     * socket SPP) y BLUETOOTH_SCAN (porque open() llama internamente a
     * cancelDiscovery()). Si faltan, el sistema lanza SecurityException con el
     * mensaje "Need android.permission.BLUETOOTH_SCAN permission ...".
     */
    private fun hasBluetoothPermissions(): Boolean {
        val ctx = appContext ?: return false
        val required = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
            arrayOf(Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.BLUETOOTH_SCAN)
        else
            arrayOf(Manifest.permission.BLUETOOTH, Manifest.permission.BLUETOOTH_ADMIN)

        return required.all {
            ContextCompat.checkSelfPermission(ctx, it) == PackageManager.PERMISSION_GRANTED
        }
    }

    // ─────────────────────────── Bluetooth discovery ─────────────────────────

    /**
     * Cancela el descubrimiento Bluetooth activo antes de abrir una conexión.
     *
     * El SDK de Zebra llama a cancelDiscovery() internamente al abrir una
     * conexión SPP. En Android 12+ (API 31) eso requiere BLUETOOTH_SCAN.
     * Hacerlo explícitamente aquí —con el check de permiso correcto— evita
     * que el SDK lance SecurityException por falta de permiso.
     */
    private fun cancelBluetoothDiscovery() {
        val ctx     = appContext ?: return
        val adapter = BluetoothAdapter.getDefaultAdapter() ?: return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12+: BLUETOOTH_SCAN es permiso en tiempo de ejecución
            val granted = ContextCompat.checkSelfPermission(ctx, Manifest.permission.BLUETOOTH_SCAN) ==
                    PackageManager.PERMISSION_GRANTED
            if (granted) adapter.cancelDiscovery()
        } else {
            // Android < 12: no se necesita permiso explícito
            adapter.cancelDiscovery()
        }
    }

    // ─────────────────────────── Zebra printing ──────────────────────────────

    private fun printImageViaBluetooth(
        mac: String,
        imageBase64: String,
        config: PrintConfig,
        copies: Int = 1,
    ) {
        val persistent = synchronized(persistentConnections) { persistentConnections[mac] }
        val conn       = persistent ?: run {
            cancelBluetoothDiscovery()
            BluetoothConnection(mac).also { it.open() }
        }

        val closeable = persistent == null

        try {
            val source      = decodeBase64ToBitmap(imageBase64)
            val labelBitmap = createLabelBitmap(
                source, config.labelWidthDots, config.labelHeightDots,
                config.useSmoothScaling, config.allowUpscale,
            )

            // ZPL completo generado por nosotros — sin SDK intermediario.
            // El SDK de Zebra genera su propio ^LL interno en printImage() y lo pisa;
            // aquí tenemos control total sobre cada comando ZPL.
            val zpl = buildString {
                append("^XA\n")
                append("${config.zplMediaCommand}\n")
                append("^PW${config.labelWidthDots}\n")
                append("^LL${config.labelHeightDots}\n")
                append("^ML${config.maxLabelLengthDots}\n")
                if (config.labelTopOffset != 0) append("^LT${config.labelTopOffset}\n")
                append("^FO0,0\n")
                append(bitmapToZplGf(labelBitmap))
                append("\n^XZ")
            }
            val zplBytes = zpl.toByteArray(Charsets.UTF_8)

            repeat(copies) {
                conn.write(zplBytes)
            }
        } catch (e: Exception) {
            if (!closeable) {
                synchronized(persistentConnections) { persistentConnections.remove(mac) }
                safeClose(conn)
            }
            throw e
        } finally {
            if (closeable) safeClose(conn)
        }
    }

    private fun printImageViaTCP(ip: String, imageBase64: String, config: PrintConfig) {
        val conn = TcpConnection(ip, TcpConnection.DEFAULT_ZPL_TCP_PORT)
        conn.open()

        try {
            val source      = decodeBase64ToBitmap(imageBase64)
            val labelBitmap = createLabelBitmap(
                source, config.labelWidthDots, config.labelHeightDots,
                config.useSmoothScaling, config.allowUpscale,
            )
            val zpl = buildString {
                append("^XA\n")
                append("${config.zplMediaCommand}\n")
                append("^PW${config.labelWidthDots}\n")
                append("^LL${config.labelHeightDots}\n")
                append("^ML${config.maxLabelLengthDots}\n")
                if (config.labelTopOffset != 0) append("^LT${config.labelTopOffset}\n")
                append("^FO0,0\n")
                append(bitmapToZplGf(labelBitmap))
                append("\n^XZ")
            }
            conn.write(zpl.toByteArray(Charsets.UTF_8))
        } finally {
            safeClose(conn)
        }
    }

    private fun printZplViaBluetooth(mac: String, zplText: String) {
        cancelBluetoothDiscovery()

        val conn = BluetoothConnection(mac)
        conn.open()
        try {
            val printer = ZebraPrinterFactory.getInstance(conn)
            printer.sendCommand("^XA^FO50,50^ADN,36,20^FD$zplText^FS^XZ")
        } finally {
            safeClose(conn)
        }
    }

    // ─────────────────────────── Image utilities ─────────────────────────────

    /**
     * Crea un bitmap del tamaño exacto de la etiqueta ([labelW] × [labelH]).
     *
     * 1. Redimensiona [source] para que quepa dentro de la etiqueta (aspect ratio).
     * 2. Crea un canvas blanco de [labelW] × [labelH].
     * 3. Centra la imagen redimensionada sobre ese canvas.
     *
     * Al pasarle este bitmap al SDK con width=0, height=0, el SDK usa el tamaño
     * natural del bitmap y genera el ^LL correcto en su ZPL interno.
     */
    private fun createLabelBitmap(
        source: Bitmap,
        labelW: Int,
        labelH: Int,
        smooth: Boolean,
        allowUpscale: Boolean,
    ): Bitmap {
        val resized = resizeBitmap(source, labelW, labelH, smooth, allowUpscale)

        val label  = Bitmap.createBitmap(labelW, labelH, Bitmap.Config.ARGB_8888)
        label.eraseColor(android.graphics.Color.WHITE)

        val left = (labelW - resized.width) / 2
        val top  = (labelH - resized.height) / 2

        Canvas(label).drawBitmap(resized, left.toFloat(), top.toFloat(), null)
        return label
    }

    /**
     * Convierte un Bitmap a comando ZPL ^GF (Graphic Field) en formato hex ASCII.
     *
     * Formato: ^GFA,[totalBytes],[totalBytes],[bytesPerRow],[hexData]
     *   - 1 bit = 1 dot. Bit 1 (MSB primero) = negro (imprime). Bit 0 = blanco.
     *   - Cada fila se rellena a múltiplo de byte.
     */
    private fun bitmapToZplGf(bitmap: Bitmap): String {
        val w           = bitmap.width
        val h           = bitmap.height
        val bytesPerRow = (w + 7) / 8
        val totalBytes  = bytesPerRow * h

        val pixels = IntArray(w * h)
        bitmap.getPixels(pixels, 0, w, 0, 0, w, h)

        val sb = StringBuilder(totalBytes * 2 + 32)
        sb.append("^GFA,$totalBytes,$totalBytes,$bytesPerRow,")

        for (y in 0 until h) {
            for (col in 0 until bytesPerRow) {
                var byte = 0
                for (bit in 0 until 8) {
                    val x = col * 8 + bit
                    byte = byte shl 1
                    if (x < w) {
                        val px  = pixels[y * w + x]
                        val lum = (0.299 * android.graphics.Color.red(px) +
                                   0.587 * android.graphics.Color.green(px) +
                                   0.114 * android.graphics.Color.blue(px)).toInt()
                        if (lum < 128) byte = byte or 1  // píxel oscuro → imprimir
                    }
                }
                sb.append(String.format("%02X", byte))
            }
        }
        return sb.toString()
    }

    private fun decodeBase64ToBitmap(base64: String): Bitmap {
        val bytes = Base64.decode(base64, Base64.DEFAULT)
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?: throw IllegalArgumentException("No se pudo decodificar la imagen base64")
    }

    private fun resizeBitmap(
        source: Bitmap,
        maxWidth: Int,
        maxHeight: Int,
        smooth: Boolean = true,
        allowUpscale: Boolean = false,
    ): Bitmap {
        val scaleLimit = if (allowUpscale) Float.MAX_VALUE else 1f
        val scale = minOf(
            maxWidth.toFloat() / source.width,
            maxHeight.toFloat() / source.height,
            scaleLimit,
        ).coerceAtLeast(0.1f)

        val newW = (source.width * scale).toInt().coerceAtLeast(1)
        val newH = (source.height * scale).toInt().coerceAtLeast(1)

        if (!smooth) return Bitmap.createScaledBitmap(source, newW, newH, true)

        val out    = Bitmap.createBitmap(newW, newH, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val paint  = Paint().apply {
            isAntiAlias    = true
            isFilterBitmap = true
            isDither       = true
        }
        canvas.drawBitmap(source, Rect(0, 0, source.width, source.height), Rect(0, 0, newW, newH), paint)
        return out
    }

    // ─────────────────────────── Persistent connection helpers ───────────────

    /**
     * Devuelve la conexión existente para [mac] si ya está abierta,
     * o abre una nueva y la almacena en [persistentConnections].
     */
    private fun getOrOpenConnection(mac: String): BluetoothConnection {
        synchronized(persistentConnections) {
            persistentConnections[mac]?.let { return it }
        }
        cancelBluetoothDiscovery()
        val conn = BluetoothConnection(mac)
        conn.open()
        synchronized(persistentConnections) { persistentConnections[mac] = conn }
        return conn
    }

    private fun closeAllPersistentConnections() {
        synchronized(persistentConnections) {
            persistentConnections.values.forEach { safeClose(it) }
            persistentConnections.clear()
        }
    }

    // ─────────────────────────── Helpers ─────────────────────────────────────

    private fun runInBackground(block: () -> Unit) = Thread(block).start()

    private fun runOnUiThread(result: Result, block: (Result) -> Unit) {
        activity?.runOnUiThread { block(result) }
    }

    /**
     * Cierra la conexión sin lanzar excepción si ya estaba cerrada.
     * Evita que un error en close() enmascare el error original de impresión.
     */
    private fun safeClose(conn: com.zebra.sdk.comm.Connection) {
        try { conn.close() } catch (_: Exception) {}
    }

    /**
     * Reintenta [maxRetries] veces el bloque dado.
     * Entre cada intento espera [RETRY_DELAY_MS] ms.
     *
     * Útil cuando la impresora BT está terminando la sesión de otro
     * dispositivo y necesita unos segundos antes de aceptar una nueva.
     */
    private fun withRetry(maxRetries: Int, block: () -> Unit) {
        var lastError: Exception? = null
        repeat(maxRetries) { attempt ->
            try {
                block()
                return   // éxito → salir
            } catch (e: Exception) {
                lastError = e
                if (attempt < maxRetries - 1) {
                    Thread.sleep(RETRY_DELAY_MS)
                }
            }
        }
        throw lastError ?: Exception("Error desconocido al imprimir")
    }

    // ─────────────────────────── PrintConfig ─────────────────────────────────

    private data class PrintConfig(
        val labelWidthDots: Int,
        val labelHeightDots: Int,
        val useSmoothScaling: Boolean,
        val printerType: String,
        /** "gap" → ^MNA  |  "mark" → ^MNB  |  "none" → ^MNN */
        val mediaType: String,
        val allowUpscale: Boolean,
        /**
         * ^ML — distancia máxima (en dots) que la impresora avanza buscando la
         * siguiente marca negra o gap. Por defecto = labelHeightDots * 2.
         * Si la impresora sigue cortando antes de tiempo, aumenta este valor.
         */
        val maxLabelLengthDots: Int,
        /**
         * ^LT — desplazamiento vertical del área de impresión respecto a la marca
         * (en dots, puede ser negativo). Ajusta si la imagen aparece desplazada
         * hacia arriba o hacia abajo dentro de la etiqueta.
         */
        val labelTopOffset: Int,
    ) {
        /** Comando ZPL correspondiente al tipo de media. */
        val zplMediaCommand: String get() = when (mediaType) {
            "mark" -> "^MNB"
            "none" -> "^MNN"
            else   -> "^MNA"
        }

        companion object {
            fun fromCall(call: MethodCall): PrintConfig {
                val labelHeightDots = call.argument<Int>("labelHeightDots") ?: 240
                return PrintConfig(
                    labelWidthDots     = call.argument<Int>("labelWidthDots")         ?: 600,
                    labelHeightDots    = labelHeightDots,
                    useSmoothScaling   = call.argument<Boolean>("useSmoothScaling")   ?: true,
                    printerType        = call.argument<String>("printerType")         ?: "zebra",
                    mediaType          = call.argument<String>("mediaType")           ?: "gap",
                    allowUpscale       = call.argument<Boolean>("allowUpscale")       ?: false,
                    maxLabelLengthDots = call.argument<Int>("maxLabelLengthDots")     ?: labelHeightDots * 2,
                    labelTopOffset     = call.argument<Int>("labelTopOffset")         ?: 0,
                )
            }
        }
    }
}
