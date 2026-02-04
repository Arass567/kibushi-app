# Changelog - Kibushi App

Tous les changements notables de ce projet seront documentés ici.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et ce projet adhère à [Semantic Versioning](https://semver.org/lang/fr/).

## [Unreleased]

### Added
- Intégration Context7 MCP pour documentation Flutter à jour
- Script `doc-check.sh` pour vérification automatique de la documentation
- CONTRIBUTING.md avec guidelines de contribution

### Changed
- Optimisation des services audio avec streams temps réel
- Amélioration de l'UI avec visualisation amplitude

## [2.0.0] - 2026-02-04

### Added
- **Mirror Vocal Service** avec 3 types (syllabe, mot, intonation)
- **Dataset Collection** éthique pour TTS
- **TTS Collection Screen** avec statistiques temps réel
- **Streams temps réel** : amplitude, état recorder/player
- **Audio Optimizer** : isolates, cache, lifecycle management
- **Fade in/out** sur lecture audio
- **Visualisation amplitude** en temps réel (barres animées)
- **Documentation complète** : README, ARCHITECTURE, API

### Changed
- Refactor complet de RecorderService avec StreamControllers
- Refactor de PlaybackService avec gestion des streams
- UI mise à jour pour utiliser les nouveaux streams

### Fixed
- Gestion des permissions microphone
- Memory leaks avec dispose pattern
- Error handling sur toutes les opérations audio

## [1.0.0] - 2026-02-03

### Added
- Initialisation projet Flutter
- Écran principal avec bouton microphone
- Enregistrement audio basique (record package)
- Lecture audio (audioplayers package)
- Dictionnaire Kibushi (484 mots)
- Thème sombre minimaliste
- Phosphor Icons
- Haptic feedback

---

## Guide de Versionnement

### Semantic Versioning (SemVer)

**Format :** `MAJOR.MINOR.PATCH`

- **MAJOR** : Changements incompatibles (breaking changes)
- **MINOR** : Nouvelles fonctionnalités (compatibles)
- **PATCH** : Corrections de bugs

### Exemples

```
2.0.0  # Breaking change : nouvelle API RecorderService
1.1.0  # Nouvelle feature : mirror vocal
1.0.1  # Fix : correction bug permission microphone
```

### Catégories de Changelog

- **Added** : Nouvelles fonctionnalités
- **Changed** : Changements comportement existant
- **Deprecated** : Fonctionnalités obsolètes
- **Removed** : Fonctionnalités supprimées
- **Fixed** : Corrections de bugs
- **Security** : Corrections de sécurité

---

## Roadmap

### v2.1.0 (Prévu)
- [ ] Export dataset vers cloud (optionnel)
- [ ] Mode offline complet
- [ ] Statistiques d'apprentissage utilisateur

### v2.2.0 (Prévu)
- [ ] Reconnaissance vocale basique
- [ ] Comparateur prononciation
- [ ] Mode quiz (sans gamification)

### v3.0.0 (Vision)
- [ ] TTS Kibushi complet (modèle entraîné)
- [ ] Conversation basique
- [ ] Export vers d'autres apps
