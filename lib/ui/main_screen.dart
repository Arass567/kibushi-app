import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import '../core/kibushi_state.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

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
          
          Center(
            child: Consumer<KibushiState>(
              builder: (context, state, child) {
                return _MicroButton(state: state);
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

class _MicroButton extends StatefulWidget {
  final KibushiState state;
  const _MicroButton({required this.state});

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
      _handleStateChange(_previousState, currentState);
      _previousState = currentState;
    }
  }

  void _handleStateChange(AppState? oldState, AppState newState) {
    // Micro-vibrations selon les transitions
    switch (newState) {
      case AppState.recording:
        // Vibration légère au début de l'enregistrement
        HapticFeedback.lightImpact();
        Vibration.vibrate(duration: 30, amplitude: 50);
        break;
      case AppState.reflecting:
        // Double pulsation discrète
        Vibration.vibrate(pattern: [0, 20, 40, 20], intensities: [50, 80, 50]);
        break;
      case AppState.mirrorPlayback:
        // Vibration "success" très douce
        HapticFeedback.mediumImpact();
        break;
      default:
        break;
    }
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.state.currentState == AppState.reflecting || 
        widget.state.currentState == AppState.mirrorPlayback ||
        widget.state.currentState == AppState.consentPrompt) return;
    
    // Feedback immédiat au toucher
    HapticFeedback.selectionClick();
    widget.state.startVoiceCapture();
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.state.currentState == AppState.reflecting || 
        widget.state.currentState == AppState.mirrorPlayback) return;
    
    widget.state.stopVoiceCapture();
  }

  @override
  Widget build(BuildContext context) {
    bool isFirst = widget.state.currentState == AppState.firstLaunch;
    bool isRecording = widget.state.currentState == AppState.recording;
    bool isReflecting = widget.state.currentState == AppState.reflecting;
    bool isMirroring = widget.state.currentState == AppState.mirrorPlayback;
    
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: () {
        if (isRecording) widget.state.stopVoiceCapture();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: isRecording ? 140 : 100,
        height: isRecording ? 140 : 100,
        decoration: BoxDecoration(
          color: _getBgColor(isRecording, isReflecting, isMirroring, isFirst),
          shape: BoxShape.circle,
          border: Border.all(
            color: _getBorderColor(isRecording, isReflecting, isMirroring, isFirst),
            width: isRecording ? 3 : 2,
          ),
          boxShadow: [
            if (isRecording)
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.2),
                blurRadius: 40,
                spreadRadius: 10,
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
          child: _getIconWidget(isRecording, isReflecting, isMirroring, isFirst),
        ),
      ),
    );
  }

  Widget _getIconWidget(bool rec, bool ref, bool mir, bool fir) {
    final iconData = _getPhosphorIcon(rec, ref, mir, fir);
    final color = _getIconColor(rec, ref, mir, fir);
    
    return PhosphorIcon(
      iconData,
      key: ValueKey<String>('${rec}_${ref}_${mir}_${fir}'),
      size: rec ? 48 : 40,
      color: color,
    );
  }

  PhosphorIconData _getPhosphorIcon(bool rec, bool ref, bool mir, bool fir) {
    if (ref) return PhosphorIconsRegular.circle; // Souffle/discret
    if (mir) return PhosphorIconsRegular.speakerHigh; // Écoute
    if (fir) return PhosphorIconsRegular.waveform; // Première ouverture
    return PhosphorIconsRegular.microphone; // Idle/Recording
  }

  Color _getBgColor(bool rec, bool ref, bool mir, bool fir) {
    if (rec) return Colors.redAccent.withOpacity(0.08);
    if (ref) return Colors.white.withOpacity(0.08);
    if (mir) return Colors.blueAccent.withOpacity(0.05);
    return Colors.transparent;
  }

  Color _getBorderColor(bool rec, bool ref, bool mir, bool fir) {
    if (rec) return Colors.redAccent.withOpacity(0.6);
    if (ref) return Colors.white54;
    if (mir) return Colors.blueAccent.withOpacity(0.4);
    return Colors.white24;
  }

  Color _getIconColor(bool rec, bool ref, bool mir, bool fir) {
    if (rec) return Colors.redAccent;
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
