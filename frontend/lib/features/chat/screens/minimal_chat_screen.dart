import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:file_picker/file_picker.dart';

import '../../../core/theme/speda_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/main_scaffold.dart';
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

    if (_editingMessageIndex != null) {
      // We're editing - use editMessage from provider to regenerate
      context.read<ChatProvider>().editMessage(_editingMessageIndex!, message);
      _editingMessageIndex = null;
    } else {
      // Normal send
      context.read<ChatProvider>().sendMessage(message);
    }
    _textController.clear();
    _focusNode.requestFocus();
  }

  // Track if we're editing a message for regeneration
  int? _editingMessageIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: SpedaColors.background,
      // drawer: _buildHistoryDrawer(), // Removed: using global drawer
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // SPEDA Logo (opens drawer) - replaces hamburger menu
          GestureDetector(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: SpedaColors.surface,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/speda_ui_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // Centered title (JARVIS style)
          Expanded(
            child: Center(
              child: Text(
                'speda',
                style: TextStyle(
                  fontFamily: 'Logirent',
                  fontSize: 24, // Slightly smaller than drawer
                  color: SpedaColors.textPrimary,
                ),
              ),
            ),
          ),

          // New chat button
          GestureDetector(
            onTap: () => context.read<ChatProvider>().clearConversation(),
            child: const Icon(
              Icons.edit_square,
              color: SpedaColors.textSecondary,
              size: 22,
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

    if (isUser) {
      // User message - compact gray pill, right aligned
      return Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8, left: 60),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: SpedaColors.userBubble,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (hasAttachments) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: message.attachments!.map((attachment) {
                          return Container(
                            constraints: const BoxConstraints(
                                maxHeight: 150, maxWidth: 150),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(File(attachment.path),
                                  fit: BoxFit.cover),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      message.content,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        color: SpedaColors.textPrimary,
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

    // AI message - with SPEDA avatar and enhanced styling
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SPEDA Response Header with Avatar
          Row(
            children: [
              // SPEDA Avatar
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: SpedaColors.surface,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    'assets/images/speda_ui_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Name and timestamp
              Text(
                'SPEDA',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: SpedaColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTime(message.timestamp),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: SpedaColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Processing indicator (animated sparkle)
          if (showProcessing) ...[
            Row(
              children: [
                _buildSparkleIcon(),
                const SizedBox(width: 10),
                Text(
                  message.processingStatus!,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: SpedaColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // AI response text
          _buildMarkdownContent(
            message.isStreaming ? '${message.content}▌' : message.content,
          ),

          // Enhanced Action Buttons
          if (!showProcessing &&
              !message.isStreaming &&
              message.content.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: SpedaColors.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Regenerate
                  _buildActionButton(
                    Icons.refresh_rounded,
                    'Regenerate',
                    () => _regenerateMessage(),
                  ),
                  _buildActionDivider(),
                  // Edit
                  _buildActionButton(
                    Icons.edit_outlined,
                    'Edit',
                    () => _editMessage(message),
                  ),
                  _buildActionDivider(),
                  // Speak
                  _buildActionButton(
                    Icons.volume_up_outlined,
                    'Speak',
                    () => _speakMessage(message.content),
                  ),
                  _buildActionDivider(),
                  // Copy
                  _buildActionButton(
                    Icons.copy_rounded,
                    'Copy',
                    () {
                      Clipboard.setData(ClipboardData(text: message.content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Copied to clipboard'),
                            duration: Duration(seconds: 1)),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Icon(
            icon,
            size: 18,
            color: SpedaColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildActionDivider() {
    return Container(
      width: 1,
      height: 16,
      color: SpedaColors.borderSubtle,
    );
  }

  Widget _buildSparkleIcon() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1500),
      builder: (context, value, child) {
        return Transform.rotate(
          angle: value * 0.5,
          child: Icon(
            Icons.auto_awesome,
            size: 20,
            color: SpedaColors.primary.withOpacity(0.5 + value * 0.5),
          ),
        );
      },
    );
  }

  void _speakMessage(String content) async {
    try {
      final apiService = context.read<ApiService>();
      // Get TTS audio URL from backend
      final audioUrl = await apiService.getTTSAudio(content);
      if (audioUrl.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Playing audio...'),
              duration: Duration(seconds: 1)),
        );
        // Audio playback would be handled by just_audio or similar
        // For now show success
        debugPrint('TTS Audio URL: $audioUrl');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('TTS unavailable'),
            backgroundColor: SpedaColors.error),
      );
    }
  }

  void _regenerateMessage() {
    final provider = context.read<ChatProvider>();
    // Call existing regenerateLastResponse which finds and re-sends last user message
    provider.regenerateLastResponse();
  }

  void _editMessage(ChatMessage message) {
    final provider = context.read<ChatProvider>();
    final messages = provider.messages;

    // Find the user message that triggered this AI response
    int aiMessageIndex = messages.indexOf(message);
    if (aiMessageIndex <= 0) return;

    // The user message is the one right before the AI response
    final userMessage = messages[aiMessageIndex - 1];
    if (!userMessage.isUser) return;

    // Put the user message in the input field for editing
    _textController.text = userMessage.content;
    _focusNode.requestFocus();

    // Store the index so when user submits, we can remove old messages and regenerate
    _editingMessageIndex = aiMessageIndex - 1;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Edit your message and send to regenerate'),
          duration: Duration(seconds: 2)),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildMarkdownContent(String content, {bool isUser = false}) {
    final textColor = isUser ? Colors.white : SpedaColors.textPrimary;
    final codeColor = isUser ? Colors.white : SpedaColors.primary;
    final codeBg = isUser ? Colors.black26 : SpedaColors.surfaceLight;

    // Parse content into segments (text and code blocks)
    final segments = _parseContentSegments(content);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: segments.map((segment) {
        if (segment.isCodeBlock) {
          // Custom code block with header
          return _buildCodeBlock(segment.language, segment.content);
        } else {
          // Regular markdown
          return MarkdownBody(
            data: segment.content,
            selectable: true,
            shrinkWrap: true,
            styleSheet: MarkdownStyleSheet(
              p: SpedaTypography.body.copyWith(color: textColor),
              h1: SpedaTypography.heading.copyWith(color: textColor),
              h2: SpedaTypography.title.copyWith(color: textColor),
              h3: SpedaTypography.title
                  .copyWith(fontSize: 15, color: textColor),
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
      }).toList(),
    );
  }

  /// Parse markdown content into segments (text vs code blocks)
  List<_ContentSegment> _parseContentSegments(String content) {
    final segments = <_ContentSegment>[];
    final codeBlockRegex = RegExp(r'```(\w*)\n([\s\S]*?)```', multiLine: true);

    int lastEnd = 0;
    for (final match in codeBlockRegex.allMatches(content)) {
      // Add text before this code block
      if (match.start > lastEnd) {
        final textBefore = content.substring(lastEnd, match.start).trim();
        if (textBefore.isNotEmpty) {
          segments
              .add(_ContentSegment(content: textBefore, isCodeBlock: false));
        }
      }

      // Add the code block
      final language = match.group(1) ?? '';
      final code = match.group(2) ?? '';
      segments.add(_ContentSegment(
        content: code.trim(),
        isCodeBlock: true,
        language: language.isEmpty ? 'code' : language,
      ));

      lastEnd = match.end;
    }

    // Add remaining text after last code block
    if (lastEnd < content.length) {
      final textAfter = content.substring(lastEnd).trim();
      if (textAfter.isNotEmpty) {
        segments.add(_ContentSegment(content: textAfter, isCodeBlock: false));
      }
    }

    // If no code blocks found, return original content
    if (segments.isEmpty) {
      segments.add(_ContentSegment(content: content, isCodeBlock: false));
    }

    return segments;
  }

  /// Build custom code block with header and copy button
  Widget _buildCodeBlock(String language, String code) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF1E1F20),
        border: Border.all(color: SpedaColors.borderSubtle),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with language and copy button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF2A2B2D),
              border: Border(
                bottom: BorderSide(color: SpedaColors.borderSubtle),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  language.toLowerCase(),
                  style: const TextStyle(
                    color: SpedaColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter',
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Code copied to clipboard'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.content_copy_rounded,
                    size: 18,
                    color: SpedaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Code content
          Container(
            padding: const EdgeInsets.all(14),
            width: double.infinity,
            child: SelectableText(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: SpedaColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    // Time-based greeting
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Personal Greeting (JARVIS-style)
          Text(
            '$greeting, Ahmet Erol.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 28,
              fontWeight: FontWeight.w300,
              color: SpedaColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'How can I assist you?',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: SpedaColors.textSecondary,
            ),
          ),

          const SizedBox(height: 48),

          // SPEDA Logo (subtle, not dominant)
          Center(
            child: Opacity(
              opacity: 0.8,
              child: Image.asset(
                'assets/images/speda_ui_logo.png',
                height: 100,
                fit: BoxFit.contain,
              ),
            ),
          ),

          const SizedBox(height: 48),

          // Quick Actions Header
          Text(
            'QUICK ACTIONS',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: SpedaColors.textTertiary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // Suggestion chips with subtle JARVIS accent
          _buildSuggestionChip(Icons.check_circle_outline, 'Check my tasks',
              'Show my tasks for today'),
          const SizedBox(height: 12),
          _buildSuggestionChip(Icons.calendar_today_outlined, 'My schedule',
              'What\'s on my calendar today?'),
          const SizedBox(height: 12),
          _buildSuggestionChip(Icons.wb_sunny_outlined, 'Daily briefing',
              'Give me my morning briefing'),
          const SizedBox(height: 12),
          _buildSuggestionChip(Icons.auto_awesome_outlined, 'Start my day',
              'Help me plan and prioritize today'),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(IconData icon, String label, String message) {
    return GestureDetector(
      onTap: () => context.read<ChatProvider>().sendMessage(message),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1B24), // Solid surface color
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: SpedaColors.primary,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: SpedaColors.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: Colors.white54,
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
          // JARVIS-style: Sharper corners, thin top border line
          decoration: BoxDecoration(
            color: SpedaColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(
              top: BorderSide(
                color: SpedaColors.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.only(top: 12),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image Previews
                if (provider.hasAttachments)
                  Container(
                    height: 80,
                    margin: const EdgeInsets.fromLTRB(
                        16, 12, 16, 4), // Add padding here
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: provider.pendingAttachments.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final attachment = provider.pendingAttachments[index];
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: FileImage(File(attachment.path)),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: -6,
                              right: -6,
                              child: GestureDetector(
                                onTap: () => provider.removeAttachment(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: SpedaColors.surface,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      size: 12,
                                      color: SpedaColors.textSecondary),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                // Gemini-style two-row input (Native look)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row 1: Text input only (clean)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24), // "A little padding" to the center
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        style: SpedaTypography.body.copyWith(
                          fontSize: 16,
                          color: SpedaColors.textPrimary,
                        ),
                        maxLines: 4,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: provider.hasAttachments
                              ? 'Ask about this image...'
                              : 'Ask S.P.E.D.A.',
                          hintStyle: SpedaTypography.body.copyWith(
                            color: SpedaColors.textTertiary,
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          fillColor: Colors.transparent,
                          filled: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        textInputAction: TextInputAction.newline,
                      ),
                    ),

                    // Row 2: Action buttons
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          20, 8, 20, 20), // More bottom padding to lift it up
                      child: Row(
                        children: [
                          // + Attach button
                          GestureDetector(
                            onTap: provider.isLoading ? null : _pickFile,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(
                                    0xFF1E1E1E), // Darker circle background
                              ),
                              child: Icon(
                                Icons.add_rounded,
                                size: 24,
                                color: SpedaColors.textSecondary,
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Voice mode button
                          GestureDetector(
                            onTap: () => _navigateToVoice(),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(
                                    0xFF1E1E1E), // Darker circle background
                              ),
                              child: Icon(
                                Icons.mic_none_rounded,
                                size: 24,
                                color: SpedaColors.textSecondary,
                              ),
                            ),
                          ),

                          const Spacer(),

                          // Send button
                          GestureDetector(
                            onTap: provider.isLoading ? null : _sendMessage,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: Colors
                                    .transparent, // Transparent background
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                provider.isLoading
                                    ? Icons.stop_rounded
                                    : Icons.send_rounded,
                                size: 24, // Slightly bigger icon
                                color: SpedaColors.textPrimary, // White icon
                              ),
                            ),
                          ),
                        ],
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

  void _navigateToVoice() {
    // Navigate to voice screen - index 1 in MainScaffold
    final scaffoldState = context.findAncestorStateOfType<MainScaffoldState>();
    if (scaffoldState != null) {
      scaffoldState.navigateTo(1);
    } else {
      // Fallback if not found (shouldn't happen)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice mode unavailable')),
      );
    }
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

  // Drawer logic moved to core/widgets/speda_drawer.dart
}

/// Helper class for parsing markdown content into segments
class _ContentSegment {
  final String content;
  final bool isCodeBlock;
  final String language;

  _ContentSegment({
    required this.content,
    required this.isCodeBlock,
    this.language = '',
  });
}
