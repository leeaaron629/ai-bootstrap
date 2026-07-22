#!/usr/bin/env bash
# install.sh — install ai-config skills, rules, and memories into Claude Code and/or Cursor
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(cat "$REPO_DIR/VERSION" 2>/dev/null || echo "unknown")"

# ── Defaults ──────────────────────────────────────────────────────────────────
HARNESS="both"       # claude | cursor | both
SCOPE="global"       # global | project
TYPE="all"           # skills | rules | memories | all
LINK=false           # symlink instead of copy
DRY_RUN=false
UNINSTALL=false
SKILL_FILTER=""      # install only this skill name (default: all)

# ── Argument parsing ───────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: ./install.sh [options]

Options:
  --harness  claude|cursor|both   Harness(es) to install into (default: both)
  --scope    global|project       Install globally or into current project (default: global)
  --type     skills|rules|memories|all  What to install (default: all)
  --skill    <name>               Install only this skill (default: all skills)
  --link                          Symlink from repo instead of copying (good for dev machines)
  --dry-run                       Print actions without making changes
  --uninstall                     Remove previously installed files
  -h, --help                      Show this help

Examples:
  ./install.sh                                  # install everything, both harnesses, global
  ./install.sh --harness claude --type skills   # skills only into Claude Code
  ./install.sh --link                           # symlink for live dev-machine sync
  ./install.sh --uninstall                      # remove all installed files
  ./install.sh --harness cursor --dry-run       # preview Cursor install
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --harness)  HARNESS="$2";      shift 2 ;;
    --scope)    SCOPE="$2";        shift 2 ;;
    --type)     TYPE="$2";         shift 2 ;;
    --skill)    SKILL_FILTER="$2"; shift 2 ;;
    --link)     LINK=true;         shift ;;
    --dry-run)  DRY_RUN=true;      shift ;;
    --uninstall) UNINSTALL=true;   shift ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# ── Path resolution ────────────────────────────────────────────────────────────
OS="$(uname -s)"
HOME_SLUG="$(echo "$HOME" | sed 's|/|-|g')"  # /Users/aaron → -Users-aaron

# Claude Code paths
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
CLAUDE_CLAUDE_MD="$HOME/.claude/CLAUDE.md"
CLAUDE_MEMORY_DIR="$HOME/.claude/projects/${HOME_SLUG}/memory"

# Cursor paths
# Commands (global slash commands): ~/.cursor/commands/
# Rules: global rules live in Cursor Settings > Rules (not file-based).
#        For file-based rules, --scope project uses .cursor/rules/ in CWD.
CURSOR_COMMANDS_DIR="$HOME/.cursor/commands"
if [[ "$SCOPE" == "project" ]]; then
  CURSOR_RULES_DIR="$(pwd)/.cursor/rules"
else
  # Cursor has no global file-based rules dir; warn and use project scope for rules.
  CURSOR_RULES_DIR="$(pwd)/.cursor/rules"
  if [[ "$HARNESS" == "cursor" || "$HARNESS" == "both" ]] && [[ "$TYPE" == "rules" || "$TYPE" == "all" ]]; then
    echo "⚠️  Note: Cursor has no global file-based rules directory."
    echo "   Rules will be installed into .cursor/rules/ in the current directory."
    echo "   For truly global rules, add them via Cursor Settings > Rules manually."
  fi
fi

DIST_DIR="$REPO_DIR/dist"

# ── Helpers ────────────────────────────────────────────────────────────────────
BEGIN_MARKER="<!-- BEGIN ai-config -->"
END_MARKER="<!-- END ai-config -->"

run() {
  if $DRY_RUN; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

copy_or_link() {
  local src="$1" dst="$2"
  if $LINK; then
    run ln -sf "$src" "$dst"
  else
    run cp -r "$src" "$dst"
  fi
}

remove_if_exists() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    run rm -rf "$path"
    echo "  removed: $path"
  fi
}

# ── Build Cursor dist artifacts ────────────────────────────────────────────────
build_if_needed() {
  if [[ "$HARNESS" == "cursor" || "$HARNESS" == "both" ]]; then
    if ! command -v python3 &>/dev/null; then
      echo "❌ python3 is required to build Cursor artifacts. Install Python 3 and retry."
      exit 1
    fi
    echo "→ Building Cursor artifacts..."
    $DRY_RUN || python3 "$REPO_DIR/scripts/build.py"
  fi
}

# ── Skills ─────────────────────────────────────────────────────────────────────
install_skills_claude() {
  echo "→ Installing skills into Claude Code..."
  run mkdir -p "$CLAUDE_SKILLS_DIR"
  for skill_dir in "$REPO_DIR/skills"/*/; do
    name="$(basename "$skill_dir")"
    [[ -n "$SKILL_FILTER" && "$name" != "$SKILL_FILTER" ]] && continue
    dst="$CLAUDE_SKILLS_DIR/$name"
    run rm -rf "$dst"
    copy_or_link "$skill_dir" "$dst"
    echo "  ✓ $name → $dst"
  done
}

uninstall_skills_claude() {
  echo "→ Uninstalling skills from Claude Code..."
  for skill_dir in "$REPO_DIR/skills"/*/; do
    name="$(basename "$skill_dir")"
    [[ -n "$SKILL_FILTER" && "$name" != "$SKILL_FILTER" ]] && continue
    remove_if_exists "$CLAUDE_SKILLS_DIR/$name"
  done
}

install_skills_cursor() {
  echo "→ Installing skills into Cursor commands..."
  run mkdir -p "$CURSOR_COMMANDS_DIR"
  for cmd_file in "$DIST_DIR/cursor/commands"/*.md; do
    [[ -f "$cmd_file" ]] || continue
    name="$(basename "$cmd_file")"
    skill_name="${name%.md}"
    [[ -n "$SKILL_FILTER" && "$skill_name" != "$SKILL_FILTER" ]] && continue
    dst="$CURSOR_COMMANDS_DIR/$name"
    $LINK && run ln -sf "$cmd_file" "$dst" || run cp "$cmd_file" "$dst"
    echo "  ✓ $name → $dst"
  done
}

uninstall_skills_cursor() {
  echo "→ Uninstalling skills from Cursor commands..."
  for cmd_file in "$DIST_DIR/cursor/commands"/*.md; do
    [[ -f "$cmd_file" ]] || continue
    name="$(basename "$cmd_file")"
    remove_if_exists "$CURSOR_COMMANDS_DIR/$name"
  done
}

# ── Rules ──────────────────────────────────────────────────────────────────────
build_managed_block() {
  local content=""
  for rule_file in "$REPO_DIR/rules"/*.md; do
    [[ -f "$rule_file" ]] || continue
    # Strip frontmatter (between first and second ---)
    body="$(awk '/^---/{found++; next} found==1{next} found>=2{print}' "$rule_file")"
    content+="$body"$'\n'
  done
  echo "$content"
}

install_rules_claude() {
  echo "→ Installing rules into Claude Code ($CLAUDE_CLAUDE_MD)..."
  local block
  block="$(build_managed_block)"

  if $DRY_RUN; then
    echo "  [dry-run] would write managed block to $CLAUDE_CLAUDE_MD"
    return
  fi

  mkdir -p "$(dirname "$CLAUDE_CLAUDE_MD")"

  if [[ ! -f "$CLAUDE_CLAUDE_MD" ]]; then
    # Fresh install — write the full file with the managed block
    printf '%s\n%s\n%s\n' "$BEGIN_MARKER" "$block" "$END_MARKER" > "$CLAUDE_CLAUDE_MD"
    echo "  ✓ created $CLAUDE_CLAUDE_MD with managed block"
  elif grep -qF "$BEGIN_MARKER" "$CLAUDE_CLAUDE_MD"; then
    # Update existing managed block in-place using awk
    awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" -v content="$block" '
      $0 == begin { print; print content; in_block=1; next }
      $0 == end   { in_block=0 }
      !in_block   { print }
    ' "$CLAUDE_CLAUDE_MD" > "${CLAUDE_CLAUDE_MD}.tmp" && mv "${CLAUDE_CLAUDE_MD}.tmp" "$CLAUDE_CLAUDE_MD"
    echo "  ✓ updated managed block in $CLAUDE_CLAUDE_MD"
  else
    # Append managed block at end of existing file
    printf '\n%s\n%s\n%s\n' "$BEGIN_MARKER" "$block" "$END_MARKER" >> "$CLAUDE_CLAUDE_MD"
    echo "  ✓ appended managed block to $CLAUDE_CLAUDE_MD"
  fi
}

uninstall_rules_claude() {
  echo "→ Uninstalling rules from Claude Code ($CLAUDE_CLAUDE_MD)..."
  if [[ ! -f "$CLAUDE_CLAUDE_MD" ]]; then
    echo "  nothing to do (file not found)"
    return
  fi
  if ! grep -qF "$BEGIN_MARKER" "$CLAUDE_CLAUDE_MD"; then
    echo "  nothing to do (no managed block found)"
    return
  fi
  if $DRY_RUN; then
    echo "  [dry-run] would remove managed block from $CLAUDE_CLAUDE_MD"
    return
  fi
  awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
    $0 == begin { in_block=1; next }
    $0 == end   { in_block=0; next }
    !in_block   { print }
  ' "$CLAUDE_CLAUDE_MD" > "${CLAUDE_CLAUDE_MD}.tmp" && mv "${CLAUDE_CLAUDE_MD}.tmp" "$CLAUDE_CLAUDE_MD"
  echo "  ✓ removed managed block from $CLAUDE_CLAUDE_MD"
}

install_rules_cursor() {
  echo "→ Installing rules into Cursor ($CURSOR_RULES_DIR)..."
  run mkdir -p "$CURSOR_RULES_DIR"
  for mdc_file in "$DIST_DIR/cursor/rules"/*.mdc; do
    [[ -f "$mdc_file" ]] || continue
    name="$(basename "$mdc_file")"
    [[ "$name" == "known-facts.mdc" ]] && continue  # handled by memories
    dst="$CURSOR_RULES_DIR/$name"
    $LINK && run ln -sf "$mdc_file" "$dst" || run cp "$mdc_file" "$dst"
    echo "  ✓ $name → $dst"
  done
}

uninstall_rules_cursor() {
  echo "→ Uninstalling rules from Cursor ($CURSOR_RULES_DIR)..."
  for mdc_file in "$DIST_DIR/cursor/rules"/*.mdc; do
    [[ -f "$mdc_file" ]] || continue
    name="$(basename "$mdc_file")"
    [[ "$name" == "known-facts.mdc" ]] && continue
    remove_if_exists "$CURSOR_RULES_DIR/$name"
  done
}

# ── Memories ───────────────────────────────────────────────────────────────────
install_memories_claude() {
  echo "→ Installing memories into Claude Code ($CLAUDE_MEMORY_DIR)..."
  run mkdir -p "$CLAUDE_MEMORY_DIR"
  for mem_file in "$REPO_DIR/memories"/*.md; do
    [[ -f "$mem_file" ]] || continue
    name="$(basename "$mem_file")"
    dst="$CLAUDE_MEMORY_DIR/$name"
    $LINK && run ln -sf "$mem_file" "$dst" || run cp "$mem_file" "$dst"
    echo "  ✓ $name → $dst"
  done
  # Regenerate MEMORY.md index
  regenerate_memory_index
}

regenerate_memory_index() {
  local index="$CLAUDE_MEMORY_DIR/MEMORY.md"
  $DRY_RUN && { echo "  [dry-run] would regenerate $index"; return; }
  {
    echo "# Memory Index"
    echo ""
    for mem_file in "$CLAUDE_MEMORY_DIR"/*.md; do
      [[ -f "$mem_file" ]] || continue
      name="$(basename "$mem_file")"
      [[ "$name" == "MEMORY.md" ]] && continue
      # Extract description from frontmatter if present
      desc="$(awk '/^---/{found++; next} found==1 && /^description:/{sub(/^description:[[:space:]]*/, ""); print; exit} found>=2{exit}' "$mem_file")"
      desc="${desc:-$name}"
      echo "- [${name%.md}]($name) — $desc"
    done
  } > "$index"
  echo "  ✓ regenerated $index"
}

uninstall_memories_claude() {
  echo "→ Uninstalling memories from Claude Code..."
  for mem_file in "$REPO_DIR/memories"/*.md; do
    [[ -f "$mem_file" ]] || continue
    name="$(basename "$mem_file")"
    remove_if_exists "$CLAUDE_MEMORY_DIR/$name"
  done
  regenerate_memory_index
}

install_memories_cursor() {
  echo "→ Installing known-facts rule into Cursor ($CURSOR_RULES_DIR)..."
  local src="$DIST_DIR/cursor/rules/known-facts.mdc"
  [[ -f "$src" ]] || { echo "  nothing to do (no memories found)"; return; }
  run mkdir -p "$CURSOR_RULES_DIR"
  dst="$CURSOR_RULES_DIR/known-facts.mdc"
  $LINK && run ln -sf "$src" "$dst" || run cp "$src" "$dst"
  echo "  ✓ known-facts.mdc → $dst"
}

uninstall_memories_cursor() {
  echo "→ Uninstalling known-facts rule from Cursor..."
  remove_if_exists "$CURSOR_RULES_DIR/known-facts.mdc"
}

# ── Main ───────────────────────────────────────────────────────────────────────
echo "ai-config installer v${VERSION}"
$DRY_RUN && echo "  (dry-run mode — no changes will be made)"
echo ""

build_if_needed

do_claude() {
  [[ "$HARNESS" == "claude" || "$HARNESS" == "both" ]]
}
do_cursor() {
  [[ "$HARNESS" == "cursor" || "$HARNESS" == "both" ]]
}
do_type() {
  [[ "$TYPE" == "$1" || "$TYPE" == "all" ]]
}

if $UNINSTALL; then
  do_type skills   && do_claude && uninstall_skills_claude
  do_type skills   && do_cursor && uninstall_skills_cursor
  do_type rules    && do_claude && uninstall_rules_claude
  do_type rules    && do_cursor && uninstall_rules_cursor
  do_type memories && do_claude && uninstall_memories_claude
  do_type memories && do_cursor && uninstall_memories_cursor
else
  do_type skills   && do_claude && install_skills_claude
  do_type skills   && do_cursor && install_skills_cursor
  do_type rules    && do_claude && install_rules_claude
  do_type rules    && do_cursor && install_rules_cursor
  do_type memories && do_claude && install_memories_claude
  do_type memories && do_cursor && install_memories_cursor
fi

echo ""
echo "Done. (v${VERSION})"
