import 'package:flutter/material.dart';

// Integration Example: How to use ShareFlowSheet in your calendar

// Example 1: Add share button to flow management
// In your flow list or flow detail page:

void _addShareButtonExample() {
  // Add this to your widget's build method:
  IconButton(
    icon: const Icon(Icons.share, color: Color(0xFFD4AF37)),
    onPressed: () {
      // _openShareSheet(context, flowId, flowTitle);
    },
    tooltip: 'Share Flow',
  );
}

// Example 2: Share sheet method
Future<void> _openShareSheet(BuildContext context, int flowId, String flowTitle) async {
  final result = await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const Placeholder(), // Replace with ShareFlowSheet
  );
  
  if (result == true) {
    // Share was successful, maybe refresh the UI or show a success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Flow shared successfully!'),
        backgroundColor: Color(0xFFD4AF37),
      ),
    );
  }
}

// Example 3: Add to Flow Studio toolbar
// In your flow editing interface:

Widget _addToolbarExample() {
  return Row(
    children: [
      IconButton(
        icon: const Icon(Icons.save, color: Color(0xFFD4AF37)),
        onPressed: () {}, // _saveFlow
      ),
      IconButton(
        icon: const Icon(Icons.share, color: Color(0xFFD4AF37)),
        onPressed: () {
          // _openShareSheet(context, _currentFlow.id, _currentFlow.title);
        },
      ),
      IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () {}, // _closeFlow
      ),
    ],
  );
}

// Example 4: Integration with existing flow management
// In your flows viewer or flow detail page:

class FlowDetailPage extends StatelessWidget {
  const FlowDetailPage({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flow Title'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Color(0xFFD4AF37)),
            onPressed: () {
              // _openShareSheet(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Your existing flow content
          Expanded(
            child: _buildFlowContent(),
          ),
          
          // Add share button to bottom actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // _openShareSheet(context);
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share Flow'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // _editFlow();
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD4AF37),
                      side: const BorderSide(color: Color(0xFFD4AF37)),
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
  
  Widget _buildFlowContent() {
    return const Center(
      child: Text('Flow Content Here'),
    );
  }
  
  Future<void> _openShareSheet(BuildContext context) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const Placeholder(), // Replace with ShareFlowSheet
    );
    
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Flow shared successfully!'),
          backgroundColor: Color(0xFFD4AF37),
        ),
      );
    }
  }
}

