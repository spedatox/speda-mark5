import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/jarvis_theme.dart';
import '../../../core/services/api_service.dart';
import '../widgets/voice_orb.dart';

enum VoiceState {
  idle,
  listening,
  processing,
  speaking,
}

class VoiceChatScreen extends StatefulWidget {
  const VoiceChatScreen({super.key});

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen>
    with TickerProviderStateMixin {
  final SpeechToText _speechToText = SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  late ApiService _apiService;

  VoiceState _state = VoiceState.idle;
  String _statusText = 'Başlamak için dokun';
  String _transcribedText = '';
  String _responseText = '';
  bool _isAvailable = false;
  double _soundLevel = 0.0;
  final bool _useDeviceTts = false; // Use server TTS with OpenAI

  late AnimationController _pulseController;
  late AnimationController _waveController;

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
    await _flutterTts.setPitch(0.9); // Slightly lower pitch for JARVIS feel
    
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

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  Future<void> _initSpeech() async {
    try {
      _isAvailable = await _speechToText.initialize(
        onStatus: _onSpeechStatus,
        onError: (error) {
          debugPrint('Speech error: $error');
          setState(() {
            _state = VoiceState.idle;
            _statusText = 'Hata oluştu, tekrar dene';
          });
        },
      );
      if (!_isAvailable) {
        setState(() {
          _statusText = 'Mikrofon kullanılamıyor';
        });
      }
    } catch (e) {
      debugPrint('Speech init failed: $e');
      _isAvailable = false;
      if (mounted) {
        setState(() {
          _statusText = 'Ses tanıma desteklenmiyor';
        });
      }
    }
  }

  void _initAudioPlayer() {
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        // Audio finished, go back to listening
        _onAudioComplete();
      }
    });
  }

  void _onSpeechStatus(String status) {
    debugPrint('Speech status: $status');
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
        _statusText = 'Başlamak için dokun';
      });
    }
  }

  void _onAudioComplete() {
    // After speaking, automatically start listening again
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _state == VoiceState.speaking) {
        _startListening();
      }
    });
  }

  Future<void> _startListening() async {
    if (!_isAvailable) {
      setState(() {
        _statusText = 'Mikrofon kullanılamıyor';
      });
      return;
    }

    // Stop any playing audio
    await _audioPlayer.stop();

    setState(() {
      _state = VoiceState.listening;
      _statusText = 'Dinliyorum...';
      _transcribedText = '';
    });

    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          _transcribedText = result.recognizedWords;
        });
      },
      onSoundLevelChange: (level) {
        setState(() {
          _soundLevel = level;
        });
      },
      localeId: 'tr_TR', // Turkish, will auto-detect if needed
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
      _statusText = 'Düşünüyorum...';
    });

    try {
      debugPrint('[Voice] Sending message: $_transcribedText');
      
      // Get response from chat API
      final response = await _apiService.sendVoiceMessage(_transcribedText);
      
      debugPrint('[Voice] Got response: ${response.substring(0, response.length.clamp(0, 100))}...');

      setState(() {
        _responseText = response;
        _state = VoiceState.speaking;
        _statusText = 'Konuşuyorum...';
      });

      // Play TTS audio
      await _playTTSResponse(response);
    } catch (e) {
      debugPrint('[Voice] Processing error: $e');
      setState(() {
        _state = VoiceState.idle;
        _statusText = 'Hata oluştu, tekrar dene';
      });
    }
  }

  Future<void> _playTTSResponse(String text) async {
    if (_useDeviceTts) {
      // Use device TTS (fallback mode)
      debugPrint('[Voice] Using device TTS...');
      await _flutterTts.speak(text);
      return;
    }
    
    try {
      debugPrint('[Voice] Getting TTS audio from server...');
      
      // Get TTS audio URL from backend
      final audioUrl = await _apiService.getTTSAudio(text);
      
      debugPrint('[Voice] Got audio URL: $audioUrl');

      await _audioPlayer.setUrl(audioUrl);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('[Voice] TTS error: $e, falling back to device TTS');
      // Fallback to device TTS
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
        // Can't interrupt processing
        break;
      case VoiceState.speaking:
        _interruptSpeaking();
        break;
    }
  }

  void _interruptSpeaking() async {
    await _audioPlayer.stop();
    await _flutterTts.stop();
    setState(() {
      _state = VoiceState.listening;
      _statusText = 'Dinliyorum...';
    });
    _startListening();
  }

  void _endConversation() async {
    await _audioPlayer.stop();
    await _flutterTts.stop();
    await _speechToText.stop();
    setState(() {
      _state = VoiceState.idle;
      _statusText = 'Başlamak için dokun';
      _transcribedText = '';
      _responseText = '';
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _audioPlayer.dispose();
    _flutterTts.stop();
    _speechToText.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarvisColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Main content - Orb
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Voice Orb
                    GestureDetector(
                      onTap: _handleTap,
                      child: VoiceOrb(
                        state: _state,
                        soundLevel: _soundLevel,
                        pulseController: _pulseController,
                        waveController: _waveController,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Status text
                    Text(
                      _statusText,
                      style: const TextStyle(
                        color: JarvisColors.textSecondary,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1,
                      ),
                    )
                        .animate(
                          onPlay: (c) => c.repeat(reverse: true),
                        )
                        .fadeIn(duration: 300.ms),

                    const SizedBox(height: 20),

                    // Transcribed text
                    if (_transcribedText.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: JarvisColors.surface.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: JarvisColors.panelBorder.withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          _transcribedText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: JarvisColors.textPrimary,
                            fontSize: 16,
                          ),
                        ),
                      ).animate().fadeIn().slideY(begin: 0.2),
                  ],
                ),
              ),
            ),

            // Bottom controls
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Speda logo/title
          Row(
            children: [
              Container(
                width: 8,
                height: 24,
                decoration: BoxDecoration(
                  color: JarvisColors.primary,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: JarvisColors.primary.withOpacity(0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'SPEDA',
                style: TextStyle(
                  color: JarvisColors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Voice mode indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: JarvisColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: JarvisColors.primary.withOpacity(0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mic,
                  size: 16,
                  color: JarvisColors.primary,
                ),
                SizedBox(width: 6),
                Text(
                  'VOICE',
                  style: TextStyle(
                    color: JarvisColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // End conversation button
          if (_state != VoiceState.idle)
            GestureDetector(
              onTap: _endConversation,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: JarvisColors.danger.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: JarvisColors.danger.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.close,
                  color: JarvisColors.danger,
                  size: 28,
                ),
              ),
            ).animate().fadeIn().scale(),
        ],
      ),
    );
  }
}
