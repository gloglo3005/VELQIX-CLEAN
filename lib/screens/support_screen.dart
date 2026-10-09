import '../services/app_translations.dart';
import '../main.dart' show localeNotifier;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  // ✅ FAQs traduites dynamiquement
  List<(String, String)> get _faqs => [
    (tr('faq1_q'), tr('faq1_a')),
    (tr('faq2_q'), tr('faq2_a')),
    (tr('faq3_q'), tr('faq3_a')),
    (tr('faq4_q'), tr('faq4_a')),
    (tr('faq5_q'), tr('faq5_a')),
  ];

  // Ouvre l'app correspondante (Email, Téléphone, WhatsApp)
  Future<void> _launch(BuildContext context, String label, String value) async {
    Uri uri;
    if (label == 'Email') {
      uri = Uri(scheme: 'mailto', path: value);
    } else if (label == tr('support_phone_label')) {
      uri = Uri(scheme: 'tel', path: value);
    } else if (label == 'WhatsApp') {
      final phone = value.replaceAll(RegExp(r'[^0-9+]'), '');
      uri = Uri.parse('https://wa.me/$phone');
    } else {
      uri = Uri.parse(value);
    }

    try {
      if (await canLaunchUrl(uri)) { await launchUrl(uri, mode: LaunchMode.externalApplication); }
    } catch (_) {
      // Fallback : copier dans le presse-papier
      await Clipboard.setData(ClipboardData(text: value));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('$label copié dans le presse-papier',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
          ]),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: localeNotifier,
      builder: (context, _, __) {
    final contacts = [
      (Icons.email_outlined,              'Email',      'smartinnovators294@gmail.com', const Color(0xFF4285F4), Icons.open_in_new_rounded),
      (Icons.phone_outlined, tr('support_phone_label'), '+228 99 42 40 87', const Color(0xFF34A853), Icons.call_rounded),
      (Icons.chat_bubble_outline_rounded, 'WhatsApp',   '+228 99 42 40 87',    const Color(0xFF25D366), Icons.open_in_new_rounded),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(tr('support_title'),
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('support_need_help'),
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(tr('support_24h'),
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.white.withOpacity(0.85))),
              ])),
            ]),
          ),

          const SizedBox(height: 24),
          Text(tr('support_contact'),
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: contacts.asMap().entries.map((e) {
                final (icon, label, value, color, actionIcon) = e.value;
                return Column(children: [
                  ListTile(
                    onTap: () => _launch(context, label, value),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    title: Text(label,
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
                    subtitle: Text(value,
                        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                    trailing: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Icon(actionIcon, size: 16, color: color),
                    ),
                  ),
                  if (e.key < contacts.length - 1) const Divider(height: 1, indent: 56),
                ]);
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),
          Text(tr('support_faq'),
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
          const SizedBox(height: 12),
          ..._faqs.map((f) => _FaqTile(question: f.$1, answer: f.$2)),
          const SizedBox(height: 40),
        ],
      ),
    );
      }, // builder
    ); // ValueListenableBuilder
  }
}

class _FaqTile extends StatefulWidget {
  final String question;
  final String answer;
  const _FaqTile({required this.question, required this.answer});
  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          onExpansionChanged: (v) => setState(() => _open = v),
          trailing: AnimatedRotation(
            turns: _open ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primary),
          ),
          title: Text(widget.question,
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
          children: [
            Text(widget.answer,
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary, height: 1.6)),
          ],
        ),
      ),
    );
  }
}
