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
echo "Não esqueça de instalar GSD e Caveman se ainda não fez:"
echo "  npx get-shit-done-cc --opencode --global --minimal"
echo "  npx skills add JuliusBrussee/caveman -a opencode"
