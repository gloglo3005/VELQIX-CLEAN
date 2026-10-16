// lib/screens/admin_tabs/admin_properties_tab.dart
// Gestion de TOUTES les annonces (tous statuts) : filtres, modération, suppression.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../services/admin_service.dart';
import '../../services/property_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart' show pendingPropertiesNotifier, publishedPropertiesNotifier;
import 'admin_common.dart';

class AdminPropertiesTab extends StatefulWidget {
  const AdminPropertiesTab({super.key});
  @override
  State<AdminPropertiesTab> createState() => _AdminPropertiesTabState();
}

class _AdminPropertiesTabState extends State<AdminPropertiesTab> {
  List<PropertyModel> _all = [];
  bool _loading = true;
  bool _limited = false; // true = route admin absente, liste partielle
  String _q = '';
  String _status = 'all';
  String _type = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    var list = await AdminService.instance.getAllProperties();
    _limited = list == null;
    if (list == null) {
      // Repli : annonces publiques approuvées + annonces en attente déjà chargées
      final approved = await PropertyService.instance.getProperties();
      final pending = pendingPropertiesNotifier.value.whereType<PropertyModel>().toList();
      final ids = <String>{};
      list = [...pending, ...approved].where((p) => ids.add(p.id)).toList();
    }
    if (!mounted) return;
    setState(() {
      _all = list!;
      _loading = false;
    });
  }

  List<PropertyModel> get _filtered {
    final q = _q.trim().toLowerCase();
    return _all.where((p) {
      if (_status != 'all' && p.status != _status) return false;
      if (_type == 'immobilier' && p.type != PropertyType.immobilier) return false;
      if (_type == 'mobilier' && p.type != PropertyType.mobilier) return false;
      if (q.isEmpty) return true;
      return [p.titre, p.adresse.ville, p.categorieLabel, p.proprietaire.fullName]
          .join(' ')
          .toLowerCase()
          .contains(q);
    }).toList();
  }

  Future<void> _act(Future<String?> Function() action, String okMsg, {String? removeFromPending}) async {
    final err = await action();
    if (!mounted) return;
    if (err != null) {
      adminSnack(context, err, error: true);
      return;
    }
    if (removeFromPending != null) {
      pendingPropertiesNotifier.value =
          pendingPropertiesNotifier.value.where((x) => (x as PropertyModel).id != removeFromPending).toList();
    }
    // Prévient l'accueil / explorer de se recharger
    publishedPropertiesNotifier.value = [...publishedPropertiesNotifier.value];
    adminSnack(context, okMsg);
    _load();
  }

  Future<void> _delete(PropertyModel p) async {
    final ok = await adminConfirm(context,
        title: 'Supprimer cette annonce ?',
        message: '« ${p.titre} » sera définitivement supprimée.',
        confirmLabel: 'Supprimer',
        danger: true);
    if (!ok) return;
    await _act(() => AdminService.instance.deleteProperty(p.id), 'Annonce supprimée.',
        removeFromPending: p.id);
  }

  Color _statusColor(String s) =>
      s == 'approuve' ? AppTheme.success : (s == 'rejete' ? AppTheme.error : AppTheme.warning);
  String _statusLabel(String s) =>
      s == 'approuve' ? 'Approuvée' : (s == 'rejete' ? 'Rejetée' : 'En attente');

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final list = _filtered;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_limited)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: Text(
                      "Liste partielle : la route GET /admin/properties n'est pas encore disponible côté API "
                      '(annonces approuvées + en attente chargées seulement).',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textPrimary)),
                ),
              TextField(
                onChanged: (v) => setState(() => _q = v),
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Rechercher par titre, ville, catégorie, propriétaire…',
                  prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textHint),
                ),
              ),
              const SizedBox(height: 10),
              AdminChipRow(
                selected: _status,
                onSelected: (v) => setState(() => _status = v),
                items: const [
                  MapEntry('all', 'Tous statuts'),
                  MapEntry('en_attente', 'En attente'),
                  MapEntry('approuve', 'Approuvées'),
                  MapEntry('rejete', 'Rejetées'),
                ],
              ),
              const SizedBox(height: 6),
              AdminChipRow(
                selected: _type,
                onSelected: (v) => setState(() => _type = v),
                items: const [
                  MapEntry('all', 'Tous types'),
                  MapEntry('immobilier', 'Immobilier'),
                  MapEntry('mobilier', 'Véhicules'),
                ],
              ),
              const SizedBox(height: 6),
              Text('${list.length} annonce${list.length > 1 ? 's' : ''}',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
            ]),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: list.isEmpty
                  ? ListView(children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: Center(
                          child: Text('Aucune annonce ne correspond.',
                              style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
                        ),
                      ),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _card(list[i]),
                    ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _card(PropertyModel p) {
    final money = p.prix.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 72,
            height: 72,
            child: p.firstImage.isEmpty
                ? Container(color: AppTheme.border, child: const Icon(Icons.image_not_supported_outlined))
                : Image.network(p.firstImage,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: AppTheme.border, child: const Icon(Icons.broken_image_outlined))),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.titre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            Text('${p.categorieLabel} · ${p.listingLabel} · ${p.adresse.ville}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
            Text('$money FCFA · par ${p.proprietaire.fullName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              AdminBadge(_statusLabel(p.status), _statusColor(p.status)),
              if (p.status != 'approuve')
                _miniAction('Approuver', AppTheme.success,
                    () => _act(() => AdminService.instance.approveProperty(p.id), 'Annonce approuvée.',
                        removeFromPending: p.id)),
              if (p.status != 'rejete')
                _miniAction('Rejeter', AppTheme.warning,
                    () => _act(() => AdminService.instance.rejectProperty(p.id), 'Annonce rejetée.',
                        removeFromPending: p.id)),
              _miniAction('Supprimer', AppTheme.error, () => _delete(p)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _miniAction(String label, Color color, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ),
      );
}
