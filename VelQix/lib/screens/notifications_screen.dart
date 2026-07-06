import '../services/app_translations.dart';
import '../main.dart' show localeNotifier;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api = ApiService.instance;
  List<Map<String, dynamic>> _notifs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _loading = true);
    final res = await _api.get('/notifications', auth: true);
    if (res['success'] == true && mounted) {
      setState(() {
        _notifs = List<Map<String, dynamic>>.from(res['data'] ?? []);
        _loading = false;
      });
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _unreadCount => _notifs.where((n) => n['isRead'] == false).length;

  Future<void> _markRead(String id) async {
    await _api.put('/notifications/$id/read', {}, auth: true);
    setState(() {
      final idx = _notifs.indexWhere((n) => n['id'] == id);
      if (idx != -1) _notifs[idx] = {..._notifs[idx], 'isRead': true};
    });
  }

  Future<void> _markAllRead() async {
    await _api.put('/notifications/read-all', {}, auth: true);
    setState(() {
      _notifs = _notifs.map((n) => {...n, 'isRead': true}).toList();
    });
  }

  Future<void> _deleteNotif(String id) async {
    // Suppression locale seulement (pas d'endpoint DELETE dans la priorité 2)
    setState(() => _notifs.removeWhere((n) => n['id'] == id));
  }

  IconData _icon(String? type) {
    switch (type) {
      case 'transaction': return Icons.payments_rounded;
      case 'annonce':     return Icons.home_rounded;
      case 'message':     return Icons.chat_bubble_rounded;
      case 'system':      return Icons.info_rounded;
      default:            return Icons.notifications_rounded;
    }
  }

  Color _color(String? type) {
    switch (type) {
      case 'transaction': return AppTheme.accent;
      case 'annonce':     return AppTheme.primary;
      case 'message':     return AppTheme.info;
      case 'system':      return AppTheme.success;
      default:            return AppTheme.textSecondary;
    }
  }

  String _timeAgo(dynamic date) {
    if (date == null) return '';
    final d = date is DateTime ? date : DateTime.tryParse(date.toString()) ?? DateTime.now();
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24)   return 'Il y a ${diff.inHours}h';
    return 'Il y a ${diff.inDays}j';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: localeNotifier,
      builder: (context, _, __) => Scaffold(
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
            if (_unreadCount > 0)
              Text('$_unreadCount non lue${_unreadCount > 1 ? 's' : ''}',
                  style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.primary)),
          ]),
          centerTitle: true,
          actions: [
            if (_unreadCount > 0)
              TextButton(
                onPressed: _markAllRead,
                child: Text(tr('notif_read_all'),
                    style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _notifs.isEmpty
                ? const EmptyState(
                    icon: Icons.notifications_off_outlined,
                    title: 'Aucune notification',
                    subtitle: 'Vous êtes à jour !',
                  )
                : RefreshIndicator(
                    onRefresh: _loadNotifications,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      itemCount: _notifs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final n = _notifs[i];
                        final id = n['id']?.toString() ?? '$i';
                        final isUnread = n['isRead'] == false;

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
                            onTap: () => isUnread ? _markRead(id) : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isUnread
                                    ? AppTheme.primary.withOpacity(0.08)
                                    : Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isUnread ? AppTheme.primary.withOpacity(0.2) : AppTheme.border,
                                  width: isUnread ? 1.5 : 1,
                                ),
                              ),
                              child: Row(children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _color(n['type']?.toString()).withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(_icon(n['type']?.toString()), size: 20, color: _color(n['type']?.toString())),
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
                                    Text(n['corps'] ?? '',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12, color: AppTheme.textSecondary, height: 1.4,
                                        ),
                                        maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text(_timeAgo(n['createdAt']),
                                        style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint)),
                                  ]),
                                ),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}