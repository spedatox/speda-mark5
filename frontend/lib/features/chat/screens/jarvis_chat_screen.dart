import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';

import '../../../core/theme/jarvis_theme.dart';
import '../../../core/widgets/hud_widgets.dart';
import '../../../core/widgets/animated_widgets.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/google_auth_service.dart';
import '../../../core/config/app_config.dart';
import '../providers/chat_provider.dart';

/// JARVIS-style chat screen with HUD elements
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _lastMessageCount = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _sendMessage() {
    final message = _textController.text.trim();
    if (message.isEmpty) return;

    context.read<ChatProvider>().sendMessage(message);
    _textController.clear();
    _focusNode.requestFocus();
  }

  void _prefillMessage(String content) {
    _textController.text = content;
    _focusNode.requestFocus();
  }

  void _regenerateLastResponse() {
    context.read<ChatProvider>().regenerateLastResponse();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: JarvisColors.background,
      drawer: _buildHistoryDrawer(),
      body: Stack(
        children: [
          // Background effects
          const Positioned.fill(
            child: HexagonPattern(color: JarvisColors.primary),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _buildChatArea(),
                ),
                _buildInputArea(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryDrawer() {
    return Drawer(
      backgroundColor: JarvisColors.surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: JarvisColors.panelBorder),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.history,
                    color: JarvisColors.primary, size: 20),
                const SizedBox(width: 12),
                Text(
                  'CONVERSATION HISTORY',
                  style: TextStyle(
                    color: JarvisColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _ConversationHistoryList(
              onConversationSelected: (conversationId) {
                Navigator.pop(context);
                context.read<ChatProvider>().loadConversation(conversationId);
              },
            ),
          ),
          // Settings Section
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: JarvisColors.panelBorder),
              ),
            ),
            child: Column(
              children: [
                // Settings button
                ListTile(
                  leading: const Icon(Icons.settings,
                      color: JarvisColors.textMuted, size: 20),
                  title: const Text(
                    'SETTINGS',
                    style: TextStyle(
                      color: JarvisColors.textMuted,
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showSettingsDialog();
                  },
                  dense: true,
                ),
                // New conversation button
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        context.read<ChatProvider>().clearConversation();
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('NEW CONVERSATION'),
                      style: TextButton.styleFrom(
                        foregroundColor: JarvisColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
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

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => const _SettingsDialog(),
    );
  }

  Widget _buildHeader() {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: JarvisColors.panelBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Hamburger menu for history
          IconButton(
            icon: const Icon(Icons.menu, size: 22),
            color: JarvisColors.textMuted,
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            tooltip: 'HISTORY',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SPEDA',
                  style: textTheme.titleMedium?.copyWith(
                    color: JarvisColors.primary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                ),
                Consumer<ChatProvider>(
                  builder: (context, chatProvider, child) {
                    final isOnline = chatProvider.isBackendConnected;
                    return GestureDetector(
                      onTap: () => chatProvider.refreshConnectionStatus(),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: isOnline
                                  ? JarvisColors.online
                                  : JarvisColors.danger,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (isOnline
                                          ? JarvisColors.online
                                          : JarvisColors.danger)
                                      .withOpacity(0.6),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            isOnline ? 'SYSTEM ONLINE' : 'SYSTEM OFFLINE',
                            style: TextStyle(
                              color: isOnline
                                  ? JarvisColors.textMuted
                                  : JarvisColors.danger,
                              fontSize: 9,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Time display
          _buildTimeDisplay(),

          const SizedBox(width: 16),

          // Actions
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            color: JarvisColors.textMuted,
            onPressed: () => context.read<ChatProvider>().clearConversation(),
            tooltip: 'NEW SESSION',
          ),
        ],
      ),
    );
  }

  Widget _buildTimeDisplay() {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final now = DateTime.now();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontFamily: JarvisTheme.fontFamily,
                color: JarvisColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            Text(
              '${now.day}.${now.month}.${now.year}',
              style: const TextStyle(
                fontFamily: JarvisTheme.fontFamily,
                color: JarvisColors.textMuted,
                fontSize: 9,
                letterSpacing: 1,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChatArea() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        if (chatProvider.messages.isEmpty) {
          _lastMessageCount = 0;
          return _buildWelcomeScreen();
        }

        final currentCount = chatProvider.messages.length;
        if (currentCount > _lastMessageCount) {
          _lastMessageCount = currentCount;
          _scrollToBottom();
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: chatProvider.messages.length,
          itemBuilder: (context, index) {
            return _buildMessageBubble(chatProvider.messages[index]);
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    // Show inline processing indicator during function/tool execution
    final showProcessingIndicator =
        message.isStreaming && message.processingStatus != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser && false) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 10, top: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: JarvisColors.primary.withOpacity(0.5)),
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: JarvisColors.primary,
                size: 14,
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? JarvisColors.primary.withOpacity(0.15)
                    : JarvisColors.surface,
                border: Border.all(
                  color: message.isUser
                      ? JarvisColors.primary.withOpacity(0.5)
                      : JarvisColors.panelBorder,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(message.isUser ? 18 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showProcessingIndicator) ...[
                    // Inline processing indicator
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: JarvisColors.primary.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          message.processingStatus!,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: JarvisColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w300,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: message.isUser
                            ? Text(
                                message.content,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: JarvisColors.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w300,
                                  height: 1.5,
                                ),
                              )
                            : _buildMarkdownContent(
                                message.isStreaming
                                    ? '${message.content}▌'
                                    : message.content,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: JarvisColors.textMuted,
                      fontSize: 9,
                      letterSpacing: 1,
                    ),
                  ),
                  if (!message.isStreaming && message.content.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: message.isUser
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        if (message.isUser)
                          GestureDetector(
                            onTap: () => _prefillMessage(message.content),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: JarvisColors.textMuted.withOpacity(0.6),
                            ),
                          ),
                        if (!message.isUser)
                          GestureDetector(
                            onTap: _regenerateLastResponse,
                            child: Icon(
                              Icons.refresh,
                              size: 16,
                              color: JarvisColors.textMuted.withOpacity(0.6),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(left: 10, top: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: JarvisColors.accent.withOpacity(0.5)),
              ),
              child: const Icon(
                Icons.person,
                color: JarvisColors.accent,
                size: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Build markdown content with code block support
  Widget _buildMarkdownContent(String content) {
    return MarkdownBody(
      data: content,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          fontFamily: 'Inter',
          color: JarvisColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w300,
          height: 1.5,
        ),
        h1: TextStyle(
          fontFamily: 'Inter',
          color: JarvisColors.primary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        h2: TextStyle(
          fontFamily: 'Inter',
          color: JarvisColors.primary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        h3: TextStyle(
          fontFamily: 'Inter',
          color: JarvisColors.primary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        strong: TextStyle(
          fontFamily: 'Inter',
          color: JarvisColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        em: TextStyle(
          fontFamily: 'Inter',
          color: JarvisColors.textPrimary,
          fontStyle: FontStyle.italic,
        ),
        code: TextStyle(
          color: JarvisColors.accent,
          backgroundColor: JarvisColors.background,
          fontFamily: 'monospace',
          fontSize: 12,
        ),
        codeblockDecoration: BoxDecoration(
          color: JarvisColors.background,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: JarvisColors.panelBorder),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: JarvisColors.primary, width: 3),
          ),
        ),
        blockquotePadding: const EdgeInsets.only(left: 12),
        listBullet: TextStyle(color: JarvisColors.primary),
        a: TextStyle(
          color: JarvisColors.accent,
          decoration: TextDecoration.underline,
        ),
      ),
      builders: {
        'code': _CodeBlockBuilder(),
      },
      onTapLink: (text, href, title) async {
        if (href != null) {
          final uri = Uri.parse(href);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
    );
  }

  Widget _buildWelcomeScreen() {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 32),

          Text(
            'SPEDA ASSISTANT',
            style: textTheme.headlineSmall?.copyWith(
              color: JarvisColors.primary,
              fontSize: 25,
              fontWeight: FontWeight.w700,
              letterSpacing: 5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'PERSONAL EXECUTIVE SYSTEM',
            style: textTheme.labelMedium?.copyWith(
              color: JarvisColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 3.2,
            ),
          ),

          const SizedBox(height: 48),

          // Quick actions
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _buildQuickAction(Icons.list_alt, 'TASKS', 'Show my tasks'),
              _buildQuickAction(Icons.calendar_today, 'SCHEDULE',
                  'What\'s on my calendar today?'),
              _buildQuickAction(
                  Icons.wb_sunny, 'BRIEFING', 'Give me my daily briefing'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, String message) {
    return HudButton(
      label: label,
      icon: icon,
      onPressed: () => context.read<ChatProvider>().sendMessage(message),
    );
  }

  Widget _buildInputArea() {
    return Consumer<ChatProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: JarvisColors.surface,
            border: Border(
              top: BorderSide(color: JarvisColors.panelBorder),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // File upload button
                _buildAttachButton(provider.isLoading),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: JarvisColors.background,
                      border: Border.all(color: JarvisColors.panelBorder),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: JarvisColors.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Message Speda...',
                        hintStyle: TextStyle(
                          fontFamily: 'Inter',
                          color: JarvisColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _buildSendButton(provider.isLoading),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isPickingFile = false;

  Future<void> _pickAndUploadFile() async {
    if (_isPickingFile) return;
    setState(() => _isPickingFile = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
        withData: false,
      );

      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      if (path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File path unavailable')),
          );
        }
        return;
      }

      await context.read<ChatProvider>().uploadFile(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingFile = false);
    }
  }

  Widget _buildAttachButton(bool isLoading) {
    return GestureDetector(
      onTap: (isLoading || _isPickingFile) ? null : _pickAndUploadFile,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: JarvisColors.background,
          border: Border.all(color: JarvisColors.panelBorder),
          borderRadius: BorderRadius.circular(24),
        ),
        child: _isPickingFile
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: ArcLoader(size: 20, strokeWidth: 2),
              )
            : Icon(
                Icons.attach_file,
                color: (isLoading || _isPickingFile)
                    ? JarvisColors.textMuted
                    : JarvisColors.accent,
                size: 20,
              ),
      ),
    );
  }

  Widget _buildSendButton(bool isLoading) {
    return GestureDetector(
      onTap: isLoading ? null : _sendMessage,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isLoading
              ? JarvisColors.panelBorder
              : JarvisColors.primary.withOpacity(0.2),
          border: Border.all(
            color: isLoading ? JarvisColors.panelBorder : JarvisColors.primary,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: isLoading
              ? null
              : [
                  BoxShadow(
                    color: JarvisColors.primary.withOpacity(0.3),
                    blurRadius: 12,
                  ),
                ],
        ),
        child: isLoading
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: ArcLoader(size: 20, strokeWidth: 2),
              )
            : const Icon(
                Icons.arrow_upward_rounded,
                color: JarvisColors.primary,
                size: 20,
              ),
      ),
    );
  }
}

/// Blinking cursor for streaming messages
class _StreamingCursor extends StatefulWidget {
  const _StreamingCursor();

  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _controller.value,
          child: Container(
            width: 8,
            height: 16,
            margin: const EdgeInsets.only(bottom: 2),
            color: JarvisColors.primary,
          ),
        );
      },
    );
  }
}

/// Conversation history list widget
class _ConversationHistoryList extends StatefulWidget {
  final Function(int) onConversationSelected;

  const _ConversationHistoryList({
    required this.onConversationSelected,
  });

  @override
  State<_ConversationHistoryList> createState() =>
      _ConversationHistoryListState();
}

class _ConversationHistoryListState extends State<_ConversationHistoryList> {
  List<ConversationPreview>? _conversations;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = context.read<ApiService>();
      final conversations = await apiService.getConversations();
      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: ArcLoader(size: 32, strokeWidth: 2),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade400, size: 32),
            const SizedBox(height: 8),
            Text(
              'Failed to load history',
              style: TextStyle(color: JarvisColors.textMuted, fontSize: 12),
            ),
            TextButton(
              onPressed: _loadConversations,
              child: const Text('RETRY'),
            ),
          ],
        ),
      );
    }

    if (_conversations == null || _conversations!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline,
                color: JarvisColors.textMuted.withOpacity(0.5), size: 48),
            const SizedBox(height: 16),
            Text(
              'No conversations yet',
              style: TextStyle(color: JarvisColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _conversations!.length,
      itemBuilder: (context, index) {
        final conv = _conversations![index];
        return _ConversationTile(
          conversation: conv,
          onTap: () => widget.onConversationSelected(conv.id),
          onDelete: () async {
            try {
              final apiService = context.read<ApiService>();
              await apiService.deleteConversation(conv.id);
              _loadConversations();
            } catch (e) {
              // Handle error
            }
          },
        );
      },
    );
  }
}

/// Individual conversation tile
class _ConversationTile extends StatelessWidget {
  final ConversationPreview conversation;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ConversationTile({
    required this.conversation,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final timeAgo = _formatTimeAgo(conversation.startedAt);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: JarvisColors.panelBorder, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: JarvisColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    conversation.preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: JarvisColors.textMuted,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: JarvisColors.textMuted,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${conversation.messageCount} messages',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: JarvisColors.textMuted,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: JarvisColors.textMuted,
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

/// Settings dialog for app configuration
class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog();

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  bool _googleConnected = false;
  bool _microsoftConnected = false;
  bool _isLoading = true;
  LlmSettings? _llmSettings;
  String? _selectedLlm;
  final TextEditingController _modelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAuthStatus();
  }

  @override
  void dispose() {
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _loadAuthStatus() async {
    try {
      final apiService = context.read<ApiService>();
      final status = await apiService.getAuthStatus();
      final llm = await apiService.getLlmSettings();
      setState(() {
        _googleConnected = status['google'] ?? false;
        _microsoftConnected = status['microsoft'] ?? false;
        _llmSettings = llm;
        _selectedLlm = llm.provider;
        _modelController.text = llm.model ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateLlm() async {
    if (_selectedLlm == null) return;
    try {
      final apiService = context.read<ApiService>();
      final updated = await apiService.updateLlm(
        provider: _selectedLlm!,
        model: _modelController.text.trim().isEmpty
            ? null
            : _modelController.text.trim(),
      );
      setState(() {
        _llmSettings = updated;
        _selectedLlm = updated.provider;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('LLM settings updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update model: $e')),
        );
      }
    }
  }

  Future<void> _connectGoogle() async {
    try {
      final apiService = context.read<ApiService>();
      final isMobile = GoogleAuthService.shouldUseNativeSignIn;

      if (isMobile) {
        // Use native Google Sign-In on mobile
        try {
          final googleAuth = GoogleAuthService();
          final auth = await googleAuth.signIn();

          if (auth != null && auth.accessToken != null) {
            // Send token to backend
            final success = await apiService.sendGoogleMobileToken(
              auth.accessToken!,
              idToken: auth.idToken,
            );

            if (success) {
              setState(() => _googleConnected = true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Google connected successfully!')),
                );
              }
              return; // Success - exit early
            } else {
              throw Exception('Failed to authenticate with backend');
            }
          } else {
            // User cancelled - just return without error
            return;
          }
        } catch (e) {
          // Native sign-in failed, fall through to web flow
          print('Native Google Sign-In failed: $e, falling back to web flow');
        }
      }

      // Use web OAuth flow (fallback for mobile if native fails, or primary for web)
      final authUrl = await apiService.getGoogleAuthUrl(
        platform: 'mobile',
      );

      if (authUrl != null) {
        await apiService.openUrl(authUrl);

        // Show waiting dialog
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: JarvisColors.surface,
              title: const Text(
                'CONNECTING TO GOOGLE',
                style: TextStyle(
                  color: JarvisColors.primary,
                  fontSize: 14,
                  letterSpacing: 2,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ArcLoader(size: 40),
                  const SizedBox(height: 16),
                  const Text(
                    'Complete sign-in in your browser, then click Done.',
                    style: TextStyle(
                        color: JarvisColors.textPrimary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _loadAuthStatus();
                    },
                    child: const Text('DONE'),
                  ),
                ],
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e')),
        );
      }
    }
  }

  Future<void> _disconnectGoogle() async {
    try {
      final apiService = context.read<ApiService>();
      await apiService.logoutGoogle();

      // Also sign out from native Google Sign-In if on mobile
      if (GoogleAuthService.shouldUseNativeSignIn) {
        await GoogleAuthService().signOut();
      }

      setState(() => _googleConnected = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to disconnect: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: JarvisColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: JarvisColors.panelBorder),
      ),
      child: Container(
        width: 420,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    color: JarvisColors.primary,
                    margin: const EdgeInsets.only(right: 12),
                  ),
                  const Text(
                    'SETTINGS',
                    style: TextStyle(
                      color: JarvisColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: JarvisColors.textMuted,
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Integrations section
              const Text(
                'INTEGRATIONS',
                style: TextStyle(
                  color: JarvisColors.textMuted,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),

              if (_isLoading)
                const Center(child: ArcLoader(size: 32))
              else ...[
                // Google Account
                _buildIntegrationTile(
                  icon: Icons.g_mobiledata,
                  title: 'Google Account',
                  subtitle: _googleConnected
                      ? 'Calendar & Tasks connected'
                      : 'Connect for Calendar & Tasks',
                  connected: _googleConnected,
                  onConnect: _connectGoogle,
                  onDisconnect: _disconnectGoogle,
                ),
                const SizedBox(height: 12),

                // Microsoft Account (future)
                _buildIntegrationTile(
                  icon: Icons.window,
                  title: 'Microsoft 365',
                  subtitle: _microsoftConnected
                      ? 'Mail connected'
                      : 'Connect for School Mail',
                  connected: _microsoftConnected,
                  onConnect: () {
                    // TODO: Implement Microsoft auth
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Microsoft integration coming soon')),
                    );
                  },
                  onDisconnect: () {},
                ),
              ],

              const SizedBox(height: 24),

              // LLM selection - Modern chip style
              const Text(
                'AI MODEL',
                style: TextStyle(
                  color: JarvisColors.textMuted,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),

              // Provider chips
              if (_llmSettings != null) ...[
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: (_llmSettings?.availableProviders ?? ['mock'])
                      .map((provider) {
                    final isSelected = _selectedLlm == provider;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedLlm = provider);
                        _updateLlm();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? JarvisColors.primary.withOpacity(0.2)
                              : JarvisColors.background,
                          border: Border.all(
                            color: isSelected
                                ? JarvisColors.primary
                                : JarvisColors.panelBorder,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color:
                                        JarvisColors.primary.withOpacity(0.3),
                                    blurRadius: 12,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getLlmIcon(provider),
                              size: 18,
                              color: isSelected
                                  ? JarvisColors.primary
                                  : JarvisColors.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getLlmDisplayName(provider),
                              style: TextStyle(
                                color: isSelected
                                    ? JarvisColors.primary
                                    : JarvisColors.textSecondary,
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: JarvisColors.primary,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Model selection dropdown
                if (_selectedLlm == 'openai' &&
                    (_llmSettings?.availableModels.isNotEmpty ?? false)) ...[
                  const Text(
                    'SELECT MODEL',
                    style: TextStyle(
                      color: JarvisColors.textMuted,
                      fontSize: 10,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: JarvisColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: JarvisColors.panelBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _llmSettings?.availableModels
                                    .contains(_modelController.text) ==
                                true
                            ? _modelController.text
                            : _llmSettings?.availableModels.first,
                        isExpanded: true,
                        dropdownColor: JarvisColors.surface,
                        icon: Icon(Icons.keyboard_arrow_down,
                            color: JarvisColors.primary),
                        style: TextStyle(
                            color: JarvisColors.textPrimary, fontSize: 13),
                        items:
                            (_llmSettings?.availableModels ?? []).map((model) {
                          return DropdownMenuItem<String>(
                            value: model,
                            child: Text(
                              model,
                              style: TextStyle(
                                color: model == _modelController.text
                                    ? JarvisColors.primary
                                    : JarvisColors.textPrimary,
                                fontWeight: model == _modelController.text
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _modelController.text = value);
                            _updateLlm();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Current model display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: JarvisColors.background.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: JarvisColors.panelBorder.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.memory,
                          size: 16, color: JarvisColors.textMuted),
                      const SizedBox(width: 8),
                      Text(
                        'Active: ',
                        style: TextStyle(
                          color: JarvisColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        _llmSettings?.model ?? 'Default',
                        style: TextStyle(
                          color: JarvisColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Backend selection
              const Text(
                'BACKEND',
                style: TextStyle(
                  color: JarvisColors.textMuted,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),

              // Backend toggle chips
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildBackendChip(
                    icon: Icons.computer,
                    label: 'Local',
                    isSelected: AppConfig.isLocalBackend,
                    onTap: () async {
                      await AppConfig.setBackendMode(AppConfig.localMode);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Switched to Local backend. Restart app to apply.'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                      setState(() {});
                    },
                  ),
                  _buildBackendChip(
                    icon: Icons.cloud,
                    label: 'Cloud',
                    isSelected: AppConfig.isCloudBackend,
                    onTap: () async {
                      await AppConfig.setBackendMode(AppConfig.cloudMode);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Switched to Cloud backend. Restart app to apply.'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Current: ${AppConfig.apiBaseUrl}',
                style: TextStyle(
                  color: JarvisColors.textMuted,
                  fontSize: 10,
                ),
              ),

              const SizedBox(height: 24),

              // About section
              const Text(
                'ABOUT',
                style: TextStyle(
                  color: JarvisColors.textMuted,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'SPEDA v0.1.0',
                style: TextStyle(
                  color: JarvisColors.textPrimary,
                  fontSize: 12,
                ),
              ),
              const Text(
                'Personal Executive Digital Assistant',
                style: TextStyle(
                  color: JarvisColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackendChip({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? JarvisColors.primary.withOpacity(0.2)
              : JarvisColors.background,
          border: Border.all(
            color: isSelected ? JarvisColors.primary : JarvisColors.panelBorder,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: JarvisColors.primary.withOpacity(0.3),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? JarvisColors.primary : JarvisColors.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? JarvisColors.primary
                    : JarvisColors.textSecondary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 0.5,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.check_circle,
                size: 16,
                color: JarvisColors.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getLlmIcon(String provider) {
    switch (provider.toLowerCase()) {
      case 'openai':
        return Icons.auto_awesome;
      case 'anthropic':
        return Icons.psychology;
      case 'google':
        return Icons.g_mobiledata;
      case 'mock':
        return Icons.bug_report;
      default:
        return Icons.smart_toy;
    }
  }

  String _getLlmDisplayName(String provider) {
    switch (provider.toLowerCase()) {
      case 'openai':
        return 'OpenAI GPT';
      case 'anthropic':
        return 'Claude';
      case 'google':
        return 'Gemini';
      case 'mock':
        return 'Mock (Test)';
      default:
        return provider.toUpperCase();
    }
  }

  Widget _buildIntegrationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool connected,
    required VoidCallback onConnect,
    required VoidCallback onDisconnect,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(
          color: connected
              ? JarvisColors.online.withOpacity(0.5)
              : JarvisColors.panelBorder,
        ),
        borderRadius: BorderRadius.circular(16),
        color: connected ? JarvisColors.online.withOpacity(0.05) : null,
      ),
      child: Row(
        children: [
          Icon(icon,
              color: connected ? JarvisColors.online : JarvisColors.textMuted,
              size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: JarvisColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: JarvisColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (connected)
            TextButton(
              onPressed: onDisconnect,
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade400,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('DISCONNECT',
                  style: TextStyle(fontSize: 10, letterSpacing: 1)),
            )
          else
            TextButton(
              onPressed: onConnect,
              style: TextButton.styleFrom(
                foregroundColor: JarvisColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('CONNECT',
                  style: TextStyle(fontSize: 10, letterSpacing: 1)),
            ),
        ],
      ),
    );
  }
}

/// Custom code block builder with copy functionality
class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(element, preferredStyle) {
    final code = element.textContent;
    String? language;

    // Try to extract language from class attribute
    if (element.attributes['class'] != null) {
      final classes = element.attributes['class']!.split(' ');
      for (final cls in classes) {
        if (cls.startsWith('language-')) {
          language = cls.substring(9);
          break;
        }
      }
    }

    return _CodeBlockWidget(code: code, language: language);
  }
}

/// Code block widget with syntax highlighting and copy button
class _CodeBlockWidget extends StatelessWidget {
  final String code;
  final String? language;

  const _CodeBlockWidget({
    required this.code,
    this.language,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: JarvisColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: JarvisColors.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with language and copy button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: JarvisColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(5),
              ),
              border: Border(
                bottom: BorderSide(color: JarvisColors.panelBorder),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  language?.toUpperCase() ?? 'CODE',
                  style: TextStyle(
                    color: JarvisColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Code copied to clipboard'),
                        backgroundColor: JarvisColors.surface,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy, size: 12, color: JarvisColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        'COPY',
                        style: TextStyle(
                          color: JarvisColors.textMuted,
                          fontSize: 9,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Code content
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              code.trim(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: JarvisColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}