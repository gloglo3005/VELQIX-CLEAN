<#
  VelQix - ETAPE 2 : compte suspendu coupe partout (AUTH-01)

  Fichiers touches (trois) :
    BACKEND  src/routes/messageRoutes.ts       la connexion Socket.io refuse aussi un compte desactive
                                               (isActive = false) avec l'erreur ACCOUNT_DISABLED, comme
                                               le fait deja authMiddleware pour les routes HTTP.
                                               Le socket d'appels partage ce controle (io.use global).
    APP      lib/services/api_service.dart     ACCOUNT_DISABLED ferme la session, comme ACCOUNT_BANNED
    APP      lib/services/auth_service.dart    ACCOUNT_DISABLED ajoute a la liste des erreurs de session

  SECURITE :
    - Sauvegarde de chaque fichier touche : <fichier>.bak-step2
    - Chaque texte a remplacer doit exister UNE seule fois, sinon RIEN n'est ecrit (aucun des 3 fichiers).
    - Relancer le script est sans danger (les points deja appliques sont ignores).
    - Fin de ligne (CRLF/LF) et absence de BOM conserves tels quels.

  Utilisation (depuis n'importe ou) :
    powershell -ExecutionPolicy Bypass -File ".\step2-compte-suspendu.ps1" `
      -BackendRoot "C:\chemin\vers\velqix-backend" -AppRoot "C:\chemin\vers\app-flutter"

  Options :
    -SkipTypecheck   ne lance pas "npm run typecheck" dans le backend
    -Rollback        restaure les sauvegardes .bak-step2 et s'arrete
  Un seul des deux dossiers peut etre donne : seuls ses fichiers sont traites.
#>
[CmdletBinding()]
param(
  [string]$BackendRoot = '',
  [string]$AppRoot = '',
  [switch]$SkipTypecheck,
  [switch]$Rollback
)
$ErrorActionPreference = 'Stop'

if (-not $BackendRoot -and -not $AppRoot) {
  throw "Donne au moins -BackendRoot et/ou -AppRoot."
}
if ($BackendRoot) {
  $BackendRoot = (Resolve-Path $BackendRoot).Path
  $pkg = Join-Path $BackendRoot 'package.json'
  if (-not (Test-Path $pkg) -or -not ((Get-Content $pkg -Raw) -match '"name":\s*"velqix-backend"')) {
    throw "Ce dossier n'est pas la racine de velqix-backend : $BackendRoot"
  }
}
if ($AppRoot) {
  $AppRoot = (Resolve-Path $AppRoot).Path
  if (-not (Test-Path (Join-Path $AppRoot 'pubspec.yaml'))) {
    throw "Ce dossier n'est pas la racine de l'app Flutter (pubspec.yaml introuvable) : $AppRoot"
  }
}

# ---------------------------------------------------------------------------
# Remplacements
# ---------------------------------------------------------------------------
$msgOld = @'
        select: { role: true },
      });

      if (!user) {
        return next(new Error("USER_NOT_FOUND"));
      }

      if (user.role === "banni") {
        return next(new Error("ACCOUNT_BANNED"));
      }
'@
$msgNew = @'
        select: { role: true, isActive: true },
      });

      if (!user) {
        return next(new Error("USER_NOT_FOUND"));
      }

      if (user.role === "banni") {
        return next(new Error("ACCOUNT_BANNED"));
      }

      // Compte desactive par un admin : meme refus que authMiddleware (HTTP).
      if (user.isActive === false) {
        return next(new Error("ACCOUNT_DISABLED"));
      }
'@

$apiOld = @'
      if (res.statusCode == 403 && data['error'] == 'ACCOUNT_BANNED') {
        await _expireSession();
      }
'@
$apiNew = @'
      if (res.statusCode == 403 &&
          (data['error'] == 'ACCOUNT_BANNED' || data['error'] == 'ACCOUNT_DISABLED')) {
        await _expireSession();
      }
'@

$authOld = @'
  'ACCOUNT_BANNED',
  'USER_NOT_FOUND',
'@
$authNew = @'
  'ACCOUNT_BANNED',
  'ACCOUNT_DISABLED',
  'USER_NOT_FOUND',
'@

$targets = @()
if ($BackendRoot) {
  $targets += @{ Root = $BackendRoot; Rel = 'src/routes/messageRoutes.ts'
                 Edits = @( @{ Name = 'socket : refuse ACCOUNT_DISABLED'; Old = $msgOld; New = $msgNew } ) }
}
if ($AppRoot) {
  $targets += @{ Root = $AppRoot; Rel = 'lib/services/api_service.dart'
                 Edits = @( @{ Name = 'api : ACCOUNT_DISABLED ferme la session'; Old = $apiOld; New = $apiNew } ) }
  $targets += @{ Root = $AppRoot; Rel = 'lib/services/auth_service.dart'
                 Edits = @( @{ Name = 'auth : ACCOUNT_DISABLED erreur de session'; Old = $authOld; New = $authNew } ) }
}

# ---------------------------------------------------------------------------
# Rollback
# ---------------------------------------------------------------------------
if ($Rollback) {
  foreach ($t in $targets) {
    $path = Join-Path $t.Root $t.Rel
    $bak = "$path.bak-step2"
    if (Test-Path $bak) {
      Copy-Item $bak $path -Force
      Remove-Item $bak -Force
      Write-Host "  < restaure : $($t.Rel)" -ForegroundColor Cyan
    } else {
      Write-Host "  = pas de sauvegarde : $($t.Rel)" -ForegroundColor Yellow
    }
  }
  Write-Host "`nRollback termine." -ForegroundColor Green
  return
}

# ---------------------------------------------------------------------------
# Phase 1 : tout calculer en memoire (rien n'est ecrit si un repere manque)
# ---------------------------------------------------------------------------
$Utf8 = New-Object System.Text.UTF8Encoding($false)
$pending = @()
Write-Host "`n[1/2] Verification des reperes" -ForegroundColor White
foreach ($t in $targets) {
  $path = Join-Path $t.Root $t.Rel
  if (-not (Test-Path $path)) { throw "Fichier introuvable : $($t.Rel)" }
  $bytes = [IO.File]::ReadAllBytes($path)
  $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
  $offset = if ($hasBom) { 3 } else { 0 }
  $content = $Utf8.GetString($bytes, $offset, $bytes.Length - $offset)
  $eol = if ($content.Contains("`r`n")) { "`r`n" } else { "`n" }
  $changed = $false
  foreach ($e in $t.Edits) {
    $old = $e.Old.Replace("`r`n", "`n").Replace("`n", $eol)
    $new = $e.New.Replace("`r`n", "`n").Replace("`n", $eol)
    if ($content.Contains($new)) {
      Write-Host "  = deja applique ($($e.Name)) : $($t.Rel)" -ForegroundColor Yellow
      continue
    }
    $first = $content.IndexOf($old, [StringComparison]::Ordinal)
    if ($first -lt 0) { throw "[$($t.Rel)] repere introuvable pour '$($e.Name)' : le fichier a change, rien n'a ete ecrit." }
    if ($content.IndexOf($old, $first + 1, [StringComparison]::Ordinal) -ge 0) { throw "[$($t.Rel)] repere ambigu pour '$($e.Name)' : rien n'a ete ecrit." }
    $content = $content.Substring(0, $first) + $new + $content.Substring($first + $old.Length)
    $changed = $true
    Write-Host "  ~ $($e.Name) : $($t.Rel)" -ForegroundColor Cyan
  }
  if ($changed) { $pending += @{ Path = $path; Rel = $t.Rel; Content = $content; HasBom = $hasBom } }
}

# ---------------------------------------------------------------------------
# Phase 2 : sauvegarde puis ecriture
# ---------------------------------------------------------------------------
Write-Host "`n[2/2] Ecriture" -ForegroundColor White
if ($pending.Count -eq 0) {
  Write-Host "  Rien a faire : l'etape 2 est deja appliquee." -ForegroundColor Yellow
} else {
  foreach ($p in $pending) {
    $bak = "$($p.Path).bak-step2"
    if (-not (Test-Path $bak)) { Copy-Item $p.Path $bak -Force }
    $out = $Utf8.GetBytes($p.Content)
    if ($p.HasBom) { $out = [byte[]](0xEF, 0xBB, 0xBF) + $out }
    [IO.File]::WriteAllBytes($p.Path, $out)
    Write-Host "  + ecrit : $($p.Rel)  (sauvegarde : .bak-step2)" -ForegroundColor Green
  }
}

if ($BackendRoot -and -not $SkipTypecheck) {
  Write-Host "`n> npm run typecheck (backend)" -ForegroundColor White
  Push-Location $BackendRoot
  try {
    npm run typecheck
    if ($LASTEXITCODE -ne 0) { throw "npm run typecheck a echoue : relance avec -Rollback si besoin." }
  } finally { Pop-Location }
}

Write-Host "`nEtape 2 appliquee." -ForegroundColor Green
if ($AppRoot) { Write-Host "Cote app : lance 'flutter analyze lib/services' dans $AppRoot" -ForegroundColor White }
Write-Host "Puis deploie le backend sur Render (git push) pour que le controle du socket soit actif." -ForegroundColor White
