import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/speda_theme.dart';
import '../../../core/services/api_service.dart';
import '../providers/task_provider.dart';

/// Ultra-minimal tasks screen - 2026 design
class MinimalTasksScreen extends StatefulWidget {
  const MinimalTasksScreen({super.key});

  @override
  State<MinimalTasksScreen> createState() => _MinimalTasksScreenState();
}

class _MinimalTasksScreenState extends State<MinimalTasksScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().loadTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpedaColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildTaskList()),
          ],
        ),
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Menu button
          GestureDetector(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: const Icon(
              Icons.menu_rounded,
              size: 26,
              color: SpedaColors.textSecondary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tasks',
                  style: SpedaTypography.heading.copyWith(
                    fontSize: 24,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Consumer<TaskProvider>(
                  builder: (context, provider, _) {
                    final pending = provider.pendingCount;
                    return Text(
                      pending > 0
                          ? '$pending task${pending > 1 ? 's' : ''} remaining'
                          : 'All caught up',
                      style: SpedaTypography.bodySmall.copyWith(
                        color: SpedaColors.textTertiary,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Refresh button
          GestureDetector(
            onTap: () => context.read<TaskProvider>().loadTasks(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SpedaColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                size: 20,
                color: SpedaColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList() {
    return Consumer<TaskProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              color: SpedaColors.primary,
              strokeWidth: 2,
            ),
          );
        }

        final tasks = provider.tasks;

        if (tasks.isEmpty) {
          return _buildEmptyState(provider.googleConnected);
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            if (task is GoogleTask) {
              return _buildTaskTile(
                id: task.id,
                title: task.title,
                notes: task.notes,
                dueDate: task.due,
                isCompleted: task.isCompleted,
                isOverdue: task.isOverdue,
                isGoogle: true,
                provider: provider,
              );
            } else {
              return _buildTaskTile(
                id: task.id,
                title: task.title,
                notes: null,
                dueDate: task.dueDate,
                isCompleted: task.isCompleted,
                isOverdue: task.isOverdue,
                isGoogle: false,
                provider: provider,
              );
            }
          },
        );
      },
    );
  }

  Widget _buildEmptyState(bool googleConnected) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: SpedaColors.surfaceLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.check_circle_outline_rounded,
              size: 48,
              color: SpedaColors.success.withAlpha(150),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            googleConnected ? 'All done!' : 'No tasks',
            style: SpedaTypography.title,
          ),
          const SizedBox(height: 8),
          Text(
            googleConnected
                ? 'You\'ve completed all your tasks'
                : 'Connect Google in Settings to sync tasks',
            style: SpedaTypography.bodySmall.copyWith(
              color: SpedaColors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTile({
    required dynamic id,
    required String title,
    String? notes,
    DateTime? dueDate,
    required bool isCompleted,
    required bool isOverdue,
    required bool isGoogle,
    required TaskProvider provider,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: SpedaColors.surface,
        borderRadius: BorderRadius.circular(SpedaRadius.lg),
        border: Border.all(
          color: isCompleted
              ? SpedaColors.success.withAlpha(50)
              : isOverdue
                  ? SpedaColors.error.withAlpha(50)
                  : SpedaColors.border,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(SpedaRadius.lg),
          onTap: () {
            // Future: open task details
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Checkbox
                GestureDetector(
                  onTap: () => provider.completeTask(id),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted
                          ? SpedaColors.success
                          : Colors.transparent,
                      border: Border.all(
                        color: isCompleted
                            ? SpedaColors.success
                            : SpedaColors.textTertiary,
                        width: 2,
                      ),
                    ),
                    child: isCompleted
                        ? const Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isGoogle) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: SpedaColors.primarySubtle,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'G',
                                style: TextStyle(
                                  color: SpedaColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              title,
                              style: SpedaTypography.body.copyWith(
                                color: isCompleted
                                    ? SpedaColors.textTertiary
                                    : SpedaColors.textPrimary,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (dueDate != null || notes != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (dueDate != null) ...[
                              Icon(
                                Icons.schedule_rounded,
                                size: 14,
                                color: isOverdue
                                    ? SpedaColors.error
                                    : SpedaColors.textTertiary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(dueDate),
                                style: SpedaTypography.caption.copyWith(
                                  color: isOverdue
                                      ? SpedaColors.error
                                      : SpedaColors.textTertiary,
                                ),
                              ),
                              if (isOverdue) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: SpedaColors.error.withAlpha(25),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Overdue',
                                    style: SpedaTypography.caption.copyWith(
                                      color: SpedaColors.error,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ],
                      if (notes != null && notes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          notes,
                          style: SpedaTypography.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == tomorrow) {
      return 'Tomorrow';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  Widget _buildFab() {
    return FloatingActionButton(
      onPressed: _showAddTaskDialog,
      backgroundColor: SpedaColors.primary,
      child: const Icon(
        Icons.add_rounded,
        color: SpedaColors.background,
      ),
    );
  }

  void _showAddTaskDialog() {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: SpedaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: SpedaColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'New Task',
              style: SpedaTypography.title,
            ),
            const SizedBox(height: 16),

            TextField(
              controller: controller,
              autofocus: true,
              style: SpedaTypography.body,
              decoration: InputDecoration(
                hintText: 'What do you need to do?',
                hintStyle: SpedaTypography.body.copyWith(
                  color: SpedaColors.textTertiary,
                ),
                filled: true,
                fillColor: SpedaColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  context.read<TaskProvider>().createTask(title: value.trim());
                  Navigator.pop(context);
                }
              },
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: SpedaTypography.label.copyWith(
                        color: SpedaColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty) {
                        context
                            .read<TaskProvider>()
                            .createTask(title: controller.text.trim());
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Add Task'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
