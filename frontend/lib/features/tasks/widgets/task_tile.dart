import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/api_response.dart';

/// Task tile widget for displaying a single task.
class TaskTile extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onComplete;
  final VoidCallback onDelete;

  const TaskTile({
    super.key,
    required this.task,
    required this.onComplete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue = task.isOverdue;
    final isCompleted = task.isCompleted;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: IconButton(
          icon: Icon(
            isCompleted
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            color: isCompleted
                ? theme.colorScheme.primary
                : isOverdue
                    ? theme.colorScheme.error
                    : null,
          ),
          onPressed: isCompleted ? null : onComplete,
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            color: isCompleted
                ? theme.colorScheme.onSurface.withOpacity(0.5)
                : null,
          ),
        ),
        subtitle: task.dueDate != null
            ? Text(
                DateFormat('MMM d, y').format(task.dueDate!),
                style: TextStyle(
                  color: isOverdue && !isCompleted
                      ? theme.colorScheme.error
                      : null,
                ),
              )
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmDelete(context),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
