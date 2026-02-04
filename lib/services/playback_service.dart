import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

/// États du lecteur audio
enum PlayerState { idle, loading, playing, paused, completed, error }

/// Erreurs possibles du lecteur
enum PlayerError { loadFailed, playbackFailed, networkError, unknown }

class PlaybackService {
  final AudioPlayer _player = AudioPlayer();
  
  /// StreamControllers pour UI réactive
  final _stateController = StreamController<PlayerState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _errorController = StreamController<PlayerError?>.broadcast();
  final _completionController = StreamController<void>.broadcast();
  
  Stream<PlayerState> get stateStream => _stateController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;
  Stream<PlayerError?> get errorStream => _errorController.stream;
  Stream<void> get completionStream => _completionController.stream;
  
  PlayerState _currentState = PlayerState.idle;
  Duration? _duration;
  
  StreamSubscription? _positionSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _completionSub;
  
  PlaybackService() {
    _initListeners();
  }
  
  void _initListeners() {
    // Écoute position pour progress bar
    _positionSub = _player.onPositionChanged.listen((position) {
      _positionController.add(position);
    });
    
    // Écoute changement état
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      switch (state) {
        case PlayerState.playing:
          _updateState(PlayerState.playing);
          break;
        case PlayerState.paused:
          _updateState(PlayerState.paused);
          break;
        case PlayerState.stopped:
          _updateState(PlayerState.idle);
          break;
      }
    });
    
    // Écoute fin de lecture
    _completionSub = _player.onPlayerComplete.listen((_) {
      _completionController.add(null);
      _updateState(PlayerState.completed);
      _updateState(PlayerState.idle);
    });
  }

  Future<bool> playLocalFile(String path) async {
    try {
      _updateState(PlayerState.loading);
      
      await _player.stop(); // Stop précédent si existe
      
      final source = DeviceFileSource(path);
      await _player.play(source);
      
      // Récupération durée
      _duration = await _player.getDuration();
      _durationController.add(_duration);
      
      debugPrint('Playing: $path (duration: $_duration)');
      return true;
      
    } on Exception catch (e) {
      _errorController.add(PlayerError.loadFailed);
      _updateState(PlayerState.error);
      debugPrint('Error playing file: $e');
      return false;
    }
  }

  Future<bool> playAsset(String assetPath) async {
    try {
      _updateState(PlayerState.loading);
      
      await _player.stop();
      
      final source = AssetSource(assetPath);
      await _player.play(source);
      
      _duration = await _player.getDuration();
      _durationController.add(_duration);
      
      debugPrint('Playing asset: $assetPath');
      return true;
      
    } catch (e) {
      _errorController.add(PlayerError.loadFailed);
      _updateState(PlayerState.error);
      debugPrint('Error playing asset: $e');
      return false;
    }
  }
  
  /// Lecture avec fade-in
  Future<bool> playWithFadeIn(String path, {Duration fadeDuration = const Duration(milliseconds: 300)}) async {
    try {
      await _player.setVolume(0.0);
      final success = await playLocalFile(path);
      if (success) {
        // Fade-in progressif
        await _fadeVolume(0.0, 1.0, fadeDuration);
      }
      return success;
    } catch (e) {
      debugPrint('Fade-in error: $e');
      return false;
    }
  }
  
  /// Fade-out avant stop
  Future<void> stopWithFadeOut({Duration fadeDuration = const Duration(milliseconds: 300)}) async {
    try {
      await _fadeVolume(1.0, 0.0, fadeDuration);
      await stop();
    } catch (e) {
      debugPrint('Fade-out error: $e');
    }
  }
  
  Future<void> _fadeVolume(double from, double to, Duration duration) async {
    final steps = 20;
    final stepDuration = duration ~/ steps;
    final stepSize = (to - from) / steps;
    
    for (var i = 0; i <= steps; i++) {
      final volume = (from + (stepSize * i)).clamp(0.0, 1.0);
      await _player.setVolume(volume);
      await Future.delayed(stepDuration);
    }
  }

  Future<void> pause() async {
    try {
      await _player.pause();
      _updateState(PlayerState.paused);
    } catch (e) {
      debugPrint('Error pausing: $e');
    }
  }

  Future<void> resume() async {
    try {
      await _player.resume();
      _updateState(PlayerState.playing);
    } catch (e) {
      debugPrint('Error resuming: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
      _updateState(PlayerState.idle);
      _positionController.add(Duration.zero);
    } catch (e) {
      debugPrint('Error stopping: $e');
    }
  }
  
  /// Seek à une position spécifique
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint('Error seeking: $e');
    }
  }
  
  /// Change volume (0.0 à 1.0)
  Future<void> setVolume(double volume) async {
    try {
      await _player.setVolume(volume.clamp(0.0, 1.0));
    } catch (e) {
      debugPrint('Error setting volume: $e');
    }
  }

  PlayerState get currentState => _currentState;
  Duration? get duration => _duration;
  
  void _updateState(PlayerState state) {
    _currentState = state;
    _stateController.add(state);
  }

  void dispose() {
    _positionSub?.cancel();
    _stateSub?.cancel();
    _completionSub?.cancel();
    _player.dispose();
    _stateController.close();
    _positionController.close();
    _durationController.close();
    _errorController.close();
    _completionController.close();
  }
}

void debugPrint(String s) => print('🦅 baby-player: $s');
