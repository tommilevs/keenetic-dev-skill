param(
  [Parameter(Mandatory = $true)][string]$Repo,
  [Parameter(Mandatory = $true)][string]$Tag,
  [Parameter(Mandatory = $true)][string]$Dir,
  [string]$Name = '',
  [string]$NotesFile = ''
)
$ErrorActionPreference = 'Stop'

# Token comes from the machine's git credential store (Windows Credential Manager).
$env:GCM_INTERACTIVE = 'never'
$env:GIT_TERMINAL_PROMPT = '0'
$cred = "protocol=https`nhost=github.com`n`n" | git credential fill 2>$null
$token = ($cred -split "`n" | Where-Object { $_ -like 'password=*' }) -replace 'password=', ''
if (-not $token) { throw 'no GitHub token in the git credential store (git credential fill returned nothing)' }

$headers = @{ Authorization = "token $token"; 'User-Agent' = 'keenetic-dev'; Accept = 'application/vnd.github+json' }
if (-not $Name) { $Name = $Tag }
$body = ''
if ($NotesFile -and (Test-Path $NotesFile)) { $body = [IO.File]::ReadAllText($NotesFile, [Text.Encoding]::UTF8) }

$existing = $null
try { $existing = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/tags/$Tag" -Headers $headers -TimeoutSec 30 } catch { $existing = $null }

if ($existing) {
  Write-Host "release $Tag already exists (id=$($existing.id)), reusing it"
  $relObj = $existing
} else {
  $payload = @{ tag_name = $Tag; name = $Name; body = $body; draft = $false; prerelease = $false } | ConvertTo-Json -Compress
  $relObj = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases" -Method Post -Headers $headers `
    -Body ([Text.Encoding]::UTF8.GetBytes($payload)) -ContentType 'application/json; charset=utf-8' -TimeoutSec 30
  Write-Host "created release $($relObj.tag_name) id=$($relObj.id)"
}

$have = @{}
foreach ($a in $relObj.assets) { $have[$a.name] = $a.id }

$files = Get-ChildItem $Dir -File | Sort-Object Name
$i = 0; $uploaded = 0; $skipped = 0; $failed = 0
foreach ($f in $files) {
  $i++
  if ($have.ContainsKey($f.Name)) {
    $skipped++
    continue
  }
  $url = "https://uploads.github.com/repos/$Repo/releases/$($relObj.id)/assets?name=$([uri]::EscapeDataString($f.Name))"
  try {
    Invoke-RestMethod $url -Method Post -Headers $headers -ContentType 'application/octet-stream' -InFile $f.FullName -TimeoutSec 600 | Out-Null
    $uploaded++
    if (($i % 20) -eq 0 -or $f.Name -like 'Packages*') { Write-Host "[$i/$($files.Count)] $($f.Name)" }
  }
  catch {
    $failed++
    Write-Host "FAIL $($f.Name): $($_.Exception.Message)"
  }
}
Write-Host "done: uploaded=$uploaded skipped=$skipped failed=$failed (total files=$($files.Count))"
if ($failed -gt 0) { exit 1 }
