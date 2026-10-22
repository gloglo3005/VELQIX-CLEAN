// lib/screens/demarcheur_screen.dart
// Interface démarcheur : voir les biens à vérifier, se rendre sur le terrain et
// confirmer que le bien existe réellement. Une annonce vérifiée est marquée
// « vérifiée sur le terrain » (avec la date et les limites du contrôle).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/verification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/net_image.dart';
import '../widgets/widgets.dart' show EmptyState;
import 'main_shell.dart';
import 'property_detail_screen.dart';

class DemarcheurScreen extends StatefulWidget {
  const DemarcheurScreen({super.key});
  @override
  State<DemarcheurScreen> createState() => _DemarcheurScreenState();
}

class _DemarcheurScreenState extends State<DemarcheurScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final Map<VerificationScope, List<PropertyModel>> _data = {};
  final Map<VerificationScope, String?> _errors = {};
  final Set<VerificationScope> _loading = {};

  static const _scopes = [VerificationScope.requested, VerificationScope.all, VerificationScope.mine];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _scopes.length, vsync: this);
    for (final s in _scopes) {
      _load(s);
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load(VerificationScope scope) async {
    setState(() {
      _loading.add(scope);
      _errors[scope] = null;
    });
    try {
      final list = await VerificationService.instance.getQueue(scope);
      if (!mounted) return;
      setState(() => _data[scope] = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errors[scope] = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading.remove(scope));
    }
  }

  void _reloadAll() {
    for (final s in _scopes) {
      _load(s);
    }
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainShell(username: '')),
      (_) => false,
    );
  }

  Future<void> _openVerify(PropertyModel p) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _VerifySheet(property: p),
    );
    if (done == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Bien vérifié : l\'annonce est maintenant marquée « vérifiée sur le terrain ».'),
        behavior: SnackBarBehavior.floating,
      ));
      _reloadAll();
    }
  }

  Future<void> _call(String phone) async {
    await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  @override
  Widget build(BuildContext context) {
    final me = AuthService.instance.currentUserOrEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Espace démarcheur',
              style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700)),
          Text(me.fullName, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w400)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Parcourir les annonces',
            icon: const Icon(Icons.storefront_rounded),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => MainShell(username: AuthService.instance.loggedUsername))),
          ),
          IconButton(tooltip: 'Se déconnecter', icon: const Icon(Icons.logout_rounded), onPressed: _logout),
        ],
        bottom: TabBar(
          controller: _tab,
          labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'Demandes'), Tab(text: 'Autres annonces'), Tab(text: 'Mes vérifications')],
        ),
      ),
      body: TabBarView(controller: _tab, children: [for (final s in _scopes) _buildList(s)]),
    );
  }

  Widget _buildList(VerificationScope scope) {
    if (_loading.contains(scope) && !_data.containsKey(scope)) {
      return const Center(child: CircularProgressIndicator());
    }
    final err = _errors[scope];
    if (err != null && !_data.containsKey(scope)) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: err,
        buttonLabel: 'Réessayer',
        onButton: () => _load(scope),
      );
    }
    final list = _data[scope] ?? [];
    if (list.isEmpty) {
      return EmptyState(
        icon: scope == VerificationScope.mine ? Icons.fact_check_outlined : Icons.task_alt_rounded,
        title: scope == VerificationScope.requested
            ? 'Aucune demande pour le moment'
            : scope == VerificationScope.mine
                ? "Vous n'avez encore rien vérifié"
                : 'Aucune annonce à vérifier',
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(scope),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _card(list[i], scope),
          ),
        ),
      ),
    );
  }

  Widget _card(PropertyModel p, VerificationScope scope) {
    final phone = p.proprietaire.telephone;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: NetImage(url: p.firstImage, width: 84, height: 84, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.titre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('${p.categorieLabel} · ${p.adresse.full}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              Text('Propriétaire : ${p.proprietaire.fullName}',
                  style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
              if (scope == VerificationScope.requested)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Vérification demandée par le propriétaire',
                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.accent)),
                ),
              if (p.fieldVerified)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Text('Vérifié sur le terrain',
                        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF0F5132))),
                  ]),
                ),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => PropertyDetailScreen(property: p))),
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: const Text('Voir'),
          ),
          if (phone.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () => _call(phone),
              icon: const Icon(Icons.call_rounded, size: 16),
              label: const Text('Appeler'),
            ),
          if (!p.fieldVerified)
            ElevatedButton.icon(
              onPressed: () => _openVerify(p),
              icon: const Icon(Icons.fact_check_rounded, size: 16),
              label: const Text('Vérifier sur place'),
            ),
        ]),
      ]),
    );
  }
}

// ─── Feuille de validation terrain ───────────────────────────────────────────
class _VerifySheet extends StatefulWidget {
  final PropertyModel property;
  const _VerifySheet({required this.property});
  @override
  State<_VerifySheet> createState() => _VerifySheetState();
}

class _VerifySheetState extends State<_VerifySheet> {
  bool _exists = false;
  bool _photos = false;
  bool _owner = false;
  bool _saving = false;
  String? _error;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _canSubmit => _exists && _photos && _owner && !_saving;

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await VerificationService.instance.verify(
      widget.property.id,
      exists: _exists,
      photosMatch: _photos,
      ownerIdentified: _owner,
      note: _note.text,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _saving = false;
        _error = err;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Vérification sur le terrain',
                style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(widget.property.titre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Text(
              'En validant, vous certifiez vous être rendu sur place. L\'annonce sera marquée '
              '« vérifiée sur le terrain » avec la date de votre visite. Cette vérification '
              'ne prouve pas la propriété et ne garantit pas la disponibilité future du bien : '
              'indiquez clairement dans votre note ce que vous avez réellement contrôlé.',
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _exists,
              onChanged: (v) => setState(() => _exists = v ?? false),
              title: Text("Le bien existe réellement à l'adresse indiquée",
                  style: GoogleFonts.poppins(fontSize: 13)),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _photos,
              onChanged: (v) => setState(() => _photos = v ?? false),
              title: Text('Les photos correspondent au bien visité', style: GoogleFonts.poppins(fontSize: 13)),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _owner,
              onChanged: (v) => setState(() => _owner = v ?? false),
              title: Text('Le propriétaire ou son mandataire a été rencontré et identifié',
                  style: GoogleFonts.poppins(fontSize: 13)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Note (facultatif)', alignLabelWithHint: true),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.error)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canSubmit ? _submit : null,
                child: _saving
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Confirmer la vérification'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
