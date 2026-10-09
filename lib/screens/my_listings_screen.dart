import '../services/app_translations.dart';
import '../main.dart' show localeNotifier;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart'; // NEW : vraie source de données
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

  // NOTE : /properties/my renvoie TOUTES les annonces de l'utilisateur, quel
  // que soit leur statut (en_attente, approuve, rejete) — donc plus besoin de
  // fusionner avec MockDataService ni de deviner l'état localement.
  List<PropertyModel> get _myProps => _serverProps;

  // Onglet « En attente » : annonces en cours de validation ET refusées
  // (avant, les refusées n'apparaissaient nulle part avec une action possible).
  List<PropertyModel> get _myPendingProps =>
      _serverProps.where((p) => p.status != 'approuve').toList();

  List<PropertyModel> get _activeProps =>
      _serverProps.where((p) => p.isAvailable && p.status == 'approuve').toList();
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
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddListingScreen())),
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
          const Icon(Icons.hourglass_empty_rounded, size: 52, color: Color(0xFFCBD5E1)),
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
        onButton: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddListingScreen())),
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

  // ─── Soumettre à nouveau une annonce refusée ───────────────────────────────
  Future<void> _resubmit(PropertyModel p) async {
    final err = await PropertyService.instance.submitProperty(p.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? 'Annonce soumise à nouveau. En attente de validation.',
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
  const _ListingManageCard({required this.property, required this.onTap, required this.onEdit, required this.onDelete, required this.onToggle});

  @override
  State<_ListingManageCard> createState() => _ListingManageCardState();
}

class _ListingManageCardState extends State<_ListingManageCard> {
  late bool _active = widget.property.isAvailable;

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
                    child: Image.network(p.firstImage, width: 100, height: 100, fit: BoxFit.cover,
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
                            p.status == 'rejete' ? 'Refusée' : 'En attente de validation',
                            style: GoogleFonts.poppins(
                              fontSize: 10, fontWeight: FontWeight.w600,
                              color: p.status == 'rejete' ? AppTheme.error : AppTheme.warning,
                            ),
                          ),
                        ],
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
                    ? Image.network(p.images.first, fit: BoxFit.cover,
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
              if (p.status == 'rejete' && onResubmit != null) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onResubmit,
                  icon: const Icon(Icons.publish_rounded, size: 16),
                  label: Text('Soumettre à nouveau', style: GoogleFonts.poppins(fontSize: 12)),
                ),
              ],
            ]),
          ),
        ],
      ]),
    );
  }
}