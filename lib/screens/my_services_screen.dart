// lib/screens/my_services_screen.dart
// « Mes demandes de services » : vérifications, visites et entretien demandés.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/mission_model.dart';
import '../services/mission_service.dart';
import '../theme/app_theme.dart';
import '../widgets/service_request_sheet.dart';
import '../widgets/widgets.dart' show EmptyState, formatFcfa;

class MyServicesScreen extends StatefulWidget {
  const MyServicesScreen({super.key});
  @override
  State<MyServicesScreen> createState() => _MyServicesScreenState();
}

class _MyServicesScreenState extends State<MyServicesScreen> with WidgetsBindingObserver {
  List<MissionModel> _items = [];
  bool _loading = true;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Retour de la page de paiement : on recharge pour voir le nouveau statut
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final list = await MissionService.instance.getMyRequests();
      if (!mounted) return;
      setState(() {
        _items = list;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
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

  Future<void> _run(MissionModel m, Future<String?> Function() action, String ok) async {
    setState(() => _busyId = m.id);
    final err = await action();
    if (!mounted) return;
    setState(() => _busyId = null);
    if (err != null) {
      _snack(err, error: true);
      return;
    }
    _snack(ok);
    _load(silent: true);
  }

  Future<void> _pay(MissionModel m) async {
    setState(() => _busyId = m.id);
    try {
      final url = await MissionService.instance.checkout(m.id);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _dispute(MissionModel m) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contester la prestation'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Que s\'est-il passé ?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Envoyer')),
        ],
      ),
    );
    ctrl.dispose();
    if (reason == null || reason.isEmpty || !mounted) return;
    await _run(m, () => MissionService.instance.dispute(m.id, reason), 'Contestation envoyée.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mes demandes de services',
            style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await showServiceRequestSheet(context);
          if (mounted) _load(silent: true);
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouveau service'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(icon: Icons.cloud_off_rounded, title: _error!, buttonLabel: 'Réessayer', onButton: _load)
              : _items.isEmpty
                  ? const EmptyState(
                      icon: Icons.fact_check_outlined,
                      title: 'Aucune demande pour le moment',
                      subtitle: 'Faites vérifier un bien, organisez une visite ou demandez un entretien.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (_, i) => _card(_items[i]),
                          ),
                        ),
                      ),
                    ),
    );
  }

  Widget _card(MissionModel m) {
    final busy = _busyId == m.id;
    final color = MissionStatus.color(m.status);
    final canCancel = !m.isPaid &&
        (m.status == MissionStatus.devis ||
            m.status == MissionStatus.devisPropose ||
            m.status == MissionStatus.attentePaiement);
    final needsClientValidation =
        m.type == MissionType.entretien && m.status == MissionStatus.rapportSoumis;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(MissionType.icon(m.type), color: AppTheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(MissionType.label(m.type),
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(MissionStatus.label(m.status),
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(m.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
        if (m.address.isNotEmpty)
          Text(m.address,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
        if (m.price > 0) ...[
          const SizedBox(height: 4),
          Text('${formatFcfa(m.price)} · ${m.isPaid ? 'payé' : 'non payé'}',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
        ],
        if (m.reportNote.isNotEmpty && m.status == MissionStatus.validee) ...[
          const SizedBox(height: 6),
          Text('Rapport : ${m.reportNote}',
              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
        ],
        if (busy)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: LinearProgressIndicator(minHeight: 3),
          )
        else if (m.isPayable || canCancel || needsClientValidation) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (m.isPayable)
              ElevatedButton.icon(
                onPressed: () => _pay(m),
                icon: const Icon(Icons.payments_rounded, size: 16),
                label: Text(m.status == MissionStatus.devisPropose ? 'Accepter et payer' : 'Payer'),
              ),
            if (needsClientValidation)
              ElevatedButton.icon(
                onPressed: () => _run(m, () => MissionService.instance.confirm(m.id), 'Prestation validée.'),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Valider la prestation'),
              ),
            if (needsClientValidation)
              OutlinedButton(onPressed: () => _dispute(m), child: const Text('Contester')),
            if (canCancel)
              OutlinedButton(
                onPressed: () => _run(m, () => MissionService.instance.cancel(m.id), 'Demande annulée.'),
                child: const Text('Annuler'),
              ),
          ]),
        ],
      ]),
    );
  }
}
