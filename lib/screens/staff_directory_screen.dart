// lib/screens/staff_directory_screen.dart
// Annuaire des démarcheurs et agents d'entretien, à contacter en cas de besoin.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/app_translations.dart';
import '../services/staff_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'messages_screen.dart';

class StaffDirectoryScreen extends StatefulWidget {
  const StaffDirectoryScreen({super.key});
  @override
  State<StaffDirectoryScreen> createState() => _StaffDirectoryScreenState();
}

class _StaffDirectoryScreenState extends State<StaffDirectoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<UserModel> _all = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await StaffService.instance.getStaff();
      if (!mounted) return;
      setState(() => _all = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'ouvrir le composeur.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final demarcheurs = _all.where((u) => u.isDemarcheur).toList();
    final agents = _all.where((u) => u.isAgentEntretien).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(tr('staff_title'),
            style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tab,
          labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
          tabs: [Tab(text: tr('staff_demarcheurs')), Tab(text: tr('staff_agents'))],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: _error!,
                  buttonLabel: 'Réessayer',
                  onButton: _load,
                )
              : TabBarView(
                  controller: _tab,
                  children: [_buildList(demarcheurs), _buildList(agents)],
                ),
    );
  }

  Widget _buildList(List<UserModel> users) {
    if (users.isEmpty) {
      return EmptyState(
        icon: Icons.support_agent_rounded,
        title: tr('staff_empty'),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _StaffCard(
              user: users[i],
              onMessage: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => ChatScreen(user: users[i]))),
              onCall: users[i].telephone.isEmpty ? null : () => _call(users[i].telephone),
            ),
          ),
        ),
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onMessage;
  final VoidCallback? onCall;
  const _StaffCard({required this.user, required this.onMessage, this.onCall});

  @override
  Widget build(BuildContext context) {
    final place = [user.countryName].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        UserAvatar(user: user, radius: 26, showBadge: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            Text(user.roleLabel,
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w500)),
            if (place.isNotEmpty)
              Text(place, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
          ]),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: tr('staff_message'),
          onPressed: onMessage,
          icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primary),
        ),
        if (onCall != null)
          IconButton(
            tooltip: tr('staff_call'),
            onPressed: onCall,
            icon: const Icon(Icons.call_rounded, color: AppTheme.success),
          ),
      ]),
    );
  }
}
