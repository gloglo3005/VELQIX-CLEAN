// lib/widgets/trust_widgets.dart
// Les 2 types d'annonces, annoncés clairement à l'utilisateur :
//  • APPROUVÉE par VelQix : bien vérifié sur le terrain par un démarcheur VelQix
//    (vérification réellement effectuée et validée). En cas de fraude, VelQix s'en charge.
//    Le Premium ne suffit PAS : il ne rend pas un bien « vérifié ».
//  • NON APPROUVÉE : bien non vérifié. En cas de fraude, VelQix ne s'en mêle pas.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart' show localeNotifier;
import '../models/models.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

String _t(String fr, String en) => localeNotifier.value.languageCode == 'en' ? en : fr;

const Color _approvedColor = Color(0xFF10B981);
const Color _unapprovedColor = Color(0xFFF59E0B);

// ─── Textes ──────────────────────────────────────────────────────────────────
String trustApprovedTitle() => _t('Annonce approuvée par VelQix', 'Listing approved by VelQix');
String trustUnapprovedTitle() => _t('Annonce non approuvée', 'Listing not approved');

String trustApprovedRule() => _t(
    "Un démarcheur VelQix s'est rendu sur le terrain et a confirmé que le bien existe réellement. En cas de fraude, VelQix s'en charge.",
    'A VelQix agent visited the site and confirmed the property really exists. In case of fraud, VelQix takes care of it.');

String trustUnapprovedRule() => _t(
    "Le bien n'a pas été vérifié sur le terrain par VelQix (un abonnement Premium ne vaut pas vérification). En cas de fraude, VelQix ne s'en mêle pas.",
    'The property has not been verified on site by VelQix (a Premium subscription is not a verification). In case of fraud, VelQix does not get involved.');

String _approvalReason(PropertyModel p) {
  {
    final who = (p.fieldVerifiedByName ?? '').trim();
    final d = p.fieldVerifiedAt;
    final date = d == null
        ? ''
        : ' (${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year})';
    return who.isEmpty
        ? _t("Vérifié sur le terrain par un démarcheur VelQix$date.",
            'Verified on site by a VelQix agent$date.')
        : _t("Vérifié sur le terrain par le démarcheur $who$date.",
            'Verified on site by agent $who$date.');
  }
}

// ─── Badge compact (cartes, listes) ──────────────────────────────────────────
class TrustBadge extends StatelessWidget {
  final PropertyModel property;
  final bool compact;
  const TrustBadge({super.key, required this.property, this.compact = true});

  @override
  Widget build(BuildContext context) {
    final ok = property.isVelqixApproved;
    final color = ok ? _approvedColor : _unapprovedColor;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: ok ? color : Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(8),
        border: ok ? null : Border.all(color: color.withOpacity(0.6)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ok ? Icons.verified_rounded : Icons.info_outline_rounded,
            size: compact ? 12 : 15, color: ok ? Colors.white : const Color(0xFFB45309)),
        const SizedBox(width: 4),
        Text(
          ok ? _t('Approuvée VelQix', 'VelQix approved') : _t('Non approuvée', 'Not approved'),
          style: GoogleFonts.poppins(
            fontSize: compact ? 10 : 12,
            fontWeight: FontWeight.w600,
            color: ok ? Colors.white : const Color(0xFFB45309),
          ),
        ),
      ]),
    );
  }
}

// ─── Encadré de la page détail ───────────────────────────────────────────────
class TrustInfoCard extends StatelessWidget {
  final PropertyModel property;
  const TrustInfoCard({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    final ok = property.isVelqixApproved;
    final color = ok ? _approvedColor : _unapprovedColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(ok ? Icons.verified_rounded : Icons.warning_amber_rounded,
              color: ok ? color : const Color(0xFFB45309), size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(ok ? trustApprovedTitle() : trustUnapprovedTitle(),
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          ),
        ]),
        const SizedBox(height: 8),
        if (ok) ...[
          Text(_approvalReason(property),
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(_t("En cas de fraude, VelQix s'en charge.", 'In case of fraud, VelQix takes care of it.'),
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
        ] else ...[
          Text(trustUnapprovedRule(),
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
              _t('Visitez le bien avant tout paiement et ne versez jamais d\'argent à l\'avance.',
                  'Visit the property before any payment and never send money in advance.'),
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
        ],
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => showTrustExplainer(context),
          child: Text(_t('Comprendre les 2 types d\'annonces', 'Understand the 2 listing types'),
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary,
                  decoration: TextDecoration.underline)),
        ),
      ]),
    );
  }
}

// ─── Les 2 définitions côte à côte ───────────────────────────────────────────
Widget _definition({required bool approved, required bool current}) {
  final color = approved ? _approvedColor : _unapprovedColor;
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(current ? 0.12 : 0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(current ? 0.8 : 0.25), width: current ? 1.6 : 1),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(approved ? Icons.verified_rounded : Icons.info_outline_rounded,
            size: 18, color: approved ? color : const Color(0xFFB45309)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(approved ? trustApprovedTitle() : trustUnapprovedTitle(),
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        ),
        if (current)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
            child: Text(_t('Cette annonce', 'This listing'),
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
      ]),
      const SizedBox(height: 6),
      Text(approved ? trustApprovedRule() : trustUnapprovedRule(),
          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textPrimary, height: 1.45)),
    ]),
  );
}

/// Feuille d'explication (accessible depuis la page détail).
Future<void> showTrustExplainer(BuildContext context, {PropertyModel? property}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_t("Les 2 types d'annonces sur VelQix", 'The 2 listing types on VelQix'),
              style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _definition(approved: true, current: property?.isVelqixApproved == true),
          _definition(approved: false, current: property != null && !property.isVelqixApproved),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: () => Navigator.pop(ctx), child: Text(_t('Fermer', 'Close'))),
          ),
        ]),
      ),
    ),
  );
}

// ─── Avertissement AVANT de discuter avec le propriétaire ────────────────────
final Set<String> _acknowledgedListings = {}; // pour ne pas redemander dans la session

/// À appeler avant d'ouvrir le chat avec le propriétaire d'une annonce.
/// Retourne true si l'utilisateur a pris connaissance du type d'annonce.
Future<bool> confirmTrustBeforeChat(BuildContext context, PropertyModel p) async {
  // Le propriétaire qui consulte sa propre annonce n'a rien à confirmer
  if (AuthService.instance.currentUser?.id == p.proprietaire.id) return true;
  if (_acknowledgedListings.contains(p.id)) return true;

  final ok = p.isVelqixApproved;
  final accepted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_t('Avant de contacter le propriétaire', 'Before contacting the owner'),
              style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            ok
                ? _t('Cette annonce est approuvée par VelQix.', 'This listing is approved by VelQix.')
                : _t("Cette annonce n'est pas approuvée par VelQix.", 'This listing is not approved by VelQix.'),
            style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: ok ? const Color(0xFF047857) : const Color(0xFFB45309)),
          ),
          const SizedBox(height: 12),
          _definition(approved: true, current: ok),
          _definition(approved: false, current: !ok),
          if (!ok)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _t("Visitez le bien avant tout paiement et ne versez jamais d'argent à l'avance.",
                    'Visit the property before any payment and never send money in advance.'),
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(_t("J'ai compris, contacter le propriétaire", 'I understand, contact the owner')),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('Annuler', 'Cancel'),
                style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
          ),
        ]),
      ),
    ),
  );

  if (accepted == true) {
    _acknowledgedListings.add(p.id);
    return context.mounted;
  }
  return false;
}
