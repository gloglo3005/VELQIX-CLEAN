import '../services/app_translations.dart';
import '../main.dart' show localeNotifier;
import 'package:flutter/material.dart';
import '../utils/image_url.dart';
import '../models/mission_model.dart';
import '../widgets/service_request_sheet.dart';
import '../widgets/trust_widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart'; // NEW : vraie source de données
import '../services/availability_service.dart';
import '../services/property_service.dart'; // NEW : suppression / mise à jour réelles
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'property_detail_screen.dart';
import 'add_listing_screen.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});
  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _loading = true;
  String? _loadError;
  List<PropertyModel> _serverProps = [];
  // availabilityStatus de chaque annonce (available | pending | unavailable | suspended | archived),
  // lu dans la réponse brute de /properties/my.
  Map<String, String> _availability = {};

  // NOTE : /properties/my renvoie TOUTES les annonces de l'utilisateur, quel
  // que soit leur statut (en_attente, approuve, rejete) — donc plus besoin de
  // fusionner avec MockDataService ni de deviner l'état localement.
  List<PropertyModel> get _myProps => _serverProps;

  // Onglet « En attente » : annonces en cours de validation ET refusées
  // (avant, les refusées n'apparaissaient nulle part avec une action possible).
  List<PropertyModel> get _myPendingProps =>
      _serverProps.where((p) => p.status != 'approuve').toList();

  List<PropertyModel> get _activeProps =>
      _serverProps.where((p) =>
          p.isAvailable && p.status == 'approuve' &&
          _availability[p.id] != 'archived' && _availability[p.id] != 'unavailable').toList();
  List<PropertyModel> get _allProps => _myProps;

  Future<void> _loadMyProperties() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final res = await ApiService.instance.get('/properties/my', auth: true);
    if (!mounted) return;
    if (res['success'] == true) {
      _serverProps = (res['data'] as List)
          .map((j) => PropertyModel.fromJson(j as Map<String, dynamic>))
          .toList();
      _availability = {
        for (final j in (res['data'] as List))
          (j as Map<String, dynamic>)['id'].toString():
              (j['availabilityStatus'] ?? 'available').toString(),
      };
    } else {
      _loadError = res['message'] ?? 'Impossible de charger tes annonces';
    }
    setState(() => _loading = false);
  }

  // Un événement temps réel (approbation/rejet par l'admin pendant que cet
  // écran est ouvert) déclenche un rechargement — source de vérité serveur.
  void _onNewProperty() => _loadMyProperties();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMyProperties();
    publishedPropertiesNotifier.addListener(_onNewProperty);
    pendingPropertiesNotifier.addListener(_onNewProperty);
  }

  @override
  void dispose() {
    publishedPropertiesNotifier.removeListener(_onNewProperty);
    pendingPropertiesNotifier.removeListener(_onNewProperty);
    _tabController.dispose();
    super.dispose();
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
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)]),
              child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.textPrimary)),
        ),
        title: Text(tr('mylist_title'), style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        centerTitle: true,
        actions: [
          GestureDetector(
            onTap: _openAddListing,
            child: Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: [
            Tab(text: "${tr('mylist_tab_active')} (${_activeProps.length})"),
            Tab(text: "${tr('mylist_tab_all')} (${_allProps.length})"),
            Tab(text: "${tr('mylist_tab_pending')} (${_myPendingProps.length})"),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_loadError!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _loadMyProperties, child: const Text('Réessayer')),
                  ]),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(_activeProps),
                    _buildList(_allProps),
                    _buildPendingList(_myPendingProps),
                  ],
                ),
    ));
  }


  Widget _buildPendingList(List<PropertyModel> props) {
    if (props.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.hourglass_empty_rounded, size: 52, color: Color(0xFF9CA3AF)),
          const SizedBox(height: 16),
          Text(tr('mylist_no_pending'),
              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Text(tr('mylist_pending_sub'),
              style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textHint)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: props.length,
      itemBuilder: (_, i) {
        final p = props[i];
        return _PendingPropertyCard(
          property: p,
          onEdit: () => _editProperty(p),
          onResubmit: () => _resubmit(p),
        );
      },
    );
  }

  Widget _buildList(List<PropertyModel> props) {
    if (props.isEmpty) {
      return EmptyState(
        icon: Icons.home_outlined,
        title: tr('mylist_no_listing'),
        subtitle: tr('mylist_no_listing_sub'),
        buttonLabel: tr('mylist_add_btn'),
        onButton: _openAddListing,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: props.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _ListingManageCard(
        property: props[i],
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PropertyDetailScreen(property: props[i]))),
        onEdit: () => _editProperty(props[i]),
        onDelete: () => _confirmDelete(context, props[i]),
        onToggle: (newValue) => _toggleAvailability(props[i], newValue),
        availability: _availability[props[i].id],
        onClose: () => _closeProperty(props[i]),
        onArchive: () => _archiveProperty(props[i]),
        onRestore: () => _restoreProperty(props[i]),
      ),
    );
  }

  // ─── Modifier une annonce (ouvre le formulaire pré-rempli) ─────────────────
  Future<void> _editProperty(PropertyModel p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddListingScreen(editing: p)),
    );
    if (mounted) _loadMyProperties();
  }

  // ─── Nouvelle annonce (recharge la liste au retour : un brouillon n'émet aucun événement) ──
  Future<void> _openAddListing() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddListingScreen()));
    if (mounted) _loadMyProperties();
  }

  // ─── Clôture / archivage / réactivation par le propriétaire (ANN-05) ───────
  Future<bool> _confirm(String title, String body, String cta) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(body, style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: Text('Annuler', style: GoogleFonts.poppins())),
          ElevatedButton(onPressed: () => Navigator.pop(dialogCtx, true), child: Text(cta, style: GoogleFonts.poppins())),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _declare(PropertyModel p, String status, String okMessage) async {
    final res = await ApiService.instance.post(
      '/properties/${p.id}/availability',
      {'status': status},
      auth: true,
    );
    if (!mounted) return;
    final ok = res['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? okMessage : (res['message'] ?? 'Action impossible'),
          style: GoogleFonts.poppins(color: Colors.white)),
      backgroundColor: ok ? AppTheme.success : AppTheme.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
    _loadMyProperties();
  }

  Future<void> _closeProperty(PropertyModel p) async {
    final sold = p.listingType == ListingType.vente;
    final ok = await _confirm(
      sold ? 'Marquer comme vendu ?' : 'Marquer comme loué ?',
      '« ${p.titre} » ne sera plus proposée dans les résultats. Tu pourras la remettre en ligne ou l\'archiver ensuite.',
      'Clôturer',
    );
    if (!ok) return;
    await _declare(p, sold ? 'sold' : 'rented',
        sold ? 'Annonce clôturée : bien vendu.' : 'Annonce clôturée : bien loué.');
  }

  Future<void> _archiveProperty(PropertyModel p) async {
    final ok = await _confirm(
      'Archiver cette annonce ?',
      '« ${p.titre} » sera retirée des annonces actives. Tu pourras la réactiver à tout moment.',
      'Archiver',
    );
    if (!ok) return;
    await _declare(p, 'archived', 'Annonce archivée.');
  }

  Future<void> _restoreProperty(PropertyModel p) async {
    await _declare(p, 'available', 'Annonce remise en ligne.');
  }

  // ─── Soumettre à nouveau une annonce refusée ───────────────────────────────
  Future<void> _resubmit(PropertyModel p) async {
    final err = await PropertyService.instance.submitProperty(p.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          err ?? (p.status == 'brouillon'
              ? 'Annonce soumise. En attente de validation.'
              : 'Annonce soumise à nouveau. En attente de validation.'),
          style: GoogleFonts.poppins(color: Colors.white)),
      backgroundColor: err != null ? AppTheme.error : AppTheme.warning,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
    _loadMyProperties();
  }

  // ─── Activer / mettre en pause une annonce (persisté côté serveur) ─────────
  Future<void> _toggleAvailability(PropertyModel p, bool newValue) async {
    final err = await PropertyService.instance.updateProperty(p.id, {'isAvailable': newValue});
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      // Le serveur n'a pas accepté le changement → on resynchronise la liste
      // pour que le switch revienne à son vrai état.
      _loadMyProperties();
      return;
    }
    // Succès : on recharge depuis le serveur pour que les compteurs d'onglets
    // (Actifs / Tous / En attente) restent cohérents avec le nouveau statut.
    _loadMyProperties();
  }

  // ─── Suppression réelle (API + retrait immédiat de la liste) ──────────────
  Future<void> _deleteProperty(PropertyModel p) async {
    // Suppression optimiste : on retire tout de suite de l'écran.
    final backup = List<PropertyModel>.from(_serverProps);
    setState(() => _serverProps.removeWhere((e) => e.id == p.id));

    final err = await PropertyService.instance.deleteProperty(p.id);
    if (!mounted) return;

    if (err != null) {
      // Échec côté serveur : on restaure la liste et on informe l'utilisateur.
      setState(() => _serverProps = backup);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(tr('mylist_deleted'), style: GoogleFonts.poppins(color: Colors.white)),
      backgroundColor: AppTheme.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _confirmDelete(BuildContext ctx, PropertyModel p) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tr('mylist_delete'), style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('Voulez-vous vraiment supprimer "${p.titre}" ?', style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text(tr('mylist_cancel'), style: GoogleFonts.poppins())),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _deleteProperty(p); // NEW : vraie suppression via l'API
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text(tr('mylist_confirm_del'), style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }
}

class _ListingManageCard extends StatefulWidget {
  final PropertyModel property;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle; // NEW : transmet le nouvel état au parent
  final String? availability; // availabilityStatus serveur (archived, unavailable, ...)
  final VoidCallback onClose;
  final VoidCallback onArchive;
  final VoidCallback onRestore;
  const _ListingManageCard({required this.property, required this.onTap, required this.onEdit, required this.onDelete, required this.onToggle,
      this.availability, required this.onClose, required this.onArchive, required this.onRestore});

  @override
  State<_ListingManageCard> createState() => _ListingManageCardState();
}

class _ListingManageCardState extends State<_ListingManageCard> {
  late bool _active = widget.property.isAvailable;
  late bool _requested = widget.property.verificationRequested;
  bool _requesting = false;

  /// Vérification terrain : service payant, demandé via la feuille de services.
  Future<void> _requestVerification() async {
    await showServiceRequestSheet(
      context,
      property: widget.property,
      initialType: MissionType.verification,
    );
  }

  Widget _buildApprovalRow(PropertyModel p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Obtenir le signe « Vérifié par VelQix »',
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 2),
        Text(
          'Pour rassurer les demandeurs : faites vérifier le bien sur place par un agent VelQix (service payant). Le statut « vérifiée sur le terrain » ne s\'obtient que par cette vérification.',
          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: (_requested || _requesting) ? null : _requestVerification,
            icon: _requesting
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_requested ? Icons.hourglass_top_rounded : Icons.verified_outlined, size: 16),
            label: const Text('Faire vérifier ce bien'),
          ),
        ),
      ]),
    );
  }

  @override
  void didUpdateWidget(covariant _ListingManageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si la liste parente a été rechargée (ex: après échec de sauvegarde),
    // on resynchronise l'état visuel du switch avec la vraie donnée serveur.
    if (oldWidget.property.isAvailable != widget.property.isAvailable) {
      _active = widget.property.isAvailable;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.property;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _active ? AppTheme.border : AppTheme.divider),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                  child: ColorFiltered(
                    colorFilter: _active ? const ColorFilter.mode(Colors.transparent, BlendMode.color) : const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                    child: Image.network(optimizeImageUrl(p.firstImage, displayWidth: 100), width: 100, height: 100, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(width: 100, height: 100, color: AppTheme.divider)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.titre, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: _active ? AppTheme.textPrimary : AppTheme.textHint), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text(p.adresse.short, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                        if (p.status != 'approuve') ...[
                          const SizedBox(height: 2),
                          Text(
                            p.status == 'rejete'
                                ? 'Refusée'
                                : p.status == 'brouillon' ? 'Brouillon' : 'En attente de validation',
                            style: GoogleFonts.poppins(
                              fontSize: 10, fontWeight: FontWeight.w600,
                              color: p.status == 'rejete'
                                  ? AppTheme.error
                                  : p.status == 'brouillon' ? AppTheme.textSecondary : AppTheme.warning,
                            ),
                          ),
                        ] else if (widget.availability == 'archived' || widget.availability == 'unavailable') ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.availability == 'archived' ? 'Archivée' : 'Clôturée (indisponible)',
                            style: GoogleFonts.poppins(
                              fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        TrustBadge(property: p),
                        const SizedBox(height: 6),
                        Row(children: [
                          Icon(Icons.remove_red_eye_outlined, size: 13, color: AppTheme.textHint),
                          const SizedBox(width: 3),
                          Text('${p.vues} vues', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                          const SizedBox(width: 8),
                          const Icon(Icons.star_rounded, size: 13, color: AppTheme.accentLight),
                          const SizedBox(width: 2),
                          Text('${p.rating}', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                        ]),
                        const SizedBox(height: 6),
                        Text(formatFcfa(p.prix), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: _active ? AppTheme.primary : AppTheme.textHint)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (p.status == 'approuve' && !p.isVelqixApproved)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: _buildApprovalRow(p),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _showAvailabilityHistory(context, p),
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: Text('Historique des confirmations',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500)),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Toggle active
                  Row(children: [
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: _active,
                        onChanged: (v) { setState(() => _active = v); widget.onToggle(v); },
                        activeColor: AppTheme.success,
                      ),
                    ),
                    Text(_active ? 'Active' : 'Pausée', style: GoogleFonts.poppins(fontSize: 11, color: _active ? AppTheme.success : AppTheme.textHint, fontWeight: FontWeight.w500)),
                  ]),
                  const Spacer(),
                  // Edit
                  GestureDetector(
                    onTap: widget.onEdit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.edit_outlined, size: 14, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Text(tr('mylist_edit'), style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Delete
                  GestureDetector(
                    onTap: widget.onDelete,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.delete_outline_rounded, size: 14, color: AppTheme.error),
                        const SizedBox(width: 4),
                        Text(tr('mylist_delete_short'), style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.error, fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ),
                  if (p.status == 'approuve')
                    PopupMenuButton<String>(
                      tooltip: 'Plus d\'actions',
                      icon: const Icon(Icons.more_vert_rounded, size: 18),
                      onSelected: (v) {
                        if (v == 'close') widget.onClose();
                        if (v == 'archive') widget.onArchive();
                        if (v == 'restore') widget.onRestore();
                      },
                      itemBuilder: (_) => [
                        if (widget.availability == 'archived')
                          const PopupMenuItem(value: 'restore', child: Text('Réactiver l\'annonce'))
                        else ...[
                          if (widget.availability == 'unavailable')
                            const PopupMenuItem(value: 'restore', child: Text('Remettre en ligne'))
                          else
                            const PopupMenuItem(value: 'close', child: Text('Clôturer (louée / vendue)')),
                          const PopupMenuItem(value: 'archive', child: Text('Archiver')),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Carte d'annonce en attente avec son statut serveur ──────────────────────
class _PendingPropertyCard extends StatelessWidget {
  final PropertyModel property;
  final VoidCallback? onEdit;
  final VoidCallback? onResubmit;
  const _PendingPropertyCard({required this.property, this.onEdit, this.onResubmit});

  @override
  Widget build(BuildContext context) {
    final p = property;
    final inPending = p.status == 'en_attente';
    final published = p.status == 'approuve';

    // Couleur et icône selon le statut
    Color borderColor;
    Color badgeBg;
    Color badgeText;
    IconData statusIcon;
    String statusLabel;

    if (published) {
      borderColor = AppTheme.success.withOpacity(0.4);
      badgeBg = AppTheme.success.withOpacity(0.1);
      badgeText = AppTheme.success;
      statusIcon = Icons.check_circle_rounded;
      statusLabel = '✓ Approuvé et publié';
    } else if (inPending) {
      borderColor = AppTheme.warning.withOpacity(0.4);
      badgeBg = AppTheme.warning.withOpacity(0.1);
      badgeText = AppTheme.warning;
      statusIcon = Icons.hourglass_top_rounded;
      statusLabel = tr('mylist_status_pending');
    } else if (p.status == 'brouillon') {
      borderColor = AppTheme.border;
      badgeBg = AppTheme.textSecondary.withOpacity(0.1);
      badgeText = AppTheme.textSecondary;
      statusIcon = Icons.edit_note_rounded;
      statusLabel = 'Brouillon';
    } else {
      borderColor = AppTheme.error.withOpacity(0.3);
      badgeBg = AppTheme.error.withOpacity(0.08);
      badgeText = AppTheme.error;
      statusIcon = Icons.error_outline_rounded;
      statusLabel = 'Refusée';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Miniature
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64, height: 64,
                child: p.images.isNotEmpty && p.images.first.startsWith('http')
                    ? Image.network(optimizeImageUrl(p.images.first, displayWidth: 300), fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            color: AppTheme.divider,
                            child: Icon(Icons.image_rounded, color: AppTheme.textHint)))
                    : Container(
                        color: AppTheme.primary.withOpacity(0.1),
                        child: const Icon(Icons.home_rounded, color: AppTheme.primary, size: 28)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.titre,
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(p.adresse.short,
                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              Row(children: [
                Icon(statusIcon, size: 13, color: badgeText),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                  child: Text(statusLabel,
                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: badgeText)),
                ),
              ]),
            ])),
          ]),
        ),
        if (!published && (onEdit != null || onResubmit != null)) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (onEdit != null)
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text('Modifier le bien', style: GoogleFonts.poppins(fontSize: 12)),
                ),
              if ((p.status == 'rejete' || p.status == 'brouillon') && onResubmit != null) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onResubmit,
                  icon: const Icon(Icons.publish_rounded, size: 16),
                  label: Text(p.status == 'brouillon' ? 'Soumettre' : 'Soumettre à nouveau', style: GoogleFonts.poppins(fontSize: 12)),
                ),
              ],
            ]),
          ),
        ],
      ]),
    );
  }
}

// ─── Historique des confirmations d'une annonce (ANN-06) ─────────────────────
Future<void> _showAvailabilityHistory(BuildContext context, PropertyModel p) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AvailabilityHistorySheet(property: p),
  );
}

class _AvailabilityHistorySheet extends StatefulWidget {
  final PropertyModel property;
  const _AvailabilityHistorySheet({required this.property});
  @override
  State<_AvailabilityHistorySheet> createState() => _AvailabilityHistorySheetState();
}

class _AvailabilityHistorySheetState extends State<_AvailabilityHistorySheet> {
  late Future<List<AvailabilityEventItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = AvailabilityService.instance.getHistory(widget.property.id);
  }

  void _retry() {
    setState(() {
      _future = AvailabilityService.instance.getHistory(widget.property.id);
    });
  }

  String _fmt(DateTime? d) {
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} à ${two(d.hour)}:${two(d.minute)}';
  }

  IconData _icon(String action) {
    if (action.startsWith('suspended')) return Icons.block_rounded;
    if (action.startsWith('restored')) return Icons.restore_rounded;
    if (action == 'declared_available' || action == 'confirmed_via_request') {
      return Icons.check_circle_rounded;
    }
    return Icons.info_rounded;
  }

  Color _color(String action) {
    if (action.startsWith('suspended')) return AppTheme.error;
    if (action.startsWith('restored')) return AppTheme.info;
    if (action == 'declared_available' || action == 'confirmed_via_request') {
      return AppTheme.success;
    }
    return AppTheme.warning;
  }

  Widget _row(AvailabilityEventItem e) {
    final color = _color(e.action);
    // L'identité d'un membre de l'équipe n'est pas montrée : on affiche l'équipe.
    final who = e.channel == 'app'
        ? (e.actorName ?? 'Vous')
        : AvailabilityEventItem.channelLabel(e.channel);
    // Les notes internes (ex. « Signalement <id> ») ne concernent pas le propriétaire.
    final note = (e.note != null && !e.note!.startsWith('Signalement')) ? e.note : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(_icon(e.action), size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AvailabilityEventItem.actionLabel(e.action),
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text('Statut : ${AvailabilityEventItem.statusLabel(e.resultStatus)}',
                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
            if (note != null)
              Text(note, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(height: 2),
            Text('${_fmt(e.createdAt)} · $who',
                style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textHint)),
          ]),
        ),
      ]),
    );
  }

  Widget _message(IconData icon, String text, {bool retry = false}) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 44, color: AppTheme.textHint),
        const SizedBox(height: 12),
        Text(text,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
        if (retry) ...[
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _retry, child: Text('Réessayer', style: GoogleFonts.poppins(fontSize: 12))),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Historique des confirmations',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(widget.property.titre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
            ]),
          ),
          Flexible(
            child: FutureBuilder<List<AvailabilityEventItem>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return _message(Icons.error_outline_rounded,
                      snap.error.toString().replaceFirst('Exception: ', ''),
                      retry: true);
                }
                final events = snap.data ?? const <AvailabilityEventItem>[];
                if (events.isEmpty) {
                  return _message(Icons.history_rounded,
                      'Aucune confirmation ni aucun changement de statut enregistré pour cette annonce.');
                }
                return ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: AppTheme.border),
                  itemBuilder: (_, i) => _row(events[i]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
