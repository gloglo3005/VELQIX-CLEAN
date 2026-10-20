// lib/screens/spaces_screen.dart
// « Mes espaces » : un seul compte, plusieurs espaces autorisés.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/spaces_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart' show EmptyState;
import 'business_space_screen.dart';
import 'plans_screen.dart';
import 'pro_space_screen.dart';

class SpacesScreen extends StatefulWidget {
  const SpacesScreen({super.key});
  @override
  State<SpacesScreen> createState() => _SpacesScreenState();
}

class _SpacesScreenState extends State<SpacesScreen> {
  MySpaces? _spaces;
  String? _error;
  bool _loading = true;
  bool _busy = false;

  static const _activities = <MapEntry<String, String>>[
    MapEntry('agent_immobilier', 'Agent immobilier'),
    MapEntry('demarcheur_independant', 'Démarcheur indépendant'),
    MapEntry('commercial', 'Commercial'),
    MapEntry('vendeur', 'Vendeur'),
    MapEntry('autre', 'Autre professionnel'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s = await SpacesService.instance.getMySpaces();
      if (!mounted) return;
      setState(() {
        _spaces = s;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.error : null,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _activatePro() async {
    final activity = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Votre activité'),
        children: [
          for (final a in _activities)
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, a.key), child: Text(a.value)),
        ],
      ),
    );
    if (activity == null || !mounted) return;
    setState(() => _busy = true);
    final err = await SpacesService.instance.activatePro(activity);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      _snack(err, error: true);
      return;
    }
    _snack('Espace Velqix Pro activé.');
    await _load();
  }

  Future<void> _activateBusiness() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Créer un espace entreprise'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: "Nom de l'entreprise ou de l'agence"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Créer')),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    setState(() => _busy = true);
    final err = await SpacesService.instance.activateBusiness(name);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      _snack(err, error: true);
      return;
    }
    _snack('Espace Velqix Business créé : vous en êtes l\'administrateur.');
    await _load();
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget action,
    bool active = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? AppTheme.primary.withOpacity(0.4) : AppTheme.border),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: AppTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
            Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
          ]),
        ),
        const SizedBox(width: 8),
        action,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _spaces;
    return Scaffold(
      appBar: AppBar(
        title: Text('Mes espaces', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || s == null
              ? EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: _error ?? 'Indisponible',
                  buttonLabel: 'Réessayer',
                  onButton: _load,
                )
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: ListView(padding: const EdgeInsets.all(16), children: [
                      Text(
                        'Un seul compte, plusieurs espaces : vous pouvez être propriétaire et professionnel '
                        'sans créer plusieurs comptes.',
                        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 14),
                      _card(
                        icon: Icons.person_rounded,
                        title: 'Espace personnel',
                        subtitle: 'Recherche, favoris, messages, publication de vos biens.',
                        action: const Icon(Icons.check_circle_rounded, color: AppTheme.success),
                      ),
                      _card(
                        icon: Icons.badge_rounded,
                        title: 'Velqix Pro',
                        subtitle: s.pro
                            ? 'Annonces, prospects, statistiques, abonnement.'
                            : 'Pour les agents, démarcheurs indépendants, commerciaux et vendeurs. Gratuit.',
                        active: s.pro,
                        action: s.pro
                            ? ElevatedButton(
                                onPressed: () => Navigator.push(
                                    context, MaterialPageRoute(builder: (_) => const ProSpaceScreen())),
                                child: const Text('Ouvrir'))
                            : OutlinedButton(
                                onPressed: _busy ? null : _activatePro, child: const Text('Activer')),
                      ),
                      _card(
                        icon: Icons.business_rounded,
                        title: 'Velqix Business',
                        subtitle: s.business
                            ? '${s.businessName ?? 'Entreprise'} · ${BusinessRole.label(s.businessRole ?? BusinessRole.admin)}'
                            : 'Pour les entreprises et agences : portefeuille, équipe, rapports.',
                        active: s.business,
                        action: s.business
                            ? ElevatedButton(
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => BusinessSpaceScreen(
                                            role: s.businessRole ?? BusinessRole.admin,
                                            companyName: s.businessName ?? 'Entreprise'))),
                                child: const Text('Ouvrir'))
                            : OutlinedButton(
                                onPressed: _busy ? null : _activateBusiness, child: const Text('Créer')),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => const PlansScreen())),
                        icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                        label: const Text('Voir les formules Freemium / Premium'),
                      ),
                    ]),
                  ),
                ),
    );
  }
}
