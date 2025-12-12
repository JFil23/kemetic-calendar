package com.example.mobile

import android.Manifest
import android.content.ContentUris
import android.content.ContentValues
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.CalendarContract
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
  private val channelName = "com.kemetic.calendar/sync"
  private val permissionRequest = 9910
  private var pendingPermissionResult: MethodChannel.Result? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
      when (call.method) {
        "requestPermissions" -> handleRequestPermissions(result)
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
        "upsertEvent" -> {
          val args = call.arguments as? Map<*, *>
          if (args == null) {
            result.error("bad_args", "Missing arguments", null)
            return@setMethodCallHandler
          }
          if (!hasCalendarPermission()) {
            result.error("no_permission", "Calendar permission not granted", null)
            return@setMethodCallHandler
          }
          result.success(upsertEvent(args))
        }
        "deleteEvent" -> {
          val args = call.arguments as? Map<*, *>
          val eventId = args?.get("eventId") as? String
          if (eventId == null) {
            result.error("bad_args", "Missing eventId", null)
            return@setMethodCallHandler
          }
          if (!hasCalendarPermission()) {
            result.success(false)
            return@setMethodCallHandler
          }
          result.success(deleteEvent(eventId))
        }
        else -> result.notImplemented()
      }
    }
  }

  private fun hasCalendarPermission(): Boolean {
    val perms = arrayOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR)
    return perms.all { ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED }
  }

  private fun handleRequestPermissions(result: MethodChannel.Result) {
    if (hasCalendarPermission()) {
      result.success(true)
      return
    }
    pendingPermissionResult = result
    val perms = arrayOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR)
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

  private fun upsertEvent(args: Map<*, *>): String? {
    val title = (args["title"] as? String) ?: "Untitled event"
    val description = args["description"] as? String
    val location = args["location"] as? String
    val allDay = args["allDay"] as? Boolean ?: false
    val start = (args["start"] as Number).toLong()
    val endArg = args["end"] as? Number
    val end = endArg?.toLong() ?: (start + 60 * 60 * 1000)
    val timeZone = (args["timeZone"] as? String) ?: TimeZone.getDefault().id
    val clientEventId = args["clientEventId"] as? String
    val calendarId = (args["calendarId"] as? String)?.toLongOrNull() ?: selectCalendarId()
    val existingId = (args["eventId"] as? String)?.toLongOrNull()

    if (calendarId == null) {
      return null
    }

    val values = ContentValues().apply {
      put(CalendarContract.Events.TITLE, title)
      put(CalendarContract.Events.DESCRIPTION, injectCid(description, clientEventId))
      put(CalendarContract.Events.EVENT_LOCATION, location)
      put(CalendarContract.Events.ALL_DAY, if (allDay) 1 else 0)
      put(CalendarContract.Events.DTSTART, start)
      put(CalendarContract.Events.DTEND, end)
      put(CalendarContract.Events.CALENDAR_ID, calendarId)
      put(CalendarContract.Events.EVENT_TIMEZONE, timeZone)
      put(CalendarContract.Events.EVENT_END_TIMEZONE, timeZone)
    }

    val cr = contentResolver
    return if (existingId == null) {
      val uri = cr.insert(CalendarContract.Events.CONTENT_URI, values)
      uri?.lastPathSegment
    } else {
      val updateUri = ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, existingId)
      val updated = cr.update(updateUri, values, null, null)
      if (updated > 0) existingId.toString() else null
    }
  }

  private fun deleteEvent(eventId: String): Boolean {
    val parsed = eventId.toLongOrNull() ?: return false
    val uri = ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, parsed)
    val rows = contentResolver.delete(uri, null, null)
    return rows > 0
  }

  private fun selectCalendarId(): Long? {
    val projection = arrayOf(
      CalendarContract.Calendars._ID,
      CalendarContract.Calendars.IS_PRIMARY,
      CalendarContract.Calendars.VISIBLE
    )
    val cursor = contentResolver.query(
      CalendarContract.Calendars.CONTENT_URI,
      projection,
      "${CalendarContract.Calendars.VISIBLE} = 1",
      null,
      null
    )
    var fallback: Long? = null
    cursor?.use {
      val idxId = it.getColumnIndex(CalendarContract.Calendars._ID)
      val idxPrimary = it.getColumnIndex(CalendarContract.Calendars.IS_PRIMARY)
      while (it.moveToNext()) {
        val id = it.getLong(idxId)
        val primary = it.getInt(idxPrimary) == 1
        if (fallback == null) fallback = id
        if (primary) {
          fallback = id
          break
        }
      }
    }
    cursor?.close()
    return fallback
  }

  private fun extractCid(text: String?): String? {
    if (text == null) return null
    val regex = Regex("kemet_cid:([^\\s]+)", RegexOption.IGNORE_CASE)
    val match = regex.find(text)
    return match?.groupValues?.getOrNull(1)
  }

  private fun injectCid(description: String?, cid: String?): String? {
    if (cid.isNullOrEmpty()) return description
    val base = description ?: ""
    val cleaned = Regex("kemet_cid:[^\\s]+", RegexOption.IGNORE_CASE).replace(base, "").trim()
    return if (cleaned.isEmpty()) {
      "kemet_cid:$cid"
    } else {
      if (cleaned.contains("kemet_cid:$cid", ignoreCase = true)) {
        cleaned
      } else {
        "$cleaned\n\nkemet_cid:$cid"
      }
    }
  }
}
