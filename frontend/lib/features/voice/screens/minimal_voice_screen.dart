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
          setState(() {
            _state = VoiceState.idle;
            _statusText = 'Error, try again';
          });
        },
      );
      if (!_isAvailable && mounted) {
        setState(() {
          _statusText = 'Microphone unavailable';
        });
      }
    } catch (e) {
      _isAvailable = false;
      if (mounted) {
        setState(() {
          _statusText = 'Speech not supported';
        });
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
      localeId: 'tr_TR',
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
      final response = await _apiService.sendVoiceMessage(_transcribedText);

      setState(() {
        _state = VoiceState.speaking;
        _statusText = 'Speaking...';
      });

      await _playTTSResponse(response);
    } catch (e) {
      setState(() {
        _state = VoiceState.idle;
        _statusText = 'Error, try again';
      });
    }
  }

  Future<void> _playTTSResponse(String text) async {
    try {
      final audioUrl = await _apiService.getTTSAudio(text);
      await _audioPlayer.setUrl(audioUrl);
      await _audioPlayer.play();
    } catch (e) {
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
          Text(
            'Voice',
            style: SpedaTypography.heading.copyWith(
              fontSize: 24,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _state != VoiceState.idle
                  ? SpedaColors.success.withAlpha(25)
                  : SpedaColors.surfaceLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: _state != VoiceState.idle
                      ? SpedaColors.success
                      : SpedaColors.textTertiary,
                ),
                const SizedBox(width: 8),
                Text(
                  _state != VoiceState.idle ? 'Active' : 'Ready',
                  style: SpedaTypography.label.copyWith(
                    color: _state != VoiceState.idle
                        ? SpedaColors.success
                        : SpedaColors.textTertiary,
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

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale = isActive ? 1.0 + (_pulseController.value * 0.1) : 1.0;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 160 + (_soundLevel.clamp(0, 10) * 4),
              height: 160 + (_soundLevel.clamp(0, 10) * 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    isListening
                        ? SpedaColors.primary.withAlpha(200)
                        : _state == VoiceState.processing
                            ? SpedaColors.warning.withAlpha(150)
                            : _state == VoiceState.speaking
                                ? SpedaColors.success.withAlpha(150)
                                : SpedaColors.surface,
                    isListening
                        ? SpedaColors.primary.withAlpha(100)
                        : _state == VoiceState.processing
                            ? SpedaColors.warning.withAlpha(75)
                            : _state == VoiceState.speaking
                                ? SpedaColors.success.withAlpha(75)
                                : SpedaColors.surfaceLight,
                  ],
                ),
                border: Border.all(
                  color: isActive ? SpedaColors.primary : SpedaColors.border,
                  width: 2,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: SpedaColors.primary.withAlpha(50),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Icon(
                  isListening
                      ? Icons.mic_rounded
                      : _state == VoiceState.processing
                          ? Icons.psychology_rounded
                          : _state == VoiceState.speaking
                              ? Icons.volume_up_rounded
                              : Icons.mic_none_rounded,
                  size: 64,
                  color: isActive ? Colors.white : SpedaColors.textSecondary,
                ),
              ),
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
