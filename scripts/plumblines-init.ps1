<#
.SYNOPSIS
  Scaffold Plumblines into a project (PowerShell twin of plumblines-init.sh).
.DESCRIPTION
  Creates the .agent_files tree, copies templates under their canonical names,
  detects source globs, writes a .plumblines config, patches .gitignore, and
  optionally installs the pre-push hook and CI workflow. Idempotent: existing
  files are left untouched and reported as skipped.
.PARAMETER Team      Team/large-codebase layout (shared/ + domains/).
.PARAMETER Dir       Memory directory (default: .agent_files).
.PARAMETER SrcGlobs  Override source globs instead of auto-detecting.
.PARAMETER Hooks     Install .git/hooks/pre-push completeness gate.
.PARAMETER Ci        Write .github/workflows/plumblines.yml.
.PARAMETER Obsidian  Drop Obsidian dashboards into <Dir>/dashboards/.
.EXAMPLE
  pwsh scripts/plumblines-init.ps1 -Team -Hooks
#>
[CmdletBinding()]
param(
  [switch]$Team,
  [string]$Dir = ".agent_files",
  [string]$SrcGlobs = "",
  [switch]$Hooks,
  [switch]$Ci,
  [switch]$Obsidian
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $PSCommandPath
$root = Split-Path -Parent $here
$tpl  = Join-Path $root "templates"
if (-not (Test-Path $tpl)) { Write-Error "templates/ not found next to this script ($tpl)"; exit 2 }

$layout = if ($Team) { "team" } else { "minimal" }
$script:made = 0
$script:skipped = 0

function New-Dir($p) {
  if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null; Write-Host "  + dir  $p" }
}
function Copy-Tpl($src, $dst) {
  if (Test-Path $dst) { Write-Host "  = skip $dst (exists)"; $script:skipped++; return }
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
  Copy-Item $src $dst; Write-Host "  + file $dst"; $script:made++
}

Write-Host "Plumblines init -> layout=$layout dir=$Dir`n"

# --- directory tree ---------------------------------------------------------
New-Dir $Dir
New-Dir (Join-Path $Dir "local/changes")
New-Dir (Join-Path $Dir "compacted")
New-Dir (Join-Path $Dir "templates")
if ($layout -eq "team") {
  New-Dir (Join-Path $Dir "shared")
  New-Dir (Join-Path $Dir "domains")
}

# --- canonical files --------------------------------------------------------
Copy-Tpl (Join-Path $tpl "AGENT_RULES.md")      (Join-Path $Dir "AGENT_RULES.md")
Copy-Tpl (Join-Path $tpl "context-priority.md") (Join-Path $Dir "CONTEXT_PRIORITY.md")
Copy-Tpl (Join-Path $tpl "loading-policy.md")   (Join-Path $Dir "LOADING_POLICY.md")
Copy-Tpl (Join-Path $tpl "project-state.md")    (Join-Path $Dir "PROJECT_STATE.md")
Copy-Tpl (Join-Path $tpl "working-state.md")    (Join-Path $Dir "local/WORKING_STATE.md")

if ($layout -eq "team") {
  Copy-Tpl (Join-Path $tpl "project-state.md") (Join-Path $Dir "shared/PROJECT_STATE.md")
  Copy-Tpl (Join-Path $tpl "decisions.md")     (Join-Path $Dir "shared/DECISION_LOG.md")
  Copy-Tpl (Join-Path $tpl "risks.md")         (Join-Path $Dir "shared/KNOWN_RISKS.md")
}

# Stamp the current commit into freshly scaffolded state files so they are valid
# from birth. Only touches the COMMIT_SHA placeholder, so user-filled values stay.
$headSha = (git rev-parse HEAD 2>$null)
if ($headSha) {
  foreach ($s in (Join-Path $Dir "PROJECT_STATE.md"), (Join-Path $Dir "local/WORKING_STATE.md"), (Join-Path $Dir "shared/PROJECT_STATE.md"), (Join-Path $Dir "shared/DECISION_LOG.md")) {
    if ((Test-Path $s) -and (Select-String -Path $s -SimpleMatch -Pattern "valid_as_of_commit: COMMIT_SHA" -Quiet)) {
      (Get-Content $s -Raw).Replace("valid_as_of_commit: COMMIT_SHA", "valid_as_of_commit: $headSha") |
        Set-Content -Path $s -Encoding utf8 -NoNewline:$false
    }
  }
}

# in-project copy of templates
Get-ChildItem (Join-Path $tpl "*.md") | ForEach-Object {
  Copy-Tpl $_.FullName (Join-Path $Dir "templates/$($_.Name)")
}

# --- source-glob detection --------------------------------------------------
if ([string]::IsNullOrWhiteSpace($SrcGlobs)) {
  $detected = foreach ($d in "src","lib","app","packages","services","cmd","pkg","internal","apps","source") {
    if (Test-Path $d -PathType Container) { "$d/" }
  }
  $SrcGlobs = if ($detected) { ($detected -join " ") } else { "src/ lib/ app/ packages/" }
}
$SrcGlobs = $SrcGlobs.Trim()
Write-Host "  src globs: $SrcGlobs"

# --- .plumblines config -----------------------------------------------------
if (Test-Path ".plumblines") {
  Write-Host "  = skip .plumblines (exists)"
} else {
  @"
# Plumblines config. Read by scripts/*.sh, the PowerShell scaffolder, and CI.
# Environment variables of the same name override these values.
agent_dir=$Dir
src_globs=$SrcGlobs
"@ | Set-Content -NoNewline:$false -Path ".plumblines" -Encoding utf8
  Write-Host "  + file .plumblines"; $script:made++
}

# --- .gitignore -------------------------------------------------------------
$giLine = "$Dir/local/"
$giHas = (Test-Path ".gitignore") -and (Select-String -Path ".gitignore" -SimpleMatch -Pattern $giLine -Quiet)
if ($giHas) {
  Write-Host "  = skip .gitignore ($giLine already present)"
} else {
  Add-Content -Path ".gitignore" -Value "`n# Plumblines branch-local agent memory`n$giLine"
  Write-Host "  + edit .gitignore (+ $giLine)"
}

# --- optional pre-push hook -------------------------------------------------
if ($Hooks) {
  $gitdir = (git rev-parse --git-dir 2>$null)
  if (-not $gitdir) {
    Write-Host "  ! -Hooks: not a git repo, skipping"
  } else {
    $hook = Join-Path $gitdir "hooks/pre-push"
    if (Test-Path $hook) {
      Write-Host "  = skip $hook (exists)"
    } else {
      "#!/usr/bin/env bash`nexec scripts/check-completeness.sh origin/main HEAD" |
        Set-Content -Path $hook -Encoding utf8 -NoNewline:$false
      Write-Host "  + file $hook"; $script:made++
    }
  }
}

# --- optional Obsidian dashboards -------------------------------------------
if ($Obsidian) {
  $obsTpl = Join-Path $tpl "obsidian"
  if (Test-Path $obsTpl) {
    New-Dir (Join-Path $Dir "dashboards")
    Get-ChildItem (Join-Path $obsTpl "*") | ForEach-Object {
      Copy-Tpl $_.FullName (Join-Path $Dir "dashboards/$($_.Name)")
    }
    Write-Host "  Obsidian: open '$Dir' as a vault (it's a dot-folder - see docs/obsidian.md),"
    Write-Host "            then open dashboards/plumblines.base."
  } else {
    Write-Host "  ! -Obsidian: $obsTpl not found, skipping"
  }
}

# --- optional CI workflow ---------------------------------------------------
if ($Ci) {
  $wf = ".github/workflows/plumblines.yml"
  if (Test-Path $wf) {
    Write-Host "  = skip $wf (exists)"
  } else {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $wf) | Out-Null
    @'
name: plumblines
on: pull_request
jobs:
  completeness:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - name: Completeness gate
        run: bash scripts/check-completeness.sh origin/${{ github.base_ref }} HEAD
      - name: Staleness report (non-blocking)
        run: bash scripts/check-staleness.sh || true
'@ | Set-Content -Path $wf -Encoding utf8
    Write-Host "  + file $wf"; $script:made++
  }
}

$short = (git rev-parse --short HEAD 2>$null); if (-not $short) { $short = "<commit>" }
Write-Host "`nDone. created=$($script:made) skipped=$($script:skipped)"
Write-Host "Next:"
Write-Host "  1. Fill $Dir/PROJECT_STATE.md (or run the plumblines-init agent skill to draft it)."
Write-Host "  2. Set valid_as_of_commit in PROJECT_STATE.md to: $short"
Write-Host "  3. Point your agent at $Dir/AGENT_RULES.md, CONTEXT_PRIORITY.md, LOADING_POLICY.md."
