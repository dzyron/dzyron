$ErrorActionPreference = 'Continue'

# gitnexus statically imports `registerHooks` from node:module (onnxruntime-node-resolver.js),
# which only exists on Node >= 22.15. The machine's Node is now v24.19.0 (via fnm, already on the
# persistent User PATH), so the old pinned Node 22.15.0 runtime is no longer needed.

# Default worker pool size is os.availableParallelism()-1 (~15 on this 16-thread machine), which
# reliably exhausts all pool slots (workers time out during top-of-script init) when the box is
# also running many concurrent Claude Code sessions. Cap it so init has enough CPU/RAM headroom.
$env:GITNEXUS_WORKER_POOL_SIZE = "4"

$logDir = Join-Path $env:USERPROFILE ".gitnexus-data\logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stamp   = "{0:yyyy-MM-dd_HHmmss}" -f (Get-Date)
$logFile = Join-Path $logDir "analyze-$stamp.log"

function Log($msg) { $msg | Out-File -FilePath $logFile -Append -Encoding utf8 }

$ghRoot = Join-Path $env:USERPROFILE "Workspace\Github"
# oh-api-gitnexus is a dedicated clone pinned to master, kept only for GitNexus indexing
# (unlike oh-api-worker, which gets checked out to feature branches during dev work).
# Flow: pull master -> re-index -> run the omh-knowledge-refresh skill against the new index.
$repo = Join-Path $ghRoot "oh-api-gitnexus"
$refreshRepoReady = $false

Log "==== $repo ===="
if (-not (Test-Path $repo)) {
  Log "SKIPPED: path not found"
} else {
  Push-Location $repo
  $pullOk = $true
  # Tracked-file changes would make the pull abort (untracked like AGENTS.md are fine).
  $dirty = & git status --porcelain --untracked-files=no
  if ($dirty) {
    Log "PULL FAILED: working tree dirty -> $($dirty -join '; ')"
    $pullOk = $false
  } else {
    # Route through cmd so git's stderr progress isn't wrapped as PowerShell NativeCommandError noise.
    & cmd /c "git checkout master 2>&1" | Out-File -FilePath $logFile -Append -Encoding utf8
    & cmd /c "git pull --ff-only origin master 2>&1" | Out-File -FilePath $logFile -Append -Encoding utf8
    if ($LASTEXITCODE -ne 0) { Log "PULL FAILED: git pull --ff-only exit $LASTEXITCODE"; $pullOk = $false }
  }
  Log ("HEAD: " + (& git rev-parse --short HEAD))

  # --skip-agents-md: never write the gitnexus block into tracked AGENTS.md/CLAUDE.md,
  # otherwise the next day's pull aborts on "local changes would be overwritten".
  & npx gitnexus analyze --embeddings --skip-agents-md *>> $logFile
  if ($LASTEXITCODE -ne 0) { Log "ANALYZE FAILED: exit $LASTEXITCODE" }
  elseif ($pullOk) { $refreshRepoReady = $true }
  Pop-Location
}

# --- Run omh-knowledge-refresh headless (report only, no apply: approval needs a human) ---
if ($refreshRepoReady) {
  $claude  = Join-Path $env:USERPROFILE ".local\bin\claude.exe"
  $report  = Join-Path $logDir "knowledge-refresh-$stamp.md"
  $tpl     = Get-Content -Raw -Encoding utf8 (Join-Path $PSScriptRoot "knowledge-refresh-prompt.md")
  $prompt  = $tpl.Replace('{{DATE}}', (Get-Date -Format 'yyyy-MM-dd'))

  # Headless = no permission prompts, so every tool the skill needs is pre-allowed here.
  $allowed = @(
    'Skill','Read','Write','Edit','Glob','Grep','Bash','PowerShell',
    'mcp__gitnexus'
  )

  # PS 5.1 defaults to OEM/ASCII on pipes: force UTF-8 both ways so the Vietnamese prompt
  # reaches claude intact and its Vietnamese report isn't mojibake.
  $OutputEncoding           = New-Object System.Text.UTF8Encoding($false)
  [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)

  Log "==== omh-knowledge-refresh -> $report ===="
  Set-Location (Join-Path $ghRoot "oh-api-gitnexus")
  $prompt | & $claude -p --output-format text --allowedTools $allowed |
    Out-File -FilePath $report -Encoding utf8
  Log "omh-knowledge-refresh exit $LASTEXITCODE"
} else {
  Log "SKIPPED omh-knowledge-refresh: oh-api pull/analyze did not succeed"
}
