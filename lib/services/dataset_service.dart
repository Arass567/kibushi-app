import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service de collecte de données audio pour entraînement TTS
/// 
/// Structure du dataset :
/// - raw/ : Fichiers WAV bruts avec métadonnées JSON
/// - processed/ : Fichiers nettoyés et normalisés
/// - metadata/ : Index global et statistiques
/// - consent/ : Preuves de consentement (hash anonymisé)
///
/// Anonymisation garantie :
/// - Pas d'identifiant personnel
/// - Hash unique par session (non traçable)
/// - Timestamp grossier (heure uniquement)
/// - Pas de géolocalisation
class DatasetService {
  static const String _datasetBasePath = '/home/raffion/kibushi-dataset';
  static const String _consentKey = 'dataset_consent_given';
  static const String _sessionIdKey = 'dataset_session_hash';
  
  final Random _random = Random();
  String? _currentSessionHash;
  
  /// Vérifie si l'utilisateur a donné son consentement
  Future<bool> hasConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_consentKey) ?? false;
  }
  
  /// Enregistre le consentement de l'utilisateur
  Future<void> giveConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, true);
    await prefs.setString(_sessionIdKey, _generateAnonymousHash());
    
    // Création du fichier de consentement (timestamp uniquement)
    final consentFile = File('$_datasetBasePath/consent/${_generateAnonymousHash()}.txt');
    await consentFile.writeAsString('Consent given at ${DateTime.now().toIso8601String()}\n');
  }
  
  /// Révoque le consentement et supprime les données
  Future<void> revokeConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, false);
    
    // Suppression des données brutes associées
    await _deleteUserData();
  }
  
  /// Initialise une nouvelle session de collecte
  Future<void> initializeSession() async {
    final prefs = await SharedPreferences.getInstance();
    _currentSessionHash = prefs.getString(_sessionIdKey);
    
    if (_currentSessionHash == null) {
      _currentSessionHash = _generateAnonymousHash();
      await prefs.setString(_sessionIdKey, _currentSessionHash!);
    }
  }
  
  /// Collecte un échantillon audio avec métadonnées
  /// 
  /// [audioPath] : Chemin du fichier WAV à collecter
  /// [context] : Contexte d'enregistrement (ex: "first_launch", "mirror", "free_speech")
  Future<AudioSample?> collectSample(String audioPath, {String context = 'free_speech'}) async {
    if (!await hasConsent()) return null;
    
    final file = File(audioPath);
    if (!file.existsSync()) return null;
    
    // Lecture et analyse du fichier
    final bytes = await file.readAsBytes();
    final wavInfo = _parseWavInfo(bytes);
    if (wavInfo == null) return null;
    
    // Calcul de la durée
    final durationMs = _calculateDuration(bytes.length, wavInfo);
    
    // Filtres de qualité
    if (!_passesQualityFilters(durationMs, wavInfo)) {
      return null; // Échantillon de mauvaise qualité
    }
    
    // Génération d'un ID unique anonyme
    final sampleId = _generateSampleId();
    final timestamp = _getGrossTimestamp();
    
    // Métadonnées (sans info personnelle)
    final metadata = AudioSampleMetadata(
      id: sampleId,
      sessionHash: _currentSessionHash ?? 'unknown',
      durationMs: durationMs,
      sampleRate: wavInfo.sampleRate,
      channels: wavInfo.channels,
      bitsPerSample: wavInfo.bitsPerSample,
      context: context,
      timestamp: timestamp,
      qualityScore: _calculateQualityScore(bytes, wavInfo),
    );
    
    // Copie vers le dataset
    final targetPath = '$_datasetBasePath/raw/$sampleId.wav';
    await file.copy(targetPath);
    
    // Sauvegarde des métadonnées JSON
    final metadataPath = '$_datasetBasePath/raw/$sampleId.json';
    final metadataFile = File(metadataPath);
    await metadataFile.writeAsString(jsonEncode(metadata.toJson()));
    
    // Mise à jour de l'index
    await _updateIndex(metadata);
    
    return AudioSample(
      id: sampleId,
      filePath: targetPath,
      metadata: metadata,
    );
  }
  
  /// Génère un hash anonyme de session
  String _generateAnonymousHash() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
  
  /// Génère un ID d'échantillon unique
  String _generateSampleId() {
    final now = DateTime.now();
    final random = _random.nextInt(10000).toString().padLeft(4, '0');
    return 'kbs_${now.millisecondsSinceEpoch}_$random';
  }
  
  /// Retourne un timestamp grossier (heure uniquement, pas de minutes/secondes)
  String _getGrossTimestamp() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}h';
  }
  
  /// Parse les infos WAV
  WavInfo? _parseWavInfo(Uint8List bytes) {
    if (bytes.length < 44) return null;
    
    final buffer = bytes.buffer;
    final data = ByteData.view(buffer);
    
    // Vérification RIFF/WAVE
    if (String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF') return null;
    if (String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') return null;
    
    return WavInfo(
      sampleRate: data.getInt32(24, Endian.little),
      channels: data.getInt16(22, Endian.little),
      bitsPerSample: data.getInt16(34, Endian.little),
    );
  }
  
  /// Calcule la durée en ms
  int _calculateDuration(int fileSize, WavInfo info) {
    final dataSize = fileSize - 44; // Moins le header
    final bytesPerMs = (info.sampleRate * info.channels * (info.bitsPerSample ~/ 8)) ~/ 1000;
    return (dataSize / bytesPerMs).round();
  }
  
  /// Vérifie les filtres de qualité
  bool _passesQualityFilters(int durationMs, WavInfo info) {
    // Durée minimale : 500ms
    if (durationMs < 500) return false;
    
    // Durée maximale : 30 secondes
    if (durationMs > 30000) return false;
    
    // Sample rate correct
    if (info.sampleRate != 16000) return false;
    
    // Mono uniquement
    if (info.channels != 1) return false;
    
    return true;
  }
  
  /// Calcule un score de qualité (0-100)
  int _calculateQualityScore(Uint8List bytes, WavInfo info) {
    // Simplification : score basé sur la présence de silences
    // En vrai, on ferait une analyse RMS du signal
    final dataBytes = bytes.sublist(44);
    
    int nonZeroSamples = 0;
    int totalSamples = 0;
    
    for (int i = 0; i < dataBytes.length - 1; i += 2) {
      final sample = (dataBytes[i + 1] << 8) | dataBytes[i];
      if (sample > 50 || sample < 65486) { // Valeurs significatives
        nonZeroSamples++;
      }
      totalSamples++;
      
      if (totalSamples > 10000) break; // Échantillon pour perf
    }
    
    final ratio = nonZeroSamples / totalSamples;
    return (ratio * 100).round().clamp(0, 100);
  }
  
  /// Met à jour l'index global
  Future<void> _updateIndex(AudioSampleMetadata metadata) async {
    final indexPath = '$_datasetBasePath/metadata/index.json';
    final indexFile = File(indexPath);
    
    List<dynamic> index = [];
    if (await indexFile.exists()) {
      final content = await indexFile.readAsString();
      index = jsonDecode(content) as List;
    }
    
    index.add(metadata.toJson());
    await indexFile.writeAsString(jsonEncode(index));
  }
  
  /// Supprime les données utilisateur
  Future<void> _deleteUserData() async {
    if (_currentSessionHash == null) return;
    
    final rawDir = Directory('$_datasetBasePath/raw');
    if (!await rawDir.exists()) return;
    
    await for (final entity in rawDir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        final content = await entity.readAsString();
        final metadata = jsonDecode(content);
        
        if (metadata['sessionHash'] == _currentSessionHash) {
          // Suppression du JSON et du WAV associé
          await entity.delete();
          final wavPath = entity.path.replaceAll('.json', '.wav');
          final wavFile = File(wavPath);
          if (await wavFile.exists()) {
            await wavFile.delete();
          }
        }
      }
    }
  }
  
  /// Récupère les statistiques du dataset
  Future<DatasetStats> getStats() async {
    final rawDir = Directory('$_datasetBasePath/raw');
    if (!await rawDir.exists()) {
      return DatasetStats(totalSamples: 0, totalDurationMs: 0);
    }
    
    int totalSamples = 0;
    int totalDuration = 0;
    
    await for (final entity in rawDir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        final content = await entity.readAsString();
        final metadata = jsonDecode(content);
        totalSamples++;
        totalDuration += (metadata['durationMs'] as num).toInt();
      }
    }
    
    return DatasetStats(
      totalSamples: totalSamples,
      totalDurationMs: totalDuration,
    );
  }
}

/// Informations WAV
class WavInfo {
  final int sampleRate;
  final int channels;
  final int bitsPerSample;
  
  WavInfo({
    required this.sampleRate,
    required this.channels,
    required this.bitsPerSample,
  });
}

/// Métadonnées d'un échantillon audio
class AudioSampleMetadata {
  final String id;
  final String sessionHash;
  final int durationMs;
  final int sampleRate;
  final int channels;
  final int bitsPerSample;
  final String context;
  final String timestamp;
  final int qualityScore;
  
  AudioSampleMetadata({
    required this.id,
    required this.sessionHash,
    required this.durationMs,
    required this.sampleRate,
    required this.channels,
    required this.bitsPerSample,
    required this.context,
    required this.timestamp,
    required this.qualityScore,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionHash': sessionHash,
    'durationMs': durationMs,
    'sampleRate': sampleRate,
    'channels': channels,
    'bitsPerSample': bitsPerSample,
    'context': context,
    'timestamp': timestamp,
    'qualityScore': qualityScore,
  };
}

/// Échantillon audio collecté
class AudioSample {
  final String id;
  final String filePath;
  final AudioSampleMetadata metadata;
  
  AudioSample({
    required this.id,
    required this.filePath,
    required this.metadata,
  });
}

/// Statistiques du dataset
class DatasetStats {
  final int totalSamples;
  final int totalDurationMs;
  
  DatasetStats({
    required this.totalSamples,
    required this.totalDurationMs,
  });
  
  double get totalDurationMinutes => totalDurationMs / 60000;
  
  @override
  String toString() => '$totalSamples échantillons (${totalDurationMinutes.toStringAsFixed(1)} min)';
}
