// lib/widgets/trust_widgets.dart
// Signes de confiance d'une annonce :
//  • SIGNE « VÉRIFIÉ » : un agent VelQix s'est rendu sur place. Seul ce signe est affiché.
//  • AUCUN SIGNE : l'annonce n'a pas (encore) été vérifiée — on n'affiche RIEN
//    (aucun message « non vérifiée »).
//  • BADGE PREMIUM : affiché pour les annonceurs abonnés Premium.
// Règles :
//  - un paiement (Premium, mise en avant) ne donne JAMAIS le signe « vérifié » ;
//  - une vérification n'est ni une garantie de disponibilité, ni une preuve de
//    propriété, ni un contrôle juridique.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart' show localeNotifier;
import '../models/models.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

String _t(String fr, String en) => localeNotifier.value.languageCode == 'en' ? en : fr;

const Color _approvedColor = Color(0xFF10B981);
const Color _premiumColor = Color(0xFFD4A017);

// ─── Textes ──────────────────────────────────────────────────────────────────
String trustApprovedTitle() => _t('Vérifiée par VelQix', 'Verified by VelQix');

String trustApprovedRule() => _t(
    "Un agent VelQix s'est rendu sur place à la date indiquée et a contrôlé que le bien existe et correspond aux photos et à la description. Cela ne prouve pas la propriété et ne garantit pas que le bien reste disponible.",
    'A VelQix agent visited the site on the date shown and checked that the property exists and matches the photos and description. This is not proof of ownership and does not guarantee the property stays available.');

/// Explication du signe (message de l'app : signe = vérifié, pas de signe = non vérifié).
String trustSignMeaning() => _t(
    'Si une annonce porte ce signe, elle a été vérifiée par VelQix. Sans ce signe, elle ne l\'a pas été.',
    'If a listing shows this sign, it has been verified by VelQix. Without the sign, it has not.');

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

// ─── Signes ronds (cartes, listes, détail) ───────────────────────────────────
Widget _sign({required IconData icon, required Color color, required double size, required String tip}) {
  return Tooltip(
    message: tip,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Icon(icon, size: size * 0.62, color: Colors.white),
    ),
  );
}

/// Signes affichés sur une annonce : Premium (annonceur abonné) et/ou Vérifié (agent VelQix).
/// Annonce sans signe → ne rend RIEN.
class TrustBadge extends StatelessWidget {
  final PropertyModel property;
  final bool compact;
  const TrustBadge({super.key, required this.property, this.compact = true});

  @override
  Widget build(BuildContext context) {
    final verified = property.isVelqixApproved;
    final premium = property.proprietaire.isPremium;
    if (!verified && !premium) return const SizedBox.shrink();
    final size = compact ? 22.0 : 28.0;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (premium)
        _sign(icon: Icons.workspace_premium_rounded, color: _premiumColor, size: size, tip: 'Premium'),
      if (premium && verified) const SizedBox(width: 5),
      if (verified)
        _sign(icon: Icons.verified_rounded, color: _approvedColor, size: size, tip: trustApprovedTitle()),
    ]);
  }
}

// ─── Page détail : uniquement les signes (rien si aucun) ─────────────────────
class TrustInfoCard extends StatelessWidget {
  final PropertyModel property;
  const TrustInfoCard({super.key, required this.property});

  /// true si au moins un signe est à afficher
  static bool hasSign(PropertyModel p) => p.isVelqixApproved || p.proprietaire.isPremium;

  @override
  Widget build(BuildContext context) {
    if (!hasSign(property)) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => showTrustExplainer(context, property: property),
        child: TrustBadge(property: property, compact: false),
      ),
    );
  }
}

/// Feuille d'explication (touche sur un signe).
Future<void> showTrustExplainer(BuildContext context, {PropertyModel? property}) {
  final verified = property?.isVelqixApproved == true;
  final premium = property?.proprietaire.isPremium == true;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _sign(icon: Icons.verified_rounded, color: _approvedColor, size: 30, tip: trustApprovedTitle()),
            const SizedBox(width: 10),
            Expanded(
              child: Text(trustApprovedTitle(),
                  style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 10),
          Text(trustSignMeaning(),
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, height: 1.45)),
          if (verified && property != null) ...[
            const SizedBox(height: 8),
            Text(_approvalReason(property),
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
          ],
          const SizedBox(height: 6),
          Text(trustApprovedRule(),
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary, height: 1.45)),
          if (premium) ...[
            const SizedBox(height: 14),
            Row(children: [
              _sign(icon: Icons.workspace_premium_rounded, color: _premiumColor, size: 26, tip: 'Premium'),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    _t('Annonceur Premium. Le statut Premium ne remplace pas la vérification VelQix.',
                        'Premium advertiser. Premium status does not replace VelQix verification.'),
                    style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary, height: 1.4)),
              ),
            ]),
          ],
          const SizedBox(height: 12),
          Text(trustLimitsNote(),
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary, height: 1.4)),
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(trustLimitsNote(),
                style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary, height: 1.45)),
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
