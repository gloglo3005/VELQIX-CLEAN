// lib/widgets/availability_widgets.dart
// Affichage de l'état de disponibilité d'une annonce (cahier des charges §7.2).
// Règle d'or (§7.1) : une annonce publiée n'est jamais assimilée à un bien
// actuellement disponible. On affiche donc toujours la DATE de l'information.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart' show localeNotifier;
import '../models/models.dart';
import '../theme/app_theme.dart';

String _t(String fr, String en) => localeNotifier.value.languageCode == 'en' ? en : fr;

String _two(int n) => n.toString().padLeft(2, '0');

/// 20/10/2026 à 14:30
String formatDateTimeFr(DateTime d) {
  final l = d.toLocal();
  return _t('${_two(l.day)}/${_two(l.month)}/${l.year} à ${_two(l.hour)}:${_two(l.minute)}',
      '${_two(l.day)}/${_two(l.month)}/${l.year} at ${_two(l.hour)}:${_two(l.minute)}');
}

String formatDateFr(DateTime d) {
  final l = d.toLocal();
  return '${_two(l.day)}/${_two(l.month)}/${l.year}';
}

Color availabilityColor(AvailabilityState s) {
  switch (s) {
    case AvailabilityState.confirmedRecently: return const Color(0xFF10B981);
    case AvailabilityState.declared:          return const Color(0xFF3B82F6);
    case AvailabilityState.pending:           return const Color(0xFFF59E0B);
    case AvailabilityState.toReconfirm:       return const Color(0xFFF59E0B);
    case AvailabilityState.unavailable:       return const Color(0xFFEF4444);
    case AvailabilityState.suspended:         return const Color(0xFF6B7280);
    case AvailabilityState.archived:          return const Color(0xFF6B7280);
  }
}

IconData availabilityIcon(AvailabilityState s) {
  switch (s) {
    case AvailabilityState.confirmedRecently: return Icons.event_available_rounded;
    case AvailabilityState.declared:          return Icons.campaign_outlined;
    case AvailabilityState.pending:           return Icons.hourglass_top_rounded;
    case AvailabilityState.toReconfirm:       return Icons.update_rounded;
    case AvailabilityState.unavailable:       return Icons.event_busy_rounded;
    case AvailabilityState.suspended:         return Icons.pause_circle_outline_rounded;
    case AvailabilityState.archived:          return Icons.archive_outlined;
  }
}

/// Libellé court (badge des cartes).
String availabilityShortLabel(AvailabilityState s) {
  switch (s) {
    case AvailabilityState.confirmedRecently: return _t('Confirmée récemment', 'Recently confirmed');
    case AvailabilityState.declared:          return _t('Déclarée disponible', 'Declared available');
    case AvailabilityState.pending:           return _t('Confirmation en attente', 'Confirmation pending');
    case AvailabilityState.toReconfirm:       return _t('À reconfirmer', 'To reconfirm');
    case AvailabilityState.unavailable:       return _t('Indisponible', 'Unavailable');
    case AvailabilityState.suspended:         return _t('Suspendue', 'Suspended');
    case AvailabilityState.archived:          return _t('Archivée', 'Archived');
  }
}

/// Titre complet (page détail), conforme au tableau du §7.2.
String availabilityTitle(AvailabilityState s) {
  switch (s) {
    case AvailabilityState.confirmedRecently: return _t('Disponibilité confirmée récemment', 'Availability recently confirmed');
    case AvailabilityState.declared:          return _t('Déclaré disponible', 'Declared available');
    case AvailabilityState.pending:           return _t('Confirmation en attente', 'Confirmation pending');
    case AvailabilityState.toReconfirm:       return _t('Disponibilité à reconfirmer', 'Availability to reconfirm');
    case AvailabilityState.unavailable:       return _t('Indisponible', 'Unavailable');
    case AvailabilityState.suspended:         return _t('Suspendue pour vérification', 'Suspended for review');
    case AvailabilityState.archived:          return _t('Archivée', 'Archived');
  }
}

/// Explication du comportement attendu, avec la date de l'information.
String availabilityDetail(PropertyModel p) {
  final s = p.availabilityState;
  final date = formatDateTimeFr(p.availabilityDate);
  switch (s) {
    case AvailabilityState.confirmedRecently:
      return _t(
          "Confirmée par l'annonceur le $date. Cette confirmation est liée à cette date : elle ne garantit pas que le bien sera encore disponible à votre arrivée.",
          'Confirmed by the advertiser on $date. This confirmation is tied to that date: it does not guarantee the property will still be available when you arrive.');
    case AvailabilityState.declared:
      return _t(
          "Déclaré disponible par l'annonceur le $date, sans confirmation récente. Demandez une confirmation avant de vous déplacer.",
          'Declared available by the advertiser on $date, with no recent confirmation. Ask for a confirmation before travelling.');
    case AvailabilityState.pending:
      return _t(
          "Une demande de confirmation est en cours. Ne considérez pas ce bien comme confirmé tant que l'annonceur n'a pas répondu.",
          'A confirmation request is in progress. Do not treat this property as confirmed until the advertiser replies.');
    case AvailabilityState.toReconfirm:
      return _t(
          "Dernière information datée du $date : elle est ancienne. Reconfirmez la disponibilité avant tout déplacement.",
          'Last information dated $date: it is old. Reconfirm availability before any trip.');
    case AvailabilityState.unavailable:
      return _t("L'annonceur a indiqué que ce bien est loué, vendu ou indisponible.",
          'The advertiser indicated this property is rented, sold or unavailable.');
    case AvailabilityState.suspended:
      return _t("Cette annonce est temporairement suspendue le temps d'un contrôle.",
          'This listing is temporarily suspended pending a review.');
    case AvailabilityState.archived:
      return _t("Cette annonce n'est plus proposée.", 'This listing is no longer offered.');
  }
}

// ─── Badge compact (cartes, listes) ──────────────────────────────────────────
class AvailabilityBadge extends StatelessWidget {
  final PropertyModel property;
  final bool compact;
  const AvailabilityBadge({super.key, required this.property, this.compact = true});

  @override
  Widget build(BuildContext context) {
    final s = property.availabilityState;
    final color = availabilityColor(s);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(availabilityIcon(s), size: compact ? 12 : 15, color: color),
        const SizedBox(width: 4),
        Text(
          availabilityShortLabel(s),
          style: GoogleFonts.poppins(
              fontSize: compact ? 10 : 12, fontWeight: FontWeight.w600, color: color),
        ),
      ]),
    );
  }
}

// ─── Encadré de la page détail ───────────────────────────────────────────────
class AvailabilityInfoCard extends StatelessWidget {
  final PropertyModel property;
  const AvailabilityInfoCard({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    final s = property.availabilityState;
    final color = availabilityColor(s);
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
          Icon(availabilityIcon(s), color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(availabilityTitle(s),
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(availabilityDetail(property),
            style: GoogleFonts.poppins(
                fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w500, height: 1.4)),
        const SizedBox(height: 6),
        Text(
          _t("Une annonce publiée n'est pas une garantie de disponibilité.",
              'A published listing is not a guarantee of availability.'),
          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ]),
    );
  }
}
