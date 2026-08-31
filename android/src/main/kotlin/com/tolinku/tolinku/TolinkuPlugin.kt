package com.tolinku.tolinku

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Reads the Play Install Referrer for the Dart side.
 *
 * A Tolinku link sends an Android visitor to the store with
 * `referrer=tolk_token=<token>` attached. Play keeps that string through the
 * install and returns it on first launch, naming the exact click rather than
 * inferring it from device signals.
 *
 * Only the raw referrer string crosses the channel. Finding our token inside it
 * is done in Dart, where the tests run everywhere rather than only where an
 * Android toolchain exists.
 */
class TolinkuPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private var channel: MethodChannel? = null
    private var signalsChannel: MethodChannel? = null
    private var context: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
        signalsChannel = MethodChannel(binding.binaryMessenger, CHANNEL_SIGNALS).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        signalsChannel?.setMethodCallHandler(null)
        signalsChannel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        // Signals Dart cannot express in the form matching compares against: an
        // IANA timezone rather than an abbreviation, and a version starting with
        // a digit rather than "Android 13 (API 33)". A signal that is absent is
        // skipped, while one present and disagreeing counts as a failed
        // comparison, so the format is the whole point of reading them here.
        if (call.method == METHOD_GET_SIGNALS) {
            result.success(
                mapOf(
                    "timezone" to java.util.TimeZone.getDefault().id,
                    "os_version" to android.os.Build.VERSION.RELEASE,
                )
            )
            return
        }

        if (call.method != METHOD_GET_REFERRER) {
            result.notImplemented()
            return
        }

        val appContext = context
        if (appContext == null) {
            result.success(null)
            return
        }

        val client = try {
            InstallReferrerClient.newBuilder(appContext).build()
        } catch (t: Throwable) {
            result.success(null)
            return
        }

        // The Play listener can fire more than once on some devices, and a
        // MethodChannel result may be sent only once.
        val settled = AtomicBoolean(false)
        val main = Handler(Looper.getMainLooper())

        // A channel result must be delivered on the platform thread; the Play
        // callback makes no such promise.
        fun settle(referrer: String?) {
            if (!settled.compareAndSet(false, true)) return
            try {
                client.endConnection()
            } catch (t: Throwable) {
                // Already gone.
            }
            main.post { result.success(referrer) }
        }

        try {
            client.startConnection(object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(responseCode: Int) {
                    val referrer = try {
                        if (responseCode == InstallReferrerClient.InstallReferrerResponse.OK) {
                            client.installReferrer.installReferrer
                        } else {
                            null
                        }
                    } catch (t: Throwable) {
                        null
                    }
                    settle(referrer)
                }

                override fun onInstallReferrerServiceDisconnected() {
                    settle(null)
                }
            })
        } catch (t: Throwable) {
            settle(null)
        }
    }

    private companion object {
        const val CHANNEL = "com.tolinku/install_referrer"
        const val CHANNEL_SIGNALS = "com.tolinku/device_signals"
        const val METHOD_GET_REFERRER = "getInstallReferrer"
        const val METHOD_GET_SIGNALS = "getDeviceSignals"
    }
}
