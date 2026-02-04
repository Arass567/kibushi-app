import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/recorder_service.dart';
import '../services/playback_service.dart';
import '../services/dictionary_service.dart';
import '../services/mirror_service.dart';
import '../services/memory_service.dart';
import '../services/dataset_service.dart';

enum AppState {
  firstLaunch,
  idle,
  promptSpeak,
  recording,
  reflecting,
  mirrorPlayback,
  listening,
  consentPrompt,  // Nouveau : demande de consentement
}

class KibushiState extends ChangeNotifier {
  final RecorderService _recorder = RecorderService();
  final PlaybackService _playback = PlaybackService();
  final DictionaryService _dictionary = DictionaryService();
  final MirrorService _mirror = MirrorService();
  final MemoryService _memory = MemoryService();
  final DatasetService _dataset = DatasetService();
  final Random _random = Random();
  
  AppState _currentState = AppState.idle;
  String? _lastRecordingPath;
  String? _lastMirrorType;
  bool _isFirstLaunch = true;
  bool _hasDatasetConsent = false;

  AppState get currentState => _currentState;
  String? get lastMirrorType => _lastMirrorType;
  bool get hasDatasetConsent => _hasDatasetConsent;

  KibushiState() {
    _init();
  }

  Future<void> _init() async {
    await _dictionary.load();
    await _dataset.initializeSession();
    
    final sessionCount = await _memory.getSessionCount();
    _hasDatasetConsent = await _dataset.hasConsent();
    
    // Si première session et pas de consentement, on montre le prompt
    if (sessionCount == 0) {
      _isFirstLaunch = true;
      if (!_hasDatasetConsent) {
        transitionTo(AppState.consentPrompt);
        return;
      }
    }
    
    if (_isFirstLaunch) {
      _handleFirstLaunch();
    }
  }

  Future<void> _handleFirstLaunch() async {
    transitionTo(AppState.firstLaunch);
    await Future.delayed(const Duration(milliseconds: 800));
  }

  /// Donne le consentement pour la collecte de données
  Future<void> giveDatasetConsent() async {
    await _dataset.giveConsent();
    _hasDatasetConsent = true;
    
    if (_isFirstLaunch) {
      _handleFirstLaunch();
    } else {
      transitionTo(AppState.idle);
    }
  }

  /// Refuse le consentement
  Future<void> declineDatasetConsent() async {
    _hasDatasetConsent = false;
    
    if (_isFirstLaunch) {
      _handleFirstLaunch();
    } else {
      transitionTo(AppState.idle);
    }
  }

  void transitionTo(AppState newState) {
    _currentState = newState;
    notifyListeners();
  }

  Future<void> startVoiceCapture() async {
    if (_isFirstLaunch) {
      _isFirstLaunch = false;
    }
    
    _lastRecordingPath = await _recorder.startRecording();
    if (_lastRecordingPath != null) {
      transitionTo(AppState.recording);
    }
  }

  Future<void> stopVoiceCapture() async {
    final path = await _recorder.stopRecording();
    transitionTo(AppState.reflecting);
    
    // Sauvegarde de la session
    await _memory.saveSession();
    
    // Collecte pour le dataset (si consentement donné)
    if (_hasDatasetConsent && path != null) {
      await _dataset.collectSample(
        path,
        context: 'free_speech',
      );
    }
    
    // Silence intentionnel (Reflecting) : 200-400ms selon specs
    await Future.delayed(Duration(milliseconds: 200 + _random.nextInt(200)));
    
    // Décision miroir probabiliste
    if (path != null && _shouldPlayMirror()) {
      final mirrorType = _selectMirrorType();
      _lastMirrorType = mirrorType.name;
      
      final mirrorPath = await _mirror.generateMirror(
        path, 
        forcedType: mirrorType,
      );
      
      if (mirrorPath != null) {
        transitionTo(AppState.mirrorPlayback);
        await _playback.playLocalFile(mirrorPath);
        
        final duration = await _getAudioDuration(mirrorPath);
        await Future.delayed(duration + const Duration(milliseconds: 300));
      }
    }
    
    transitionTo(AppState.idle);
  }

  bool _shouldPlayMirror() {
    final baseProbability = 0.7;
    
    if (_lastMirrorType != null && _random.nextDouble() < 0.3) {
      return false;
    }
    
    return _random.nextDouble() < baseProbability;
  }

  MirrorType _selectMirrorType() {
    final rand = _random.nextDouble();
    if (rand < 0.4) return MirrorType.syllable;
    if (rand < 0.75) return MirrorType.word;
    return MirrorType.intonation;
  }

  Future<Duration> _getAudioDuration(String path) async {
    final file = File(path);
    if (!file.existsSync()) return const Duration(seconds: 1);
    
    final size = await file.length();
    final seconds = size ~/ 32000;
    return Duration(milliseconds: (seconds * 1000).clamp(300, 2000));
  }

  /// Récupère les stats du dataset
  Future<String> getDatasetStats() async {
    final stats = await _dataset.getStats();
    return stats.toString();
  }

  @override
  void dispose() {
    _recorder.dispose();
    _playback.dispose();
    super.dispose();
  }
}
