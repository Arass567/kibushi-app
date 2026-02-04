import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import '../core/kibushi_state.dart';
import '../services/tts_collection_service.dart';

/// Écran de collecte TTS structurée
/// Mode spécial pour enregistrer des phrases pour entraînement du modèle vocal
class TTSCollectionScreen extends StatefulWidget {
  const TTSCollectionScreen({super.key});

  @override
  State<TTSCollectionScreen> createState() => _TTSCollectionScreenState();
}

class _TTSCollectionScreenState extends State<TTSCollectionScreen> {
  String _selectedCategory = 'phrases';
  final TTSCollectionService _collectionService = TTSCollectionService();
  Map<String, CategoryStats>? _stats;
  bool _isRecording = false;
  String? _currentPrompt;
  
  @override
  void initState() {
    super.initState();
    _initService();
  }
  
  Future<void> _initService() async {
    await _collectionService.init();
    _loadStats();
    _loadNewPrompt();
  }
  
  Future<void> _loadStats() async {
    final stats = await _collectionService.getStats();
    setState(() {
      _stats = stats;
    });
  }
  
  void _loadNewPrompt() {
    final prompt = _collectionService.getRandomPrompt(_selectedCategory);
    setState(() {
      _currentPrompt = prompt;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            // Stats
            if (_stats != null) _buildStatsRow(),
            
            const SizedBox(height: 40),
            
            // Prompt
            _buildPromptArea(),
            
            const Spacer(),
            
            // Bouton d'enregistrement
            _buildRecordButton(),
            
            const SizedBox(height: 40),
            
            // Sélecteur de catégorie
            _buildCategorySelector(),
            
            const SizedBox(height: 20),
            
            // Bouton export
            _buildExportButton(),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const PhosphorIcon(
              PhosphorIconsRegular.arrowLeft,
              color: Colors.white54,
            ),
          ),
          const Text(
            'collection voix',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
  
  Widget _buildStatsRow() {
    final stat = _stats![_selectedCategory];
    if (stat == null) return const SizedBox.shrink();
    
    final percent = stat.progressPercent.toStringAsFixed(0);
    final minutes = stat.totalMinutes.toStringAsFixed(1);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('$percent%', 'complété'),
          Container(width: 1, height: 30, color: Colors.white12),
          _buildStatItem('${stat.currentCount}', 'enregistrés'),
          Container(width: 1, height: 30, color: Colors.white12),
          _buildStatItem('${minutes}m', 'audio'),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w300,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
  
  Widget _buildPromptArea() {
    final category = TTSCollectionService.categories[_selectedCategory]!;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            category.label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          if (_currentPrompt != null)
            Text(
              _currentPrompt!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 24,
                fontWeight: FontWeight.w300,
              ),
            )
          else
            Text(
              category.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
                fontStyle: FontStyle.italic,
              ),
            ),
          const SizedBox(height: 20),
          if (_currentPrompt != null)
            TextButton(
              onPressed: _loadNewPrompt,
              child: Text(
                'autre',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildRecordButton() {
    return GestureDetector(
      onTapDown: (_) => _startRecording(),
      onTapUp: (_) => _stopRecording(),
      onTapCancel: () => _stopRecording(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: _isRecording ? 160 : 120,
        height: _isRecording ? 160 : 120,
        decoration: BoxDecoration(
          color: _isRecording 
              ? Colors.redAccent.withOpacity(0.2) 
              : Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: _isRecording ? Colors.redAccent : Colors.white30,
            width: _isRecording ? 3 : 2,
          ),
          boxShadow: _isRecording
              ? [
                  BoxShadow(
                    color: Colors.redAccent.withOpacity(0.3),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ]
              : null,
        ),
        child: PhosphorIcon(
          _isRecording 
              ? PhosphorIconsRegular.stop 
              : PhosphorIconsRegular.microphone,
          size: _isRecording ? 56 : 48,
          color: _isRecording ? Colors.redAccent : Colors.white70,
        ),
      ),
    );
  }
  
  Widget _buildCategorySelector() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: TTSCollectionService.categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final entry = TTSCollectionService.categories.entries.elementAt(index);
          final isSelected = entry.key == _selectedCategory;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = entry.key;
                _loadNewPrompt();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected 
                    ? Colors.white.withOpacity(0.1) 
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected ? Colors.white30 : Colors.white10,
                ),
              ),
              child: Text(
                entry.value.label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white38,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildExportButton() {
    return TextButton.icon(
      onPressed: _exportData,
      icon: const PhosphorIcon(
        PhosphorIconsRegular.export,
        color: Colors.white38,
        size: 18,
      ),
      label: const Text(
        'exporter vers PC',
        style: TextStyle(
          color: Colors.white38,
          fontSize: 13,
        ),
      ),
    );
  }
  
  void _startRecording() {
    HapticFeedback.lightImpact();
    setState(() {
      _isRecording = true;
    });
    // TODO: Démarrer l'enregistrement via RecorderService
  }
  
  void _stopRecording() async {
    if (!_isRecording) return;
    
    HapticFeedback.mediumImpact();
    setState(() {
      _isRecording = false;
    });
    
    // TODO: Arrêter et sauvegarder via RecorderService
    
    // Feedback visuel
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('enregistré', style: TextStyle(color: Colors.white70)),
        backgroundColor: Colors.black.withOpacity(0.8),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    
    // Recharge les stats et un nouveau prompt
    await _loadStats();
    _loadNewPrompt();
  }
  
  void _exportData() async {
    try {
      final zipPath = await _collectionService.prepareExport();
      
      // TODO: Démarrer serveur HTTP pour transfert
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Text(
              'prêt pour export',
              style: TextStyle(color: Colors.white70),
            ),
            content: Text(
              'fichier: $zipPath\n\nsur le même WiFi, ouvre \"http://[IP]:8080\" sur ton PC',
              style: TextStyle(color: Colors.white54),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ok', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('erreur: $e', style: const TextStyle(color: Colors.white70)),
          backgroundColor: Colors.redAccent.withOpacity(0.8),
        ),
      );
    }
  }
}
