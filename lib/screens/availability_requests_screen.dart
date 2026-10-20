// lib/screens/availability_requests_screen.dart
// « Visites et confirmations » : demandes envoyées (demandeur) et reçues
// (annonceur). Cahier des charges §6.3, VIS-01, VIS-02.
//
// Règle d'affichage : une demande sans réponse reste « en attente » ou
// « expirée » ; elle n'est JAMAIS présentée comme une confirmation.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/availability_service.dart';
import '../theme/app_theme.dart';
import '../widgets/availability_actions.dart' show pickSlot;
import '../widgets/availability_widgets.dart' show formatDateTimeFr;
import '../widgets/widgets.dart' show EmptyState;

class AvailabilityRequestsScreen extends StatefulWidget {
  const AvailabilityRequestsScreen({super.key});
  @override
  State<AvailabilityRequestsScreen> createState() => _AvailabilityRequestsScreenState();
}

class _AvailabilityRequestsScreenState extends State<AvailabilityRequestsScreen> {
  List<AvailabilityRequest> _received = [];
  List<AvailabilityRequest> _sent = [];
  bool _loading = true;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      // Un utilisateur qui n'a pas d'annonce reçoit simplement une liste vide.
      final results = await Future.wait([
        AvailabilityService.instance.getReceived().catchError((_) => <AvailabilityRequest>[]),
        AvailabilityService.instance.getMine(),
      ]);
      if (!mounted) return;
      setState(() {
        _received = results[0];
        _sent = results[1];
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

  Future<void> _respond(AvailabilityRequest r, String response) async {
    DateTime? slot;
    if (response == AvailabilityResponse.proposeSlot) {
      slot = await pickSlot(context);
      if (slot == null || !mounted) return;
    }
    setState(() => _busyId = r.id);
    final err = await AvailabilityService.instance.respond(r.id, response: response, proposedSlot: slot);
    if (!mounted) return;
    setState(() => _busyId = null);
    if (err != null) {
      _snack(err, error: true);
      return;
    }
    _snack('Réponse envoyée.');
    _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Visites et confirmations', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          bottom: TabBar(tabs: [
            Tab(text: 'Reçues${_received.where((r) => r.isPending).isEmpty ? '' : ' (${_received.where((r) => r.isPending).length})'}'),
            const Tab(text: 'Envoyées'),
          ]),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_error!, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 13)),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
                      ]),
                    ),
                  )
                : TabBarView(children: [
                    _list(_received, received: true),
                    _list(_sent, received: false),
                  ]),
      ),
    );
  }

  Widget _list(List<AvailabilityRequest> items, {required bool received}) {
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.event_available_outlined,
        title: received ? 'Aucune demande reçue' : 'Aucune demande envoyée',
        subtitle: received
            ? 'Les demandes de confirmation et de visite sur vos annonces apparaîtront ici.'
            : 'Depuis une annonce, utilisez « Demander une confirmation » ou « Organiser une visite ».',
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _card(items[i], received: received),
      ),
    );
  }

  ({String label, Color color}) _statusInfo(AvailabilityRequest r, bool received) {
    switch (r.status) {
      case AvailabilityRequestStatus.available:
        return (label: 'Disponibilité confirmée', color: AppTheme.success);
      case AvailabilityRequestStatus.unavailable:
        return (label: 'Indisponible', color: AppTheme.error);
      case AvailabilityRequestStatus.slotProposed:
        return (label: 'Autre créneau proposé', color: AppTheme.info);
      case AvailabilityRequestStatus.expired:
        return (label: 'Expirée, sans réponse', color: AppTheme.textSecondary);
      case AvailabilityRequestStatus.cancelled:
        return (label: 'Annulée', color: AppTheme.textSecondary);
      default:
        return (label: 'En attente de réponse', color: AppTheme.warning);
    }
  }

  Widget _card(AvailabilityRequest r, {required bool received}) {
    final st = _statusInfo(r, received);
    final busy = _busyId == r.id;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(r.isVisit ? Icons.event_available_outlined : Icons.fact_check_outlined,
              size: 18, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(r.propertyTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          '${r.isVisit ? 'Demande de visite' : 'Demande de confirmation'}'
          '${received ? ' · ${r.requesterName}' : ''} · ${formatDateTimeFr(r.createdAt)}',
          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
        ),
        if (r.desiredSlot != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Créneau souhaité : ${formatDateTimeFr(r.desiredSlot!)}',
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textPrimary)),
          ),
        if ((r.note ?? '').trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('« ${r.note!.trim()} »',
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
          ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: st.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(st.label,
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: st.color)),
        ),
        if (r.status == AvailabilityRequestStatus.slotProposed && r.proposedSlot != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Créneau proposé : ${formatDateTimeFr(r.proposedSlot!)}',
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textPrimary)),
          ),
        if (r.isPending && !received)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              "Sans réponse de l'annonceur, ne considérez pas le bien comme confirmé.",
              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ),
        if (r.status == AvailabilityRequestStatus.expired)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              "Aucune réponse reçue : l'absence de réponse n'est pas une confirmation.",
              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ),
        if (received && r.isPending) ...[
          const SizedBox(height: 10),
          if (busy)
            const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              ElevatedButton(
                onPressed: () => _respond(r, AvailabilityResponse.available),
                child: const Text('Toujours disponible'),
              ),
              OutlinedButton(
                onPressed: () => _respond(r, AvailabilityResponse.unavailable),
                child: const Text('Indisponible'),
              ),
              if (r.isVisit)
                OutlinedButton(
                  onPressed: () => _respond(r, AvailabilityResponse.proposeSlot),
                  child: const Text('Autre créneau'),
                ),
            ]),
        ],
      ]),
    );
  }
}
