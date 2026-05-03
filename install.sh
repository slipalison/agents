#!/usr/bin/env bash
set -euo pipefail

# OpenCode Stack - Setup Script (Linux/macOS)

DEST="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Instalando OpenCode Stack em: $DEST"

# Backup se já existir
if [[ -d "$DEST" ]]; then
  BACKUP="$DEST.backup.$(date +%Y%m%d-%H%M%S)"
  echo "==> Diretório existente encontrado. Criando backup em: $BACKUP"
  cp -r "$DEST" "$BACKUP"
fi

# Cria estrutura
mkdir -p "$DEST/agent" "$DEST/skills"

# Copia config files
cp "$SCRIPT_DIR/AGENTS.md" "$DEST/AGENTS.md"
cp "$SCRIPT_DIR/opencode.json" "$DEST/opencode.json"

# Copia agentes
cp -r "$SCRIPT_DIR/agent/." "$DEST/agent/"

# Copia skills
cp -r "$SCRIPT_DIR/skills/." "$DEST/skills/"

echo ""
echo "==> Instalação concluída!"
echo ""
echo "Próximos passos:"
echo "  1. Verifique os agentes:    opencode agent list"
echo "  2. Inicie uma sessão:       cd ~/seu-projeto && opencode"
echo "  3. Use Tab até o agente primário ser 'tech-lead'"
echo ""

# Detecta se GSD e Caveman já estão instalados
GSD_INSTALLED=false
CAVEMAN_INSTALLED=false

if ls "$DEST/skills/" 2>/dev/null | grep -q "^gsd"; then
  GSD_INSTALLED=true
fi
if [[ -d "$DEST/skills/caveman" ]]; then
  CAVEMAN_INSTALLED=true
fi

if $GSD_INSTALLED && $CAVEMAN_INSTALLED; then
  echo "==> GSD e Caveman já instalados — pulando."
else
  if ! command -v npx &>/dev/null; then
    echo "⚠  npx não encontrado — instale Node.js e rode manualmente:"
    $GSD_INSTALLED     || echo "  npx get-shit-done-cc@latest"
    $CAVEMAN_INSTALLED || echo "  npx skills add JuliusBrussee/caveman"
  else
    PROMPT="Instalar"
    $GSD_INSTALLED     || PROMPT="$PROMPT GSD"
    $CAVEMAN_INSTALLED || { $GSD_INSTALLED && PROMPT="$PROMPT +"; PROMPT="$PROMPT Caveman"; }
    echo -n "$PROMPT agora? [Y/n]: "
    read -r answer
    if [[ ! "$answer" =~ ^[Nn] ]]; then
      if ! $GSD_INSTALLED; then
        echo ""
        echo "==> GSD (Get Shit Done)"
        npx get-shit-done-cc@latest || echo "⚠  GSD falhou — rode manualmente: npx get-shit-done-cc@latest"
      fi
      if ! $CAVEMAN_INSTALLED; then
        echo ""
        echo "==> Caveman"
        npx skills add JuliusBrussee/caveman || echo "⚠  Caveman falhou — rode manualmente: npx skills add JuliusBrussee/caveman"
      fi
    fi
  fi
fi
