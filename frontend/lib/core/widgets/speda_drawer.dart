import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/chat/providers/chat_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/speda_theme.dart';

class SpedaDrawer extends StatefulWidget {
  final Function(int)? onNavigation;

  const SpedaDrawer({super.key, this.onNavigation});

  @override
  State<SpedaDrawer> createState() => _SpedaDrawerState();
}

class _SpedaDrawerState extends State<SpedaDrawer> {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: SpedaColors.surface,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // New conversation button (Moved to top)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onNavigation?.call(0);
                      context.read<ChatProvider>().clearConversation();
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New Conversation'),
                    style: TextButton.styleFrom(
                      foregroundColor: SpedaColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: SpedaColors.surfaceLight,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),

              // Navigation items section
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  children: [
                    _buildNavDrawerItem(Icons.mic_rounded, 'Voice Mode', 1),
                    _buildNavDrawerItem(
                        Icons.check_circle_outline_rounded, 'Tasks', 2),
                    _buildNavDrawerItem(
                        Icons.calendar_today_rounded, 'Calendar', 3),
                    _buildNavDrawerItem(Icons.wb_sunny_rounded, 'Briefing', 4),
                    _buildNavDrawerItem(Icons.settings_rounded, 'Settings', 5),
                  ],
                ),
              ),

              SpedaWidgets.divider(),

              // History Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.history_rounded,
                      color: SpedaColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'History',
                      style: SpedaTypography.title.copyWith(
                        color: SpedaColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              // Conversation list
              _ConversationHistoryList(
                onConversationSelected: (conversationId) {
                  Navigator.pop(context); // Close drawer

                  // Navigate to chat screen (0)
                  widget.onNavigation?.call(0);

                  // Load conversation
                  context.read<ChatProvider>().loadConversation(conversationId);
                },
              ),

              const SizedBox(height: 20), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavDrawerItem(IconData icon, String label, int screenIndex) {
    return ListTile(
      leading: Icon(icon, color: SpedaColors.textSecondary, size: 22),
      title: Text(label,
          style: SpedaTypography.body.copyWith(color: SpedaColors.textPrimary)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () {
        Navigator.pop(context);
        widget.onNavigation?.call(screenIndex);
      },
    );
  }
}

/// Conversation history list widget
class _ConversationHistoryList extends StatefulWidget {
  final Function(int conversationId) onConversationSelected;

  const _ConversationHistoryList({required this.onConversationSelected});

  @override
  State<_ConversationHistoryList> createState() =>
      _ConversationHistoryListState();
}

class _ConversationHistoryListState extends State<_ConversationHistoryList> {
  List<ConversationPreview>? _conversations;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    try {
      final apiService = context.read<ApiService>();
      final conversations = await apiService.getConversations();
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _deleteConversation(int id) async {
    try {
      final apiService = context.read<ApiService>();
      await apiService.deleteConversation(id);

      // Update local list
      setState(() {
        _conversations?.removeWhere((c) => c.id == id);
      });

      // If current conversation was deleted, clear chat
      final currentChatId = context.read<ChatProvider>().currentConversationId;
      if (currentChatId == id) {
        if (mounted) context.read<ChatProvider>().clearConversation();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete conversation')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: SpedaColors.textSecondary));
    }

    if (_conversations == null || _conversations!.isEmpty) {
      return Center(
        child: Text(
          'No history',
          style: SpedaTypography.body.copyWith(color: SpedaColors.textTertiary),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _conversations!.length,
      itemBuilder: (context, index) {
        final conversation = _conversations![index];
        // Safely handle potential nulls if title/timestamp are null
        final title =
            conversation.title.isNotEmpty ? conversation.title : 'New Chat';

        return ListTile(
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SpedaTypography.body.copyWith(
              color: SpedaColors.textPrimary,
              fontSize: 14,
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
          dense: true,
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 16, color: SpedaColors.textTertiary),
            onPressed: () => _deleteConversation(conversation.id),
          ),
          onTap: () => widget.onConversationSelected(conversation.id),
        );
      },
    );
  }
}
