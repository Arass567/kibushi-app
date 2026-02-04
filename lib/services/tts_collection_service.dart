import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service de collecte structurée pour entraînement TTS
/// 
/// Organise les enregistrements en 4 catégories :
/// 1. PHRASES - Phrases complètes pour voix naturelle
/// 2. SYLLABLES - Syllabes isolées (A, E, I, O, U, etc.)
/// 3. DICTIONARY - Mots du dictionnaire Kibushi
/// 4. INTONATIONS - Variations d'expressivité
class TTSCollectionService {
  static const String _collectionDir = 'tts_collection';
  static const String _statsKey = 'tts_collection_stats';
  
  final Random _random = Random();
  String? _appDir;
  
  /// Catégories de collecte
  static const Map<String, CollectionCategory> categories = {
    'phrases': CollectionCategory(
      id: 'phrases',
      label: 'phrases',
      description: 'parle naturellement. phrases complètes.',
      targetCount: 100,
      minDurationMs: 2000,
      maxDurationMs: 8000,
    ),
    'syllables': CollectionCategory(
      id: 'syllables',
      label: 'syllabes',
      description: 'A. E. I. O. U. clairement.',
      targetCount: 250, // 50 de chaque
      minDurationMs: 300,
      maxDurationMs: 1500,
      prompts: ['A', 'E', 'I', 'O', 'U', 'KA', 'KE', 'KI', 'KO', 'KU', 'LA', 'LE', 'LI', 'LO', 'LU'],
    ),
    'dictionary': CollectionCategory(
      id: 'dictionary',
      label: 'dictionnaire',
      description: 'mots du corpus Kibushi.',
      targetCount: 200,
      minDurationMs: 500,
      maxDurationMs: 3000,
    ),
    'intonations': CollectionCategory(
      id: 'intonations',
      label: 'intonations',
      description: 'questions. exclamations. calme.',
      targetCount: 50,
      minDurationMs: 1000,
      maxDurationMs: 5000,
      prompts: [
        'question montante ?',
        'exclamation !',
        'phrase calme.',
        'doute...',
        'joie !',
      ],
    ),
  };
  
  /// Initialise le service
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _appDir = dir.path;
    
    // Crée les dossiers de collection
    for (final category in categories.values) {
      final catDir = Directory('$_appDir/$_collectionDir/${category.id}');
      if (!await catDir.exists()) {
        await catDir.create(recursive: true);
      }
    }
  }
  
  /// Enregistre un échantillon structuré
  Future<TTSSample> recordSample(
    String categoryId,
    String audioSourcePath, {
    String? prompt,
    String? notes,
  }) async {
    final category = categories[categoryId]!;
    final sampleId = _generateSampleId();
    
    // Création du dossier de la catégorie si besoin
    final catDir = Directory('$_appDir/$_collectionDir/$categoryId');
    if (!await catDir.exists()) {
      await catDir.create(recursive: true);
    }
    
    // Copie du fichier audio
    final targetPath = '${catDir.path}/$sampleId.wav';
    final sourceFile = File(audioSourcePath);
    await sourceFile.copy(targetPath);
    
    // Analyse du fichier
    final bytes = await sourceFile.readAsBytes();
    final durationMs = _estimateDuration(bytes);
    
    // Métadonnées
    final metadata = TTSSampleMetadata(
      id: sampleId,
      categoryId: categoryId,
      prompt: prompt,
      notes: notes,
      durationMs: durationMs,
      recordedAt: DateTime.now().toIso8601String(),
      fileSize: bytes.length,
    );
    
    // Sauvegarde JSON
    final jsonPath = '${catDir.path}/$sampleId.json';
    final jsonFile = File(jsonPath);
    await jsonFile.writeAsString(metadata.toJsonString());
    
    // Mise à jour des stats
    await _updateStats(categoryId);
    
    return TTSSample(
      id: sampleId,
      categoryId: categoryId,
      filePath: targetPath,
      metadata: metadata,
    );
  }
  
  /// Récupère les statistiques de collecte
  Future<Map<String, CategoryStats>> getStats() async {
    final stats = <String, CategoryStats>{};
    
    for (final entry in categories.entries) {
      final categoryId = entry.key;
      final category = entry.value;
      
      final catDir = Directory('$_appDir/$_collectionDir/$categoryId');
      if (!await catDir.exists()) {
        stats[categoryId] = CategoryStats(
          category: category,
          currentCount: 0,
          totalDurationMs: 0,
        );
        continue;
      }
      
      int count = 0;
      int totalDuration = 0;
      
      await for (final entity in catDir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          final content = await entity.readAsString();
          final data = jsonDecode(content);
          count++;
          totalDuration += (data['durationMs'] as num).toInt();
        }
      }
      
      stats[categoryId] = CategoryStats(
        category: category,
        currentCount: count,
        totalDurationMs: totalDuration,
      );
    }
    
    return stats;
  }
  
  /// Génère un rapport de collecte pour l'affichage
  Future<String> generateReport() async {
    final stats = await getStats();
    final buffer = StringBuffer();
    
    buffer.writeln('=== COLLECTION TTS ===\n');
    
    int totalSamples = 0;
    int totalDuration = 0;
    
    for (final entry in stats.entries) {
      final catId = entry.key;
      final stat = entry.value;
      
      totalSamples += stat.currentCount;
      totalDuration += stat.totalDurationMs;
      
      final percent = (stat.currentCount / stat.category.targetCount * 100).toStringAsFixed(0);
      final minutes = (stat.totalDurationMs / 60000).toStringAsFixed(1);
      
      buffer.writeln('${stat.category.label}: ${stat.currentCount}/${stat.category.targetCount} ($percent%) - ${minutes}min');
    }
    
    buffer.writeln('\n=== TOTAL ===');
    buffer.writeln('$totalSamples échantillons - ${(totalDuration / 60000).toStringAsFixed(1)} minutes');
    
    return buffer.toString();
  }
  
  /// Prépare l'export pour transfert vers PC
  Future<String> prepareExport() async {
    final exportDir = Directory('$_appDir/export_tts');
    if (await exportDir.exists()) {
      await exportDir.delete(recursive: true);
    }
    await exportDir.create();
    
    final collectionDir = Directory('$_appDir/$_collectionDir');
    if (!await collectionDir.exists()) {
      throw Exception('Pas de données à exporter');
    }
    
    // Copie récursive
    await _copyDirectory(collectionDir, exportDir);
    
    // Génère le rapport
    final report = await generateReport();
    final reportFile = File('${exportDir.path}/RAPPORT.txt');
    await reportFile.writeAsString(report);
    
    // Crée un ZIP
    final zipPath = '$_appDir/kibushi_tts_export.zip';
    await _createZip(exportDir.path, zipPath);
    
    return zipPath;
  }
  
  /// Génère un ID unique
  String _generateSampleId() {
    final now = DateTime.now();
    final random = _random.nextInt(10000).toString().padLeft(4, '0');
    return 'tts_${now.millisecondsSinceEpoch}_$random';
  }
  
  /// Estime la durée d'un fichier WAV
  int _estimateDuration(Uint8List bytes) {
    if (bytes.length < 44) return 0;
    final dataSize = bytes.length - 44;
    // 16kHz mono 16bit = 32000 bytes/sec
    return (dataSize / 32).round();
  }
  
  /// Met à jour les stats
  Future<void> _updateStats(String categoryId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_statsKey/$categoryId';
    final current = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, current + 1);
  }
  
  /// Copie un dossier récursivement
  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await for (final entity in source.list()) {
      final name = entity.path.split('/').last;
      final destPath = '${destination.path}/$name';
      
      if (entity is Directory) {
        final destDir = Directory(destPath);
        await destDir.create();
        await _copyDirectory(entity, destDir);
      } else if (entity is File) {
        await entity.copy(destPath);
      }
    }
  }
  
  /// Crée un ZIP
  Future<void> _createZip(String sourceDir, String targetPath) async {
    // Utilise la commande system zip
    final result = await Process.run('zip', ['-r', targetPath, '.'], 
      workingDirectory: sourceDir);
    
    if (result.exitCode != 0) {
      throw Exception('Erreur création ZIP: ${result.stderr}');
    }
  }
  
  /// Récupère un prompt aléatoire pour une catégorie
  String? getRandomPrompt(String categoryId) {
    final category = categories[categoryId];
    if (category?.prompts == null || category!.prompts!.isEmpty) {
      return null;
    }
    return category.prompts![_random.nextInt(category.prompts!.length)];
  }
}

/// Catégorie de collecte
class CollectionCategory {
  final String id;
  final String label;
  final String description;
  final int targetCount;
  final int minDurationMs;
  final int maxDurationMs;
  final List<String>? prompts;
  
  const CollectionCategory({
    required this.id,
    required this.label,
    required this.description,
    required this.targetCount,
    required this.minDurationMs,
    required this.maxDurationMs,
    this.prompts,
  });
}

/// Métadonnées d'un échantillon
class TTSSampleMetadata {
  final String id;
  final String categoryId;
  final String? prompt;
  final String? notes;
  final int durationMs;
  final String recordedAt;
  final int fileSize;
  
  TTSSampleMetadata({
    required this.id,
    required this.categoryId,
    this.prompt,
    this.notes,
    required this.durationMs,
    required this.recordedAt,
    required this.fileSize,
  });
  
  String toJsonString() {
    return '''{
  "id": "$id",
  "categoryId": "$categoryId",
  "prompt": ${prompt != null ? '"$prompt"' : 'null'},
  "notes": ${notes != null ? '"$notes"' : 'null'},
  "durationMs": $durationMs,
  "recordedAt": "$recordedAt",
  "fileSize": $fileSize
}''';
  }
}

/// Échantillon TTS
class TTSSample {
  final String id;
  final String categoryId;
  final String filePath;
  final TTSSampleMetadata metadata;
  
  TTSSample({
    required this.id,
    required this.categoryId,
    required this.filePath,
    required this.metadata,
  });
}

/// Stats d'une catégorie
class CategoryStats {
  final CollectionCategory category;
  final int currentCount;
  final int totalDurationMs;
  
  CategoryStats({
    required this.category,
    required this.currentCount,
    required this.totalDurationMs,
  });
  
  double get progressPercent => (currentCount / category.targetCount * 100);
  double get totalMinutes => totalDurationMs / 60000;
}
