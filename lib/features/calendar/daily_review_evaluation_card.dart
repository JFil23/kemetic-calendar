// lib/features/calendar/daily_review_evaluation_card.dart
// Daily review evaluation card with app theme colors

import 'package:flutter/material.dart';

class DailyReviewEvaluationCard extends StatelessWidget {
  final int completedFlowsCount;
  final int completedTasksCount;
  final VoidCallback onAddToJournal;
  final VoidCallback onDismiss;

  const DailyReviewEvaluationCard({
    super.key,
    required this.completedFlowsCount,
    required this.completedTasksCount,
    required this.onAddToJournal,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final total = completedFlowsCount + completedTasksCount;
    
    if (total == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0F), // Surface color from app theme
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withOpacity(0.3), // Primary purple border
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with glossy gradient
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF8B5CF6), // Primary purple
                  const Color(0xFFA78BFA), // Secondary purple
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.stars_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Day Complete!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary text
                Text(
                  _getSummaryText(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),

                // Stats with glossy accents
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black, // True black
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (completedFlowsCount > 0) ...[
                        _buildStatItem(
                          icon: Icons.route_rounded,
                          count: completedFlowsCount,
                          label: completedFlowsCount == 1 ? 'Flow' : 'Flows',
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD4AF37), Color(0xFFFFE8A3)], // Gold
                          ),
                        ),
                        if (completedTasksCount > 0) const SizedBox(width: 24),
                      ],
                      if (completedTasksCount > 0)
                        _buildStatItem(
                          icon: Icons.check_circle_rounded,
                          count: completedTasksCount,
                          label: completedTasksCount == 1 ? 'Task' : 'Tasks',
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4DA3FF), Color(0xFFBFE0FF)], // Blue
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Action button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: onAddToJournal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6), // Primary purple
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.edit_note_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Add to Journal',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required int count,
    required String label,
    required Gradient gradient,
  }) {
    return Expanded(
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => gradient.createShader(bounds),
            child: Icon(
              icon,
              size: 28,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              foreground: Paint()..shader = gradient.createShader(
                const Rect.fromLTWH(0, 0, 100, 100),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  String _getSummaryText() {
    final total = completedFlowsCount + completedTasksCount;
    
    if (total == 1) {
      return 'You completed 1 task today. Would you like to add it to your journal?';
    }
    
    return 'You completed $total tasks today! Would you like to add them to your journal?';
  }
}