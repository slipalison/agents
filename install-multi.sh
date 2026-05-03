#!/usr/bin/env bash
# agents_for_cli — Multi-Target Installer (Linux / macOS)
# Targets: OpenCode | Claude Code | GitHub Copilot | Antigravity
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

# ── Menu ───────────────────────────────────────────────────────────────────────

show_menu() {
  echo ""
  echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║      agents_for_cli — Multi-Target Installer   ║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}"
  echo ""
  echo "  1) OpenCode       (~/.config/opencode/)"
  echo "  2) Claude Code    (~/.claude/agents/ + ~/.claude/skills/)"
  echo "  3) Copilot        (.github/copilot-instructions.md + .vscode/)"
  echo "  4) Antigravity    (~/.config/antigravity/)"
  echo "  5) Opencode CLI   (same as 1)"
  echo ""
  echo "  Selecione separando por vírgula ou digite 'all'"
  echo -n "  → "
  read -r RAW_SELECTION
}

parse_selection() {
  local raw="$1"
  if [[ "$raw" == "all" ]]; then echo "1 2 3 4"; return; fi
  local result=""
  IFS=',' read -ra parts <<< "$raw"
  for part in "${parts[@]}"; do
    local n; n=$(echo "$part" | tr -d ' ')
    [[ "$n" =~ ^[1-5]$ ]] && result="$result $n"
  done
  # 5 is alias for 1
  result=$(echo "$result" | sed 's/5/1/g')
  echo "${result# }" | tr ' ' '\n' | sort -u | tr '\n' ' '
}

# ── Frontmatter helpers ────────────────────────────────────────────────────────

# Extract a top-level scalar field from YAML frontmatter (between first ---)
fm_field() {
  local file="$1" field="$2"
  awk -v f="$field" '
    /^---$/ { n++; if (n == 2) exit; next }
    n == 1 && $0 ~ "^" f ":" {
      sub("^" f ":[[:space:]]*", "")
      gsub(/^"|"$/, "")
      print
      exit
    }
  ' "$file"
}

# Check if a tool is enabled (true) under the "tools:" section of frontmatter
fm_tool_enabled() {
  local file="$1" tool="$2"
  awk -v t="$tool" '
    /^---$/ { n++; if (n == 2) exit; next }
    n == 1 && /^tools:/ { in_tools = 1; next }
    n == 1 && in_tools && /^[^ \t]/ { in_tools = 0 }
    n == 1 && in_tools && $0 ~ ("^[[:space:]]+" t ": true") { print "yes"; exit }
  ' "$file"
}

# Extract body content — everything after the second ---
fm_body() {
  awk '/^---$/ { n++; if (n == 2) { found = 1; next } } found { print }' "$1"
}

# ── ADAPTER: OpenCode ──────────────────────────────────────────────────────────

install_opencode() {
  local dest="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
  echo ""
  echo -e "${BLUE}▶ OpenCode${NC} → $dest"

  if [[ -d "$dest" ]]; then
    local bak="$dest.backup.$(date +%Y%m%d-%H%M%S)"
    echo "  backup → $bak"
    cp -r "$dest" "$bak"
  fi

  mkdir -p "$dest/agent" "$dest/skills"
  cp "$SCRIPT_DIR/AGENTS.md"     "$dest/AGENTS.md"
  cp "$SCRIPT_DIR/opencode.json" "$dest/opencode.json"
  cp -r "$SCRIPT_DIR/agent/."    "$dest/agent/"
  cp -r "$SCRIPT_DIR/skills/."   "$dest/skills/"

  echo -e "  ${GREEN}✓ done${NC}"
  echo "  Próximo: opencode agent list"
}

# ── ADAPTER: Claude Code ───────────────────────────────────────────────────────

_claude_convert_agent() {
  local src="$1" dest_dir="$2" name="$3"

  local desc; desc=$(fm_field "$src" "description")
  local mode; mode=$(fm_field "$src" "mode")

  # Build YAML tools list from opencode boolean flags
  local tools="tools:"
  for t in read write edit grep glob bash; do
    [[ "$(fm_tool_enabled "$src" "$t")" == "yes" ]] && tools="${tools}"$'\n'"  - ${t}"
  done
  # Primary agents can spawn sub-agents
  if [[ "$mode" == "primary" ]]; then
    tools="${tools}"$'\n'"  - task"
    tools="${tools}"$'\n'"  - todowrite"
  fi

  # Write Claude Code format agent file
  {
    echo "---"
    echo "name: ${name}"
    echo "description: ${desc}"
    echo "model: claude-sonnet-4-6"
    echo "${tools}"
    echo "---"
    echo ""
    fm_body "$src"
  } > "${dest_dir}/${name}.md"
}

install_claude_code() {
  local base="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  local agents_dir="${base}/agents"
  local skills_dir="${base}/skills"

  echo ""
  echo -e "${BLUE}▶ Claude Code${NC} → ${base}"

  mkdir -p "${agents_dir}" "${skills_dir}"

  for f in "${SCRIPT_DIR}/agent/"*.md; do
    local name; name=$(basename "$f" .md)
    _claude_convert_agent "$f" "${agents_dir}" "${name}"
    echo "  agent: ${name}"
  done

  cp -r "${SCRIPT_DIR}/skills/." "${skills_dir}/"
  local skill_count; skill_count=$(find "${SCRIPT_DIR}/skills" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
  echo "  skills: ${skill_count} copiadas"

  # Append global rules to CLAUDE.md (create if missing)
  local claude_md="${base}/CLAUDE.md"
  # Guard: don't append twice
  if grep -q "BEGIN: agents_for_cli" "${claude_md}" 2>/dev/null; then
    echo "  CLAUDE.md: regras já presentes — ignorado"
  else
    {
      echo ""
      echo "<!-- BEGIN: agents_for_cli global rules -->"
      cat "${SCRIPT_DIR}/AGENTS.md"
      echo ""
      echo "<!-- END: agents_for_cli global rules -->"
    } >> "${claude_md}"
    echo "  CLAUDE.md: regras globais appended"
  fi

  echo -e "  ${GREEN}✓ done${NC}"
  echo "  Uso: em qualquer projeto, @tech-lead para orquestrar"
}

# ── ADAPTER: GitHub Copilot ───────────────────────────────────────────────────

install_copilot() {
  echo ""
  echo -e "${BLUE}▶ GitHub Copilot${NC}"
  local project_dir="${PWD}"
  echo -n "  Diretório do projeto [${PWD}]: "
  read -r input_dir
  [[ -n "$input_dir" ]] && project_dir="$input_dir"

  local gh_dir="${project_dir}/.github"
  local vscode_dir="${project_dir}/.vscode"
  mkdir -p "${gh_dir}" "${vscode_dir}"

  local out="${gh_dir}/copilot-instructions.md"

  {
    echo "# Custom Instructions for GitHub Copilot"
    echo ""
    echo "> Generated by agents_for_cli — $(date +%Y-%m-%d)"
    echo ""
    echo "---"
    echo ""
    cat "${SCRIPT_DIR}/AGENTS.md"
    echo ""
    echo "---"
    echo ""
    echo "## Agent Roles"
    echo ""
    for f in "${SCRIPT_DIR}/agent/"*.md; do
      local name; name=$(basename "$f" .md)
      local desc; desc=$(fm_field "$f" "description")
      echo "### @${name}"
      echo ""
      echo "> ${desc}"
      echo ""
      fm_body "$f"
      echo ""
      echo "---"
      echo ""
    done
  } > "${out}"

  local lines; lines=$(wc -l < "${out}" | tr -d ' ')
  echo "  .github/copilot-instructions.md: ${lines} linhas"

  local settings="${vscode_dir}/settings.json"
  if [[ -f "${settings}" ]]; then
    echo "  .vscode/settings.json: já existe — não sobrescrevi"
    echo '  Adicione: "github.copilot.chat.codeGeneration.useInstructionFiles": true'
  else
    cat > "${settings}" <<'SETTINGS'
{
  "github.copilot.chat.codeGeneration.useInstructionFiles": true,
  "github.copilot.chat.codeGeneration.instructions": [
    { "file": ".github/copilot-instructions.md" }
  ]
}
SETTINGS
    echo "  .vscode/settings.json: criado"
  fi

  echo -e "  ${GREEN}✓ done${NC}"
  echo "  Reinicie o VS Code para aplicar"
  echo -e "  ${YELLOW}⚠  Copilot CLI (gh copilot) não suporta agentes customizados${NC}"
}

# ── ADAPTER: Antigravity ───────────────────────────────────────────────────────

install_antigravity() {
  local dest="${ANTIGRAVITY_CONFIG_DIR:-$HOME/.config/antigravity}"
  echo ""
  echo -e "${BLUE}▶ Antigravity${NC} → ${dest}"
  echo -e "  ${YELLOW}⚠  Formato inferido — verifique a doc oficial do Antigravity${NC}"

  mkdir -p "${dest}/agents" "${dest}/skills"

  # Write agents.yaml manifest
  {
    echo "# agents_for_cli — Antigravity Config"
    echo "# Verifique o formato em: https://docs.antigravity.ai"
    echo "# Gerado em: $(date +%Y-%m-%d)"
    echo ""
    echo "global_instructions: AGENTS.md"
    echo ""
    echo "agents:"
    for f in "${SCRIPT_DIR}/agent/"*.md; do
      local name; name=$(basename "$f" .md)
      local desc; desc=$(fm_field "$f" "description")
      local mode; mode=$(fm_field "$f" "mode")
      echo "  - name: ${name}"
      echo "    description: \"${desc}\""
      echo "    role: ${mode}"
      echo "    instructions: agents/${name}.md"
    done
  } > "${dest}/agents.yaml"

  # Agent instruction files (body only — opencode frontmatter stripped)
  for f in "${SCRIPT_DIR}/agent/"*.md; do
    local name; name=$(basename "$f" .md)
    fm_body "$f" > "${dest}/agents/${name}.md"
    echo "  agent: ${name}"
  done

  cp -r "${SCRIPT_DIR}/skills/." "${dest}/skills/"
  cp "${SCRIPT_DIR}/AGENTS.md"   "${dest}/AGENTS.md"

  echo -e "  ${GREEN}✓ done${NC}"
  echo -e "  ${YELLOW}⚠  Revise ${dest}/agents.yaml e ajuste o schema se necessário${NC}"
}

# ── Dependencies: GSD + Caveman ───────────────────────────────────────────────

install_deps() {
  echo ""
  echo -n "  Instalar GSD + Caveman agora? [Y/n]: "
  read -r answer
  [[ "$answer" =~ ^[Nn] ]] && return

  if ! command -v npx &>/dev/null; then
    echo -e "  ${YELLOW}⚠  npx não encontrado — instale Node.js e rode manualmente:${NC}"
    echo "    npx get-shit-done-cc@latest"
    echo "    npx skills add JuliusBrussee/caveman"
    return
  fi

  echo ""
  echo -e "${BLUE}▶ GSD (Get Shit Done)${NC}"
  npx get-shit-done-cc@latest || echo -e "  ${YELLOW}⚠  GSD falhou — rode manualmente: npx get-shit-done-cc@latest${NC}"

  echo ""
  echo -e "${BLUE}▶ Caveman${NC}"
  npx skills add JuliusBrussee/caveman || echo -e "  ${YELLOW}⚠  Caveman falhou — rode manualmente: npx skills add JuliusBrussee/caveman${NC}"
}

# ── Main ───────────────────────────────────────────────────────────────────────

main() {
  show_menu

  local selected
  selected=$(parse_selection "${RAW_SELECTION}")

  if [[ -z "${selected// /}" ]]; then
    echo -e "${RED}Nenhuma seleção válida. Saindo.${NC}"
    exit 1
  fi

  echo ""
  echo "Instalando para: [${selected}]"

  for num in ${selected}; do
    case "${num}" in
      1) install_opencode ;;
      2) install_claude_code ;;
      3) install_copilot ;;
      4) install_antigravity ;;
    esac
  done

  echo ""
  echo -e "${GREEN}╔════════════════════════════════╗${NC}"
  echo -e "${GREEN}║   Instalação concluída ✓       ║${NC}"
  echo -e "${GREEN}╚════════════════════════════════╝${NC}"

  install_deps
}

main
