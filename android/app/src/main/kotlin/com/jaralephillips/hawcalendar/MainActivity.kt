package com.jaralephillips.hawcalendar

import android.Manifest
import android.content.ContentUris
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.CalendarContract
import android.provider.Settings
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
  private val channelName = "com.kemetic.calendar/sync"
  private val shellBackChannelName = "com.kemetic.calendar/shell_back"
  private val permissionRequest = 9910
  private var pendingPermissionResult: MethodChannel.Result? = null
  private var shellBackChannel: MethodChannel? = null
  private var shellBackCallback: OnBackInvokedCallback? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    shellBackChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shellBackChannelName)
    registerShellBackCallback()

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
      when (call.method) {
        "requestPermissions" -> handleRequestPermissions(result)
        "hasPermissions" -> result.success(hasCalendarPermission())
        "getStableDeviceId" -> result.success(getStableDeviceId())
        "fetchEvents" -> {
          val args = call.arguments as? Map<*, *>
          if (args == null) {
            result.error("bad_args", "Missing arguments", null)
            return@setMethodCallHandler
          }
          if (!hasCalendarPermission()) {
            result.success(emptyList<Any>())
            return@setMethodCallHandler
          }
          val start = (args["start"] as Number).toLong()
          val end = (args["end"] as Number).toLong()
          result.success(fetchEvents(start, end))
        }
        else -> result.notImplemented()
      }
    }
  }

  override fun onDestroy() {
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

  private fun hasCalendarPermission(): Boolean {
    return ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED
  }

  private fun getStableDeviceId(): String? {
    val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
      ?.trim()
      ?.takeIf { it.isNotEmpty() && it != "9774d56d682e549c" }
    return androidId?.let { "android:$it" }
  }

  private fun handleRequestPermissions(result: MethodChannel.Result) {
    if (hasCalendarPermission()) {
      result.success(true)
      return
    }
    pendingPermissionResult = result
    val perms = arrayOf(Manifest.permission.READ_CALENDAR)
    ActivityCompat.requestPermissions(this, perms, permissionRequest)
  }

  override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
    super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    if (requestCode == permissionRequest) {
      val granted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
      pendingPermissionResult?.success(granted)
      pendingPermissionResult = null
    }
  }

  private fun fetchEvents(startMillis: Long, endMillis: Long): List<Map<String, Any?>> {
    val uriBuilder: Uri.Builder = CalendarContract.Instances.CONTENT_URI.buildUpon()
    ContentUris.appendId(uriBuilder, startMillis)
    ContentUris.appendId(uriBuilder, endMillis)

    val projection = arrayOf(
      CalendarContract.Instances.EVENT_ID,
      CalendarContract.Instances.TITLE,
      CalendarContract.Instances.DESCRIPTION,
      CalendarContract.Instances.EVENT_LOCATION,
      CalendarContract.Instances.BEGIN,
      CalendarContract.Instances.END,
      CalendarContract.Instances.ALL_DAY,
      CalendarContract.Instances.EVENT_TIMEZONE,
      CalendarContract.Instances.CALENDAR_ID
    )

    val results = mutableListOf<Map<String, Any?>>()
    val cr = contentResolver
    val cursor = cr.query(uriBuilder.build(), projection, null, null, null)
    cursor?.use {
      val idxEventId = it.getColumnIndex(CalendarContract.Instances.EVENT_ID)
      val idxTitle = it.getColumnIndex(CalendarContract.Instances.TITLE)
      val idxDescription = it.getColumnIndex(CalendarContract.Instances.DESCRIPTION)
      val idxLocation = it.getColumnIndex(CalendarContract.Instances.EVENT_LOCATION)
      val idxBegin = it.getColumnIndex(CalendarContract.Instances.BEGIN)
      val idxEnd = it.getColumnIndex(CalendarContract.Instances.END)
      val idxAllDay = it.getColumnIndex(CalendarContract.Instances.ALL_DAY)
      val idxTimezone = it.getColumnIndex(CalendarContract.Instances.EVENT_TIMEZONE)
      val idxCalendarId = it.getColumnIndex(CalendarContract.Instances.CALENDAR_ID)

      while (it.moveToNext()) {
        val eventId = it.getLong(idxEventId)
        val description = it.getString(idxDescription)
        val cid = extractCid(description)
        results.add(
          mapOf(
            "eventId" to eventId.toString(),
            "title" to (it.getString(idxTitle) ?: ""),
            "description" to (description ?: ""),
            "location" to (it.getString(idxLocation) ?: ""),
            "start" to it.getLong(idxBegin),
            "end" to it.getLong(idxEnd),
            "allDay" to (it.getInt(idxAllDay) == 1),
            "calendarId" to it.getLong(idxCalendarId).toString(),
            "timeZone" to (it.getString(idxTimezone) ?: TimeZone.getDefault().id),
            "lastModified" to System.currentTimeMillis(),
            "clientEventId" to cid
          )
        )
      }
    }
    cursor?.close()
    return results
  }

  private fun extractCid(text: String?): String? {
    if (text == null) return null
    val regex = Regex("kemet_cid:([^\\s]+)", RegexOption.IGNORE_CASE)
    val match = regex.find(text)
    return match?.groupValues?.getOrNull(1)
  }
}
