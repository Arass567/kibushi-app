#!/bin/bash
# doc-check.sh - Vérifie que la documentation est à jour avec le code

echo "🦅 baby : Vérification de la documentation..."

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0

# 1. Vérifier que tous les fichiers services sont documentés dans API.md
echo "📋 Vérification API.md..."

for service_file in lib/services/*_service.dart; do
    service_name=$(basename "$service_file" .dart | sed 's/_service//')
    if ! grep -q "## ${service_name^}Service" API.md; then
        echo -e "${RED}❌ $service_name non documenté dans API.md${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done

# 2. Vérifier que les méthodes publiques sont documentées
echo "📋 Vérification méthodes publiques..."

# Extraire les méthodes publiques des services et vérifier leur présence dans API.md
for service_file in lib/services/*_service.dart; do
    service_name=$(basename "$service_file" .dart)
    
    # Trouver les méthodes publiques (Future<T> name( ou void name()
    grep -E "^\s*(Future<[^>]+>|void|bool|int|String)\s+\w+\(" "$service_file" | \
    grep -v "^\s*//" | \
    while read -r line; do
        method_name=$(echo "$line" | grep -oE "\w+\s*\(" | head -1 | tr -d '(')
        
        if [ -n "$method_name" ] && [ "$method_name" != "dispose" ]; then
            if ! grep -q "$method_name" API.md; then
                echo -e "${YELLOW}⚠️  $service_name::$method_name non documenté${NC}"
            fi
        fi
    done
done

# 3. Vérifier que le README mentionne toutes les fonctionnalités
echo "📋 Vérification README.md..."

if [ -f "lib/ui/tts_collection_screen.dart" ] && ! grep -q "TTS" README.md; then
    echo -e "${YELLOW}⚠️  Fonctionnalité TTS non mentionnée dans README${NC}"
fi

# 4. Vérifier que les dépendances pubspec.yaml sont dans README
echo "📋 Vérification dépendances..."

if [ -f "pubspec.yaml" ]; then
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]+([a-z_]+):[[:space:]]*[\^~]?[0-9] ]]; then
            pkg="${BASH_REMATCH[1]}"
            if [ -n "$pkg" ] && [ "$pkg" != "flutter" ] && [ "$pkg" != "sdk" ]; then
                if ! grep -q "$pkg" README.md; then
                    echo -e "${YELLOW}⚠️  Package '$pkg' non listé dans README${NC}"
                fi
            fi
        fi
    done < pubspec.yaml
fi

# 5. Vérifier la date de dernière mise à jour
echo "📋 Vérification fraîcheur..."

if [ -f "API.md" ]; then
    last_modified=$(stat -c %Y API.md 2>/dev/null || stat -f %m API.md 2>/dev/null)
    last_commit=$(git log -1 --format=%ct lib/services/ 2>/dev/null || echo "0")
    
    if [ "$last_commit" -gt "$last_modified" ]; then
        echo -e "${YELLOW}⚠️  API.md peut être obsolète (code modifié après la doc)${NC}"
    fi
fi

# Résultat
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ Documentation à jour !${NC}"
    exit 0
else
    echo -e "${RED}❌ $ERRORS problème(s) trouvé(s)${NC}"
    echo "💡 Lance 'dart doc' pour générer la doc API automatiquement"
    exit 1
fi
