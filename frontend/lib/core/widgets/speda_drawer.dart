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
      backgroundColor: const Color(0xFF0A0A0F), // Deep JARVIS background
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SPEDA Header with Logo
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: SpedaColors.surface,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/images/speda_ui_logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'speda',
                          style: TextStyle(
                            fontFamily: 'Logirent',
                            fontSize: 28,
                            color: SpedaColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'cItadel ecosystem',
                          style: TextStyle(
                            fontFamily: 'Logirent',
                            fontSize: 12, // Adjusted for Logirent
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.5,
                            color: SpedaColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // New conversation button - JARVIS style
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    widget.onNavigation?.call(0);
                    context.read<ChatProvider>().clearConversation();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: SpedaColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: SpedaColors.primary.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded,
                            size: 18, color: SpedaColors.primary),
                        const SizedBox(width: 10),
                        Text(
                          'NEW CONVERSATION',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: SpedaColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Navigation Section Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Text(
                  'NAVIGATION',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: SpedaColors.textTertiary,
                  ),
                ),
              ),

              // Navigation items - JARVIS style
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    _buildNavDrawerItem(Icons.mic_rounded, 'VOICE MODE', 1),
                    _buildNavDrawerItem(
                        Icons.check_circle_outline_rounded, 'TASKS', 2),
                    _buildNavDrawerItem(
                        Icons.calendar_today_rounded, 'CALENDAR', 3),
                    _buildNavDrawerItem(Icons.wb_sunny_rounded, 'BRIEFING', 4),
                    _buildNavDrawerItem(Icons.settings_rounded, 'SETTINGS', 5),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Divider with JARVIS style
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                height: 1,
                color: SpedaColors.borderSubtle,
              ),

              // History Header - JARVIS style
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Text(
                  'HISTORY',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: SpedaColors.textTertiary,
                  ),
                ),
              ),

              // Conversation list
              _ConversationHistoryList(
                onConversationSelected: (conversationId) {
                  Navigator.pop(context);
                  widget.onNavigation?.call(0);
                  context.read<ChatProvider>().loadConversation(conversationId);
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavDrawerItem(IconData icon, String label, int screenIndex) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        widget.onNavigation?.call(screenIndex);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: SpedaColors.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: const Border(
            left: BorderSide(
              color: SpedaColors.primary,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: SpedaColors.primary, size: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.8,
                color: SpedaColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
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
