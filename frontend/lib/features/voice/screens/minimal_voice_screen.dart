import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/speda_theme.dart';
import '../../../core/services/api_service.dart';

enum VoiceState {
  idle,
  listening,
  processing,
  speaking,
}

/// Ultra-minimal voice screen - 2026 design
class MinimalVoiceScreen extends StatefulWidget {
  const MinimalVoiceScreen({super.key});

  @override
  State<MinimalVoiceScreen> createState() => _MinimalVoiceScreenState();
}

class _MinimalVoiceScreenState extends State<MinimalVoiceScreen>
    with TickerProviderStateMixin {
  final SpeechToText _speechToText = SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  late ApiService _apiService;

  VoiceState _state = VoiceState.idle;
  String _statusText = 'Tap to speak';
  String _transcribedText = '';
  bool _isAvailable = false;
  double _soundLevel = 0.0;
  String? _preferredLocale;

  late AnimationController _pulseController;
  late AnimationController _rotateController;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initAudioPlayer();
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('tr-TR');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(0.9);

    _flutterTts.setCompletionHandler(() {
      _onAudioComplete();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apiService = context.read<ApiService>();
    _initSpeech();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
  }

  Future<void> _initSpeech() async {
    try {
      _isAvailable = await _speechToText.initialize(
        onStatus: _onSpeechStatus,
        onError: (error) {
          debugPrint('Speech error: ${error.errorMsg}');
          if (mounted) {
            setState(() {
              _state = VoiceState.idle;
              _statusText = 'Speech error: ${error.errorMsg}';
            });
          }
        },
      );

      if (_isAvailable && mounted) {
        final locales = await _speechToText.locales();
        debugPrint(
            'Available locales: ${locales.map((l) => l.localeId).join(", ")}');
        final turkishLocale =
            locales.where((l) => l.localeId.startsWith('tr')).firstOrNull;
        final englishLocale =
            locales.where((l) => l.localeId.startsWith('en')).firstOrNull;
        _preferredLocale = turkishLocale?.localeId ??
            englishLocale?.localeId ??
            locales.firstOrNull?.localeId;
        debugPrint('Using locale: $_preferredLocale');
      } else if (!_isAvailable && mounted) {
        setState(() => _statusText = 'Microphone unavailable');
      }
    } catch (e) {
      debugPrint('Speech init error: $e');
      _isAvailable = false;
      if (mounted) {
        setState(() => _statusText = 'Speech not supported: $e');
      }
    }
  }

  void _initAudioPlayer() {
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onAudioComplete();
      }
    });
  }

  void _onSpeechStatus(String status) {
    if (status == 'done' && _state == VoiceState.listening) {
      _onSpeechDone();
    }
  }

  void _onSpeechDone() {
    if (_transcribedText.isNotEmpty) {
      _processVoiceInput();
    } else {
      setState(() {
        _state = VoiceState.idle;
        _statusText = 'Tap to speak';
      });
    }
  }

  void _onAudioComplete() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _state == VoiceState.speaking) {
        _startListening();
      }
    });
  }

  Future<void> _startListening() async {
    if (!_isAvailable) {
      setState(() => _statusText = 'Microphone unavailable');
      return;
    }

    await _audioPlayer.stop();

    setState(() {
      _state = VoiceState.listening;
      _statusText = 'Listening...';
      _transcribedText = '';
    });

    await _speechToText.listen(
      onResult: (result) {
        setState(() => _transcribedText = result.recognizedWords);
      },
      onSoundLevelChange: (level) {
        setState(() => _soundLevel = level);
      },
      localeId: _preferredLocale,
      listenMode: ListenMode.dictation,
      cancelOnError: false,
      partialResults: true,
    );
  }

  Future<void> _stopListening() async {
    await _speechToText.stop();
  }

  Future<void> _processVoiceInput() async {
    setState(() {
      _state = VoiceState.processing;
      _statusText = 'Thinking...';
    });

    try {
      final response = await _apiService.sendVoiceMessage(
        _transcribedText,
        onFunctionStart: (functionName) {
          // Update status with detailed function message
          setState(() {
            _statusText = _getFunctionStatusMessage(functionName);
          });
        },
      );

      setState(() {
        _state = VoiceState.speaking;
        _statusText = 'Speaking...';
      });

      await _playTTSResponse(response);
    } catch (e) {
      debugPrint('Voice processing error: $e');
      setState(() {
        _state = VoiceState.idle;
        _statusText = 'Error: $e';
      });
    }
  }

  /// Get a user-friendly status message for function execution
  String _getFunctionStatusMessage(String functionName) {
    switch (functionName) {
      // Calendar functions
      case 'get_calendar_events':
        return '📅 Google Calendar\'a bağlanılıyor...';
      case 'create_calendar_event':
        return '📅 Takvime etkinlik oluşturuluyor...';
      case 'update_calendar_event':
        return '📅 Etkinlik güncelleniyor...';
      case 'delete_calendar_event':
        return '📅 Etkinlik siliniyor...';

      // Task functions
      case 'get_tasks':
        return '✅ Görevler sunucudan alınıyor...';
      case 'create_task':
        return '✅ Görev oluşturuluyor...';
      case 'complete_task':
        return '✅ Görev tamamlanıyor...';
      case 'delete_task':
        return '🗑️ Görev siliniyor...';
      case 'update_task':
        return '✅ Görev güncelleniyor...';

      // Weather functions
      case 'get_current_weather':
        return '🌤️ Hava durumu alınıyor...';
      case 'get_weather_forecast':
        return '🌤️ Hava tahmini alınıyor...';

      // News functions
      case 'get_news_headlines':
        return '📰 Haberler getiriliyor...';
      case 'search_news':
        return '📰 Haberler aranıyor...';

      // Search functions
      case 'web_search':
        return '🔍 Web araması yapılıyor...';

      // Briefing functions
      case 'get_daily_briefing':
        return '📋 Günlük özet hazırlanıyor...';

      // Memory functions
      case 'remember':
        return '🧠 Hafızaya kaydediliyor...';
      case 'recall':
        return '🧠 Hafızadan çağrılıyor...';

      // Email functions
      case 'send_email':
        return '📧 E-posta gönderiliyor...';
      case 'draft_email':
        return '📧 E-posta taslağı oluşturuluyor...';

      default:
        return '⚙️ Sunucuya bağlanılıyor...';
    }
  }

  Future<void> _playTTSResponse(String text) async {
    try {
      debugPrint(
          '[VoiceMode] Streaming TTS for: ${text.substring(0, text.length > 30 ? 30 : text.length)}...');

      // Construct the streaming URL - audio plays as bytes arrive
      final encodedText = Uri.encodeQueryComponent(text);
      final streamUrl =
          '${_apiService.baseUrl}/api/voice/stream?text=$encodedText&voice=marin';

      debugPrint('[VoiceMode] Stream URL: $streamUrl');

      // Play immediately - player buffers and plays as first bytes arrive
      await _audioPlayer.setUrl(streamUrl);
      await _audioPlayer.play();

      debugPrint('[VoiceMode] Streaming OpenAI TTS audio');
    } catch (e) {
      debugPrint(
          '[VoiceMode] Streaming TTS failed, falling back to device TTS. Error: $e');
      await _flutterTts.speak(text);
    }
  }

  void _handleTap() {
    switch (_state) {
      case VoiceState.idle:
        _startListening();
        break;
      case VoiceState.listening:
        _stopListening();
        break;
      case VoiceState.processing:
        break;
      case VoiceState.speaking:
        _interruptSpeaking();
        break;
    }
  }

  void _interruptSpeaking() async {
    await _audioPlayer.stop();
    await _flutterTts.stop();
    _startListening();
  }

  void _endConversation() async {
    await _audioPlayer.stop();
    await _flutterTts.stop();
    await _speechToText.stop();
    setState(() {
      _state = VoiceState.idle;
      _statusText = 'Tap to speak';
      _transcribedText = '';
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    _audioPlayer.dispose();
    _flutterTts.stop();
    _speechToText.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpedaColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildVoiceOrb(),
                    const SizedBox(height: 40),
                    _buildStatusText(),
                    const SizedBox(height: 20),
                    if (_transcribedText.isNotEmpty) _buildTranscribedText(),
                  ],
                ),
              ),
            ),
            _buildBottomControls(),
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
          // SPEDA Logo (opens drawer)
          GestureDetector(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: SpedaColors.surface,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/speda_ui_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Title
          Expanded(
            child: Text(
              'voIce mode',
              style: TextStyle(
                fontFamily: 'Logirent',
                fontSize: 26,
                color: SpedaColors.textPrimary,
              ),
            ),
          ),
          // Status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _state != VoiceState.idle
                  ? SpedaColors.primary.withOpacity(0.12)
                  : const Color(0xFF2A2A3A),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _state != VoiceState.idle
                    ? SpedaColors.primary.withOpacity(0.3)
                    : const Color(0xFF4A4A5A),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: _state != VoiceState.idle
                      ? SpedaColors.primary
                      : const Color(0xFF6A6A7A),
                ),
                const SizedBox(width: 8),
                Text(
                  _state != VoiceState.idle ? 'ACTIVE' : 'STANDBY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: _state != VoiceState.idle
                        ? SpedaColors.primary
                        : const Color(0xFF6A6A7A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceOrb() {
    final isActive = _state != VoiceState.idle;
    final isListening = _state == VoiceState.listening;
    final isProcessing = _state == VoiceState.processing;
    final isSpeaking = _state == VoiceState.speaking;

    // Colors based on state
    final primaryColor = isListening || isProcessing || isSpeaking
        ? SpedaColors.primary
        : const Color(0xFF2A2A3A);
    final glowOpacity = isActive ? 0.6 : 0.0;

    // Label text
    String labelText = 'TAP TO START';
    if (isListening) labelText = 'LISTENING';
    if (isProcessing) labelText = 'THINKING';
    if (isSpeaking) labelText = 'SPEAKING';

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulseValue = _pulseController.value;
          final soundScale = _soundLevel.clamp(0, 10) / 10;

          return SizedBox(
            width: 280,
            height: 280,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow ring (animated)
                if (isActive)
                  Container(
                    width: 260 + (pulseValue * 20) + (soundScale * 30),
                    height: 260 + (pulseValue * 20) + (soundScale * 30),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            primaryColor.withOpacity(0.2 + (pulseValue * 0.1)),
                        width: 1,
                      ),
                    ),
                  ),

                // Second ring
                if (isActive)
                  Container(
                    width: 230 + (pulseValue * 10) + (soundScale * 20),
                    height: 230 + (pulseValue * 10) + (soundScale * 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            primaryColor.withOpacity(0.3 + (pulseValue * 0.15)),
                        width: 1.5,
                      ),
                    ),
                  ),

                // Third ring (main outer)
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive
                          ? primaryColor.withOpacity(0.5)
                          : const Color(0xFF3A3A4A),
                      width: 2,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: primaryColor.withOpacity(glowOpacity),
                              blurRadius: 40,
                              spreadRadius: 5,
                            ),
                          ]
                        : null,
                  ),
                ),

                // Inner circle with SPEDA logo
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1A1A24),
                    border: Border.all(
                      color: isActive
                          ? primaryColor.withOpacity(0.7)
                          : const Color(0xFF3A3A4A),
                      width: 2,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // SPEDA Logo
                      Image.asset(
                        'assets/images/speda_ui_logo.png',
                        width: 60,
                        height: 60,
                        color:
                            isActive ? primaryColor : const Color(0xFF5A5A6A),
                        colorBlendMode: BlendMode.srcIn,
                      ),
                      const SizedBox(height: 8),
                      // State label
                      Text(
                        labelText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                          color:
                              isActive ? primaryColor : const Color(0xFF5A5A6A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusText() {
    return Text(
      _statusText,
      style: SpedaTypography.body.copyWith(
        color: SpedaColors.textSecondary,
        fontSize: 18,
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildTranscribedText() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpedaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SpedaColors.border),
      ),
      child: Text(
        _transcribedText,
        textAlign: TextAlign.center,
        style: SpedaTypography.body,
      ),
    ).animate().fadeIn().slideY(begin: 0.2);
  }

  Widget _buildBottomControls() {
    if (_state == VoiceState.idle) {
      return const SizedBox(height: 100);
    }

    return Container(
      padding: const EdgeInsets.all(32),
      child: GestureDetector(
        onTap: _endConversation,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: SpedaColors.error.withAlpha(25),
            shape: BoxShape.circle,
            border: Border.all(
              color: SpedaColors.error.withAlpha(100),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.close_rounded,
            color: SpedaColors.error,
            size: 28,
          ),
        ),
      ).animate().fadeIn().scale(),
    );
  }
}
