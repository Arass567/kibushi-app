#!/bin/bash
# update-docs.sh - Met à jour la documentation après changements de code

echo "🦅 baby : Mise à jour de la documentation..."

cd ~/projects/kibushi || exit 1

# 1. Vérifier si des fichiers services ont changé
SERVICES_CHANGED=$(git diff --name-only HEAD~1 lib/services/ 2>/dev/null | wc -l)

if [ "$SERVICES_CHANGED" -gt 0 ]; then
    echo "📋 Services modifiés détectés"
    echo "   Pense à mettre à jour API.md avec les nouvelles méthodes"
fi

# 2. Vérifier si nouvelle dépendance
if git diff --name-only HEAD~1 pubspec.yaml | grep -q "pubspec.yaml"; then
    echo "📦 Dépendances modifiées"
    echo "   Pense à mettre à jour README.md avec les nouvelles deps"
fi

# 3. Vérifier si nouvel écran UI
if git diff --name-only HEAD~1 lib/ui/ | grep -q "lib/ui/"; then
    echo "🖼️  UI modifiée"
    echo "   Pense à mettre à jour README.md (features)"
fi

# 4. Lancer le check
./scripts/doc-check.sh

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Documentation obsolète détectée"
    echo "   Modifie les fichiers .md manuellement ou demande-moi de le faire"
    exit 1
fi

echo ""
echo "✅ Documentation à jour !"
