import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:file_picker/file_picker.dart';
import 'package:markdown/markdown.dart' as md; // For ElementBuilder

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
          // Menu button (opens drawer with history + other screens)
          // Use Builder to get context under Scaffold if needed, but here we are in MainScaffold
          // actually MinimalChatScreen is child of MainScaffold so Scaffold.of(context) gets MainScaffold
          GestureDetector(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: const Icon(
              Icons.menu_rounded,
              color: SpedaColors.textSecondary,
              size: 26,
            ),
          ),

          // Centered title (Gemini style)
          Expanded(
            child: Center(
              child: Text(
                'S.P.E.D.A.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
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

    // AI message - no bubble, with response header (Gemini style)
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8, right: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    color: SpedaColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // AI response text (no bubble)
          _buildMarkdownContent(
            message.isStreaming ? '${message.content}▌' : message.content,
          ),

          // Actions below text (Regenerate, Edit, etc) - Left aligned
          if (!showProcessing &&
              !message.isStreaming &&
              message.content.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                // Regenerate
                GestureDetector(
                  onTap: () => _regenerateMessage(),
                  child: const Icon(Icons.refresh_rounded,
                      size: 18, color: SpedaColors.textSecondary),
                ),
                const SizedBox(width: 20),
                // Edit
                GestureDetector(
                  onTap: () => _editMessage(message),
                  child: const Icon(Icons.edit_outlined,
                      size: 18, color: SpedaColors.textSecondary),
                ),
                const SizedBox(width: 20),
                // Speaker
                GestureDetector(
                  onTap: () => _speakMessage(message.content),
                  child: const Icon(Icons.volume_up_outlined,
                      size: 18, color: SpedaColors.textSecondary),
                ),
                const SizedBox(width: 20),
                // Copy (Adding for utility)
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Copied to clipboard'),
                          duration: Duration(seconds: 1)),
                    );
                  },
                  child: const Icon(Icons.copy_rounded,
                      size: 16, color: SpedaColors.textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
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

    return MarkdownBody(
      data: content,
      selectable: true,
      builders: {
        'pre': CodeBlockBuilder(context),
      },
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Speda Branding (Logo + Slogan)
          Center(
            child: Column(
              children: [
                // Logo
                Image.asset(
                  'assets/images/speda_ui_logo.png',
                  height: 120, // Bigger logo
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                // Full name slogan (One row)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'SPECIALIZED PERSONAL EXECUTIVE DIGITAL ASSISTANT',
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: SpedaColors.textSecondary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Suggestion chips (Gemini style - vertical stack)
          _buildSuggestionChip(
              '📋', 'Check my tasks', 'Show my tasks for today'),
          const SizedBox(height: 12),
          _buildSuggestionChip(
              '📅', 'My schedule', 'What\'s on my calendar today?'),
          const SizedBox(height: 12),
          _buildSuggestionChip(
              '☀️', 'Daily briefing', 'Give me my morning briefing'),
          const SizedBox(height: 12),
          _buildSuggestionChip(
              '✨', 'Start my day', 'Help me plan and prioritize today'),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String emoji, String label, String message) {
    return GestureDetector(
      onTap: () => context.read<ChatProvider>().sendMessage(message),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: SpedaColors.surface,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: SpedaColors.textPrimary,
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
          // Native style: Rounded top corners, minimal top padding
          decoration: BoxDecoration(
            color: SpedaColors.surface, // Match nav bar color
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.only(top: 12), // "Very few padding" on top
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

/// Custom builder for code blocks to add header and copy button
class CodeBlockBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  CodeBlockBuilder(this.context);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    if (element.tag != 'pre') return null;

    // Fenced code blocks are usually <pre><code class="language-xyz">...</code></pre>
    if (element.children != null &&
        element.children!.isNotEmpty &&
        element.children!.first is md.Element &&
        (element.children!.first as md.Element).tag == 'code') {
      final codeElement = element.children!.first as md.Element;
      final languageClass = codeElement.attributes['class'] ?? '';

      // Extract language name (e.g. language-python -> python)
      String language = '';
      if (languageClass.startsWith('language-')) {
        language = languageClass.substring(9);
      } else {
        language = languageClass; // fallback
      }

      if (language.isEmpty) language = 'code';

      // Extract raw code text
      final textContent = codeElement.textContent;

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: SpedaColors.surface, // Container bg
          border: Border.all(color: SpedaColors.borderSubtle),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFF2D2E30), // Slightly darker header
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    language.toUpperCase(),
                    style: const TextStyle(
                      color: SpedaColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: textContent));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Code copied!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: const Icon(
                      Icons.content_copy_rounded,
                      size: 16,
                      color: SpedaColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Code Content
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF1E1F20), // Dark code bg
              width: double.infinity,
              child: SelectableText(
                textContent,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: SpedaColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return null;
  }
}
