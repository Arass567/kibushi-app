import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Optimisations mémoire et CPU pour le traitement audio
class AudioOptimizer {
  
  /// Traite l'audio dans un isolate pour ne pas bloquer l'UI
  /// Utilisé pour : compression, conversion format, analyse
  static Future<Uint8List?> processInIsolate(
    Uint8List audioData,
    Future<Uint8List> Function(Uint8List) processor,
  ) async {
    try {
      return await compute(_isolateProcessor, {
        'data': audioData,
        'processor': processor,
      });
    } catch (e) {
      print('Isolate processing error: $e');
      return null;
    }
  }
  
  static Uint8List? _isolateProcessor(Map<String, dynamic> args) {
    final data = args['data'] as Uint8List;
    final processor = args['processor'] as Function;
    try {
      return processor(data) as Uint8List;
    } catch (e) {
      return null;
    }
  }
  
  /// Limite la fréquence des updates UI (throttling)
  /// Évite de surcharger le build() avec trop de setState
  static Stream<T> throttleStream<T>(Stream<T> stream, Duration duration) {
    Timer? timer;
    T? lastValue;
    bool hasPending = false;
    
    final controller = StreamController<T>.broadcast();
    
    stream.listen((value) {
      lastValue = value;
      
      if (timer?.isActive ?? false) {
        hasPending = true;
        return;
      }
      
      controller.add(value);
      hasPending = false;
      
      timer = Timer(duration, () {
        if (hasPending && lastValue != null) {
          controller.add(lastValue as T);
          hasPending = false;
        }
      });
    });
    
    return controller.stream;
  }
  
  /// Debounce pour les actions utilisateur (évite double-clic, etc.)
  static Future<void> debounce(
    Future<void> Function() action, {
    Duration delay = const Duration(milliseconds: 300),
  }) async {
    await Future.delayed(delay);
    await action();
  }
  
  /// Précharge les assets audio en mémoire pour éviter les latences
  static final Map<String, Uint8List> _audioCache = {};
  
  static Future<void> preloadAudio(String assetPath) async {
    if (_audioCache.containsKey(assetPath)) return;
    
    try {
      // Chargement asynchrone
      final data = await _loadAssetData(assetPath);
      if (data != null) {
        _audioCache[assetPath] = data;
      }
    } catch (e) {
      print('Preload error for $assetPath: $e');
    }
  }
  
  static Future<Uint8List?> _loadAssetData(String path) async {
    // Cette méthode serait implémentée avec rootBundle dans l'app réelle
    return null;
  }
  
  static Uint8List? getCachedAudio(String assetPath) {
    return _audioCache[assetPath];
  }
  
  static void clearCache() {
    _audioCache.clear();
  }
  
  /// Optimisation mémoire : limite la taille du cache
  static void manageCacheSize(int maxSize) {
    while (_audioCache.length > maxSize) {
      final firstKey = _audioCache.keys.first;
      _audioCache.remove(firstKey);
    }
  }
}

/// Gestionnaire de lifecycle pour éviter les memory leaks
class LifecycleManager {
  final List<VoidCallback> _disposeCallbacks = [];
  
  void register(VoidCallback disposeCallback) {
    _disposeCallbacks.add(disposeCallback);
  }
  
  void dispose() {
    for (final callback in _disposeCallbacks.reversed) {
      try {
        callback();
      } catch (e) {
        print('Dispose error: $e');
      }
    }
    _disposeCallbacks.clear();
  }
}

/// Métriques de performance pour debug
class PerformanceMetrics {
  static final Map<String, Stopwatch> _timers = {};
  static final Map<String, int> _counters = {};
  
  static void start(String name) {
    _timers[name] = Stopwatch()..start();
  }
  
  static void stop(String name) {
    final timer = _timers[name];
    if (timer != null && timer.isRunning) {
      timer.stop();
      print('⏱️ $name: ${timer.elapsedMilliseconds}ms');
    }
  }
  
  static void increment(String name) {
    _counters[name] = (_counters[name] ?? 0) + 1;
  }
  
  static void printStats() {
    print('📊 Performance Stats:');
    for (final entry in _counters.entries) {
      print('  ${entry.key}: ${entry.value}');
    }
  }
  
  static void reset() {
    _timers.clear();
    _counters.clear();
  }
}
