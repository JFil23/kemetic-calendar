// lib/features/calendar/ics_preview_card.dart

import 'package:flutter/material.dart';

class IcsPreviewCard extends StatelessWidget {
  final String title;
  final DateTime startTime;
  final DateTime? endTime;
  final String? location;
  final String? description;
  final VoidCallback onAdd;
  final VoidCallback onEditAndAdd;
  final VoidCallback onCancel;

  const IcsPreviewCard({
    Key? key,
    required this.title,
    required this.startTime,
    this.endTime,
    this.location,
    this.description,
    required this.onAdd,
    required this.onEditAndAdd,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF000000), // True black
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    color: Color(0xFFD4AF37), // Gold
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Import Calendar Event',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFFD4AF37)),
                    onPressed: onCancel,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Event Title
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Date & Time
              _buildInfoRow(
                icon: Icons.access_time,
                text: _formatDateTime(startTime, endTime),
              ),

              // Location
              if (location != null && location!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.location_on,
                  text: location!,
                ),
              ],

              // Description
              if (description != null && description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0D0F), // Dark surface
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    description!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  // Edit & Add Button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onEditAndAdd,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD4AF37),
                        side: const BorderSide(color: Color(0xFFD4AF37)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Edit & Add',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Add Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onAdd,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37), // Gold
                        foregroundColor: const Color(0xFF000000), // Black text
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.6),
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime start, DateTime? end) {
    final startDate = '${_monthName(start.month)} ${start.day}, ${start.year}';
    final startTime = _formatTime(start);

    if (end == null) {
      return '$startDate at $startTime';
    }

    final endTime = _formatTime(end);
    
    // Same day
    if (start.year == end.year && 
        start.month == end.month && 
        start.day == end.day) {
      return '$startDate\n$startTime - $endTime';
    }

    // Different days
    final endDate = '${_monthName(end.month)} ${end.day}, ${end.year}';
    return '$startDate at $startTime\nto $endDate at $endTime';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}

