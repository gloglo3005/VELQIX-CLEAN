// lib/screens/admin_tabs/admin_common.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class AdminBadge extends StatelessWidget {
  final String label;
  final Color color;
  const AdminBadge(this.label, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
      );
}

Color adminRoleColor(String role) {
  switch (role) {
    case 'admin':           return AppTheme.error;
    case 'proprietaire':    return AppTheme.primary;
    case 'demarcheur':      return AppTheme.accent;
    case 'agent_entretien': return AppTheme.success;
    default:                return AppTheme.textSecondary;
  }
}

Future<bool> adminConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
      content: Text(message, style: GoogleFonts.poppins(fontSize: 13)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel,
              style: TextStyle(color: danger ? AppTheme.error : AppTheme.primary, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return ok == true;
}

void adminSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? AppTheme.error : null,
    behavior: SnackBarBehavior.floating,
  ));
}

/// Barre de filtres horizontale (chips).
class AdminChipRow extends StatelessWidget {
  final List<MapEntry<String, String>> items; // valeur → libellé
  final String selected;
  final ValueChanged<String> onSelected;
  const AdminChipRow({super.key, required this.items, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final e in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(e.value, style: GoogleFonts.poppins(fontSize: 12)),
                selected: selected == e.key,
                onSelected: (_) => onSelected(e.key),
              ),
            ),
        ]),
      );
}
