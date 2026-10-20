// lib/widgets/trust_widgets.dart
// Niveau de vérification d'une annonce (cahier des charges §3.3, §6.4, §10.3, §14.3) :
//  • VÉRIFIÉE SUR LE TERRAIN : un agent VelQix s'est rendu sur place. Le statut
//    précise la date, ce qui a été contrôlé et les LIMITES du contrôle.
//  • NON VÉRIFIÉE : aucune vérification terrain par VelQix.
// Règles :
//  - un paiement (Premium, mise en avant) ne donne JAMAIS le statut « vérifié » ;
//  - une vérification n'est ni une garantie de disponibilité, ni une preuve de
//    propriété, ni un contrôle juridique ; VelQix ne promet pas de prendre en
//    charge les fraudes.

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
String trustApprovedTitle() => _t('Vérifiée sur le terrain', 'Verified on site');
String trustUnapprovedTitle() => _t('Non vérifiée par VelQix', 'Not verified by VelQix');

String trustApprovedRule() => _t(
    "Un agent VelQix s'est rendu sur place à la date indiquée et a contrôlé que le bien existe et correspond aux photos et à la description. Cela ne prouve pas la propriété et ne garantit pas que le bien reste disponible.",
    'A VelQix agent visited the site on the date shown and checked that the property exists and matches the photos and description. This is not proof of ownership and does not guarantee the property stays available.');

String trustUnapprovedRule() => _t(
    "Aucun agent VelQix n'a vérifié ce bien sur le terrain. Les informations sont données par l'annonceur.",
    'No VelQix agent has checked this property on site. The information is provided by the advertiser.');

/// Limites des garanties (cahier des charges §14.3) — affichées sans détour.
String trustLimitsNote() => _t(
    "Une annonce n'est pas une garantie de disponibilité. La mise en relation ne remplace pas les contrôles juridiques d'une transaction immobilière. Visitez le bien avant tout paiement et ne versez jamais d'argent à l'avance.",
    'A listing is not a guarantee of availability. Matching does not replace the legal checks of a property transaction. Visit the property before any payment and never send money in advance.');

String _approvalReason(PropertyModel p) {
  if (p.fieldVerified) {
    final who = (p.fieldVerifiedByName ?? '').trim();
    final d = p.fieldVerifiedAt;
    final date = d == null
        ? ''
        : ' (${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year})';
    return who.isEmpty
        ? _t("Vérifié sur le terrain par un agent VelQix$date.",
            'Verified on site by a VelQix agent$date.')
        : _t("Vérifié sur le terrain par l'agent $who$date.",
            'Verified on site by agent $who$date.');
  }
  return '';
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
          ok ? _t('Vérifiée terrain', 'Verified on site') : _t('Non vérifiée', 'Not verified'),
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
          Text(trustApprovedRule(),
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
        ] else ...[
          Text(trustUnapprovedRule(),
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
        ],
        const SizedBox(height: 4),
        Text(trustLimitsNote(),
            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary, height: 1.4)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => showTrustExplainer(context),
          child: Text(_t('Comprendre les niveaux de vérification', 'Understand verification levels'),
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
          Text(_t('Niveaux de vérification sur VelQix', 'Verification levels on VelQix'),
              style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _definition(approved: true, current: property?.isVelqixApproved == true),
          _definition(approved: false, current: property != null && !property.isVelqixApproved),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _t('Un paiement (abonnement Premium, mise en avant) ne donne jamais le statut « vérifiée sur le terrain ».',
                  'A payment (Premium, promotion) never grants the “verified on site” status.'),
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(trustLimitsNote(),
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary, height: 1.4)),
          ),
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
                ? _t('Cette annonce a été vérifiée sur le terrain.', 'This listing was verified on site.')
                : _t("Cette annonce n'a pas été vérifiée par VelQix.", 'This listing has not been verified by VelQix.'),
            style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: ok ? const Color(0xFF047857) : const Color(0xFFB45309)),
          ),
          const SizedBox(height: 12),
          _definition(approved: true, current: ok),
          _definition(approved: false, current: !ok),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(trustLimitsNote(),
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
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
