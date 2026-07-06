import '../services/app_translations.dart';
import '../main.dart' show localeNotifier;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/mock_data.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // ✅ On fusionne les notifs mock (historique) + notifs temps réel (admin)
  List<Map<String, dynamic>> get _allNotifs {
    final realTime = List<Map<String, dynamic>>.from(appNotificationsNotifier.value);
    final mock = List<Map<String, dynamic>>.from(MockDataService.notifications);
    return [...realTime, ...mock];
  }

  void _onNotifChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    appNotificationsNotifier.addListener(_onNotifChanged);
  }

  @override
  void dispose() {
    appNotificationsNotifier.removeListener(_onNotifChanged);
    super.dispose();
  }

  void _markRead(String id) {
    final idx = appNotificationsNotifier.value.indexWhere((n) => n['id'] == id);
    if (idx != -1) {
      final updated = List<Map<String, dynamic>>.from(appNotificationsNotifier.value);
      updated[idx] = {...updated[idx], 'lu': true};
      appNotificationsNotifier.value = updated;
    }
  }

  void _markAllRead() {
    // Marquer les notifs temps réel
    final updated = appNotificationsNotifier.value
        .map((n) => {...n, 'lu': true})
        .toList();
    appNotificationsNotifier.value = updated;
    // Marquer les mock
    for (var n in MockDataService.notifications) {
      n['lu'] = true;
    }
    setState(() {});
  }

  void _deleteNotif(String id) {
    // Supprimer des notifs temps réel
    appNotificationsNotifier.value =
        appNotificationsNotifier.value.where((n) => n['id'] != id).toList();
    // Supprimer des mock
    MockDataService.notifications.removeWhere((n) => n['id'] == id);
    setState(() {});
  }

  IconData _icon(String type) {
    switch (type) {
      case 'success': return Icons.check_circle_rounded;
      case 'error': return Icons.cancel_rounded;
      case 'warning': return Icons.warning_rounded;
      case 'message': return Icons.chat_bubble_rounded;
      case 'payment': return Icons.payments_rounded;
      case 'review': return Icons.star_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'success': return AppTheme.success;
      case 'error': return AppTheme.error;
      case 'warning': return AppTheme.warning;
      case 'message': return AppTheme.primary;
      case 'payment': return AppTheme.accent;
      case 'review': return AppTheme.accentLight;
      default: return AppTheme.info;
    }
  }

  String _timeAgo(dynamic date) {
    if (date == null) return '';
    final d = date is DateTime ? date : DateTime.tryParse(date.toString()) ?? DateTime.now();
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'À l\'instant';
    if (diff.inMinutes < 60) return "${tr('notif_time_mins')} ${diff.inMinutes} min";
    if (diff.inHours < 24) return "${tr('notif_time_hours')} ${diff.inHours}h";
    return "${tr('notif_time_days')} ${diff.inDays}j";
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: localeNotifier,
      builder: (context, _, __) {
    final notifs = _allNotifs;
    final unreadCount = notifs.where((n) => n['lu'] == false).length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.textPrimary),
          ),
        ),
        title: Column(children: [
          Text(tr('notif_title'),
              style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          if (unreadCount > 0)
            Text('$unreadCount non lue${unreadCount > 1 ? 's' : ''}',
                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.primary)),
        ]),
        centerTitle: true,
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text(tr('notif_read_all'),
                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: notifs.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_off_outlined,
              title: 'Aucune notification',
              subtitle: 'Vous êtes à jour !',
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              itemCount: notifs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final n = notifs[i];
                final id = n['id']?.toString() ?? '$i';
                final isUnread = n['lu'] == false;
                final isRealTime = appNotificationsNotifier.value.any((r) => r['id'] == id);

                return Dismissible(
                  key: Key(id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => _deleteNotif(id),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
                  ),
                  child: GestureDetector(
                    onTap: () => isRealTime ? _markRead(id) : setState(() => n['lu'] = true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isUnread ? AppTheme.primary.withOpacity(0.08) : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isUnread ? AppTheme.primary.withOpacity(0.2) : AppTheme.border,
                          width: isUnread ? 1.5 : 1,
                        ),
                      ),
                      child: Row(children: [
                        // Icône colorée
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _color(n['type']).withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_icon(n['type']), size: 20, color: _color(n['type'])),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(
                                child: Text(n['titre'] ?? '',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    )),
                              ),
                              if (isUnread)
                                Container(
                                  width: 8, height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ]),
                            const SizedBox(height: 3),
                            Text(n['message'] ?? '',
                                style: GoogleFonts.poppins(
                                  fontSize: 12, color: AppTheme.textSecondary, height: 1.4,
                                ),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(_timeAgo(n['date']),
                                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint)),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                );
              },
            ),
    );
      }, // builder
    ); // ValueListenableBuilder
  }
}
