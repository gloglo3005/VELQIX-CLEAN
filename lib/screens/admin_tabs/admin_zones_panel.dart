// lib/screens/admin_tabs/admin_zones_panel.dart
// Zones de couverture et tarifs par zone (GEO-01, GEO-02).
//
// • Tant qu'aucune zone n'existe, la couverture n'est pas limitée.
// • Dès qu'une zone existe, seules les zones « desservies » reçoivent des demandes de services.
// • Vérification : le tarif de la zone est facturé automatiquement (sinon tarif général).
// • Visite / entretien : le tarif de la zone sert de référence et pré-remplit le devis.
// Chaque modification est enregistrée dans le journal d'activité côté serveur.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/mission_model.dart';
import '../../services/zone_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart' show formatFcfa;
import 'admin_common.dart';

const _rateTypes = [MissionType.verification, MissionType.visite, MissionType.entretien];

int _toInt(String s) => int.tryParse(s.trim().replaceAll(RegExp(r'\s'), '')) ?? 0;

class AdminZonesPanel extends StatefulWidget {
  const AdminZonesPanel({super.key});

  @override
  State<AdminZonesPanel> createState() => _AdminZonesPanelState();
}

class _AdminZonesPanelState extends State<AdminZonesPanel> {
  List<AdminZone> _zones = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final z = await ZoneService.instance.adminList();
      if (!mounted) return;
      setState(() => _zones = z);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Exécute une action serveur, affiche le résultat et recharge la liste.
  Future<void> _run(Future<String?> Function() action, String okMessage) async {
    final err = await action();
    if (!mounted) return;
    if (err != null) {
      adminSnack(context, err, error: true);
      return;
    }
    adminSnack(context, okMessage);
    await _load();
  }

  // ─── Zone : création / modification ───────────────────────────────────────
  Future<void> _editZone([AdminZone? zone]) async {
    final name = TextEditingController(text: zone?.name ?? '');
    final country = TextEditingController(text: zone?.country ?? 'TG');
    final aliases = TextEditingController(text: zone?.aliases.join(', ') ?? '');
    final note = TextEditingController(text: zone?.note ?? '');
    var active = zone?.isActive ?? true;
    String? error;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        return AlertDialog(
          title: Text(zone == null ? 'Nouvelle zone' : 'Modifier la zone',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom de la zone (ex. Lomé)')),
              const SizedBox(height: 10),
              TextField(
                controller: country,
                maxLength: 2,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Pays (code à 2 lettres)'),
              ),
              TextField(
                controller: aliases,
                decoration: const InputDecoration(
                  labelText: 'Autres noms (séparés par des virgules)',
                  helperText: 'Quartiers ou orthographes reconnus comme cette zone',
                  helperMaxLines: 2,
                ),
              ),
              const SizedBox(height: 10),
              TextField(controller: note, decoration: const InputDecoration(labelText: 'Note interne (facultatif)')),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Zone desservie', style: GoogleFonts.poppins(fontSize: 13)),
                subtitle: Text('Désactivée : les demandes dans cette zone sont refusées.',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                value: active,
                onChanged: (v) => setD(() => active = v),
              ),
              if (error != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(error!, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.error)),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            TextButton(
              onPressed: () {
                if (name.text.trim().isEmpty) {
                  setD(() => error = 'Le nom de la zone est obligatoire.');
                  return;
                }
                if (country.text.trim().length != 2) {
                  setD(() => error = 'Le pays doit être un code à 2 lettres (ex. TG).');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      }),
    );

    final nameValue = name.text.trim();
    final countryValue = country.text.trim().toUpperCase();
    final aliasValues = aliases.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final noteValue = note.text.trim();
    final activeValue = active;
    name.dispose();
    country.dispose();
    aliases.dispose();
    note.dispose();
    if (ok != true || !mounted) return;

    if (zone == null) {
      await _run(
        () => ZoneService.instance.createZone(
          name: nameValue,
          country: countryValue,
          aliases: aliasValues,
          isActive: activeValue,
          note: noteValue,
        ),
        'Zone créée.',
      );
    } else {
      await _run(
        () => ZoneService.instance.updateZone(
          zone.id,
          name: nameValue,
          country: countryValue,
          aliases: aliasValues,
          isActive: activeValue,
          note: noteValue,
        ),
        'Zone mise à jour.',
      );
    }
  }

  Future<void> _toggle(AdminZone z, bool active) async {
    if (!active) {
      final ok = await adminConfirm(
        context,
        title: 'Suspendre la zone ?',
        message: 'Les demandes de services dans « ${z.name} » seront refusées tant que la zone ne sera pas '
            "réactivée. L'action est enregistrée dans le journal d'activité.",
        confirmLabel: 'Suspendre',
        danger: true,
      );
      if (!ok || !mounted) return;
    }
    await _run(() => ZoneService.instance.setActive(z.id, active), active ? 'Zone réactivée.' : 'Zone suspendue.');
  }

  Future<void> _delete(AdminZone z) async {
    final ok = await adminConfirm(
      context,
      title: 'Supprimer la zone ?',
      message: '« ${z.name} » et ses tarifs seront supprimés. Les missions déjà créées gardent le nom de leur zone. '
          "Attention : s'il ne reste aucune zone, la couverture n'est plus limitée.",
      confirmLabel: 'Supprimer',
      danger: true,
    );
    if (!ok || !mounted) return;
    await _run(() => ZoneService.instance.deleteZone(z.id), 'Zone supprimée.');
  }

  // ─── Tarifs de la zone ────────────────────────────────────────────────────
  Future<void> _editRates(AdminZone z) async {
    final price = <String, TextEditingController>{};
    final pay = <String, TextEditingController>{};
    final transport = <String, TextEditingController>{};
    for (final t in _rateTypes) {
      final r = z.rates[t];
      price[t] = TextEditingController(text: r?.price.toString() ?? '');
      pay[t] = TextEditingController(text: r?.agentPay.toString() ?? '');
      transport[t] = TextEditingController(text: r == null ? '' : r.transport.toString());
    }
    String? error;

    bool isBlank(String t) => price[t]!.text.trim().isEmpty && pay[t]!.text.trim().isEmpty && transport[t]!.text.trim().isEmpty;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        Widget field(TextEditingController c, String label) => Expanded(
              child: TextField(
                controller: c,
                keyboardType: TextInputType.number,
                onChanged: (_) => setD(() => error = null),
                decoration: InputDecoration(labelText: label, isDense: true),
              ),
            );
        return AlertDialog(
          title: Text('Tarifs : ${z.name}', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(
                  'Laisse les trois champs vides pour utiliser le tarif général. '
                  'Vérification : tarif facturé dans la zone. Visite et entretien : tarif de référence du devis.',
                  style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                ),
                for (final t in _rateTypes) ...[
                  const SizedBox(height: 14),
                  Text(MissionType.label(t), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Row(children: [
                    field(price[t]!, 'Prix client (F)'),
                    const SizedBox(width: 8),
                    field(pay[t]!, 'Agent (F)'),
                    const SizedBox(width: 8),
                    field(transport[t]!, 'Transport (F)'),
                  ]),
                  if (!isBlank(t))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Builder(builder: (_) {
                        final margin = _toInt(price[t]!.text) - _toInt(pay[t]!.text) - _toInt(transport[t]!.text);
                        return Text('Marge avant frais de paiement : ${formatFcfa(margin.toDouble())}',
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: margin > 0 ? AppTheme.success : AppTheme.error));
                      }),
                    ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.error)),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            TextButton(
              onPressed: () {
                for (final t in _rateTypes) {
                  if (isBlank(t)) continue;
                  final p = _toInt(price[t]!.text), a = _toInt(pay[t]!.text), tr = _toInt(transport[t]!.text);
                  if (p <= 0 || a <= 0) {
                    setD(() => error = '${MissionType.label(t)} : renseigne le prix et la rémunération de l\'agent.');
                    return;
                  }
                  if (p < a + tr) {
                    setD(() => error = '${MissionType.label(t)} : le prix doit couvrir l\'agent et le transport.');
                    return;
                  }
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      }),
    );

    // Tarifs à envoyer : nouveau tarif, ou null si la zone en avait un et qu'il est vidé.
    final toSend = <String, ZoneRate?>{};
    for (final t in _rateTypes) {
      if (isBlank(t)) {
        if (z.rates[t] != null) toSend[t] = null;
      } else {
        toSend[t] = ZoneRate(price: _toInt(price[t]!.text), agentPay: _toInt(pay[t]!.text), transport: _toInt(transport[t]!.text));
      }
    }
    for (final c in [...price.values, ...pay.values, ...transport.values]) {
      c.dispose();
    }
    if (ok != true || !mounted) return;
    if (toSend.isEmpty) {
      adminSnack(context, 'Aucune modification.');
      return;
    }
    final confirmed = await adminConfirm(
      context,
      title: 'Modifier les tarifs ?',
      message: 'Les nouveaux tarifs de « ${z.name} » s\'appliquent aux prochaines demandes. '
          "Les missions déjà créées ne changent pas. L'action est enregistrée dans le journal d'activité.",
      confirmLabel: 'Enregistrer',
      danger: true,
    );
    if (!confirmed || !mounted) return;
    await _run(() => ZoneService.instance.saveRates(z.id, toSend), 'Tarifs enregistrés.');
  }

  // ─── Rendu ────────────────────────────────────────────────────────────────
  String _rateLine(AdminZone z, String type) {
    final r = z.rates[type];
    if (r == null) {
      return type == MissionType.verification ? 'tarif général' : 'aucun tarif de référence';
    }
    return '${formatFcfa(r.price.toDouble())} · agent ${formatFcfa(r.agentPay.toDouble())} · transport ${formatFcfa(r.transport.toDouble())}';
  }

  Widget _card(AdminZone z) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${z.name} · ${z.country}',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          AdminBadge(z.isActive ? 'Desservie' : 'Suspendue', z.isActive ? AppTheme.success : AppTheme.warning),
        ]),
        if (z.aliases.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Reconnue aussi comme : ${z.aliases.join(', ')}',
              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
        ],
        if (z.note != null) ...[
          const SizedBox(height: 2),
          Text(z.note!, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint)),
        ],
        const SizedBox(height: 8),
        for (final t in _rateTypes)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text('${MissionType.label(t)} : ${_rateLine(z, t)}',
                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
          ),
        const SizedBox(height: 6),
        Wrap(spacing: 4, runSpacing: 0, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Switch(value: z.isActive, onChanged: (v) => _toggle(z, v)),
          TextButton.icon(
            onPressed: () => _editZone(z),
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: const Text('Modifier'),
          ),
          TextButton.icon(
            onPressed: () => _editRates(z),
            icon: const Icon(Icons.payments_rounded, size: 16),
            label: const Text('Tarifs'),
          ),
          TextButton.icon(
            onPressed: () => _delete(z),
            icon: Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.error),
            label: Text('Supprimer', style: TextStyle(color: AppTheme.error)),
          ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _zones.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null && _zones.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: AppTheme.warning),
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 13)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Réessayer')),
          ]),
        ),
      );
    }
    final served = _zones.where((z) => z.isActive).length;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                _zones.isEmpty
                    ? "Aucune zone n'est définie : la couverture n'est pas limitée. Dès qu'une zone existe, "
                        'seules les zones desservies reçoivent des demandes de services.'
                    : '$served zone${served > 1 ? "s" : ""} desservie${served > 1 ? "s" : ""} sur ${_zones.length}. '
                        "Les demandes de services en dehors des zones desservies sont refusées.",
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: () => _editZone(),
                  icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                  label: const Text('Ajouter une zone'),
                ),
              ),
              const SizedBox(height: 14),
              for (final z in _zones) _card(z),
            ],
          ),
        ),
      ),
    );
  }
}
