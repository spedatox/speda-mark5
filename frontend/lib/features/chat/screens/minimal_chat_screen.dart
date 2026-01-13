import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/theme/speda_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/models/api_response.dart';
import '../providers/chat_provider.dart';

/// Ultra-minimal chat screen - 2026 design
class MinimalChatScreen extends StatefulWidget {
  const MinimalChatScreen({super.key});

  @override
  State<MinimalChatScreen> createState() => _MinimalChatScreenState();
}

class _MinimalChatScreenState extends State<MinimalChatScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: SpedaColors.background,
      drawer: _buildHistoryDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildChatArea()),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Menu button
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: const Icon(
              Icons.menu_rounded,
              color: SpedaColors.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Title & status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SPEDA',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: SpedaColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Consumer<ChatProvider>(
                  builder: (context, provider, _) {
                    final isOnline = provider.isBackendConnected;
                    return Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isOnline
                                ? SpedaColors.success
                                : SpedaColors.textTertiary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOnline ? 'Online' : 'Offline',
                          style: SpedaTypography.caption.copyWith(
                            color: SpedaColors.textTertiary,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // New chat button
          GestureDetector(
            onTap: () => context.read<ChatProvider>().clearConversation(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SpedaColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: SpedaColors.textSecondary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          itemCount: chatProvider.messages.length,
          itemBuilder: (context, index) {
            return _buildMessageBubble(chatProvider.messages[index]);
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    final showProcessing =
        message.isStreaming && message.processingStatus != null;
    final hasAttachments =
        message.attachments != null && message.attachments!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? SpedaColors.userAccent : SpedaColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display attachments if any
                  if (hasAttachments) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: message.attachments!.map((attachment) {
                        return Container(
                          constraints: const BoxConstraints(
                            maxHeight: 200,
                            maxWidth: 200,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isUser
                                  ? Colors.white.withOpacity(0.2)
                                  : SpedaColors.border,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(attachment.path),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],

                  if (showProcessing) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: SpedaColors.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          message.processingStatus!,
                          style: SpedaTypography.caption.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (isUser)
                    _buildMarkdownContent(message.content, isUser: true)
                  else
                    _buildMarkdownContent(
                      message.isStreaming
                          ? '${message.content}▌'
                          : message.content,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: SpedaTypography.caption.copyWith(
                      color: isUser
                          ? Colors.white.withOpacity(0.6)
                          : SpedaColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildMarkdownContent(String content, {bool isUser = false}) {
    final textColor = isUser ? Colors.white : SpedaColors.textPrimary;
    final codeColor = isUser ? Colors.white : SpedaColors.primary;
    final codeBg = isUser ? Colors.black26 : SpedaColors.surfaceLight;

    return MarkdownBody(
      data: content,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: SpedaTypography.body.copyWith(color: textColor),
        h1: SpedaTypography.heading.copyWith(color: textColor),
        h2: SpedaTypography.title.copyWith(color: textColor),
        h3: SpedaTypography.title.copyWith(fontSize: 15, color: textColor),
        strong: SpedaTypography.body.copyWith(
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        em: SpedaTypography.body.copyWith(
          fontStyle: FontStyle.italic,
          color: textColor,
        ),
        code: TextStyle(
          color: codeColor,
          backgroundColor: codeBg,
          fontFamily: 'monospace',
          fontSize: 13,
        ),
        codeblockDecoration: BoxDecoration(
          color: codeBg,
          borderRadius: BorderRadius.circular(8),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: codeColor, width: 2),
          ),
        ),
        blockquotePadding: const EdgeInsets.only(left: 12),
        a: TextStyle(
          color: codeColor,
          decoration: TextDecoration.underline,
        ),
      ),
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            SizedBox(
              width: 100,
              height: 100,
              child: Image.asset(
                'assets/images/speda_ui_logo.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'SPEDA',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: SpedaColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Personal Executive System',
              style: SpedaTypography.bodySmall.copyWith(
                color: SpedaColors.textTertiary,
              ),
            ),

            const SizedBox(height: 48),

            // Quick actions
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _buildQuickAction(
                    'Tasks', Icons.check_circle_outline, 'Show my tasks'),
                _buildQuickAction('Schedule', Icons.calendar_today_outlined,
                    'What\'s on my calendar today?'),
                _buildQuickAction('Briefing', Icons.wb_sunny_outlined,
                    'Give me my daily briefing'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(String label, IconData icon, String message) {
    return GestureDetector(
      onTap: () => context.read<ChatProvider>().sendMessage(message),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: SpedaColors.surfaceLight,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: SpedaColors.border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: SpedaColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: SpedaTypography.label.copyWith(
                color: SpedaColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Consumer<ChatProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SpedaColors.surface,
            border: Border(
              top: BorderSide(color: SpedaColors.border, width: 0.5),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Previews (Gemini style)
                if (provider.hasAttachments)
                  Container(
                    height: 100,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: provider.pendingAttachments.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final attachment = provider.pendingAttachments[index];
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: SpedaColors.border),
                                image: DecorationImage(
                                  image: FileImage(File(attachment.path)),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: -8,
                              right: -8,
                              child: GestureDetector(
                                onTap: () => provider.removeAttachment(index),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: SpedaColors.surface,
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: SpedaColors.border),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: SpedaColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                // Input Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Attachment button
                    GestureDetector(
                      onTap: provider.isLoading ? null : _pickFile,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 2),
                        decoration: BoxDecoration(
                          color: SpedaColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.add_photo_alternate_rounded,
                          size: 24,
                          color: provider.isLoading
                              ? SpedaColors.textTertiary
                              : SpedaColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Input field
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: SpedaColors.surfaceLight,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          style: SpedaTypography.body,
                          maxLines: 5,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText: provider.hasAttachments
                                ? 'Ask about this image...'
                                : 'Message...',
                            hintStyle: SpedaTypography.body.copyWith(
                              color: SpedaColors.textTertiary,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          textInputAction: TextInputAction.send,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Send button
                    GestureDetector(
                      onTap: provider.isLoading ? null : _sendMessage,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 2),
                        decoration: BoxDecoration(
                          color: SpedaColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          size: 20,
                          color: SpedaColors.background,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          context.read<ChatProvider>().addImageAttachment(file.path!);
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  Widget _buildHistoryDrawer() {
    return Drawer(
      backgroundColor: SpedaColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
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
            SpedaWidgets.divider(),

            // Conversation list
            Expanded(
              child: _ConversationHistoryList(
                onConversationSelected: (conversationId) {
                  Navigator.pop(context);
                  context.read<ChatProvider>().loadConversation(conversationId);
                },
              ),
            ),

            SpedaWidgets.divider(),

            // New conversation button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.read<ChatProvider>().clearConversation();
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New Conversation'),
                  style: TextButton.styleFrom(
                    foregroundColor: SpedaColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
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
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: SpedaColors.primary,
          strokeWidth: 2,
        ),
      );
    }

    if (_conversations == null || _conversations!.isEmpty) {
      return Center(
        child: Text(
          'No conversations yet',
          style: SpedaTypography.bodySmall.copyWith(
            color: SpedaColors.textTertiary,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _conversations!.length,
      itemBuilder: (context, index) {
        final conv = _conversations![index];
        return ListTile(
          onTap: () => widget.onConversationSelected(conv.id),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          title: Text(
            conv.title ?? 'Untitled',
            style: SpedaTypography.body.copyWith(
              color: SpedaColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            conv.preview ?? '',
            style: SpedaTypography.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: SpedaColors.textTertiary,
            size: 20,
          ),
        );
      },
    );
  }
}
