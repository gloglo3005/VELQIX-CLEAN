# VelQix - Flutter : ecran d'appel = seulement « En attente... »

param([string]$Root = (Get-Location).Path)
if (-not (Test-Path (Join-Path $Root 'pubspec.yaml')) -or -not (Test-Path (Join-Path $Root 'lib\main.dart'))) {
    throw "Lance ce script depuis la racine du projet Flutter (dossier contenant pubspec.yaml), ou passe -Root <chemin>."
}
Write-Host "Projet Flutter : $Root" -ForegroundColor Green


$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Write-Step($m) { Write-Host "  -> $m" -ForegroundColor Cyan }

function Backup-Once($full) {
    $bak = "$full.bak-notif"
    if ((Test-Path $full) -and -not (Test-Path $bak)) { Copy-Item $full $bak }
}

function Write-NewFile([string]$Root, [string]$Rel, [string]$Content) {
    $full = Join-Path $Root $Rel
    $dir = Split-Path $full -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Backup-Once $full
    $txt = $Content.Replace("`r`n", "`n").Replace("`n", "`r`n")
    [System.IO.File]::WriteAllText($full, $txt, $utf8)
    Write-Step "cree/remplace : $Rel"
}

function Patch-File([string]$Root, [string]$Rel, [string]$Old, [string]$New, [int]$Expected = 1) {
    $full = Join-Path $Root $Rel
    if (-not (Test-Path $full)) { throw "Fichier introuvable : $Rel" }
    $raw  = [System.IO.File]::ReadAllText($full, $utf8)
    $crlf = $raw.Contains("`r`n")
    $txt  = $raw.Replace("`r`n", "`n")
    $o = $Old.Replace("`r`n", "`n")
    $n = $New.Replace("`r`n", "`n")
    if ($txt.Contains($n)) { Write-Step "deja applique : $Rel"; return }
    $count = [regex]::Matches($txt, [regex]::Escape($o)).Count
    if ($count -ne $Expected) {
        throw "Ancre non trouvee dans $Rel (attendu $Expected, trouve $count). Le fichier a change depuis l'analyse : rien n'a ete modifie pour cette etape."
    }
    Backup-Once $full
    $txt = $txt.Replace($o, $n)
    if ($crlf) { $txt = $txt.Replace("`n", "`r`n") }
    [System.IO.File]::WriteAllText($full, $txt, $utf8)
    Write-Step "patch : $Rel"
}


$o = @'
_remoteJoined ? _formattedDuration : _status,
'@
$n = @'
_remoteJoined ? _formattedDuration : 'En attente...',
'@
Patch-File $Root 'lib\screens\agora_call_screen.dart' $o $n 1

$o = @'
            if (!_joined) ...[
              const SizedBox(height: 20),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
              ),
            ],
'@
$n = @'
            // (aucun indicateur : seul « En attente... » s'affiche)
'@
Patch-File $Root 'lib\screens\agora_call_screen.dart' $o $n 1

$o = @'
                Text(_status,
                    textAlign: TextAlign.center,
'@
$n = @'
                Text(_status == 'Appel terminé' ? _status : 'En attente...',
                    textAlign: TextAlign.center,
'@
Patch-File $Root 'lib\screens\agora_video_call_screen.dart' $o $n 1

$o = @'
                if (!_joined) ...[
                  const SizedBox(height: 20),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
                  ),
                ],
'@
$n = @'
                // (aucun indicateur : seul « En attente... » s'affiche)
'@
Patch-File $Root 'lib\screens\agora_video_call_screen.dart' $o $n 1


Write-Host "Termine. Relance l'app (arret complet). Version web : reconstruis et redeploie." -ForegroundColor Green
