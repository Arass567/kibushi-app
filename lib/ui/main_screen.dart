import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import '../core/kibushi_state.dart';
import '../services/recorder_service.dart';

/// Écran principal avec visualisation audio temps réel
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final RecorderService _recorderService = RecorderService();
  
  // Streams subscriptions
  StreamSubscription? _stateSub;
  StreamSubscription? _amplitudeSub;
  StreamSubscription? _errorSub;
  
  double _currentAmplitude = 0.0;
  RecorderState _recorderState = RecorderState.idle;
  AudioError? _lastError;
  
  @override
  void initState() {
    super.initState();
    _initStreams();
  }
  
  void _initStreams() {
    // Écoute changements d'état
    _stateSub = _recorderService.stateStream.listen((state) {
      setState(() => _recorderState = state);
      _handleStateChange(state);
    });
    
    // Écoute amplitude pour visualisation
    _amplitudeSub = _recorderService.amplitudeStream.listen((amp) {
      setState(() => _currentAmplitude = amp);
    });
    
    // Écoute erreurs
    _errorSub = _recorderService.errorStream.listen((error) {
      if (error != null) {
        setState(() => _lastError = error);
        _showErrorSnackBar(error);
      }
    });
  }
  
  void _handleStateChange(RecorderState state) {
    // Haptic feedback selon l'état
    switch (state) {
      case RecorderState.recording:
        HapticFeedback.lightImpact();
        Vibration.vibrate(duration: 30, amplitude: 50);
        break;
      case RecorderState.paused:
        Vibration.vibrate(pattern: [0, 20, 40, 20], intensities: [50, 80, 50]);
        break;
      case RecorderState.idle:
        if (_recorderState == RecorderState.recording) {
          HapticFeedback.mediumImpact();
        }
        break;
      default:
        break;
    }
  }
  
  void _showErrorSnackBar(AudioError error) {
    String message;
    switch (error) {
      case AudioError.noPermission:
        message = 'microphone requis';
        break;
      case AudioError.recordingFailed:
        message = 'erreur enregistrement';
        break;
      case AudioError.fileSystemError:
        message = 'erreur fichier';
        break;
      default:
        message = 'erreur audio';
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        backgroundColor: Colors.redAccent.withOpacity(0.8),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _amplitudeSub?.cancel();
    _errorSub?.cancel();
    _recorderService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Titre Kibushi
          const Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Text(
              'Kibushi',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white24,
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
          ),
          
          // Prompt de consentement ou texte contextuel
          Consumer<KibushiState>(
            builder: (context, state, child) {
              if (state.currentState == AppState.consentPrompt) {
                return const _ConsentPrompt();
              }
              if (state.currentState == AppState.firstLaunch) {
                return const Positioned(
                  top: 100,
                  left: 0,
                  right: 0,
                  child: FadeInText(text: 'tu peux répéter'),
                );
              }
              if (state.currentState == AppState.mirrorPlayback && state.lastMirrorType != null) {
                return Positioned(
                  top: 100,
                  left: 0,
                  right: 0,
                  child: FadeInText(
                    text: _getMirrorLabel(state.lastMirrorType!),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          
          // Visualisation amplitude (visible pendant l'enregistrement)
          if (_recorderState == RecorderState.recording)
            Positioned(
              top: 200,
              left: 0,
              right: 0,
              child: _AmplitudeVisualizer(amplitude: _currentAmplitude),
            ),
          
          Center(
            child: Consumer<KibushiState>(
              builder: (context, state, child) {
                return _MicroButton(
                  state: state,
                  recorderService: _recorderService,
                  recorderState: _recorderState,
                );
              },
            ),
          ),
          
          const Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              'viens. on se parle',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white10,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _getMirrorLabel(String type) {
  switch (type) {
    case 'syllable':
      return 'syllabe';
    case 'word':
      return 'mot';
    case 'intonation':
      return 'souffle';
    default:
      return '';
  }
}

class FadeInText extends StatelessWidget {
  final String text;
  const FadeInText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 2),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 16,
              fontWeight: FontWeight.w300,
            ),
          ),
        );
      },
    );
  }
}

/// Visualisation temps réel de l'amplitude audio
class _AmplitudeVisualizer extends StatelessWidget {
  final double amplitude;
  
  const _AmplitudeVisualizer({required this.amplitude});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(20, (index) {
          // Animation des barres selon l'amplitude
          final delay = index * 0.05;
          final height = (amplitude * 50 * (0.5 + (index % 3) * 0.25)).clamp(4.0, 50.0);
          
          return AnimatedContainer(
            duration: const Duration(milliseconds: 50),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 4,
            height: height,
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.3 + amplitude * 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}

class _MicroButton extends StatefulWidget {
  final KibushiState state;
  final RecorderService recorderService;
  final RecorderState recorderState;
  
  const _MicroButton({
    required this.state,
    required this.recorderService,
    required this.recorderState,
  });

  @override
  State<_MicroButton> createState() => _MicroButtonState();
}

class _MicroButtonState extends State<_MicroButton> {
  AppState? _previousState;

  @override
  void didUpdateWidget(_MicroButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    final currentState = widget.state.currentState;
    if (_previousState != currentState) {
      _previousState = currentState;
    }
  }

  Future<void> _onTapDown(TapDownDetails details) async {
    if (widget.state.currentState == AppState.reflecting || 
        widget.state.currentState == AppState.mirrorPlayback ||
        widget.state.currentState == AppState.consentPrompt) return;
    
    HapticFeedback.selectionClick();
    
    // Démarrage enregistrement via RecorderService
    final path = await widget.recorderService.startRecording();
    if (path != null) {
      widget.state.startVoiceCapture();
    }
  }

  Future<void> _onTapUp(TapUpDetails details) async {
    if (widget.state.currentState == AppState.reflecting || 
        widget.state.currentState == AppState.mirrorPlayback) return;
    
    // Arrêt enregistrement
    await widget.recorderService.stopRecording();
    widget.state.stopVoiceCapture();
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = widget.recorderState == RecorderState.recording ||
                        widget.state.currentState == AppState.recording;
    final isPaused = widget.recorderState == RecorderState.paused;
    final isReflecting = widget.state.currentState == AppState.reflecting;
    final isMirroring = widget.state.currentState == AppState.mirrorPlayback;
    final isFirst = widget.state.currentState == AppState.firstLaunch;
    
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: () async {
        if (isRecording) {
          await widget.recorderService.stopRecording();
          widget.state.stopVoiceCapture();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: isRecording ? 140 : 100,
        height: isRecording ? 140 : 100,
        decoration: BoxDecoration(
          color: _getBgColor(isRecording, isPaused, isReflecting, isMirroring, isFirst),
          shape: BoxShape.circle,
          border: Border.all(
            color: _getBorderColor(isRecording, isPaused, isReflecting, isMirroring, isFirst),
            width: isRecording ? 3 : 2,
          ),
          boxShadow: [
            if (isRecording)
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.2),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            if (isPaused)
              BoxShadow(
                color: Colors.orangeAccent.withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            if (isReflecting)
              BoxShadow(
                color: Colors.white.withOpacity(0.15),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            if (isMirroring)
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.15),
                blurRadius: 50,
                spreadRadius: 15,
              ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _getIconWidget(isRecording, isPaused, isReflecting, isMirroring, isFirst),
        ),
      ),
    );
  }

  Widget _getIconWidget(bool rec, bool paused, bool ref, bool mir, bool fir) {
    final iconData = _getPhosphorIcon(rec, paused, ref, mir, fir);
    final color = _getIconColor(rec, paused, ref, mir, fir);
    
    return PhosphorIcon(
      iconData,
      key: ValueKey<String>('${rec}_${paused}_${ref}_${mir}_${fir}'),
      size: rec ? 48 : 40,
      color: color,
    );
  }

  PhosphorIconData _getPhosphorIcon(bool rec, bool paused, bool ref, bool mir, bool fir) {
    if (paused) return PhosphorIconsRegular.pause; // Pause
    if (ref) return PhosphorIconsRegular.circle; // Souffle/discret
    if (mir) return PhosphorIconsRegular.speakerHigh; // Écoute
    if (fir) return PhosphorIconsRegular.waveform; // Première ouverture
    return PhosphorIconsRegular.microphone; // Idle/Recording
  }

  Color _getBgColor(bool rec, bool paused, bool ref, bool mir, bool fir) {
    if (rec) return Colors.redAccent.withOpacity(0.08);
    if (paused) return Colors.orangeAccent.withOpacity(0.08);
    if (ref) return Colors.white.withOpacity(0.08);
    if (mir) return Colors.blueAccent.withOpacity(0.05);
    return Colors.transparent;
  }

  Color _getBorderColor(bool rec, bool paused, bool ref, bool mir, bool fir) {
    if (rec) return Colors.redAccent.withOpacity(0.6);
    if (paused) return Colors.orangeAccent.withOpacity(0.6);
    if (ref) return Colors.white54;
    if (mir) return Colors.blueAccent.withOpacity(0.4);
    return Colors.white24;
  }

  Color _getIconColor(bool rec, bool paused, bool ref, bool mir, bool fir) {
    if (rec) return Colors.redAccent;
    if (paused) return Colors.orangeAccent;
    if (ref) return Colors.white70;
    if (mir) return Colors.blueAccent;
    return Colors.white60;
  }
}

/// Widget de demande de consentement pour le dataset
class _ConsentPrompt extends StatelessWidget {
  const _ConsentPrompt();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 80,
      left: 40,
      right: 40,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'contribuer à la voix ?',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'tes enregistrements peuvent aider à créer une voix. anonyme. silencieux. réversible.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    context.read<KibushiState>().declineDatasetConsent();
                  },
                  child: const Text(
                    'non',
                    style: TextStyle(color: Colors.white38),
                  ),
                ),
                const SizedBox(width: 20),
                TextButton(
                  onPressed: () {
                    context.read<KibushiState>().giveDatasetConsent();
                  },
                  child: const Text(
                    'oui',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
