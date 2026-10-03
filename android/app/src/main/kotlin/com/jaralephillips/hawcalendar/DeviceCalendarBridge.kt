package com.jaralephillips.hawcalendar

import android.Manifest
import android.app.Activity
import android.content.ContentUris
import android.content.pm.PackageManager
import android.database.ContentObserver
import android.database.Cursor
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.provider.CalendarContract
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.time.Instant
import java.time.ZoneOffset
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** Device calendar reads only. There is deliberately no provider mutation path. */
class DeviceCalendarBridge(private val activity: Activity, messenger: BinaryMessenger) :
  MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
  private val channel = MethodChannel(messenger, "com.kemetic.calendar/device_import_v1")
  private val events = EventChannel(messenger, "com.kemetic.calendar/device_import_changes_v1")
  private val main = Handler(Looper.getMainLooper())
  private val worker = Executors.newSingleThreadExecutor()
  private var pendingPermission: Reply? = null
  private var observer: ContentObserver? = null
  private var disposed = false
  private val permissionCode = 9921

  init { channel.setMethodCallHandler(this); events.setStreamHandler(this) }

  private fun permission(): String = if (ContextCompat.checkSelfPermission(activity,
    Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED) "granted" else "denied"

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    if (disposed) { result.error("disposed", null, null); return }
    when (call.method) {
      "permissionStatus" -> result.success(permission())
      "deviceId" -> {
        val id = Settings.Secure.getString(activity.contentResolver, Settings.Secure.ANDROID_ID)
        if (id.isNullOrBlank() || id == "9774d56d682e549c") result.error("device_unavailable", null, null)
        else result.success("android:$id")
      }
      "requestPermission" -> {
        if (permission() == "granted") { result.success("granted"); return }
        if (pendingPermission != null) { result.error("permission_in_progress", null, null); return }
        val reply = Reply(result)
        pendingPermission = reply
        main.postDelayed({
          if (pendingPermission === reply) { pendingPermission = null; reply.error("timeout") }
        }, 90000)
        ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.READ_CALENDAR), permissionCode)
      }
      "listCalendars" -> read(result) { signal -> listCalendars(signal) }
      "readSnapshot" -> {
        val args = call.arguments as? Map<*, *>
        val rawIds = args?.get("calendarIds") as? List<*>
        val ids = rawIds?.filterIsInstance<String>()
        val from = (args?.get("fromMs") as? Number)?.toLong()
        val until = (args?.get("untilMs") as? Number)?.toLong()
        if (ids == null || ids.isEmpty() || ids.size != rawIds.size || ids.size > 50 ||
          ids.toSet().size != ids.size || from == null || until == null || until <= from ||
          until - from > 730L * 86400000L) {
          result.error("invalid_range", null, null); return
        }
        read(result) { signal -> snapshot(ids, from, until, signal) }
      }
      else -> result.notImplemented()
    }
  }

  fun onRequestPermissionsResult(requestCode: Int): Boolean {
    if (requestCode != permissionCode) return false
    val reply = pendingPermission
    pendingPermission = null
    reply?.success(permission())
    return true
  }

  private fun listCalendars(signal: CancellationSignal): List<Map<String, Any?>> {
    val rows = mutableListOf<Map<String, Any?>>()
    val columns = arrayOf("_id", "calendar_displayName", "calendar_color", "account_name", "account_type", "_sync_id")
    val cursor = activity.contentResolver.query(CalendarContract.Calendars.CONTENT_URI, columns, null, null, null, signal)
      ?: throw ReadFailure("read_failed")
    cursor.use {
      while (it.moveToNext()) {
        signal.throwIfCanceled()
        rows.add(mapOf("native_id" to it.getLong(0).toString(), "label" to (it.getString(1) ?: "Calendar"),
          "color" to String.format("#%06x", it.getInt(2) and 0xffffff),
          "account_label" to (it.getString(3) ?: "This phone"),
          "kind" to (it.getString(4) ?: "local"),
          "source_id" to "${it.getString(4)}:${it.getString(3)}",
          "provider_calendar_id" to it.getString(5)))
      }
    }
    return rows
  }

  private fun snapshot(ids: List<String>, from: Long, until: Long, signal: CancellationSignal): Map<String, Any> {
    val inventory = listCalendars(signal).map { it["native_id"] }.toSet()
    if (!inventory.containsAll(ids)) throw ReadFailure("source_unavailable")
    val uri = CalendarContract.Instances.CONTENT_URI.buildUpon().also {
      ContentUris.appendId(it, from); ContentUris.appendId(it, until)
    }.build()
    val columns = arrayOf("event_id", "calendar_id", "title", "description", "eventLocation", "begin", "end",
      "allDay", "_sync_id", "original_id", "original_sync_id", "originalInstanceTime", "originalAllDay", "rrule", "rdate")
    val selection = "calendar_id IN (${ids.joinToString(",") { "?" }})"
    val cursor = activity.contentResolver.query(uri, columns, selection, ids.toTypedArray(), null, signal)
      ?: throw ReadFailure("read_failed")
    val rows = mutableListOf<Map<String, Any?>>()
    val identities = mutableSetOf<String>()
    val masters = mutableMapOf<Long, Pair<String, Boolean>>()
    cursor.use {
      while (it.moveToNext()) {
        signal.throwIfCanceled()
        if (rows.size >= 50000) throw ReadFailure("too_many_events")
        val eventId = it.getLong(0)
        val calendar = it.getLong(1).toString()
        val start = it.getLong(5); val end = it.getLong(6)
        if (end <= start) throw ReadFailure("invalid_event")
        val allDay = it.getInt(7) != 0
        val originalId = it.longOrNull(9)
        val originalTime = it.longOrNull(11)
        val recurring = originalTime != null || !it.getString(13).isNullOrEmpty() || !it.getString(14).isNullOrEmpty()
        val master = if (originalId != null) masters.getOrPut(originalId) { master(originalId, signal) } else null
        val syncId = it.getString(10)?.takeIf { v -> v.isNotBlank() }
          ?: if (originalId == null) it.getString(8)?.takeIf { v -> v.isNotBlank() } else null
        val series = if (syncId != null) "sync:$syncId" else master?.first ?: "local:$eventId"
        val wasAllDay = it.longOrNull(12)?.let { v -> v != 0L } ?: master?.second ?: allDay
        val original = originalTime ?: start
        val anchor = if (!recurring) "single" else if (wasAllDay) "date:${date(original)}" else "time:${instant(original)}"
        if (!identities.add("$calendar\u0000$series\u0000$anchor")) throw ReadFailure("ambiguous_identity")
        rows.add(mapOf("native_calendar_id" to calendar, "provider_event_id" to series, "recurrence_id" to anchor,
          "title" to (it.getString(2) ?: ""), "detail" to (it.getString(3) ?: ""),
          "location" to (it.getString(4) ?: ""), "all_day" to allDay,
          "starts_at" to instant(start), "ends_at" to instant(end),
          "start_date" to if (allDay) date(start) else null, "end_date" to if (allDay) date(end) else null))
      }
    }
    return mapOf("complete" to true, "calendarIds" to ids, "fromMs" to from, "untilMs" to until, "events" to rows)
  }

  private fun master(id: Long, signal: CancellationSignal): Pair<String, Boolean> {
    val cursor = activity.contentResolver.query(ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, id),
      arrayOf("_sync_id", "allDay"), null, null, null, signal) ?: throw ReadFailure("series_unavailable")
    cursor.use {
      if (!it.moveToFirst()) throw ReadFailure("series_unavailable")
      val syncId = it.getString(0)?.takeIf { v -> v.isNotBlank() }
      return Pair(if (syncId == null) "local:$id" else "sync:$syncId", it.getInt(1) != 0)
    }
  }

  private fun read(result: MethodChannel.Result, work: (CancellationSignal) -> Any) {
    val reply = Reply(result)
    val signal = CancellationSignal()
    val deadline = Runnable { signal.cancel(); reply.error("timeout") }
    main.postDelayed(deadline, 20000)
    worker.execute {
      try {
        if (permission() != "granted") throw ReadFailure("permission_denied")
        val value = work(signal)
        if (permission() != "granted") throw ReadFailure("permission_denied")
        main.post { main.removeCallbacks(deadline); if (disposed) reply.error("disposed") else reply.success(value) }
      } catch (error: Exception) {
        val code = when (error) { is ReadFailure -> error.code; is SecurityException -> "permission_denied"; else -> "read_failed" }
        main.post { main.removeCallbacks(deadline); reply.error(code) }
      }
    }
  }

  override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
    onCancel(null)
    val listener = object : ContentObserver(main) {
      override fun onChange(selfChange: Boolean) { if (!disposed) sink.success("changed") }
    }
    activity.contentResolver.registerContentObserver(CalendarContract.CONTENT_URI, true, listener)
    observer = listener
  }
  override fun onCancel(arguments: Any?) {
    observer?.let { activity.contentResolver.unregisterContentObserver(it) }; observer = null
  }
  fun dispose() {
    disposed = true; onCancel(null); pendingPermission?.error("disposed"); pendingPermission = null
    channel.setMethodCallHandler(null); events.setStreamHandler(null); worker.shutdownNow()
  }
  private class ReadFailure(val code: String) : Exception()
  private class Reply(private val result: MethodChannel.Result) {
    private val done = AtomicBoolean(false)
    fun success(value: Any?) { if (done.compareAndSet(false, true)) result.success(value) }
    fun error(code: String) { if (done.compareAndSet(false, true)) result.error(code, null, null) }
  }
  private fun Cursor.longOrNull(index: Int): Long? = if (isNull(index)) null else getLong(index)
  private fun instant(millis: Long): String = Instant.ofEpochMilli(millis).toString()
  // Android Calendar Provider stores all-day dates in UTC, independently of device time zone.
  private fun date(millis: Long): String = Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate().toString()
}
