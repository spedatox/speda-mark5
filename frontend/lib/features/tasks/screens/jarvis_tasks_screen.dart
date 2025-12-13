import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/jarvis_theme.dart';
import '../../../core/widgets/hud_widgets.dart';
import '../../../core/widgets/animated_widgets.dart';
import '../../../core/services/api_service.dart';
import '../providers/task_provider.dart';

/// JARVIS-style tasks screen
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  @override
  void initState() {
    super.initState();
    // Initial load - subsequent refreshes handled by MainScaffold on tab change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().loadTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarvisColors.background,
      body: Stack(
        children: [
          const Positioned.fill(
            child: HexagonPattern(color: JarvisColors.primary),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildTaskList()),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: JarvisColors.panelBorder),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 32,
            color: JarvisColors.primary,
            margin: const EdgeInsets.only(right: 12),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'TASK MANAGEMENT',
                  style: TextStyle(
                    color: JarvisColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                ),
                Text(
                  'ACTIVE OBJECTIVES',
                  style: TextStyle(
                    color: JarvisColors.textMuted,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          Consumer<TaskProvider>(
            builder: (context, provider, _) {
              final pending = provider.pendingCount;
              return DataDisplay(
                label: 'PENDING',
                value: pending.toString(),
                valueColor:
                    pending > 0 ? JarvisColors.warning : JarvisColors.online,
              );
            },
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
            child: ArcLoader(size: 60),
          );
        }

        final tasks = provider.tasks;
        
        if (tasks.isEmpty) {
          return _buildEmptyState(provider.googleConnected);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            if (task is GoogleTask) {
              return _buildGoogleTaskTile(task, provider);
            } else {
              return _buildTaskTile(task, provider);
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
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: JarvisColors.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'NO ACTIVE TASKS',
            style: TextStyle(
              color: JarvisColors.textMuted,
              fontSize: 14,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            googleConnected
                ? 'All objectives completed'
                : 'Connect Google in Settings to see your tasks',
            style: const TextStyle(
              color: JarvisColors.textMuted,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleTaskTile(GoogleTask task, TaskProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: JarvisColors.panelBackground,
        border: Border.all(
          color: task.isCompleted
              ? JarvisColors.online.withOpacity(0.3)
              : JarvisColors.accent.withOpacity(0.3),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: GridPatternPainter()),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Status indicator
                GestureDetector(
                  onTap: () => provider.completeTask(task.id),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: task.isCompleted
                            ? JarvisColors.online
                            : JarvisColors.accent,
                        width: 2,
                      ),
                      color: task.isCompleted
                          ? JarvisColors.online.withOpacity(0.2)
                          : Colors.transparent,
                    ),
                    child: task.isCompleted
                        ? const Icon(
                            Icons.check,
                            color: JarvisColors.online,
                            size: 14,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 16),

                // Task content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.g_mobiledata, color: JarvisColors.accent, size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              task.title.toUpperCase(),
                              style: TextStyle(
                                color: task.isCompleted
                                    ? JarvisColors.textMuted
                                    : JarvisColors.textPrimary,
                                fontSize: 13,
                                letterSpacing: 1,
                                decoration: task.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (task.due != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 12,
                              color: task.isOverdue ? Colors.red.shade400 : JarvisColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(task.due!),
                              style: TextStyle(
                                color: task.isOverdue ? Colors.red.shade400 : JarvisColors.textMuted,
                                fontSize: 10,
                                letterSpacing: 1,
                              ),
                            ),
                            if (task.isOverdue) ...[
                              const SizedBox(width: 8),
                              const Text(
                                'OVERDUE',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 9,
                                  letterSpacing: 1,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (task.notes != null && task.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.notes!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: JarvisColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTile(task, TaskProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: JarvisColors.panelBackground,
        border: Border.all(
          color: task.isCompleted
              ? JarvisColors.online.withOpacity(0.3)
              : JarvisColors.panelBorder,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: GridPatternPainter()),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Status indicator
                GestureDetector(
                  onTap: () => provider.completeTask(task.id),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: task.isCompleted
                            ? JarvisColors.online
                            : JarvisColors.primary,
                        width: 2,
                      ),
                      color: task.isCompleted
                          ? JarvisColors.online.withOpacity(0.2)
                          : Colors.transparent,
                    ),
                    child: task.isCompleted
                        ? const Icon(
                            Icons.check,
                            color: JarvisColors.online,
                            size: 14,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 16),

                // Task content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title.toUpperCase(),
                        style: TextStyle(
                          color: task.isCompleted
                              ? JarvisColors.textMuted
                              : JarvisColors.textPrimary,
                          fontSize: 13,
                          letterSpacing: 1,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (task.dueDate != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule,
                              size: 12,
                              color: JarvisColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(task.dueDate!),
                              style: const TextStyle(
                                color: JarvisColors.textMuted,
                                fontSize: 10,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Priority indicator (TaskModel doesn't have priority, use default)
                Container(
                  width: 4,
                  height: 32,
                  color: task.isOverdue ? JarvisColors.danger : JarvisColors.primary,
                ),
              ],
            ),
          ),

          // Corner accents
          Positioned(
              top: 0,
              left: 0,
              child: HudCorner(position: CornerPosition.topLeft, size: 8)),
          Positioned(
              top: 0,
              right: 0,
              child: HudCorner(position: CornerPosition.topRight, size: 8)),
          Positioned(
              bottom: 0,
              left: 0,
              child: HudCorner(position: CornerPosition.bottomLeft, size: 8)),
          Positioned(
              bottom: 0,
              right: 0,
              child: HudCorner(position: CornerPosition.bottomRight, size: 8)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  Widget _buildFab() {
    return GestureDetector(
      onTap: () => _showAddTaskDialog(),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: JarvisColors.primary.withOpacity(0.2),
          border: Border.all(color: JarvisColors.primary),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: JarvisColors.primary.withOpacity(0.3),
              blurRadius: 16,
            ),
          ],
        ),
        child: const Icon(
          Icons.add,
          color: JarvisColors.primary,
          size: 28,
        ),
      ),
    );
  }

  void _showAddTaskDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: JarvisColors.surface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: JarvisColors.panelBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    color: JarvisColors.primary,
                    margin: const EdgeInsets.only(right: 12),
                  ),
                  const Text(
                    'NEW TASK',
                    style: TextStyle(
                      color: JarvisColors.primary,
                      fontSize: 14,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: JarvisColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Task description...',
                  hintStyle: TextStyle(color: JarvisColors.textMuted),
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    context
                        .read<TaskProvider>()
                        .createTask(title: value.trim());
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  HudButton(
                    label: 'CANCEL',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  HudButton(
                    label: 'CREATE',
                    color: JarvisColors.online,
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty) {
                        context
                            .read<TaskProvider>()
                            .createTask(title: controller.text.trim());
                        Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
