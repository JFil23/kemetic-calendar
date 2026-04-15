import 'package:flutter/material.dart';

import '../../shared/glossy_text.dart';
import 'kemetic_node_library.dart';
import 'kemetic_node_model.dart';

enum NodeLinkPickerAction { link, unlink }

class NodeLinkPickerResult {
  final NodeLinkPickerAction action;
  final KemeticNode? node;

  const NodeLinkPickerResult.link(this.node)
    : action = NodeLinkPickerAction.link;

  const NodeLinkPickerResult.unlink()
    : action = NodeLinkPickerAction.unlink,
      node = null;
}

Future<NodeLinkPickerResult?> showNodeLinkPickerSheet({
  required BuildContext context,
  required String selectedText,
  KemeticNode? currentNode,
}) {
  final nodes = KemeticNodeLibrary.nodes;
  return showModalBottomSheet<NodeLinkPickerResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.black,
    builder: (ctx) {
      final controller = TextEditingController();
      return StatefulBuilder(
        builder: (context, setSheet) {
          final query = controller.text.trim().toLowerCase();
          final filtered = nodes
              .where(
                (node) =>
                    query.isEmpty ||
                    node.title.toLowerCase().contains(query) ||
                    node.aliases.any(
                      (alias) => alias.toLowerCase().contains(query),
                    ),
              )
              .toList();

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  KemeticGold.text(
                    'Link Insight',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    selectedText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Search nodes...',
                      hintStyle: TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search, color: Colors.white54),
                    ),
                    onChanged: (_) => setSheet(() {}),
                  ),
                  const SizedBox(height: 10),
                  if (currentNode != null)
                    Card(
                      color: const Color(0xFF121212),
                      child: ListTile(
                        leading: const Icon(
                          Icons.link_off,
                          color: Colors.white70,
                        ),
                        title: Text(
                          'Remove link to ${currentNode.title}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: const Text(
                          'Leave the selected text unlinked.',
                          style: TextStyle(color: Colors.white54),
                        ),
                        onTap: () => Navigator.of(
                          ctx,
                        ).pop(const NodeLinkPickerResult.unlink()),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'No matching nodes.',
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final node = filtered[index];
                              final isCurrent = currentNode?.id == node.id;
                              return Card(
                                color: isCurrent
                                    ? const Color(0xFF1E1A12)
                                    : const Color(0xFF101010),
                                child: ListTile(
                                  leading: Icon(
                                    isCurrent
                                        ? Icons.check_circle
                                        : Icons.account_tree_outlined,
                                    color: isCurrent
                                        ? KemeticGold.base
                                        : Colors.white70,
                                  ),
                                  title: Text(
                                    node.title,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: node.aliases.isEmpty
                                      ? (isCurrent
                                            ? const Text(
                                                'Currently linked',
                                                style: TextStyle(
                                                  color: Colors.white54,
                                                ),
                                              )
                                            : null)
                                      : Text(
                                          isCurrent
                                              ? '${node.aliases.join(', ')}\nCurrently linked'
                                              : node.aliases.join(', '),
                                          style: const TextStyle(
                                            color: Colors.white54,
                                          ),
                                        ),
                                  isThreeLine:
                                      isCurrent && node.aliases.isNotEmpty,
                                  onTap: () => Navigator.of(
                                    ctx,
                                  ).pop(NodeLinkPickerResult.link(node)),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
