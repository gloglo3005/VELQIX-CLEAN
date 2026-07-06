import '../services/app_translations.dart';
import '../main.dart' show localeNotifier;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _api = ApiService.instance;

  List<Map<String, dynamic>> _all = [];
  bool _loading = true;

  List<Map<String, dynamic>> get _locations =>
      _all.where((t) => t['type'] == 'location').toList();
  List<Map<String, dynamic>> get _achats =>
      _all.where((t) => t['type'] == 'achat').toList();

  double get _totalRevenu => _all
      .where((t) => t['status'] == 'confirme' || t['status'] == 'termine')
      .fold(0.0, (a, b) => a + (b['montant'] ?? 0).toDouble());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _loading = true);
    final res = await _api.get('/transactions', auth: true);
    if (res['success'] == true && mounted) {
      setState(() {
        _all = List<Map<String, dynamic>>.from(res['data'] ?? []);
        _loading = false;
      });
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'confirme':   return 'Confirmé';
      case 'en_attente': return 'En attente';
      case 'annule':     return 'Annulé';
      case 'termine':    return 'Terminé';
      default:           return status ?? '';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'confirme':   return AppTheme.success;
      case 'en_attente': return AppTheme.warning;
      case 'annule':     return AppTheme.error;
      default:           return AppTheme.textSecondary;
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'confirme':   return Icons.check_circle_rounded;
      case 'en_attente': return Icons.access_time_rounded;
      case 'annule':     return Icons.cancel_rounded;
      default:           return Icons.done_all_rounded;
    }
  }

  String _methodLabel(String? method) {
    switch (method) {
      case 'mobile_money': return '📱 Mobile Money';
      case 'carte':        return '💳 Carte bancaire';
      case 'especes':      return '💵 Espèces';
      default:             return method ?? '';
    }
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
          title: Text(tr('trans_title'),
              style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          centerTitle: true,
          bottom: TabBar(
            controller: _tabController,
            labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primary,
            tabs: [
              Tab(text: "${tr('trans_tab_all')} (${_all.length})"),
              Tab(text: "${tr('trans_tab_loc')} (${_locations.length})"),
              Tab(text: "${tr('trans_tab_buy')} (${_achats.length})"),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                // ── Carte résumé ─────────────────────────────────────
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr('trans_revenue'),
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.white.withOpacity(0.8))),
                        Text(formatFcfa(_totalRevenu),
                            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                        Text(
                          "${_all.where((t) => t['status'] == 'confirme' || t['status'] == 'termine').length} ${tr('trans_confirmed')}",
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.white.withOpacity(0.7)),
                        ),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
                    ),
                  ]),
                ),
                // ── Liste ────────────────────────────────────────────
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadTransactions,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildList(_all),
                        _buildList(_locations),
                        _buildList(_achats),
                      ],
                    ),
                  ),
                ),
              ]),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Aucune transaction',
        subtitle: 'Vos transactions apparaîtront ici.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final t = list[i];
        final property = t['property'] as Map<String, dynamic>? ?? {};
        final images = property['images'] as List<dynamic>? ?? [];
        final imageUrl = images.isNotEmpty ? images.first.toString() : '';
        final df = DateFormat('dd MMM yyyy', 'fr_FR');
        final dateDebut = t['dateDebut'] != null
            ? DateTime.tryParse(t['dateDebut'].toString())
            : null;
        final dateFin = t['dateFin'] != null
            ? DateTime.tryParse(t['dateFin'].toString())
            : null;
        final status = t['status']?.toString();
        final montant = (t['montant'] ?? 0).toDouble();

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
          ),
          child: Column(children: [
            Row(children: [
              // Image bien
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                child: imageUrl.isNotEmpty
                    ? Image.network(imageUrl, width: 80, height: 80, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(width: 80, height: 80, color: AppTheme.divider))
                    : Container(width: 80, height: 80, color: AppTheme.divider,
                        child: const Icon(Icons.home_rounded, color: AppTheme.textHint)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(property['titre'] ?? 'Bien',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(t['type'] == 'location' ? '📅 Location' : '🏷️ Achat',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                    const SizedBox(height: 5),
                    Text(formatFcfa(montant),
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(children: [
                  Icon(_statusIcon(status), color: _statusColor(status), size: 22),
                  const SizedBox(height: 4),
                  Text(_statusLabel(status),
                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: _statusColor(status))),
                ]),
              ),
            ]),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (dateDebut != null)
                      Text("${tr('trans_start')} : ${df.format(dateDebut)}",
                          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                    if (dateFin != null)
                      Text("${tr('trans_end')} : ${df.format(dateFin)}",
                          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                  ]),
                ),
                Text(_methodLabel(t['moyenPaiement']?.toString()),
                    style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
              ]),
            ),
          ]),
        );
      },
    );
  }
}