<#
.SYNOPSIS
  Étape 4 — Jetons de session dans le stockage sécurisé (flutter_secure_storage).

.DESCRIPTION
  PRÉREQUIS (à la racine du projet Flutter, le dossier qui contient "lib" et "pubspec.yaml") :
      flutter pub add flutter_secure_storage
  Le script vérifie que la dépendance est dans pubspec.yaml et s'arrête sinon.

  Modifie UN seul fichier : lib\services\api_service.dart
    - access token et refresh token : Keychain (iOS) / Keystore (Android) au lieu de SharedPreferences ;
    - migration automatique des sessions existantes (pas de déconnexion forcée) ;
    - signatures publiques inchangées (getToken, saveToken, getRefreshToken, saveRefreshToken, clearToken) :
      aucun autre fichier à modifier.
  Les autres préférences (thème, cache du profil et des annonces) restent dans SharedPreferences.
  Sauvegarde api_service.dart.bak-step4 ; s'arrête sans rien écrire si un texte attendu est introuvable.

.EXAMPLE
  flutter pub add flutter_secure_storage
  powershell -ExecutionPolicy Bypass -File .\step4-secure-storage.ps1
  # Annuler (puis : flutter pub remove flutter_secure_storage si tu abandonnes) :
  powershell -ExecutionPolicy Bypass -File .\step4-secure-storage.ps1 -Rollback
#>
param(
  [string]$Root = (Get-Location).Path,
  [switch]$Rollback
)

$ErrorActionPreference = 'Stop'
$Tag = 'step4'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Rel = 'lib\services\api_service.dart'

function Count-Occurrences([string]$haystack, [string]$needle) {
  return $haystack.Split([string[]]@($needle), [System.StringSplitOptions]::None).Length - 1
}
function Fail([string]$msg) { Write-Host "ERREUR : $msg" -ForegroundColor Red; exit 1 }

$p = Join-Path $Root $Rel
if (-not (Test-Path $p)) { Fail "Fichier introuvable : $Rel (lance le script depuis la racine du projet Flutter, ou passe -Root)." }
$bak = "$p.bak-$Tag"

if ($Rollback) {
  if (-not (Test-Path $bak)) { Fail "Sauvegarde introuvable : $Rel.bak-$Tag (rien n'a été modifié)." }
  Copy-Item -LiteralPath $bak -Destination $p -Force
  Remove-Item -LiteralPath $bak -Force
  Write-Host "  restauré : $Rel"
  Write-Host "Rollback de l'étape 4 terminé." -ForegroundColor Green
  exit 0
}

$Patches = @(
  ,@(@'
import 'package:http/http.dart' as http;
'@, @'
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
'@)
  ,@(@'
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kToken);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRefreshToken);
  }

  Future<void> saveRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRefreshToken, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kRefreshToken);
  }
'@, @'
  // Les jetons sont dans le stockage sécurisé du système (Keychain iOS, Keystore Android),
  // plus dans SharedPreferences (texte clair).
  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  // Migration unique : les sessions existantes (jetons en SharedPreferences) sont recopiées
  // dans le stockage sécurisé puis effacées des préférences, sans déconnecter l'utilisateur.
  Future<void>? _legacyMigration;

  Future<void> _ensureMigrated() => _legacyMigration ??= _migrateLegacyTokens();

  Future<void> _migrateLegacyTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in [_kToken, _kRefreshToken]) {
        final legacy = prefs.getString(key);
        if (legacy == null) continue;
        if (await _secure.read(key: key) == null) {
          await _secure.write(key: key, value: legacy);
        }
        await prefs.remove(key);
      }
    } catch (_) {
      // Stockage sécurisé indisponible : les anciennes valeurs restent en place, nouvel essai au prochain appel.
      _legacyMigration = null;
    }
  }

  // Une clé de chiffrement devenue illisible (restauration de sauvegarde Android, par exemple)
  // fait échouer la lecture : on repart d'un stockage vide, l'utilisateur se reconnecte.
  Future<void> _resetSecureStorage() async {
    try {
      await _secure.deleteAll();
    } catch (_) {}
  }

  Future<String?> _readSecure(String key) async {
    await _ensureMigrated();
    try {
      return await _secure.read(key: key);
    } catch (_) {
      await _resetSecureStorage();
      return null;
    }
  }

  Future<void> _writeSecure(String key, String value) async {
    await _ensureMigrated();
    try {
      await _secure.write(key: key, value: value);
    } catch (_) {
      await _resetSecureStorage();
      await _secure.write(key: key, value: value);
    }
  }

  Future<String?> getToken() => _readSecure(_kToken);

  Future<void> saveToken(String token) => _writeSecure(_kToken, token);

  Future<String?> getRefreshToken() => _readSecure(_kRefreshToken);

  Future<void> saveRefreshToken(String token) => _writeSecure(_kRefreshToken, token);

  Future<void> clearToken() async {
    try {
      await _secure.delete(key: _kToken);
      await _secure.delete(key: _kRefreshToken);
    } catch (_) {
      await _resetSecureStorage();
    }
    // Anciennes copies en clair éventuelles (session non encore migrée).
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kRefreshToken);
  }
'@)
)

# 1) Garde-fous : rien n'est écrit tant que tout n'est pas validé.
$pubspec = Join-Path $Root 'pubspec.yaml'
if (-not (Test-Path $pubspec)) { Fail "pubspec.yaml introuvable dans '$Root'." }
if (-not (Select-String -LiteralPath $pubspec -Pattern '^\s*flutter_secure_storage\s*:' -Quiet)) {
  Fail "flutter_secure_storage absent de pubspec.yaml. Exécute d'abord :  flutter pub add flutter_secure_storage   puis relance ce script."
}
if (Test-Path $bak) { Fail "Une sauvegarde existe déjà : $Rel.bak-$Tag (étape déjà appliquée ?). Utilise -Rollback." }

$bytes = [System.IO.File]::ReadAllBytes($p)
$hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
$offset = 0; if ($hasBom) { $offset = 3 }
$text = $Utf8NoBom.GetString($bytes, $offset, $bytes.Length - $offset)
$eol = "`n"; if ($text.Contains("`r`n")) { $eol = "`r`n" }

$i = 0
foreach ($pair in $Patches) {
  $i++
  $old = $pair[0] -replace "`r?`n", $eol
  $new = $pair[1] -replace "`r?`n", $eol
  $n = Count-Occurrences $text $old
  if ($n -ne 1) { Fail "$Rel : remplacement #$i — texte attendu trouvé $n fois (1 requis). Le fichier a changé depuis l'analyse ; rien n'a été modifié." }
  $text = $text.Replace($old, $new)
}

# 2) Sauvegarde puis écriture.
Copy-Item -LiteralPath $p -Destination $bak
[System.IO.File]::WriteAllText($p, $text, (New-Object System.Text.UTF8Encoding($hasBom)))
Write-Host "  modifié : $Rel   (sauvegarde : $Rel.bak-$Tag)"

Write-Host ""
Write-Host "Étape 4 appliquée." -ForegroundColor Green
Write-Host "Vérifie maintenant :"
Write-Host "  flutter pub get"
Write-Host "  flutter analyze"
Write-Host "Android : minSdkVersion 23 ou plus requis (android/app/build.gradle)."
Write-Host "Test de migration : installe l'ancienne version, connecte-toi, installe cette version par-dessus -> toujours connecté."
Write-Host "Pour annuler : powershell -ExecutionPolicy Bypass -File .\step4-secure-storage.ps1 -Rollback"
