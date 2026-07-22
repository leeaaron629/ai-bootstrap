# install.ps1 — install ai-config skills, rules, and memories into Claude Code and/or Cursor
# Requires PowerShell 5.1+ (Windows) or PowerShell 7+ (cross-platform)
param(
    [ValidateSet("claude","cursor","both")]
    [string]$Harness = "both",

    [ValidateSet("global","project")]
    [string]$Scope = "global",

    [ValidateSet("skills","rules","memories","all")]
    [string]$Type = "all",

    [string]$Skill = "",

    [switch]$Link,
    [switch]$DryRun,
    [switch]$Uninstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Version = if (Test-Path "$RepoDir\VERSION") { Get-Content "$RepoDir\VERSION" -Raw } else { "unknown" }
$Version = $Version.Trim()

# ── Path resolution ────────────────────────────────────────────────────────────
$HomeDir = $env:USERPROFILE
# Windows home slug: C:\Users\Aaron → C--Users-Aaron (replace : and \ with -).
# NOTE: this is a best-effort guess at Claude Code's Windows project-dir slug and
# has NOT been verified on Windows. If memories don't appear, check the resolved
# $ClaudeMemoryDir printed below against your actual ~/.claude/projects/* dir.
$HomeSlug = $HomeDir -replace "[:\\]", "-"

$ClaudeSkillsDir = "$HomeDir\.claude\skills"
$ClaudeMd        = "$HomeDir\.claude\CLAUDE.md"
$ClaudeMemoryDir = "$HomeDir\.claude\projects\$HomeSlug\memory"

$CursorCommandsDir = "$HomeDir\.cursor\commands"
# Cursor has no global file-based rules dir; empty under global scope means "skip".
$CursorRulesDir    = if ($Scope -eq "project") {
    Join-Path (Get-Location) ".cursor\rules"
} else {
    ""
}
if ($CursorRulesDir -eq "" -and $Harness -in "cursor","both" -and $Type -in "rules","all") {
    Write-Host "WARN: Cursor has no global file-based rules directory."
    Write-Host "      Cursor rules/memories are skipped under -Scope global."
    Write-Host "      Re-run with -Scope project inside a repo, or use Cursor Settings > Rules."
}

$DistDir = "$RepoDir\dist"

$BeginMarker = "<!-- BEGIN ai-config -->"
$EndMarker   = "<!-- END ai-config -->"

# ── Helpers ────────────────────────────────────────────────────────────────────
function Invoke-Action {
    param([string]$Description, [scriptblock]$Action)
    if ($DryRun) {
        Write-Host "  [dry-run] $Description"
    } else {
        & $Action
    }
}

function Copy-OrLink {
    param([string]$Src, [string]$Dst)
    if ($Link) {
        Invoke-Action "New-Item -ItemType SymbolicLink $Dst -> $Src" {
            New-Item -ItemType SymbolicLink -Path $Dst -Target $Src -Force | Out-Null
        }
    } else {
        Invoke-Action "Copy $Src -> $Dst" {
            if (Test-Path $Src -PathType Container) {
                Copy-Item -Recurse -Force $Src $Dst
            } else {
                Copy-Item -Force $Src $Dst
            }
        }
    }
}

function Remove-IfExists {
    param([string]$Path)
    if (Test-Path $Path) {
        Invoke-Action "Remove $Path" { Remove-Item -Recurse -Force $Path }
        Write-Host "  removed: $Path"
    }
}

# ── Build ──────────────────────────────────────────────────────────────────────
function Build-IfNeeded {
    if ($Harness -notin "cursor","both") { return }
    $py = if     (Get-Command python3 -ErrorAction SilentlyContinue) { "python3" }
          elseif (Get-Command python  -ErrorAction SilentlyContinue) { "python" }
          else   { Write-Error "Python 3 is required to build Cursor artifacts. Install Python 3 and retry."; exit 1 }
    Write-Host "-> Building Cursor artifacts..."
    if (-not $DryRun) { & $py "$RepoDir\scripts\build.py" }
}

# ── Frontmatter strip ──────────────────────────────────────────────────────────
function Get-Body {
    param([string]$FilePath)
    $lines = Get-Content $FilePath
    $found = 0
    $body = @()
    foreach ($line in $lines) {
        if ($found -ge 2) { $body += $line; continue }
        if ($line -eq "---") { $found++; continue }
    }
    return $body -join "`n"
}

# ── Skills ─────────────────────────────────────────────────────────────────────
function Install-SkillsClaude {
    Write-Host "-> Installing skills into Claude Code..."
    Invoke-Action "mkdir $ClaudeSkillsDir" { New-Item -ItemType Directory -Force $ClaudeSkillsDir | Out-Null }
    Get-ChildItem "$RepoDir\skills" -Directory | ForEach-Object {
        $name = $_.Name
        if ($Skill -and $name -ne $Skill) { return }
        $dst = "$ClaudeSkillsDir\$name"
        Remove-IfExists $dst
        Copy-OrLink $_.FullName $dst
        Write-Host "  + $name -> $dst"
    }
}

function Uninstall-SkillsClaude {
    Write-Host "-> Uninstalling skills from Claude Code..."
    Get-ChildItem "$RepoDir\skills" -Directory | ForEach-Object {
        $name = $_.Name
        if ($Skill -and $name -ne $Skill) { return }
        Remove-IfExists "$ClaudeSkillsDir\$name"
    }
}

function Install-SkillsCursor {
    Write-Host "-> Installing skills into Cursor commands..."
    Invoke-Action "mkdir $CursorCommandsDir" { New-Item -ItemType Directory -Force $CursorCommandsDir | Out-Null }
    Get-ChildItem "$DistDir\cursor\commands" -Filter "*.md" | ForEach-Object {
        $skillName = $_.BaseName
        if ($Skill -and $skillName -ne $Skill) { return }
        $dst = "$CursorCommandsDir\$($_.Name)"
        Copy-OrLink $_.FullName $dst
        Write-Host "  + $($_.Name) -> $dst"
    }
}

function Uninstall-SkillsCursor {
    Write-Host "-> Uninstalling skills from Cursor commands..."
    Get-ChildItem "$DistDir\cursor\commands" -Filter "*.md" -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-IfExists "$CursorCommandsDir\$($_.Name)"
    }
}

# ── Rules ──────────────────────────────────────────────────────────────────────
function Get-ManagedBlock {
    $parts = @()
    Get-ChildItem "$RepoDir\rules" -Filter "*.md" | Sort-Object Name | ForEach-Object {
        $parts += Get-Body $_.FullName
    }
    return $parts -join "`n"
}

function Install-RulesClaude {
    Write-Host "-> Installing rules into Claude Code ($ClaudeMd)..."
    $block = Get-ManagedBlock
    if ($DryRun) { Write-Host "  [dry-run] would write managed block to $ClaudeMd"; return }

    New-Item -ItemType Directory -Force (Split-Path $ClaudeMd) | Out-Null

    if (-not (Test-Path $ClaudeMd)) {
        Set-Content $ClaudeMd "$BeginMarker`n$block`n$EndMarker"
        Write-Host "  + created $ClaudeMd with managed block"
    } elseif ((Get-Content $ClaudeMd -Raw) -match [regex]::Escape($BeginMarker)) {
        $content = Get-Content $ClaudeMd -Raw
        $pattern = "(?s)" + [regex]::Escape($BeginMarker) + ".*?" + [regex]::Escape($EndMarker)
        $replacement = "$BeginMarker`n$block`n$EndMarker"
        # MatchEvaluator so `$` in rule bodies is inserted literally (not treated as $1/$&)
        $evaluator = { param($m) $replacement }.GetNewClosure()
        $content = [regex]::Replace($content, $pattern, $evaluator)
        Set-Content $ClaudeMd $content
        Write-Host "  + updated managed block in $ClaudeMd"
    } else {
        Add-Content $ClaudeMd "`n$BeginMarker`n$block`n$EndMarker"
        Write-Host "  + appended managed block to $ClaudeMd"
    }
}

function Uninstall-RulesClaude {
    Write-Host "-> Uninstalling rules from Claude Code ($ClaudeMd)..."
    if (-not (Test-Path $ClaudeMd)) { Write-Host "  nothing to do"; return }
    $content = Get-Content $ClaudeMd -Raw
    if ($content -notmatch [regex]::Escape($BeginMarker)) { Write-Host "  nothing to do"; return }
    if ($DryRun) { Write-Host "  [dry-run] would remove managed block"; return }
    $pattern = "(?s)\n?" + [regex]::Escape($BeginMarker) + ".*?" + [regex]::Escape($EndMarker) + "\n?"
    $content = $content -replace $pattern, ""
    Set-Content $ClaudeMd $content
    Write-Host "  + removed managed block from $ClaudeMd"
}

function Install-RulesCursor {
    if ($CursorRulesDir -eq "") { Write-Host "-> Skipping Cursor rules (global scope; use -Scope project)."; return }
    Write-Host "-> Installing rules into Cursor ($CursorRulesDir)..."
    Invoke-Action "mkdir $CursorRulesDir" { New-Item -ItemType Directory -Force $CursorRulesDir | Out-Null }
    Get-ChildItem "$DistDir\cursor\rules" -Filter "*.mdc" | Where-Object { $_.Name -ne "known-facts.mdc" } | ForEach-Object {
        $dst = "$CursorRulesDir\$($_.Name)"
        Copy-OrLink $_.FullName $dst
        Write-Host "  + $($_.Name) -> $dst"
    }
}

function Uninstall-RulesCursor {
    if ($CursorRulesDir -eq "") { Write-Host "-> Skipping Cursor rules (global scope; use -Scope project)."; return }
    Get-ChildItem "$DistDir\cursor\rules" -Filter "*.mdc" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne "known-facts.mdc" } | ForEach-Object {
        Remove-IfExists "$CursorRulesDir\$($_.Name)"
    }
}

# ── Memories ───────────────────────────────────────────────────────────────────
function Regenerate-MemoryIndex {
    $index = "$ClaudeMemoryDir\MEMORY.md"
    if ($DryRun) { Write-Host "  [dry-run] would regenerate $index"; return }
    $lines = @("# Memory Index", "")
    Get-ChildItem $ClaudeMemoryDir -Filter "*.md" | Where-Object { $_.Name -ne "MEMORY.md" } | ForEach-Object {
        $desc = $_.BaseName
        $lines += "- [$($_.BaseName)]($($_.Name)) — $desc"
    }
    Set-Content $index ($lines -join "`n")
    Write-Host "  + regenerated $index"
}

function Repo-HasMemories {
    return @(Get-ChildItem "$RepoDir\memories" -Filter "*.md" -ErrorAction SilentlyContinue).Count -gt 0
}

function Install-MemoriesClaude {
    if (-not (Repo-HasMemories)) {
        Write-Host "-> No memories in repo; leaving Claude Code memory dir untouched."
        return
    }
    Write-Host "-> Installing memories into Claude Code ($ClaudeMemoryDir)..."
    Invoke-Action "mkdir $ClaudeMemoryDir" { New-Item -ItemType Directory -Force $ClaudeMemoryDir | Out-Null }
    Get-ChildItem "$RepoDir\memories" -Filter "*.md" | ForEach-Object {
        $dst = "$ClaudeMemoryDir\$($_.Name)"
        Copy-OrLink $_.FullName $dst
        Write-Host "  + $($_.Name) -> $dst"
    }
    Regenerate-MemoryIndex
}

function Uninstall-MemoriesClaude {
    if (-not (Repo-HasMemories)) {
        Write-Host "-> No memories in repo; leaving Claude Code memory dir untouched."
        return
    }
    Get-ChildItem "$RepoDir\memories" -Filter "*.md" -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-IfExists "$ClaudeMemoryDir\$($_.Name)"
    }
    Regenerate-MemoryIndex
}

function Install-MemoriesCursor {
    if ($CursorRulesDir -eq "") { Write-Host "-> Skipping Cursor known-facts (global scope; use -Scope project)."; return }
    $src = "$DistDir\cursor\rules\known-facts.mdc"
    if (-not (Test-Path $src)) { Write-Host "  nothing to do (no memories)"; return }
    Invoke-Action "mkdir $CursorRulesDir" { New-Item -ItemType Directory -Force $CursorRulesDir | Out-Null }
    Copy-OrLink $src "$CursorRulesDir\known-facts.mdc"
    Write-Host "  + known-facts.mdc -> $CursorRulesDir"
}

function Uninstall-MemoriesCursor {
    if ($CursorRulesDir -eq "") { Write-Host "-> Skipping Cursor known-facts (global scope; use -Scope project)."; return }
    Remove-IfExists "$CursorRulesDir\known-facts.mdc"
}

# ── Main ───────────────────────────────────────────────────────────────────────
Write-Host "ai-config installer v$Version"
if ($DryRun) { Write-Host "  (dry-run mode — no changes will be made)" }
Write-Host ""

Build-IfNeeded

$doClaude = $Harness -in "claude","both"
$doCursor = $Harness -in "cursor","both"
$doSkills    = $Type -in "skills","all"
$doRules     = $Type -in "rules","all"
$doMemories  = $Type -in "memories","all"

if ($Uninstall) {
    if ($doSkills)    { if ($doClaude) { Uninstall-SkillsClaude };   if ($doCursor) { Uninstall-SkillsCursor } }
    if ($doRules)     { if ($doClaude) { Uninstall-RulesClaude };    if ($doCursor) { Uninstall-RulesCursor } }
    if ($doMemories)  { if ($doClaude) { Uninstall-MemoriesClaude }; if ($doCursor) { Uninstall-MemoriesCursor } }
} else {
    if ($doSkills)    { if ($doClaude) { Install-SkillsClaude };   if ($doCursor) { Install-SkillsCursor } }
    if ($doRules)     { if ($doClaude) { Install-RulesClaude };    if ($doCursor) { Install-RulesCursor } }
    if ($doMemories)  { if ($doClaude) { Install-MemoriesClaude }; if ($doCursor) { Install-MemoriesCursor } }
}

Write-Host ""
Write-Host "Done. (v$Version)"
