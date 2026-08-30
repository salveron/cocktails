package dev.salveron.cocktails

import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Answers the name the reader has already given this phone, which is what the
 * app announces itself as until they say otherwise (ADR 28). Null where the
 * setting was never written; the Dart side keeps the fallback.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "dev.salveron.cocktails/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "name" -> result.success(
                        Settings.Global.getString(contentResolver, Settings.Global.DEVICE_NAME)
                    )
                    else -> result.notImplemented()
                }
            }
    }
}
