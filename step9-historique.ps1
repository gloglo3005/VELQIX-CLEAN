# ============================================================================
# VelQix - Etape 9 : Historique des confirmations visible (ANN-06)
# Fichiers : lib\services\availability_service.dart  (modifie)
#            lib\screens\my_listings_screen.dart      (modifie)
# Usage    : depuis la racine du projet Flutter (dossier contenant pubspec.yaml)
#            .\step9-historique.ps1            -> applique
#            .\step9-historique.ps1 -Rollback  -> remet les fichiers d'origine
# ============================================================================
param([switch]$Rollback)
$ErrorActionPreference = 'Stop'

$root  = (Get-Location).Path
$utf8  = New-Object System.Text.UTF8Encoding($false)
$sRel  = 'lib\services\availability_service.dart'
$mRel  = 'lib\screens\my_listings_screen.dart'
$sPath = Join-Path $root $sRel
$mPath = Join-Path $root $mRel
$sBak  = $sPath + '.bak-step9'
$mBak  = $mPath + '.bak-step9'

if (-not (Test-Path (Join-Path $root 'pubspec.yaml'))) {
    throw "Lance ce script depuis la racine du projet Flutter (pubspec.yaml introuvable dans $root)."
}

if ($Rollback) {
    if (-not (Test-Path $sBak) -or -not (Test-Path $mBak)) { throw "Sauvegardes .bak-step9 incompletes : rien n'a ete restaure." }
    Move-Item -LiteralPath $sBak -Destination $sPath -Force
    Move-Item -LiteralPath $mBak -Destination $mPath -Force
    Write-Host "Restaure : $sRel"
    Write-Host "Restaure : $mRel"
    Write-Host "Rollback termine."
    return
}

function Norm([string]$t) { return $t.Replace("`r`n", "`n") }

function Replace-Once([string]$text, [string]$old, [string]$new, [string]$label) {
    $old = Norm $old; $new = Norm $new
    $i = $text.IndexOf($old, [StringComparison]::Ordinal)
    if ($i -lt 0) { throw "Texte introuvable ($label). Aucun fichier modifie." }
    if ($text.IndexOf($old, $i + 1, [StringComparison]::Ordinal) -ge 0) { throw "Texte present plusieurs fois ($label). Aucun fichier modifie." }
    return $text.Substring(0, $i) + $new + $text.Substring($i + $old.Length)
}

# ------------------------------------------------------------- Contenus
$s1Old = @'
class AvailabilityService {
'@
$s1New = @'
/// Une ligne de l'historique de disponibilité d'une annonce (ANN-06).
/// Le serveur ne la modifie ni ne l'efface jamais.
class AvailabilityEventItem {
  final String id;
  final String action;
  final String resultStatus;
  final String channel; // app | system | admin
  final String? actorName;
  final String? note;
  final DateTime? createdAt;

  const AvailabilityEventItem({
    required this.id,
    required this.action,
    required this.resultStatus,
    required this.channel,
    required this.actorName,
    required this.note,
    required this.createdAt,
  });

  factory AvailabilityEventItem.fromJson(Map<String, dynamic> j) {
    String? sn(dynamic v) {
      final t = v?.toString().trim() ?? '';
      return t.isEmpty ? null : t;
    }

    return AvailabilityEventItem(
      id: (j['id'] ?? '').toString(),
      action: (j['action'] ?? '').toString(),
      resultStatus: (j['resultStatus'] ?? '').toString(),
      channel: (j['channel'] ?? '').toString(),
      actorName: sn(j['actorName']),
      note: sn(j['note']),
      createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString())?.toLocal(),
    );
  }

  static String actionLabel(String a) {
    switch (a) {
      case 'declared_available':   return 'Bien confirmé disponible';
      case 'declared_rented':      return 'Bien déclaré loué';
      case 'declared_sold':        return 'Bien déclaré vendu';
      case 'declared_unavailable': return 'Bien déclaré indisponible';
      case 'confirmed_via_request':   return 'Disponibilité confirmée suite à une demande';
      case 'unavailable_via_request': return 'Indisponibilité déclarée suite à une demande';
      case 'suspended_by_admin':   return 'Annonce suspendue par l\'équipe';
      case 'restored_by_admin':    return 'Annonce rétablie par l\'équipe';
      case 'suspended_by_reports': return 'Annonce suspendue après signalements';
      default:                     return a;
    }
  }

  static String statusLabel(String s) {
    switch (s) {
      case 'available':   return 'Disponible';
      case 'pending':     return 'À reconfirmer';
      case 'unavailable': return 'Indisponible';
      case 'rented':      return 'Loué';
      case 'sold':        return 'Vendu';
      case 'suspended':   return 'Suspendue';
      case 'archived':    return 'Archivée';
      default:            return s;
    }
  }

  static String channelLabel(String c) {
    switch (c) {
      case 'app':    return 'Application';
      case 'admin':  return 'Équipe VelQix';
      case 'system': return 'Automatique';
      default:       return c;
    }
  }
}

class AvailabilityService {
'@
$s2Old = @'
  final _api = ApiService.instance;
'@
$s2New = @'
  final _api = ApiService.instance;

  /// Propriétaire (ou admin) : historique daté des confirmations et changements
  /// de statut d'une annonce, du plus récent au plus ancien (ANN-06).
  /// Lance une Exception avec un message lisible en cas d'échec.
  Future<List<AvailabilityEventItem>> getHistory(String propertyId) async {
    final res = await _api.get('/properties/$propertyId/availability-history', auth: true);
    if (res['success'] != true) throw Exception(_msg(res, "Impossible de charger l'historique."));
    final data = res['data'];
    if (data is! List) return <AvailabilityEventItem>[];
    return data
        .whereType<Map>()
        .map((m) => AvailabilityEventItem.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }
'@
$m1Old = @'
import '../services/api_service.dart'; // NEW : vraie source de données
'@
$m1New = @'
import '../services/api_service.dart'; // NEW : vraie source de données
import '../services/availability_service.dart';
'@
$m2Old = @'
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Toggle active
'@
$m2New = @'
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _showAvailabilityHistory(context, p),
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: Text('Historique des confirmations',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500)),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Toggle active
'@
$mAppend = @'
// ─── Historique des confirmations d'une annonce (ANN-06) ─────────────────────
Future<void> _showAvailabilityHistory(BuildContext context, PropertyModel p) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AvailabilityHistorySheet(property: p),
  );
}

class _AvailabilityHistorySheet extends StatefulWidget {
  final PropertyModel property;
  const _AvailabilityHistorySheet({required this.property});
  @override
  State<_AvailabilityHistorySheet> createState() => _AvailabilityHistorySheetState();
}

class _AvailabilityHistorySheetState extends State<_AvailabilityHistorySheet> {
  late Future<List<AvailabilityEventItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = AvailabilityService.instance.getHistory(widget.property.id);
  }

  void _retry() {
    setState(() {
      _future = AvailabilityService.instance.getHistory(widget.property.id);
    });
  }

  String _fmt(DateTime? d) {
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} à ${two(d.hour)}:${two(d.minute)}';
  }

  IconData _icon(String action) {
    if (action.startsWith('suspended')) return Icons.block_rounded;
    if (action.startsWith('restored')) return Icons.restore_rounded;
    if (action == 'declared_available' || action == 'confirmed_via_request') {
      return Icons.check_circle_rounded;
    }
    return Icons.info_rounded;
  }

  Color _color(String action) {
    if (action.startsWith('suspended')) return AppTheme.error;
    if (action.startsWith('restored')) return AppTheme.info;
    if (action == 'declared_available' || action == 'confirmed_via_request') {
      return AppTheme.success;
    }
    return AppTheme.warning;
  }

  Widget _row(AvailabilityEventItem e) {
    final color = _color(e.action);
    // L'identité d'un membre de l'équipe n'est pas montrée : on affiche l'équipe.
    final who = e.channel == 'app'
        ? (e.actorName ?? 'Vous')
        : AvailabilityEventItem.channelLabel(e.channel);
    // Les notes internes (ex. « Signalement <id> ») ne concernent pas le propriétaire.
    final note = (e.note != null && !e.note!.startsWith('Signalement')) ? e.note : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(_icon(e.action), size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AvailabilityEventItem.actionLabel(e.action),
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text('Statut : ${AvailabilityEventItem.statusLabel(e.resultStatus)}',
                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
            if (note != null)
              Text(note, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(height: 2),
            Text('${_fmt(e.createdAt)} · $who',
                style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textHint)),
          ]),
        ),
      ]),
    );
  }

  Widget _message(IconData icon, String text, {bool retry = false}) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 44, color: AppTheme.textHint),
        const SizedBox(height: 12),
        Text(text,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
        if (retry) ...[
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _retry, child: Text('Réessayer', style: GoogleFonts.poppins(fontSize: 12))),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Historique des confirmations',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(widget.property.titre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
            ]),
          ),
          Flexible(
            child: FutureBuilder<List<AvailabilityEventItem>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return _message(Icons.error_outline_rounded,
                      snap.error.toString().replaceFirst('Exception: ', ''),
                      retry: true);
                }
                final events = snap.data ?? const <AvailabilityEventItem>[];
                if (events.isEmpty) {
                  return _message(Icons.history_rounded,
                      'Aucune confirmation ni aucun changement de statut enregistré pour cette annonce.');
                }
                return ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: AppTheme.border),
                  itemBuilder: (_, i) => _row(events[i]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
'@

# ------------------------------------------------------- Verifications
foreach ($f in @($sPath, $mPath)) { if (-not (Test-Path $f)) { throw "Fichier introuvable : $f" } }
foreach ($b in @($sBak, $mBak))   { if (Test-Path $b) { throw "$b existe deja : fais -Rollback d'abord. Aucun fichier modifie." } }

$sRaw = [System.IO.File]::ReadAllText($sPath, $utf8); $sCrlf = $sRaw.Contains("`r`n"); $s = Norm $sRaw
$mRaw = [System.IO.File]::ReadAllText($mPath, $utf8); $mCrlf = $mRaw.Contains("`r`n"); $m = Norm $mRaw

if ($s.Contains('getHistory') -or $m.Contains('_showAvailabilityHistory')) { throw "Etape 9 deja appliquee ? Aucun fichier modifie." }

$s = Replace-Once $s $s1Old $s1New 'classe AvailabilityService'
$s = Replace-Once $s $s2Old $s2New 'methode getHistory'
$m = Replace-Once $m $m1Old $m1New 'import availability_service'
$m = Replace-Once $m $m2Old $m2New 'bouton historique'
if (-not $m.EndsWith("`n")) { $m += "`n" }
$m += "`n" + (Norm $mAppend) + "`n"

# -------------------------------------------------------------- Ecriture
Copy-Item -LiteralPath $sPath -Destination $sBak
Copy-Item -LiteralPath $mPath -Destination $mBak
if ($sCrlf) { $s = $s.Replace("`n", "`r`n") }
if ($mCrlf) { $m = $m.Replace("`n", "`r`n") }
[System.IO.File]::WriteAllText($sPath, $s, $utf8)
[System.IO.File]::WriteAllText($mPath, $m, $utf8)

Write-Host ""
Write-Host "Etape 9 appliquee."
Write-Host "  modifie : $sRel  (sauvegarde .bak-step9)"
Write-Host "    - modele AvailabilityEventItem + methode getHistory()"
Write-Host "  modifie : $mRel  (sauvegarde .bak-step9)"
Write-Host "    - bouton 'Historique des confirmations' sur chaque annonce"
Write-Host "    - feuille datee des confirmations et changements de statut"
Write-Host ""
Write-Host "Ensuite : flutter analyze, puis teste dans Mes annonces."
Write-Host "Annuler : .\step9-historique.ps1 -Rollback"
