import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// États possibles de l'enregistreur
enum RecorderState { idle, recording, paused, error }

/// Événements d'erreur audio
enum AudioError { noPermission, recordingFailed, fileSystemError, unknown }

class RecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  
  /// StreamController pour les mises à jour temps réel de l'UI
  final _stateController = StreamController<RecorderState>.broadcast();
  final _amplitudeController = StreamController<double>.broadcast();
  final _errorController = StreamController<AudioError?>.broadcast();
  
  Stream<RecorderState> get stateStream => _stateController.stream;
  Stream<double> get amplitudeStream => _amplitudeController.stream;
  Stream<AudioError?> get errorStream => _errorController.stream;
  
  RecorderState _currentState = RecorderState.idle;
  Timer? _amplitudeTimer;
  String? _currentPath;
  
  /// Vérifie les permissions microphone
  Future<bool> checkPermission() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _errorController.add(AudioError.noPermission);
      }
      return hasPermission;
    } catch (e) {
      _errorController.add(AudioError.unknown);
      debugPrint('Permission check error: $e');
      return false;
    }
  }
  
  /// Demande les permissions avec explication
  Future<bool> requestPermission() async {
    try {
      // Note: Sur iOS/Android, la permission est demandée automatiquement
      // par le package 'record' lors du premier startRecording()
      // Cette méthode vérifie juste l'état actuel
      return await checkPermission();
    } catch (e) {
      debugPrint('Permission request error: $e');
      return false;
    }
  }

  Future<String?> startRecording() async {
    try {
      // Vérification permission avant démarrage
      if (!await checkPermission()) {
        debugPrint('Permission denied');
        return null;
      }
      
      // Gestion de l'audio focus - pause si autre app utilise le micro
      final isRecording = await _recorder.isRecording();
      if (isRecording) {
        debugPrint('Already recording, stopping first');
        await stopRecording();
      }

      final Directory tempDir = await getTemporaryDirectory();
      final String path = '${tempDir.path}/kibushi_temp_${DateTime.now().millisecondsSinceEpoch}.wav';
      
      // Nettoyage fichier précédent
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }

      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      );

      await _recorder.start(config, path: path);
      _currentPath = path;
      _updateState(RecorderState.recording);
      
      // Démarrage monitoring amplitude pour visualisation
      _startAmplitudeMonitoring();
      
      debugPrint('Recording started: $path');
      return path;
      
    } on FileSystemException catch (e) {
      _errorController.add(AudioError.fileSystemError);
      debugPrint('Filesystem error: $e');
      return null;
    } catch (e) {
      _errorController.add(AudioError.recordingFailed);
      debugPrint('Error starting record: $e');
      return null;
    }
  }

  Future<String?> stopRecording() async {
    try {
      _stopAmplitudeMonitoring();
      final path = await _recorder.stop();
      _updateState(RecorderState.idle);
      debugPrint('Recording stopped: $path');
      return path;
    } catch (e) {
      _errorController.add(AudioError.recordingFailed);
      _updateState(RecorderState.error);
      debugPrint('Error stopping record: $e');
      return null;
    }
  }
  
  /// Pause temporaire (appel entrant, etc.)
  Future<void> pauseRecording() async {
    try {
      await _recorder.pause();
      _stopAmplitudeMonitoring();
      _updateState(RecorderState.paused);
      debugPrint('Recording paused');
    } catch (e) {
      debugPrint('Error pausing record: $e');
    }
  }
  
  /// Reprend après pause
  Future<void> resumeRecording() async {
    try {
      await _recorder.resume();
      _startAmplitudeMonitoring();
      _updateState(RecorderState.recording);
      debugPrint('Recording resumed');
    } catch (e) {
      debugPrint('Error resuming record: $e');
    }
  }
  
  /// Monitoring amplitude pour visualisation UI
  void _startAmplitudeMonitoring() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) async {
      try {
        final amp = await _recorder.getAmplitude();
        // Normalisation entre 0 et 1
        final normalized = (amp.current + 50) / 50;
        _amplitudeController.add(normalized.clamp(0.0, 1.0));
      } catch (e) {
        // Ignorer les erreurs de monitoring
      }
    });
  }
  
  void _stopAmplitudeMonitoring() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    _amplitudeController.add(0.0);
  }
  
  void _updateState(RecorderState state) {
    _currentState = state;
    _stateController.add(state);
  }
  
  RecorderState get currentState => _currentState;
  String? get currentPath => _currentPath;

  void dispose() {
    _stopAmplitudeMonitoring();
    _recorder.dispose();
    _stateController.close();
    _amplitudeController.close();
    _errorController.close();
  }
}

void debugPrint(String s) => print('🦅 baby-recorder: $s');
