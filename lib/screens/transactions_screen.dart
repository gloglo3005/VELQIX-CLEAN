import '../services/app_translations.dart';
import '../main.dart' show localeNotifier;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/mock_data.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _all = MockDataService.myTransactions;
  List<TransactionModel> get _locations => _all.where((t) => t.type == 'location').toList();
  List<TransactionModel> get _achats => _all.where((t) => t.type == 'achat').toList();

  double get _totalRevenu => _all.where((t) => t.statut == 'confirme' || t.statut == 'termine').fold(0, (a, b) => a + b.montant);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: localeNotifier,
      builder: (context, _, __) =>
    Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)]),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.textPrimary)),
        ),
        title: Text(tr('trans_title'), style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
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
      body: Column(
        children: [
          // Summary card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('trans_revenue'), style: GoogleFonts.poppins(fontSize: 12, color: Colors.white.withOpacity(0.8))),
                Text(formatFcfa(_totalRevenu), style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                Text("${_all.where((t) => t.statut == 'confirme' || t.statut == 'termine').length} ${tr('trans_confirmed')}",
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.white.withOpacity(0.7))),
              ])),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
              ),
            ]),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(_all),
                _buildList(_locations),
                _buildList(_achats),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildList(List<TransactionModel> list) {
    if (list.isEmpty) return EmptyState(icon: Icons.receipt_long_outlined, title: 'Aucune transaction', subtitle: 'Vos transactions apparaîtront ici.');
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _TransactionDetailCard(t: list[i]),
    );
  }
}

class _TransactionDetailCard extends StatelessWidget {
  final TransactionModel t;
  const _TransactionDetailCard({required this.t});

  Color get _statusColor {
    switch (t.statut) {
      case 'confirme': return AppTheme.success;
      case 'en_attente': return AppTheme.warning;
      case 'annule': return AppTheme.error;
      default: return AppTheme.textSecondary;
    }
  }

  IconData get _statusIcon {
    switch (t.statut) {
      case 'confirme': return Icons.check_circle_rounded;
      case 'en_attente': return Icons.access_time_rounded;
      case 'annule': return Icons.cancel_rounded;
      default: return Icons.done_all_rounded;
    }
  }

  String get _methodLabel {
    switch (t.methode) {
      case 'mobile_money': return '📱 Mobile Money';
      case 'carte': return '💳 Carte bancaire';
      case 'paypal': return '🅿️ PayPal';
      default: return t.methode;
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy', 'fr_FR');
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16)),
                child: Image.network(t.property.firstImage, width: 80, height: 80, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(width: 80, height: 80, color: AppTheme.divider)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.property.titre, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(t.type == 'location' ? '📅 Location' : '🏷️ Achat', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                      const SizedBox(height: 5),
                      Text(formatFcfa(t.montant), style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    Icon(_statusIcon, color: _statusColor, size: 22),
                    const SizedBox(height: 4),
                    Text(t.statutLabel, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: _statusColor)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("${tr('trans_start')} : ${df.format(t.dateDebut)}", style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                if (t.dateFin != null)
                  Text("${tr('trans_end')} : ${df.format(t.dateFin!)}", style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
              ])),
              Text(_methodLabel, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
            ]),
          ),
        ],
      ),
    );
  }
}
