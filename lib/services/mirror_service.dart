import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Service de miroir vocal avancé
/// Implémente les 3 types de miroirs définis dans les specs Kibushi :
/// - Type A : Dernière syllabe (300-600ms)
/// - Type B : Dernier mot approximatif (700-1200ms)
/// - Type C : Intonation (250-400ms)
class MirrorService {
  final Random _random = Random();

  /// Génère un miroir vocal à partir du fichier source
  /// Retourne le chemin du fichier miroir ou null si échec
  Future<String?> generateMirror(String sourcePath, {MirrorType? forcedType}) async {
    final file = File(sourcePath);
    if (!file.existsSync()) return null;

    final bytes = await file.readAsBytes();
    if (bytes.length < 44) return null; // WAV header minimum

    // Parse le header WAV pour obtenir les métadonnées
    final wavInfo = _parseWavHeader(bytes);
    if (wavInfo == null) return null;

    // Sélection du type de miroir (aléatoire ou forcé)
    final mirrorType = forcedType ?? _selectMirrorType();
    
    // Calcul de la durée du miroir selon le type
    final durationMs = _calculateMirrorDuration(mirrorType);
    
    // Extraction du fragment audio
    final mirrorBytes = _extractMirrorFragment(
      bytes, 
      wavInfo, 
      durationMs,
      mirrorType,
    );
    
    if (mirrorBytes == null) return null;

    // Application des fades (fade-in 20-50ms, fade-out 40-80ms)
    final processedBytes = _applyFades(mirrorBytes, wavInfo, mirrorType);
    
    // Sauvegarde du fichier miroir
    final mirrorPath = sourcePath.replaceAll('.wav', '_mirror_${mirrorType.name}.wav');
    await _writeWavFile(mirrorPath, processedBytes, wavInfo);
    
    return mirrorPath;
  }

  /// Sélectionne aléatoirement un type de miroir avec pondération
  MirrorType _selectMirrorType() {
    final rand = _random.nextDouble();
    if (rand < 0.4) return MirrorType.syllable;      // 40% Type A
    if (rand < 0.75) return MirrorType.word;         // 35% Type B
    return MirrorType.intonation;                     // 25% Type C
  }

  /// Calcule la durée du miroir selon le type (avec variation aléatoire)
  int _calculateMirrorDuration(MirrorType type) {
    switch (type) {
      case MirrorType.syllable:
        // Type A : 300-600ms
        return 300 + _random.nextInt(300);
      case MirrorType.word:
        // Type B : 700-1200ms
        return 700 + _random.nextInt(500);
      case MirrorType.intonation:
        // Type C : 250-400ms
        return 250 + _random.nextInt(150);
    }
  }

  /// Extrait le fragment final de l'audio selon le type de miroir
  Uint8List? _extractMirrorFragment(
    Uint8List source,
    WavInfo info,
    int durationMs,
    MirrorType type,
  ) {
    final bytesPerMs = (info.sampleRate * info.channels * (info.bitsPerSample ~/ 8)) ~/ 1000;
    final fragmentSize = durationMs * bytesPerMs;
    
    // Position de début (on prend à la fin du fichier)
    final dataStart = 44; // Après le header WAV
    final dataEnd = source.length;
    final startPos = dataEnd - fragmentSize;
    
    if (startPos < dataStart) return null; // Fichier trop court

    // Ajustement selon le type de miroir
    int adjustedStart = startPos;
    
    switch (type) {
      case MirrorType.syllable:
        // Type A : on essaie de tomber sur une voyelle (simplifié : milieu du fragment)
        adjustedStart = startPos + (fragmentSize ~/ 4);
        break;
      case MirrorType.word:
        // Type B : on prend plus tôt pour avoir le contexte du mot
        adjustedStart = startPos - (fragmentSize ~/ 3);
        if (adjustedStart < dataStart) adjustedStart = dataStart;
        break;
      case MirrorType.intonation:
        // Type C : on prend la toute fin pour l'inflexion
        adjustedStart = startPos;
        break;
    }

    final endPos = adjustedStart + fragmentSize;
    if (endPos > dataEnd) return null;

    return Uint8List.sublistView(source, adjustedStart, endPos);
  }

  /// Applique les fades (fade-in 20-50ms, fade-out 40-80ms)
  Uint8List _applyFades(Uint8List audioData, WavInfo info, MirrorType type) {
    final bytesPerSample = info.bitsPerSample ~/ 8;
    final bytesPerMs = (info.sampleRate * info.channels * bytesPerSample) ~/ 1000;
    
    // Durées des fades selon le type
    final fadeInMs = 20 + _random.nextInt(30);   // 20-50ms
    final fadeOutMs = 40 + _random.nextInt(40);  // 40-80ms
    
    final fadeInSamples = fadeInMs * bytesPerMs;
    final fadeOutSamples = fadeOutMs * bytesPerMs;
    
    final result = Uint8List.fromList(audioData);
    
    // Fade in (début du fragment)
    for (int i = 0; i < fadeInSamples && i < result.length; i += bytesPerSample) {
      final factor = i / fadeInSamples;
      _applyFactorToSample(result, i, bytesPerSample, factor);
    }
    
    // Fade out (fin du fragment)
    for (int i = 0; i < fadeOutSamples && i < result.length; i += bytesPerSample) {
      final pos = result.length - i - bytesPerSample;
      final factor = i / fadeOutSamples;
      _applyFactorToSample(result, pos, bytesPerSample, factor);
    }
    
    return result;
  }

  /// Applique un facteur d'atténuation à un échantillon
  void _applyFactorToSample(Uint8List data, int pos, int bytesPerSample, double factor) {
    if (bytesPerSample == 2) {
      // 16-bit PCM
      int sample = data.buffer.asInt16List()[pos ~/ 2];
      sample = (sample * factor).toInt();
      data.buffer.asInt16List()[pos ~/ 2] = sample;
    } else if (bytesPerSample == 1) {
      // 8-bit PCM
      int sample = (data[pos] - 128);
      sample = (sample * factor).toInt();
      data[pos] = (sample + 128).toInt();
    }
  }

  /// Parse le header WAV pour extraire les métadonnées
  WavInfo? _parseWavHeader(Uint8List bytes) {
    if (bytes.length < 44) return null;
    
    final buffer = bytes.buffer;
    final data = ByteData.view(buffer);
    
    // Vérification du header "RIFF"
    if (String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF') return null;
    if (String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') return null;
    
    return WavInfo(
      sampleRate: data.getInt32(24, Endian.little),
      channels: data.getInt16(22, Endian.little),
      bitsPerSample: data.getInt16(34, Endian.little),
    );
  }

  /// Écrit un fichier WAV avec le nouveau fragment
  Future<void> _writeWavFile(String path, Uint8List audioData, WavInfo info) async {
    final file = File(path);
    final sink = file.openWrite();
    
    // Header WAV
    final header = ByteData(44);
    
    // RIFF
    header.setUint8(0, 0x52); header.setUint8(1, 0x49); header.setUint8(2, 0x46); header.setUint8(3, 0x46);
    // Taille du fichier
    header.setInt32(4, 36 + audioData.length, Endian.little);
    // WAVE
    header.setUint8(8, 0x57); header.setUint8(9, 0x41); header.setUint8(10, 0x56); header.setUint8(11, 0x45);
    // fmt
    header.setUint8(12, 0x66); header.setUint8(13, 0x6D); header.setUint8(14, 0x74); header.setUint8(15, 0x20);
    // Taille du chunk fmt
    header.setInt32(16, 16, Endian.little);
    // Format audio (1 = PCM)
    header.setInt16(20, 1, Endian.little);
    // Nombre de canaux
    header.setInt16(22, info.channels, Endian.little);
    // Sample rate
    header.setInt32(24, info.sampleRate, Endian.little);
    // Byte rate
    header.setInt32(28, info.sampleRate * info.channels * (info.bitsPerSample ~/ 8), Endian.little);
    // Block align
    header.setInt16(32, info.channels * (info.bitsPerSample ~/ 8), Endian.little);
    // Bits per sample
    header.setInt16(34, info.bitsPerSample, Endian.little);
    // data
    header.setUint8(36, 0x64); header.setUint8(37, 0x61); header.setUint8(38, 0x74); header.setUint8(39, 0x61);
    // Taille des données
    header.setInt32(40, audioData.length, Endian.little);
    
    sink.add(header.buffer.asUint8List());
    sink.add(audioData);
    await sink.close();
  }
}

/// Types de miroirs vocaux
enum MirrorType {
  syllable,    // Type A : Dernière syllabe
  word,        // Type B : Dernier mot
  intonation,  // Type C : Intonation
}

/// Informations extraites du header WAV
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
