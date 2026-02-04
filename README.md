# Kibushi App

Application mobile Flutter pour la préservation et l'apprentissage de la langue **Kibushi** (Mayotte, Comores).

## 🎯 Objectif

Créer une expérience d'apprentissage linguistique minimaliste et immersive, sans "AI slop" (design générique d'IA).

## ✨ Fonctionnalités

### Core
- **Mirror Vocal** : Répétition audio avec 3 types de miroirs
  - Type A (Syllabe) : 300-600ms, répétition simple
  - Type B (Mot) : 700-1200ms, écho avec fade
  - Type C (Intonation) : 250-400ms, capture du souffle
  
- **Collection TTS** : Enregistrement structuré pour entraînement de modèles vocaux
  - 4 catégories : phrases, syllabes, dictionnaire, intonations
  - Export des données
  - Gestion des consentements

### UX
- Interface ultra-minimaliste (single button)
- Dark theme (#0A0A0A)
- Phosphor Icons (non-conventionnels)
- Haptic feedback (vibrations contextuelles)
- Visualisation audio temps réel (barres d'amplitude)

## 🏗️ Architecture

```
lib/
├── core/
│   └── kibushi_state.dart          # State management (Provider)
├── services/
│   ├── recorder_service.dart       # Enregistrement avec streams
│   ├── playback_service.dart       # Lecture audio avec fade
│   ├── mirror_service.dart         # Logique miroir vocal
│   ├── dataset_service.dart        # Gestion dataset éthique
│   ├── dictionary_service.dart     # Dictionnaire Kibushi (484 mots)
│   ├── tts_collection_service.dart # Collection TTS structurée
│   ├── memory_service.dart         # Cache mémoire
│   └── audio_optimizer.dart        # Optimisations performance
├── ui/
│   ├── main_screen.dart            # Écran principal (mirror)
│   └── tts_collection_screen.dart  # Écran collection dataset
└── main.dart
```

## 🚀 Démarrage

### Prérequis
- Flutter SDK 3.6.0+
- Android SDK 35
- JDK 21

### Installation

```bash
# Cloner le repo
git clone https://github.com/Arass567/kibushi-app.git
cd kibushi-app

# Installer les dépendances
flutter pub get

# Lancer en debug
flutter run

# Compiler APK release
flutter build apk --release
```

## 📝 Spécifications Techniques

### Audio
- **Format** : WAV 16kHz mono
- **Package** : `record` (enregistrement), `audioplayers` (lecture)
- **Permissions** : Microphone (Android/iOS)

### State Management
- **Provider** pour l'état global
- **Streams** pour les mises à jour temps réel
  - `RecorderState` : idle, recording, paused, error
  - `PlayerState` : idle, loading, playing, paused, completed, error

### Performance
- Isolate processing pour tâches CPU-intensive
- Throttling des updates UI (50ms)
- Cache mémoire avec gestion de taille
- Dispose pattern pour éviter les memory leaks

## 🧪 Tests

```bash
# Tests unitaires
flutter test

# Tests d'intégration
flutter test integration_test/
```

## 📦 Dépendances Principales

```yaml
dependencies:
  flutter:
    sdk: flutter
  record: ^5.0.0           # Enregistrement audio
  audioplayers: ^5.0.0     # Lecture audio
  phosphor_flutter: ^2.0.0 # Icons non-conventionnels
  vibration: ^1.8.0        # Haptic feedback
  provider: ^6.1.0         # State management
  path_provider: ^2.1.0    # Chemins fichiers
  archive: ^3.4.0          # Export ZIP
```

## 🗂️ Structure des Données

### Dataset TTS
```
~/kibushi-dataset/
├── voyelles/          # 5 échantillons (A, E, I, O, U)
├── syllabes/          # 45 échantillons (KA-KU, MA-MU, etc.)
├── mots/              # 51 mots du dictionnaire
├── metadata/          # JSON avec timestamps, catégories
└── consent/           # Formulaires de consentement
```

### Dictionnaire Kibushi
- 484 entrées au format JSON
- Champs : `shikomor`, `français`, `catégorie`

## 🤝 Contribution

### Convention de Code
- **Style** : Dart standard (flutter format)
- **Naming** : camelCase pour variables/fonctions, PascalCase pour classes
- **Comments** : Documentation des public APIs

### Workflow
1. Créer une branche : `git checkout -b feature/nom-feature`
2. Commiter : `git commit -m "feat: description"`
3. Pusher : `git push origin feature/nom-feature`
4. Pull Request vers `master`

### Types de Commit
- `feat:` Nouvelle fonctionnalité
- `fix:` Correction de bug
- `docs:` Documentation
- `refactor:` Refactoring
- `perf:` Performance
- `test:` Tests

## 🦅 Contact

**Projet** : Opération Phénix  
**Agent** : baby (OpenClaw)  
**Human** : Assan RAFFION

## 📄 Licence

Propriétaire - Tous droits réservés
