# Architecture Technique - Kibushi App

## Vue d'ensemble

L'application suit une architecture **Clean Architecture** simplifiée avec séparation claire des responsabilités.

```
┌─────────────────────────────────────┐
│           UI Layer                  │
│  ┌─────────┐    ┌─────────────────┐ │
│  │ Main    │    │ TTS Collection  │ │
│  │ Screen  │    │ Screen          │ │
│  └────┬────┘    └────────┬────────┘ │
└───────┼──────────────────┼──────────┘
        │                  │
        ▼                  ▼
┌─────────────────────────────────────┐
│         Service Layer               │
│  ┌─────────┐ ┌─────────┐ ┌────────┐│
│  │Recorder │ │Playback │ │ Mirror ││
│  │Service  │ │Service  │ │Service ││
│  └─────────┘ └─────────┘ └────────┘│
│  ┌─────────┐ ┌─────────┐ ┌────────┐│
│  │ Dataset │ │TTS Coll.│ │ Memory ││
│  │Service  │ │Service  │ │Service ││
│  └─────────┘ └─────────┘ └────────┘│
└─────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────┐
│         Core Layer                  │
│  ┌─────────────────────────────┐   │
│  │      KibushiState           │   │
│  │   (Provider Pattern)        │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

## Couches Détaillées

### 1. UI Layer (`lib/ui/`)

**Responsabilité** : Affichage et interaction utilisateur

#### MainScreen
- **StatefulWidget** avec gestion des streams
- **Subscribers** :
  - `RecorderService.stateStream` → Mise à jour bouton
  - `RecorderService.amplitudeStream` → Visualisation audio
  - `RecorderService.errorStream` → SnackBar erreurs
- **Animations** : Fade-in text, bouton pulsant

#### TTSCollectionScreen
- **Gestion complète** : Enregistrement, lecture, stats
- **Streams utilisés** :
  - `RecorderService` : État + amplitude
  - `PlaybackService` : État + completion
- **Features** : Pause long-press, playback dernier enregistrement

### 2. Service Layer (`lib/services/`)

#### RecorderService
```dart
class RecorderService {
  // Streams publics
  Stream<RecorderState> get stateStream;
  Stream<double> get amplitudeStream;
  Stream<AudioError?> get errorStream;
  
  // Méthodes
  Future<bool> checkPermission();
  Future<String?> startRecording();
  Future<String?> stopRecording();
  Future<void> pauseRecording();
  Future<void> resumeRecording();
}
```

**Pattern** : StreamController.broadcast() pour multi-subscribers

#### PlaybackService
```dart
class PlaybackService {
  // Streams
  Stream<PlayerState> get stateStream;
  Stream<Duration> get positionStream;
  Stream<void> get completionStream;
  
  // Features
  Future<bool> playWithFadeIn(String path, {Duration fadeDuration});
  Future<void> stopWithFadeOut({Duration fadeDuration});
}
```

#### MirrorService
- **Logique** : Analyse durée + sélection type miroir
- **Fade** : In/out avec courbe ease-out
- **Probabiliste** : 70% de répéter le mirror

### 3. Core Layer (`lib/core/`)

#### KibushiState (Provider)
```dart
class KibushiState extends ChangeNotifier {
  // États
  AppState _currentState;  // firstLaunch, recording, reflecting, etc.
  String? _lastMirrorType;
  bool _hasDatasetConsent;
  
  // Actions
  void startVoiceCapture();
  void stopVoiceCapture();
  void giveDatasetConsent();
}
```

**Pattern** : ChangeNotifier + Consumer/Provider

## Gestion des Streams

### Diagramme de Flux

```
Utilisateur appuie bouton
         │
         ▼
┌─────────────────┐
│  GestureDetector │
│   onTapDown     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ RecorderService │
│ startRecording()│
└────────┬────────┘
         │
         ├──► StreamController<RecorderState>
         │         │
         │         ├──► MainScreen (update UI)
         │         └──► TTSCollectionScreen (update UI)
         │
         └──► Timer (amplitude monitoring)
                  │
                  └──► StreamController<double>
                            │
                            └──► AmplitudeVisualizer (bars animation)
```

### Gestion du Cycle de Vie

```dart
class _MainScreenState extends State<MainScreen> {
  StreamSubscription? _stateSub;
  StreamSubscription? _amplitudeSub;
  
  @override
  void initState() {
    super.initState();
    _stateSub = service.stateStream.listen(...);
    _amplitudeSub = service.amplitudeStream.listen(...);
  }
  
  @override
  void dispose() {
    _stateSub?.cancel();
    _amplitudeSub?.cancel();
    service.dispose();  // Ferme les StreamControllers
    super.dispose();
  }
}
```

## Optimisations

### 1. Performance

#### Throttling des Updates
```dart
// Évite de surcharger le build()
Stream<T> throttleStream<T>(Stream<T> stream, Duration duration) {
  // Limite à 1 update / 50ms
}
```

#### Isolate Processing
```dart
// Traitement audio sans bloquer l'UI
Future<Uint8List?> processInIsolate(Uint8List data, processor) {
  return compute(_isolateProcessor, data);
}
```

### 2. Mémoire

#### Cache Management
```dart
class AudioOptimizer {
  static final Map<String, Uint8List> _audioCache = {};
  static void manageCacheSize(int maxSize);
}
```

#### Dispose Pattern
```dart
class LifecycleManager {
  final List<VoidCallback> _disposeCallbacks = [];
  void register(VoidCallback disposeCallback);
  void dispose();  // Appelle tous les callbacks en sens inverse
}
```

## Patterns Utilisés

### 1. Repository Pattern
Les Services agissent comme repositories pour les fonctionnalités audio.

### 2. Observer Pattern
Streams pour la communication asynchrone entre services et UI.

### 3. State Pattern
`AppState` enum pour gérer les transitions d'état de l'application.

### 4. Singleton Pattern
Services instanciés une fois et partagés (via Provider ou injection).

## Flux de Données Audio

```
Microphone
    │
    ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   Record     │───►│  Fichier WAV │───►│  Mirror/     │
│   Package    │    │  (temp)      │    │  Playback    │
└──────────────┘    └──────────────┘    └──────────────┘
                                               │
                                               ▼
                                        ┌──────────────┐
                                        │ TTSCollection│
                                        │   Dataset    │
                                        └──────────────┘
```

## Sécurité & Permissions

### Android
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
```

### iOS
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Enregistrement vocal pour miroir et dataset</string>
```

### Gestion Runtime
```dart
Future<bool> checkPermission() async {
  if (!await _recorder.hasPermission()) {
    _errorController.add(AudioError.noPermission);
    return false;
  }
  return true;
}
```

## Tests

### Unit Tests
```dart
test('RecorderService transitions', () {
  final service = RecorderService();
  expect(service.currentState, RecorderState.idle);
  
  service.startRecording();
  expect(service.currentState, RecorderState.recording);
});
```

### Widget Tests
```dart
testWidgets('MicroButton shows recording state', (tester) async {
  await tester.pumpWidget(...);
  await tester.tap(find.byType(GestureDetector));
  await tester.pump();
  
  expect(find.byIcon(PhosphorIconsRegular.stop), findsOneWidget);
});
```

## Future Improvements

1. **BLoC Pattern** : Migration depuis Provider pour plus de scalabilité
2. **Dependency Injection** : Utilisation de `get_it` ou `injectable`
3. **Freezed** : Génération de classes immuables pour les états
4. **Drift** : Base de données locale si besoin de persistence complexe
