import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import '../core/kibushi_state.dart';
import '../services/recorder_service.dart';
import '../services/playback_service.dart';
import '../services/tts_collection_service.dart';

/// Écran de collecte TTS structurée avec streams temps réel
class TTSCollectionScreen extends StatefulWidget {
  const TTSCollectionScreen({super.key});

  @override
  State<TTSCollectionScreen> createState() => _TTSCollectionScreenState();
}

class _TTSCollectionScreenState extends State<TTSCollectionScreen> {
  final TTSCollectionService _collectionService = TTSCollectionService();
  final RecorderService _recorderService = RecorderService();
  final PlaybackService _playbackService = PlaybackService();
  
  // Subscriptions
  StreamSubscription? _recorderStateSub;
  StreamSubscription? _amplitudeSub;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _playerCompletionSub;
  
  // États
  String _selectedCategory = 'phrases';
  Map<String, CategoryStats>? _stats;
  RecorderState _recorderState = RecorderState.idle;
  PlayerState _playerState = PlayerState.idle;
  String? _currentPrompt;
  double _currentAmplitude = 0.0;
  String? _lastRecordingPath;
  bool _isPlayingLast = false;
  
  @override
  void initState() {
    super.initState();
    _initServices();
    _initStreams();
  }
  
  void _initStreams() {
    // Recorder streams
    _recorderStateSub = _recorderService.stateStream.listen((state) {
      setState(() => _recorderState = state);
    });
    
    _amplitudeSub = _recorderService.amplitudeStream.listen((amp) {
      setState(() => _currentAmplitude = amp);
    });
    
    // Player streams
    _playerStateSub = _playbackService.stateStream.listen((state) {
      setState(() => _playerState = state);
    });
    
    _playerCompletionSub = _playbackService.completionStream.listen((_) {
      setState(() => _isPlayingLast = false);
    });
  }
  
  Future<void> _initServices() async {
    await _collectionService.init();
    await _loadStats();
    _loadNewPrompt();
  }
  
  Future<void> _loadStats() async {
    final stats = await _collectionService.getStats();
    setState(() => _stats = stats);
  }
  
  void _loadNewPrompt() {
    final prompt = _collectionService.getRandomPrompt(_selectedCategory);
    setState(() => _currentPrompt = prompt);
  }
  
  @override
  void dispose() {
    _recorderStateSub?.cancel();
    _amplitudeSub?.cancel();
    _playerStateSub?.cancel();
    _playerCompletionSub?.cancel();
    _recorderService.dispose();
    _playbackService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = _recorderState == RecorderState.recording;
    final isPaused = _recorderState == RecorderState.paused;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            // Stats
            if (_stats != null) _buildStatsRow(),
            
            const SizedBox(height: 30),
            
            // Visualisation amplitude (pendant enregistrement)
            if (isRecording || isPaused)
              _buildAmplitudeVisualizer(),
            
            const SizedBox(height: 20),
            
            // Prompt
            _buildPromptArea(),
            
            const Spacer(),
            
            // Bouton d'enregistrement avec état
            _buildRecordButton(),
            
            const SizedBox(height: 20),
            
            // Bouton lecture du dernier enregistrement
            if (_lastRecordingPath != null)
              _buildPlaybackButton(),
            
            const SizedBox(height: 20),
            
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
          // Indicateur état recorder
          _buildStatusIndicator(),
        ],
      ),
    );
  }
  
  Widget _buildStatusIndicator() {
    Color color;
    IconData icon;
    
    switch (_recorderState) {
      case RecorderState.recording:
        color = Colors.redAccent;
        icon = PhosphorIconsFill.record;
        break;
      case RecorderState.paused:
        color = Colors.orangeAccent;
        icon = PhosphorIconsFill.pause;
        break;
      case RecorderState.error:
        color = Colors.red;
        icon = PhosphorIconsFill.warning;
        break;
      default:
        color = Colors.white24;
        icon = PhosphorIconsRegular.circle;
    }
    
    return PhosphorIcon(
      icon,
      color: color,
      size: 20,
    );
  }
  
  Widget _buildAmplitudeVisualizer() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(15, (index) {
          final height = (_currentAmplitude * 30 * (0.5 + (index % 3) * 0.2)).clamp(4.0, 30.0);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 50),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 3,
            height: height,
            decoration: BoxDecoration(
              color: _recorderState == RecorderState.paused
                  ? Colors.orangeAccent.withOpacity(0.5)
                  : Colors.redAccent.withOpacity(0.3 + _currentAmplitude * 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
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
    final isRecording = _recorderState == RecorderState.recording;
    final isPaused = _recorderState == RecorderState.paused;
    
    return GestureDetector(
      onTapDown: (_) => _startRecording(),
      onTapUp: (_) => _stopRecording(),
      onTapCancel: () => _stopRecording(),
      onLongPress: isRecording ? () => _pauseRecording() : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: isRecording ? 160 : 120,
        height: isRecording ? 160 : 120,
        decoration: BoxDecoration(
          color: isRecording 
              ? Colors.redAccent.withOpacity(0.2) 
              : isPaused
                  ? Colors.orangeAccent.withOpacity(0.2)
                  : Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: isRecording 
                ? Colors.redAccent 
                : isPaused
                    ? Colors.orangeAccent
                    : Colors.white30,
            width: isRecording ? 3 : 2,
          ),
          boxShadow: isRecording
              ? [
                  BoxShadow(
                    color: Colors.redAccent.withOpacity(0.3),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ]
              : isPaused
                  ? [
                      BoxShadow(
                        color: Colors.orangeAccent.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ]
                  : null,
        ),
        child: PhosphorIcon(
          isRecording 
              ? PhosphorIconsRegular.stop 
              : isPaused
                  ? PhosphorIconsRegular.play
                  : PhosphorIconsRegular.microphone,
          size: isRecording ? 56 : 48,
          color: isRecording 
              ? Colors.redAccent 
              : isPaused
                  ? Colors.orangeAccent
                  : Colors.white70,
        ),
      ),
    );
  }
  
  Widget _buildPlaybackButton() {
    final isPlaying = _playerState == PlayerState.playing || _isPlayingLast;
    
    return TextButton.icon(
      onPressed: _playLastRecording,
      icon: PhosphorIcon(
        isPlaying ? PhosphorIconsRegular.stop : PhosphorIconsRegular.play,
        color: Colors.white54,
        size: 20,
      ),
      label: Text(
        isPlaying ? 'arrêter' : 'écouter',
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 13,
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
  
  Future<void> _startRecording() async {
    HapticFeedback.lightImpact();
    
    // Vérifie permission d'abord
    if (!await _recorderService.checkPermission()) {
      _showMessage('permission microphone requise', isError: true);
      return;
    }
    
    final path = await _recorderService.startRecording();
    if (path == null) {
      _showMessage('erreur démarrage', isError: true);
    }
  }
  
  Future<void> _stopRecording() async {
    if (_recorderState != RecorderState.recording && _recorderState != RecorderState.paused) return;
    
    HapticFeedback.mediumImpact();
    
    final path = await _recorderService.stopRecording();
    if (path != null) {
      _lastRecordingPath = path;
      
      // Sauvegarde dans le service de collection
      if (_currentPrompt != null) {
        await _collectionService.saveRecording(
          category: _selectedCategory,
          prompt: _currentPrompt!,
          audioPath: path,
        );
      }
      
      _showMessage('enregistré');
      await _loadStats();
      _loadNewPrompt();
    }
  }
  
  Future<void> _pauseRecording() async {
    if (_recorderState == RecorderState.recording) {
      await _recorderService.pauseRecording();
      _showMessage('pause');
    } else if (_recorderState == RecorderState.paused) {
      await _recorderService.resumeRecording();
    }
  }
  
  Future<void> _playLastRecording() async {
    if (_lastRecordingPath == null) return;
    
    if (_playerState == PlayerState.playing) {
      await _playbackService.stop();
      setState(() => _isPlayingLast = false);
    } else {
      setState(() => _isPlayingLast = true);
      await _playbackService.playLocalFile(_lastRecordingPath!);
    }
  }
  
  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        backgroundColor: isError 
            ? Colors.redAccent.withOpacity(0.8)
            : Colors.black.withOpacity(0.8),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
  
  Future<void> _exportData() async {
    try {
      final zipPath = await _collectionService.prepareExport();
      
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
              'fichier: $zipPath\n\nenvoie via Telegram à baby',
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
      _showMessage('erreur: $e', isError: true);
    }
  }
}
