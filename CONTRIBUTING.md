# Contributing Guide - Kibushi App

## 🎯 Objectif

Maintenir une documentation **toujours à jour** et **synchronisée** avec le code.

## 📝 Règles de Documentation

### 1. Modifier la doc en même temps que le code

**❌ Ne pas faire :**
```bash
git add lib/services/new_feature.dart
git commit -m "Add new feature"
# Documentation mise à jour... jamais
```

**✅ À la place :**
```bash
git add lib/services/new_feature.dart
# Modifier API.md pour documenter la nouvelle méthode
git add API.md
git commit -m "Add new feature + update API docs"
```

### 2. Structure des Commits

Format : `type(scope): description`

**Types :**
- `feat:` Nouvelle fonctionnalité
- `fix:` Correction de bug
- `docs:` Modification documentation
- `refactor:` Refactoring
- `perf:` Performance
- `test:` Tests

**Exemples :**
```
feat(recorder): add pause/resume functionality
docs(api): document RecorderService.pauseRecording()
refactor(mirror): extract fade logic to helper method
```

### 3. Checklist Avant Commit

- [ ] Code testé sur device
- [ ] API.md mis à jour si nouveau service/méthode
- [ ] README.md mis à jour si nouvelle feature visible
- [ ] ARCHITECTURE.md mis à jour si changement structure
- [ ] `scripts/doc-check.sh` passe sans erreur

### 4. Documentation Auto-Générée

**Dart Doc :**
```bash
# Générer la documentation API
dart doc

# Ouvrir dans navigateur
open doc/api/index.html
```

**Versioning :**
Chaque release majeure doit avoir :
- Tag git : `git tag -a v1.0.0 -m "Version 1.0.0"`
- CHANGELOG.md mis à jour
- README.md avec version à jour

## 🔄 Workflow de Mise à Jour

### Quand modifier quelle doc ?

| Changement | Fichier à modifier |
|------------|-------------------|
| Nouveau service | API.md + ARCHITECTURE.md |
| Nouvelle méthode publique | API.md |
| Changement signature | API.md |
| Nouvelle dépendance | README.md + pubspec.yaml |
| Changement UI | README.md (features) |
| Refactoring architecture | ARCHITECTURE.md |
| Bug fix important | CHANGELOG.md |

### Script de Vérification

```bash
# Vérifier que tout est documenté
./scripts/doc-check.sh

# Si erreurs, corriger puis re-vérifier
./scripts/doc-check.sh
```

## 📊 Standards de Documentation

### Commentaires de Code

**Format DartDoc :**
```dart
/// Démarrage de l'enregistrement audio.
/// 
/// Retourne le chemin du fichier ou null si échec.
/// 
/// Exemple :
/// ```dart
/// final path = await recorder.startRecording();
/// if (path != null) print('Enregistrement : $path');
/// ```
Future<String?> startRecording() async {
  // ...
}
```

### Documentation Markdown

**Structure API.md :**
```markdown
## NomDuService

### Description
Brève description du service.

### Énumérations
Liste des enums utilisées.

### Streams
Tableau des streams publics.

### Méthodes
#### `nomMethode(params)`
Description détaillée.

**Paramètres :**
- `param1` : description

**Retour :** type et description

**Exemple :**
```dart
// code exemple
```
```

## 🚀 Release Process

### 1. Préparation
```bash
# Mettre à jour CHANGELOG.md
# Mettre à jour version dans pubspec.yaml
# Vérifier docs
./scripts/doc-check.sh
```

### 2. Commit
```bash
git add .
git commit -m "chore(release): prepare v1.1.0"
git tag -a v1.1.0 -m "Version 1.1.0"
git push origin master --tags
```

### 3. Post-Release
- [ ] Créer release GitHub avec notes
- [ ] Attacher APK/Ipa
- [ ] Mettre à jour README avec nouvelle version

## 🧪 Tests et Documentation

### Tests Unitaires
```bash
flutter test
```

### Tests d'Intégration
```bash
flutter test integration_test/
```

### Couverture
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

## 🆘 Besoin d'Aide ?

- **baby** (OpenClaw) : Vérification automatique via cron
- **Issues GitHub** : Signaler un bug ou demande de feature
- **Context7** : Documentation Flutter à jour

## 📈 Checklist Projet Sain

- [ ] README.md à jour
- [ ] API.md couvre tous les services
- [ ] ARCHITECTURE.md reflète le code actuel
- [ ] CHANGELOG.md tenu à jour
- [ ] Tests passent
- [ ] `doc-check.sh` passe
- [ ] Pas de warnings `flutter analyze`

---

**Rappel :** Une feature non documentée n'existe pas.
