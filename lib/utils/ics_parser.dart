// lib/utils/ics_parser.dart

import 'dart:io';

class IcsEvent {
  final String title;
  final DateTime startTime;
  final DateTime? endTime;
  final String? location;
  final String? description;
  final bool isAllDay;

  IcsEvent({
    required this.title,
    required this.startTime,
    this.endTime,
    this.location,
    this.description,
    this.isAllDay = false,
  });

  @override
  String toString() {
    return 'IcsEvent(title: $title, start: $startTime, end: $endTime, location: $location, allDay: $isAllDay)';
  }
}

class IcsParser {
  /// Parse an ICS file from a file path
  static Future<List<IcsEvent>> parseFile(String filePath) async {
    try {
      print('[IcsParser] Reading file: $filePath');
      final file = File(filePath);
      final content = await file.readAsString();
      print('[IcsParser] File content length: ${content.length} characters');
      return parseString(content);
    } catch (e) {
      print('[IcsParser] Error reading file: $e');
      return [];
    }
  }

  /// Parse an ICS string directly
  static List<IcsEvent> parseString(String icsContent) {
    try {
      print('[IcsParser] Starting to parse ICS content');
      final events = <IcsEvent>[];
      
      // Manual parsing - split into lines
      final lines = icsContent.split('\n').map((line) => line.trim()).toList();
      print('[IcsParser] Total lines to process: ${lines.length}');
      
      bool inEvent = false;
      Map<String, String> currentEvent = {};
      
      for (var line in lines) {
        if (line.isEmpty) continue;
        
        if (line == 'BEGIN:VEVENT') {
          inEvent = true;
          currentEvent = {};
          print('[IcsParser] Found VEVENT start');
        } else if (line == 'END:VEVENT') {
          inEvent = false;
          print('[IcsParser] Found VEVENT end, parsing event data: $currentEvent');
          final event = _parseEventMap(currentEvent);
          if (event != null) {
            events.add(event);
            print('[IcsParser] Successfully parsed event: ${event.title}');
          }
        } else if (inEvent) {
          // Parse property line
          final colonIndex = line.indexOf(':');
          if (colonIndex > 0) {
            final key = line.substring(0, colonIndex);
            final value = line.substring(colonIndex + 1);
            currentEvent[key] = value;
            print('[IcsParser] Found property: $key = $value');
          }
        }
      }

      print('[IcsParser] Parsed ${events.length} events');
      return events;
    } catch (e) {
      print('[IcsParser] Error parsing ICS: $e');
      return [];
    }
  }
  
  /// Parse event from a map of properties
  static IcsEvent? _parseEventMap(Map<String, String> properties) {
    try {
      // Extract title
      final title = properties['SUMMARY'] ?? 'Untitled Event';
      print('[IcsParser] Event title: $title');
      
      // Extract start time
      final startRaw = properties['DTSTART'];
      if (startRaw == null) {
        print('[IcsParser] Warning: Event missing DTSTART, skipping');
        return null;
      }
      
      print('[IcsParser] DTSTART raw value: $startRaw');
      final startTime = _parseDateTime(startRaw);
      if (startTime == null) {
        print('[IcsParser] Warning: Could not parse DTSTART: $startRaw');
        return null;
      }
      
      print('[IcsParser] Parsed start time: $startTime');
      
      // Extract end time
      DateTime? endTime;
      final endRaw = properties['DTEND'];
      if (endRaw != null) {
        print('[IcsParser] DTEND raw value: $endRaw');
        endTime = _parseDateTime(endRaw);
        print('[IcsParser] Parsed end time: $endTime');
      }
      
      // Extract location
      final location = properties['LOCATION'];
      if (location != null) {
        print('[IcsParser] Location: $location');
      }
      
      // Extract description
      final description = properties['DESCRIPTION'];
      if (description != null) {
        print('[IcsParser] Description: $description');
      }
      
      return IcsEvent(
        title: title,
        startTime: startTime,
        endTime: endTime,
        location: location,
        description: description,
        isAllDay: false,
      );
    } catch (e) {
      print('[IcsParser] Error parsing event: $e');
      return null;
    }
  }

  /// Parse a datetime string (YYYYMMDDTHHMMSS or YYYYMMDDTHHMMSSZ)
  static DateTime? _parseDateTime(String dtStr) {
    try {
      print('[IcsParser] Parsing datetime: $dtStr');
      
      // Remove timezone indicator and separators
      final cleaned = dtStr.replaceAll(RegExp(r'[^0-9TZ]'), '');
      print('[IcsParser] Cleaned datetime: $cleaned');
      
      if (cleaned.length >= 15) {
        final year = int.parse(cleaned.substring(0, 4));
        final month = int.parse(cleaned.substring(4, 6));
        final day = int.parse(cleaned.substring(6, 8));
        final hour = int.parse(cleaned.substring(9, 11));
        final minute = int.parse(cleaned.substring(11, 13));
        final second = int.parse(cleaned.substring(13, 15));
        
        print('[IcsParser] Parsed components: year=$year, month=$month, day=$day, hour=$hour, minute=$minute, second=$second');
        
        // Check if UTC (ends with Z)
        final isUtc = cleaned.endsWith('Z');
        print('[IcsParser] Is UTC: $isUtc');
        
        if (isUtc) {
          final result = DateTime.utc(year, month, day, hour, minute, second);
          print('[IcsParser] Created UTC DateTime: $result');
          return result;
        } else {
          final result = DateTime(year, month, day, hour, minute, second);
          print('[IcsParser] Created local DateTime: $result');
          return result;
        }
      }
      
      print('[IcsParser] Warning: DateTime string too short: $cleaned');
      return null;
    } catch (e) {
      print('[IcsParser] Error parsing datetime: $e');
      return null;
    }
  }
}