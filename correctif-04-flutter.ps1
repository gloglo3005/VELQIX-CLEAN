# ============================================================================
# Correctif 4 (FLUTTER) - Logements populaires vides sans Premium (point 4) + prix de verification (point 6)
# A lancer dans le dossier du projet FLUTTER (celui qui contient « lib »).
#   powershell -ExecutionPolicy Bypass -File .\correctif-04-flutter.ps1
# Anciens fichiers sauvegardes en *.bak-correctif04
# ============================================================================

$ErrorActionPreference = "Stop"
$racine = (Get-Location).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)
$suffixe = "bak-correctif04"

function Patch-Fichier([string]$chemin, [object[]]$edits) {
  $complet = Join-Path $racine $chemin
  if (-not (Test-Path $complet)) { throw "Fichier introuvable : $chemin" }
  $brut = [System.IO.File]::ReadAllText($complet)
  $crlf = $brut.Contains("`r`n")
  $t = $brut.Replace("`r`n", "`n")
  $i = 0
  foreach ($e in $edits) {
    $i++
    $n = ([regex]::Matches($t, [regex]::Escape($e.Old))).Count
    if ($n -ne 1) { throw "[$chemin] modification $i : texte a remplacer trouve $n fois (attendu : 1). Aucun fichier modifie pour celui-ci." }
    $t = $t.Replace($e.Old, $e.New)
  }
  if ($crlf) { $t = $t.Replace("`n", "`r`n") }
  Copy-Item $complet "$complet.$suffixe" -Force
  [System.IO.File]::WriteAllText($complet, $t, $utf8)
  Write-Host "OK  $chemin ($i modifications)" -ForegroundColor Green
}

function Ecrire-Fichier([string]$chemin, [string]$contenu) {
  $complet = Join-Path $racine $chemin
  $dossier = Split-Path $complet -Parent
  if (-not (Test-Path $dossier)) { New-Item -ItemType Directory -Path $dossier -Force | Out-Null }
  if (Test-Path $complet) { Copy-Item $complet "$complet.$suffixe" -Force }
  [System.IO.File]::WriteAllText($complet, $contenu, $utf8)
  Write-Host "OK  $chemin" -ForegroundColor Green
}


if (-not (Test-Path (Join-Path $racine "lib"))) { throw "Dossier 'lib' introuvable : place-toi dans le dossier du projet Flutter avant de lancer ce script." }

Patch-Fichier "lib/screens/home_screen.dart" @(
@{ Old = @'
    // Les annonces en vedette (mises en avant) s'affichent ici. S'il n'y en a
    // pas encore, on retombe sur les biens les plus consultés.

'@
  New = @'
    // Cette section n'affiche QUE les annonces mises en avant (propriétaires Premium).
    // Tant que personne n'est Premium, elle reste vide et donc masquée.

'@
}
@{ Old = @'
    final populaires = immoDispo.toList()
      ..sort((a, b) => b.vues.compareTo(a.vues));
    final popularTop = (vedettes.isNotEmpty ? vedettes : populaires).take(8).toList();
'@
  New = @'
    final popularTop = vedettes.take(8).toList();
'@
}
)

Patch-Fichier "lib/widgets/service_request_sheet.dart" @(
@{ Old = @'
  ServicePricing _pricing = ServicePricing.fallback;
'@
  New = @'
  // null = tarifs du serveur pas encore reçus : on n'affiche alors AUCUN prix
  // (avant, un prix « de secours » s'affichait puis était remplacé par le vrai).
  ServicePricing? _pricing;
'@
}
@{ Old = @'
  Future<void> _loadPricing() async {
    final p = await MissionService.instance.getPricing(zone: _propertyZone ?? _zone);
'@
  New = @'
  Future<void> _loadPricing() async {
    // Changement de zone : on masque l'ancien prix le temps de recevoir le nouveau.
    if (mounted && _pricing != null) setState(() => _pricing = null);
    final p = await MissionService.instance.getPricing(zone: _propertyZone ?? _zone);
'@
}
@{ Old = @'
    final price = _pricing.of(_type);
'@
  New = @'
    final price = _pricing?.of(_type);
'@
}
@{ Old = @'
          Text('Prix : ${_priceText(price)}',
'@
  New = @'
          Text(price == null ? 'Prix : chargement…' : 'Prix : ${_priceText(price)}',
'@
}
@{ Old = @'
            price.onQuote
                ? "VelQix vous envoie
'@
  New = @'
            price == null
                ? 'Récupération du tarif…'
                : price.onQuote
                ? "VelQix vous envoie
'@
}
@{ Old = @'
        label: price.onQuote ? 'Demander un devis' : 'Demander (${formatFcfa(price.price!)})',
        isLoading: _sending,
        onPressed: _send,
'@
  New = @'
        label: price == null
            ? 'Chargement du tarif…'
            : (price.onQuote ? 'Demander un devis' : 'Demander (${formatFcfa(price.price!)})'),
        isLoading: _sending,
        onPressed: price == null ? null : _send,
'@
}
)

Patch-Fichier "lib/services/mission_service.dart" @(
@{ Old = @'
    verification: ServicePrice(price: 3500, agentPay: 1500, transport: 300),
'@
  New = @'
    // Mêmes valeurs que PRICING_DEFAULTS du backend (missionRules.ts) : plus d'écart 3500 / 5000.
    verification: ServicePrice(price: 5000, agentPay: 2500, transport: 500),
'@
}
)

Patch-Fichier "lib/screens/admin_tabs/admin_ops_tab.dart" @(
@{ Old = @'
'Vérification terrain', '3500'),
'@
  New = @'
'Vérification terrain', '5000'),
'@
}
@{ Old = @'
'Vérification terrain', '1500'),
'@
  New = @'
'Vérification terrain', '2500'),
'@
}
@{ Old = @'
'Vérification terrain', '300'),
'@
  New = @'
'Vérification terrain', '500'),
'@
}
@{ Old = @'
'Vérification terrain', '200'),
'@
  New = @'
'Vérification terrain', '300'),
'@
}
@{ Old = @'
'Commissions et frais', '0'),
'@
  New = @'
'Commissions et frais', '10'),
'@
}
@{ Old = @'
'Abonnements', '11000'),
'@
  New = @'
'Abonnements', '10000'),
'@
}
@{ Old = @'
'Abonnements', '20000'),
'@
  New = @'
'Abonnements', '18000'),
'@
}
)

Write-Host ""
Write-Host "Termine. Lance : flutter run" -ForegroundColor Cyan
