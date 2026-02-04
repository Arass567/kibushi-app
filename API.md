# API Reference - Kibushi Services

## RecorderService

Service d'enregistrement audio avec gestion des streams temps réel.

### Énumérations

```dart
enum RecorderState { idle, recording, paused, error }

enum AudioError { 
  noPermission,      // Permission microphone refusée
  recordingFailed,   // Échec démarrage enregistrement
  fileSystemError,   // Erreur accès fichier
  unknown            // Erreur inconnue
}
```

### Streams Publics

| Stream | Type | Description |
|--------|------|-------------|
| `stateStream` | `Stream<RecorderState>` | État actuel du recorder |
| `amplitudeStream` | `Stream<double>` | Amplitude normalisée (0.0 - 1.0) |
| `errorStream` | `Stream<AudioError?>` | Erreurs éventuelles |

### Méthodes

#### `checkPermission()`
```dart
Future<bool> checkPermission()
```
Vérifie si l'application a la permission d'accéder au microphone.

**Retour** : `true` si permission accordée, `false` sinon.

**Émet** : `AudioError.noPermission` sur `errorStream` si refusée.

---

#### `requestPermission()`
```dart
Future<bool> requestPermission()
```
Demande la permission microphone (iOS/Android la demande automatiquement au premier `startRecording`).

---

#### `startRecording()`
```dart
Future<String?> startRecording()
```
Démarre l'enregistrement audio.

**Configuration** :
- Format : WAV
- Sample rate : 16kHz
- Canaux : 1 (mono)
- Chemin : Fichier temporaire avec timestamp

**Retour** : Chemin du fichier ou `null` si échec.

**Émet** :
- `RecorderState.recording` sur `stateStream`
- Amplitude toutes les 50ms sur `amplitudeStream`

**Erreurs possibles** :
- `AudioError.noPermission`
- `AudioError.recordingFailed`
- `AudioError.fileSystemError`

---

#### `stopRecording()`
```dart
Future<String?> stopRecording()
```
Arrête l'enregistrement et retourne le chemin du fichier.

**Retour** : Chemin du fichier WAV ou `null`.

**Émet** : `RecorderState.idle` sur `stateStream`.

---

#### `pauseRecording()`
```dart
Future<void> pauseRecording()
```
Met l'enregistrement en pause (appel entrant, etc.).

**Émet** : `RecorderState.paused` sur `stateStream`.

---

#### `resumeRecording()`
```dart
Future<void> resumeRecording()
```
Reprend l'enregistrement après une pause.

**Émet** : `RecorderState.recording` sur `stateStream`.

---

#### `dispose()`
```dart
void dispose()
```
Libère les ressources (à appeler dans `dispose()` du widget).

**Ferme** : Tous les StreamControllers et le recorder natif.

---

## PlaybackService

Service de lecture audio avec fade in/out et gestion des streams.

### Énumérations

```dart
enum PlayerState { idle, loading, playing, paused, completed, error }

enum PlayerError { 
  loadFailed,     // Impossible de charger le fichier
  playbackFailed, // Erreur pendant la lecture
  networkError,   // Erreur réseau (si streaming)
  unknown
}
```

### Streams Publics

| Stream | Type | Description |
|--------|------|-------------|
| `stateStream` | `Stream<PlayerState>` | État du lecteur |
| `positionStream` | `Stream<Duration>` | Position actuelle |
| `durationStream` | `Stream<Duration?>` | Durée totale |
| `completionStream` | `Stream<void>` | Fin de lecture |
| `errorStream` | `Stream<PlayerError?>` | Erreurs |

### Méthodes

#### `playLocalFile(path)`
```dart
Future<bool> playLocalFile(String path)
```
Lecture d'un fichier local.

**Paramètres** :
- `path` : Chemin absolu du fichier

**Retour** : `true` si succès, `false` sinon.

**Émet** : `PlayerState.loading` puis `PlayerState.playing`.

---

#### `playWithFadeIn(path, fadeDuration)`
```dart
Future<bool> playWithFadeIn(
  String path, 
  {Duration fadeDuration = const Duration(milliseconds: 300)}
)
```
Lecture avec fade-in progressif.

**Paramètres** :
- `path` : Chemin du fichier
- `fadeDuration` : Durée du fade (défaut: 300ms)

---

#### `stopWithFadeOut(fadeDuration)`
```dart
Future<void> stopWithFadeOut(
  {Duration fadeDuration = const Duration(milliseconds: 300)}
)
```
Arrêt avec fade-out.

---

#### `pause()` / `resume()` / `stop()`
```dart
Future<void> pause()
Future<void> resume()
Future<void> stop()
```
Contrôles de base de la lecture.

---

#### `seek(position)`
```dart
Future<void> seek(Duration position)
```
Seek à une position spécifique.

---

#### `setVolume(volume)`
```dart
Future<void> setVolume(double volume)
```
Change le volume (0.0 à 1.0).

---

#### `dispose()`
```dart
void dispose()
```
Libère les ressources.

---

## MirrorService

Service de réflexion vocale (echo/mirror).

### Types de Mirror

```dart
enum MirrorType { syllable, word, intonation }
```

| Type | Durée | Description |
|------|-------|-------------|
| `syllable` | 300-600ms | Répétition simple de syllabe |
| `word` | 700-1200ms | Écho avec fade in/out |
| `intonation` | 250-400ms | Capture du souffle/intonation |

### Méthodes

#### `playMirror(audioPath, type)`
```dart
Future<void> playMirror(String audioPath, MirrorType type)
```
Joue le mirror vocal selon le type.

---

#### `shouldMirror()`
```dart
bool shouldMirror()
```
Détermine si on doit jouer le mirror (probabilité 70%).

**Retour** : `true` 70% du temps.

---

## TTSCollectionService

Service de collection de données pour entraînement TTS.

### Catégories

```dart
Map<String, CategoryConfig> categories = {
  'phrases': CategoryConfig(label: 'phrases', targetCount: 50),
  'syllabes': CategoryConfig(label: 'syllabes', targetCount: 100),
  'dictionary': CategoryConfig(label: 'mots', targetCount: 200),
  'intonations': CategoryConfig(label: 'souffles', targetCount: 30),
};
```

### Méthodes

#### `init()`
```dart
Future<void> init()
```
Initialise le service et charge les stats existantes.

---

#### `getRandomPrompt(category)`
```dart
String? getRandomPrompt(String category)
```
Retourne un prompt aléatoire pour la catégorie.

---

#### `saveRecording(category, prompt, audioPath)`
```dart
Future<void> saveRecording({
  required String category,
  required String prompt,
  required String audioPath,
})
```
Sauvegarde un enregistrement avec métadonnées.

**Crée** :
- Copie du fichier dans `~/kibushi-dataset/{category}/`
- Entrée JSON dans `metadata/`

---

#### `getStats()`
```dart
Future<Map<String, CategoryStats>> getStats()
```
Retourne les statistiques de collecte.

```dart
class CategoryStats {
  final int currentCount;      // Nombre d'enregistrements
  final int targetCount;       // Objectif
  final double totalMinutes;   // Durée totale audio
  double get progressPercent;  // % de complétion
}
```

---

#### `prepareExport()`
```dart
Future<String> prepareExport()
```
Prépare un fichier ZIP pour export.

**Retour** : Chemin du fichier ZIP.

---

## AudioOptimizer

Utilitaires d'optimisation audio et mémoire.

### Méthodes Statiques

#### `processInIsolate(data, processor)`
```dart
static Future<Uint8List?> processInIsolate(
  Uint8List audioData,
  Future<Uint8List> Function(Uint8List) processor,
)
```
Traite l'audio dans un isolate (pas de blocage UI).

---

#### `throttleStream(stream, duration)`
```dart
static Stream<T> throttleStream<T>(Stream<T> stream, Duration duration)
```
Limite la fréquence des events d'un stream.

---

#### `preloadAudio(assetPath)`
```dart
static Future<void> preloadAudio(String assetPath)
```
Précharge un asset audio en mémoire.

---

#### `clearCache()` / `manageCacheSize(maxSize)`
```dart
static void clearCache()
static void manageCacheSize(int maxSize)
```
Gestion du cache mémoire audio.

---

## KibushiState (Provider)

Gestion d'état global de l'application.

### États

```dart
enum AppState {
  firstLaunch,     // Premier lancement
  idle,           // En attente
  recording,      // Enregistrement en cours
  reflecting,     // Phase réflexion (mirror pending)
  mirrorPlayback, // Lecture du mirror
  consentPrompt,  // Demande de consentement dataset
}
```

### Propriétés

| Propriété | Type | Description |
|-----------|------|-------------|
| `currentState` | `AppState` | État actuel |
| `lastMirrorType` | `String?` | Type du dernier mirror joué |
| `hasDatasetConsent` | `bool` | Consentement dataset accordé |

### Méthodes

#### `startVoiceCapture()` / `stopVoiceCapture()`
Démarre/arrête la capture vocale (met à jour l'état).

#### `giveDatasetConsent()` / `declineDatasetConsent()`
Gestion du consentement pour la collecte de données.

---

## Exemples d'Utilisation

### Enregistrement avec Visualisation

```dart
class _MyScreenState extends State<MyScreen> {
  final _recorder = RecorderService();
  double _amplitude = 0.0;
  
  @override
  void initState() {
    super.initState();
    _recorder.amplitudeStream.listen((amp) {
      setState(() => _amplitude = amp);
    });
  }
  
  void _onRecord() async {
    if (await _recorder.checkPermission()) {
      await _recorder.startRecording();
    }
  }
  
  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }
}
```

### Lecture avec Fade

```dart
final _player = PlaybackService();

await _player.playWithFadeIn(
  '/path/to/audio.wav',
  fadeDuration: Duration(milliseconds: 500),
);
```

### Collecte TTS

```dart
final _collection = TTSCollectionService();
await _collection.init();

final prompt = _collection.getRandomPrompt('syllabes');
// ... enregistrement audio ...

await _collection.saveRecording(
  category: 'syllabes',
  prompt: prompt!,
  audioPath: recordedPath,
);

final stats = await _collection.getStats();
print('Progress: ${stats['syllabes']?.progressPercent}%');
```
