package com.jaralephillips.hawcalendar

import android.os.Build
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val shellBackChannelName = "com.kemetic.calendar/shell_back"
  private var deviceCalendarBridge: DeviceCalendarBridge? = null
  private var shellBackChannel: MethodChannel? = null
  private var shellBackCallback: OnBackInvokedCallback? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    deviceCalendarBridge = DeviceCalendarBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    shellBackChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shellBackChannelName)
    registerShellBackCallback()
  }

  override fun onDestroy() {
    deviceCalendarBridge?.dispose()
    deviceCalendarBridge = null
    unregisterShellBackCallback()
    shellBackChannel = null
    super.onDestroy()
  }

  @Deprecated("Deprecated in Java")
  override fun onBackPressed() {
    handleAndroidBack()
  }

  private fun registerShellBackCallback() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || shellBackCallback != null) {
      return
    }
    val callback = OnBackInvokedCallback { handleAndroidBack() }
    onBackInvokedDispatcher.registerOnBackInvokedCallback(
      OnBackInvokedDispatcher.PRIORITY_DEFAULT,
      callback
    )
    shellBackCallback = callback
  }

  private fun unregisterShellBackCallback() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
      return
    }
    shellBackCallback?.let { onBackInvokedDispatcher.unregisterOnBackInvokedCallback(it) }
    shellBackCallback = null
  }

  private fun handleAndroidBack() {
    val channel = shellBackChannel
    if (channel == null) {
      forwardBackToFlutter()
      return
    }

    channel.invokeMethod("handleAndroidBack", null, object : MethodChannel.Result {
      override fun success(result: Any?) {
        if (result == true) {
          return
        }
        forwardBackToFlutter()
      }

      override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        forwardBackToFlutter()
      }

      override fun notImplemented() {
        forwardBackToFlutter()
      }
    })
  }

  private fun forwardBackToFlutter() {
    flutterEngine?.navigationChannel?.popRoute()
  }

  override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
    super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    deviceCalendarBridge?.onRequestPermissionsResult(requestCode)
  }
}
