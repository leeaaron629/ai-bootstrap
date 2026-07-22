#!/usr/bin/env python3
"""
Build script: transforms canonical source files into harness-specific dist artifacts.

Outputs:
  dist/cursor/commands/<name>.md   — Cursor slash commands (from skills)
  dist/cursor/rules/<name>.mdc     — Cursor rules (from rules)
  dist/cursor/rules/known-facts.mdc — Cursor facts rule (from memories)
"""

import re
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
SKILLS_DIR = REPO_ROOT / "skills"
RULES_DIR = REPO_ROOT / "rules"
MEMORIES_DIR = REPO_ROOT / "memories"
DIST_DIR = REPO_ROOT / "dist"

CURSOR_COMMANDS_DIR = DIST_DIR / "cursor" / "commands"
CURSOR_RULES_DIR = DIST_DIR / "cursor" / "rules"


def parse_frontmatter(text: str) -> tuple[dict, str]:
    """Split YAML frontmatter from body. Returns (meta_dict, body)."""
    if not text.startswith("---"):
        return {}, text
    end = text.index("---", 3)
    fm_text = text[3:end].strip()
    body = text[end + 3:].lstrip("\n")
    meta = {}
    for line in fm_text.splitlines():
        if ":" in line:
            k, _, v = line.partition(":")
            meta[k.strip()] = v.strip()
    return meta, body


def build_cursor_commands():
    """Skills → Cursor slash commands."""
    CURSOR_COMMANDS_DIR.mkdir(parents=True, exist_ok=True)
    for skill_dir in sorted(SKILLS_DIR.iterdir()):
        skill_md = skill_dir / "SKILL.md"
        if not skill_md.exists():
            continue
        text = skill_md.read_text()
        meta, body = parse_frontmatter(text)
        name = skill_dir.name

        prefix = f"> **Input:** {meta['argument-hint']}\n\n" if "argument-hint" in meta else ""
        out_path = CURSOR_COMMANDS_DIR / f"{name}.md"
        out_path.write_text(prefix + body)
        print(f"  command: {out_path.relative_to(REPO_ROOT)}")


def build_cursor_rules():
    """Rule files → Cursor .mdc rules (one per topic file)."""
    CURSOR_RULES_DIR.mkdir(parents=True, exist_ok=True)
    for rule_file in sorted(RULES_DIR.glob("*.md")):
        text = rule_file.read_text()
        meta, body = parse_frontmatter(text)

        always_apply = meta.get("cursor-always-apply", "true").lower() == "true"
        title = meta.get("title", rule_file.stem)

        cursor_fm = f"---\ndescription: {title}\nalwaysApply: {str(always_apply).lower()}\n---\n\n"
        out_name = re.sub(r"^\d+-", "", rule_file.stem) + ".mdc"
        out_path = CURSOR_RULES_DIR / out_name
        out_path.write_text(cursor_fm + body)
        print(f"  rule:    {out_path.relative_to(REPO_ROOT)}")


def build_cursor_known_facts():
    """Memories → a single Cursor known-facts.mdc rule."""
    memory_files = sorted(MEMORIES_DIR.glob("*.md"))
    if not memory_files:
        return

    CURSOR_RULES_DIR.mkdir(parents=True, exist_ok=True)
    sections = []
    for mf in memory_files:
        text = mf.read_text()
        _, body = parse_frontmatter(text)
        sections.append(body.strip())

    cursor_fm = "---\ndescription: Known facts and context\nalwaysApply: true\n---\n\n"
    out_path = CURSOR_RULES_DIR / "known-facts.mdc"
    out_path.write_text(cursor_fm + "\n\n---\n\n".join(sections) + "\n")
    print(f"  facts:   {out_path.relative_to(REPO_ROOT)}")


def main():
    print("Building Cursor artifacts...")
    build_cursor_commands()
    build_cursor_rules()
    build_cursor_known_facts()
    print("Done.")


if __name__ == "__main__":
    main()
