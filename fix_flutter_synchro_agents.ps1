# VelQix - Flutter : le client et l'agent d'une mission peuvent s'ecrire depuis la carte de mission

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


$c = @'
import 'package:flutter/material.dart';

import '../screens/messages_screen.dart';
import 'property_service.dart';

/// Ouvre la conversation avec un utilisateur à partir de son id.
/// Sert aux missions : le client écrit à l'agent assigné, l'agent écrit
/// au client, depuis la carte de la mission.
Future<void> openChatWith(BuildContext context, String userId) async {
  final nav = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final user = await PropertyService.instance.fetchUserProfile(userId, auth: true);

  if (user == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Impossible d\'ouvrir la conversation pour le moment.')),
    );
    return;
  }

  nav.push(
    MaterialPageRoute(
      builder: (_) => ChatScreen(user: user, otherUserId: userId),
    ),
  );
}
'@
Write-NewFile $Root 'lib\services\chat_launcher.dart' $c

$o = @'
  final String clientName;
'@
$n = @'
  final String clientName;
  final String? clientId; // pour écrire au client (agent assigné)
  final String? agentId;  // pour écrire à l'agent (client)
'@
Patch-File $Root 'lib\models\mission_model.dart' $o $n 1

$o = @'
    this.clientName = '',
'@
$n = @'
    this.clientName = '',
    this.clientId,
    this.agentId,
'@
Patch-File $Root 'lib\models\mission_model.dart' $o $n 1

$o = @'
      clientName: (j['clientName'] ?? '').toString(),
'@
$n = @'
      clientName: (j['clientName'] ?? '').toString(),
      clientId: (j['clientId'] ?? '').toString().isEmpty ? null : j['clientId'].toString(),
      agentId: (j['agentId'] ?? '').toString().isEmpty ? null : j['agentId'].toString(),
'@
Patch-File $Root 'lib\models\mission_model.dart' $o $n 1

$o = @'
import '../services/mission_service.dart';
'@
$n = @'
import '../services/chat_launcher.dart';
import '../services/mission_service.dart';
'@
Patch-File $Root 'lib\screens\my_services_screen.dart' $o $n 1

$o = @'
        if (busy)
          const Padding(
            padding: EdgeInsets.only(top: 10),
'@
$n = @'
        if ((m.agentId ?? '').isNotEmpty && m.status != MissionStatus.annulee) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => openChatWith(context, m.agentId!),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
              label: const Text("Écrire à l'agent"),
            ),
          ),
        ],
        if (busy)
          const Padding(
            padding: EdgeInsets.only(top: 10),
'@
Patch-File $Root 'lib\screens\my_services_screen.dart' $o $n 1

$o = @'
import '../services/chat_service.dart';
'@
$n = @'
import '../services/chat_launcher.dart';
import '../services/chat_service.dart';
'@
Patch-File $Root 'lib\screens\agent_workspace_screen.dart' $o $n 1

$o = @'
                onPressed: () => _call(m.contactPhone),
              ),
          ]),
'@
$n = @'
                onPressed: () => _call(m.contactPhone),
              ),
            if ((m.clientId ?? '').isNotEmpty)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Message',
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primary, size: 20),
                onPressed: () => openChatWith(context, m.clientId!),
              ),
          ]),
'@
Patch-File $Root 'lib\screens\agent_workspace_screen.dart' $o $n 1


Write-Host "Termine. Applique aussi fix_backend_synchro_agents.ps1 sur le backend, puis relance l'app." -ForegroundColor Green
