// lib/widgets/availability_actions.dart
// Actions liées à la disponibilité d'une annonce (cahier des charges §5.2, §5.3,
// §6.3, §7.3, §7.5 ; exigences VIS-01, VIS-02, SIG-01) :
//  • demandeur : « Demander une confirmation », « Organiser une visite »,
//    « Signaler l'annonce » ;
//  • annonceur : « Le bien est toujours disponible », « loué », « vendu ».

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart' show localeNotifier;
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/availability_service.dart';
import '../theme/app_theme.dart';
import 'auth_gate.dart';
import 'availability_widgets.dart';

String _t(String fr, String en) => localeNotifier.value.languageCode == 'en' ? en : fr;

void _toast(BuildContext context, String message, {bool error = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    behavior: SnackBarBehavior.floating,
    backgroundColor: error ? AppTheme.error : null,
  ));
}

/// Sélecteur de créneau (date puis heure). Retourne null si annulé.
Future<DateTime?> pickSlot(BuildContext context) async {
  final now = DateTime.now();
  final d = await showDatePicker(
    context: context,
    initialDate: now.add(const Duration(days: 1)),
    firstDate: now,
    lastDate: now.add(const Duration(days: 90)),
  );
  if (d == null || !context.mounted) return null;
  final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
  if (t == null) return null;
  return DateTime(d.year, d.month, d.day, t.hour, t.minute);
}

/// Boutons affichés sur la page d'une annonce.
class AvailabilityActionsRow extends StatelessWidget {
  final PropertyModel property;
  final VoidCallback? onChanged;
  const AvailabilityActionsRow({super.key, required this.property, this.onChanged});

  bool get _isOwner {
    final me = AuthService.instance.currentUser?.id;
    return me != null && me.isNotEmpty && me == property.proprietaire.id;
  }

  @override
  Widget build(BuildContext context) {
    final state = property.availabilityState;
    final closed = state == AvailabilityState.unavailable ||
        state == AvailabilityState.archived ||
        state == AvailabilityState.suspended;

    if (_isOwner) return _ownerActions(context);

    return Wrap(spacing: 8, runSpacing: 8, children: [
      if (!closed) ...[
        ElevatedButton.icon(
          onPressed: () => _openRequest(context, AvailabilityRequestType.confirmation),
          icon: const Icon(Icons.fact_check_outlined, size: 16),
          label: Text(_t('Demander une confirmation', 'Ask for confirmation')),
        ),
        OutlinedButton.icon(
          onPressed: () => _openRequest(context, AvailabilityRequestType.visit),
          icon: const Icon(Icons.event_available_outlined, size: 16),
          label: Text(_t('Organiser une visite', 'Plan a visit')),
        ),
      ],
      TextButton.icon(
        onPressed: () => _openReport(context),
        icon: const Icon(Icons.flag_outlined, size: 16),
        label: Text(_t("Signaler l'annonce", 'Report listing')),
      ),
    ]);
  }

  // ── Annonceur : mises à jour simples (§7.3), sans sollicitation lourde ────
  Widget _ownerActions(BuildContext context) {
    final canRent = property.listingType != ListingType.vente;
    final canSell = property.listingType != ListingType.location;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_t('Mettre à jour la disponibilité', 'Update availability'),
          style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ElevatedButton.icon(
          onPressed: () => _declare(context, DeclaredAvailability.available, confirm: false),
          icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
          label: Text(_t('Le bien est toujours disponible', 'Still available')),
        ),
        if (canRent)
          OutlinedButton.icon(
            onPressed: () => _declare(context, DeclaredAvailability.rented),
            icon: const Icon(Icons.key_rounded, size: 16),
            label: Text(_t('Le bien est loué', 'Property rented')),
          ),
        if (canSell)
          OutlinedButton.icon(
            onPressed: () => _declare(context, DeclaredAvailability.sold),
            icon: const Icon(Icons.sell_outlined, size: 16),
            label: Text(_t('Le bien est vendu', 'Property sold')),
          ),
      ]),
    ]);
  }

  Future<void> _declare(BuildContext context, String status, {bool confirm = true}) async {
    if (confirm) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(_t('Retirer des offres actives ?', 'Remove from active offers?')),
          content: Text(_t(
              "L'annonce ne sera plus présentée comme une offre disponible. Vous pourrez la republier plus tard.",
              'The listing will no longer be shown as an available offer. You can republish it later.')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t('Annuler', 'Cancel'))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_t('Confirmer', 'Confirm'))),
          ],
        ),
      );
      if (ok != true) return;
    }
    final err = await AvailabilityService.instance.declare(property.id, status);
    if (!context.mounted) return;
    if (err != null) {
      _toast(context, err, error: true);
    } else {
      _toast(context, _t('Disponibilité mise à jour.', 'Availability updated.'));
      onChanged?.call();
    }
  }

  Future<void> _openRequest(BuildContext context, String type) async {
    if (!await requireLogin(context,
        reason: type == AvailabilityRequestType.visit
            ? _t('organiser une visite', 'plan a visit')
            : _t('demander une confirmation', 'ask for a confirmation'))) {
      return;
    }
    if (!context.mounted) return;
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _RequestSheet(property: property, type: type),
    );
    if (sent == true) {
      _toast(
          context,
          _t("Demande envoyée. L'annonceur est notifié ; sans réponse, ne considérez pas le bien comme confirmé.",
              'Request sent. The advertiser is notified; without a reply, do not treat the property as confirmed.'));
      onChanged?.call();
    }
  }

  Future<void> _openReport(BuildContext context) async {
    if (!await requireLogin(context, reason: _t('signaler une annonce', 'report a listing'))) return;
    if (!context.mounted) return;
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ReportSheet(property: property),
    );
    if (sent == true) {
      _toast(context,
          _t("Signalement envoyé. L'équipe VelQix l'examinera ; un signalement isolé n'entraîne pas de sanction automatique.",
              'Report sent. The VelQix team will review it; a single report does not trigger an automatic penalty.'));
    }
  }
}

// ─── Feuille « Demander une confirmation » / « Organiser une visite » ────────
class _RequestSheet extends StatefulWidget {
  final PropertyModel property;
  final String type;
  const _RequestSheet({required this.property, required this.type});

  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  final _note = TextEditingController();
  DateTime? _slot;
  bool _busy = false;
  String? _error;

  bool get _isVisit => widget.type == AvailabilityRequestType.visit;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _busy = true; _error = null; });
    final err = await AvailabilityService.instance.createRequest(
      widget.property.id,
      type: widget.type,
      desiredSlot: _slot,
      note: _note.text,
    );
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context, true);
    } else {
      setState(() { _busy = false; _error = err; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_isVisit ? _t('Organiser une visite', 'Plan a visit') : _t('Demander une confirmation', 'Ask for confirmation'),
                style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(widget.property.titre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
              ),
              child: Text(
                _t("L'annonceur recevra une notification et pourra confirmer, déclarer le bien indisponible ou proposer une autre date. S'il ne répond pas, la demande reste en attente ou expire : ce silence n'est jamais une garantie de disponibilité.",
                    'The advertiser will be notified and can confirm, mark the property unavailable or suggest another date. If they do not reply, the request stays pending or expires: silence is never a guarantee of availability.'),
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textPrimary, height: 1.4),
              ),
            ),
            const SizedBox(height: 12),
            if (_isVisit)
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        final s = await pickSlot(context);
                        if (s != null && mounted) setState(() => _slot = s);
                      },
                icon: const Icon(Icons.schedule_rounded, size: 16),
                label: Text(_slot == null
                    ? _t('Choisir un créneau souhaité (facultatif)', 'Pick a preferred slot (optional)')
                    : formatDateTimeFr(_slot!)),
              ),
            if (_isVisit) const SizedBox(height: 10),
            TextField(
              controller: _note,
              enabled: !_busy,
              maxLines: 3,
              maxLength: 300,
              decoration: InputDecoration(
                labelText: _t('Message (facultatif)', 'Message (optional)'),
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.error)),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_t('Envoyer la demande', 'Send request')),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Feuille « Signaler l'annonce » (§7.5) ───────────────────────────────────
class _ReportSheet extends StatefulWidget {
  final PropertyModel property;
  const _ReportSheet({required this.property});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _details = TextEditingController();
  String? _reason;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) {
      setState(() => _error = _t('Choisissez un motif.', 'Choose a reason.'));
      return;
    }
    setState(() { _busy = true; _error = null; });
    final err = await AvailabilityService.instance.report(
      widget.property.id,
      _reason!,
      details: _details.text,
    );
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context, true);
    } else {
      setState(() { _busy = false; _error = err; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_t("Signaler l'annonce", 'Report this listing'),
                style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(widget.property.titre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 10),
            for (final r in ReportReason.all)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                enabled: !_busy,
                title: Text(r.label, style: GoogleFonts.poppins(fontSize: 13)),
                leading: Icon(
                  _reason == r.code ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: _reason == r.code ? AppTheme.primary : AppTheme.textHint,
                  size: 20,
                ),
                onTap: () => setState(() => _reason = r.code),
              ),
            const SizedBox(height: 6),
            TextField(
              controller: _details,
              enabled: !_busy,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: _t('Précisions (facultatif)', 'Details (optional)'),
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.error)),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_t('Envoyer le signalement', 'Send report')),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
