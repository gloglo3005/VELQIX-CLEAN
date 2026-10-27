import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/image_url.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'property_detail_screen.dart';
import 'messages_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _focusNode  = FocusNode();
  Timer? _debounce;

  List<dynamic> _users      = [];
  List<dynamic> _properties = [];
  bool   _loading     = false;
  bool   _hasSearched = false;
  String _lastQuery   = '';

  // Filtres d'annonces (ANN-02) : appliqués côté serveur par GET /properties
  double? _surfaceMin;
  double? _surfaceMax;
  int?    _piecesMin;
  int?    _freshDays;      // confirmées par l'annonceur depuis N jours
  bool    _verifiedOnly = false;

  bool get _hasFilters =>
      _surfaceMin != null || _surfaceMax != null || _piecesMin != null ||
      _freshDays != null || _verifiedOnly;

  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _focusNode.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  // ─── Debounce 400ms ──────────────────────────────────────────────────────────
  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q == _lastQuery) return;
    if (q.length < 2 && !_hasFilters) {
      setState(() { _users = []; _properties = []; _hasSearched = false; _lastQuery = ''; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (!mounted) return;
    setState(() { _loading = true; _lastQuery = q; });
    try {
      var users = <dynamic>[];
      var props = <dynamic>[];
      if (q.length >= 2) {
        final res = await ApiService.instance.get(
          '/search?q=${Uri.encodeComponent(q)}',
          auth: true,
        );
        final data = res['data'] ?? {};
        users = (data['users']      as List?) ?? [];
        props = (data['properties'] as List?) ?? [];
      }
      // Filtres actifs : les annonces viennent de /properties (filtrées côté serveur)
      if (_hasFilters) props = await _filteredProperties(q);
      if (!mounted) return;
      setState(() {
        _users      = users;
        _properties = props;
        _hasSearched = true;
      });
      if (_users.isEmpty && _properties.isNotEmpty) _tabCtrl.animateTo(1);
      if (_properties.isEmpty && _users.isNotEmpty) _tabCtrl.animateTo(0);
    } catch (_) {
      if (mounted) setState(() => _hasSearched = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clear() {
    _searchCtrl.clear();
    setState(() { _users = []; _properties = []; _hasSearched = false; _lastQuery = ''; });
    _focusNode.requestFocus();
  }

  // ─── Reconstruction PropertyModel depuis JSON API ─────────────────────────────
  PropertyModel _propertyFromJson(Map<String, dynamic> p) => PropertyModel.fromJson(p);

  // ─── Annonces filtrées (surface, pièces, fraîcheur, vérification) ────────────
  Future<List<dynamic>> _filteredProperties(String q) async {
    final params = <String, String>{
      if (_surfaceMin != null) 'surfaceMin': _surfaceMin!.toString(),
      if (_surfaceMax != null) 'surfaceMax': _surfaceMax!.toString(),
      if (_piecesMin != null)  'piecesMin': _piecesMin!.toString(),
      if (_freshDays != null)  'confirmedWithinDays': _freshDays!.toString(),
      if (_verifiedOnly)       'verified': 'true',
    };
    final res = await ApiService.instance.get(
      '/properties?${Uri(queryParameters: params).query}',
    );
    if (res['success'] != true) return <dynamic>[];
    var list = (res['data'] as List?) ?? <dynamic>[];
    // Le texte saisi (si >= 2 caractères) affine ensuite titre, ville, adresse, catégorie.
    if (q.length >= 2) {
      final needle = q.toLowerCase();
      list = list.where((p) {
        final m = p as Map<String, dynamic>;
        return [m['titre'], m['ville'], m['adresse'], m['categorie']]
            .any((v) => (v ?? '').toString().toLowerCase().contains(needle));
      }).toList();
    }
    return list;
  }

  // ─── Feuille de filtres ──────────────────────────────────────────────────────
  Future<void> _openFilters() async {
    final surfMinCtrl = TextEditingController(text: _surfaceMin?.toStringAsFixed(0) ?? '');
    final surfMaxCtrl = TextEditingController(text: _surfaceMax?.toStringAsFixed(0) ?? '');
    int?  pieces   = _piecesMin;
    int?  fresh    = _freshDays;
    bool  verified = _verifiedOnly;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.adaptiveSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        final txt = AppTheme.adaptiveText(ctx);

        Widget title(String s) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(s, style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w600, color: txt)),
        );

        Widget choice<T>(String label, T? value, T? current, void Function(T?) onPick) =>
            ChoiceChip(
              label: Text(label, style: GoogleFonts.poppins(fontSize: 12)),
              selected: current == value,
              onSelected: (_) => setSheet(() => onPick(value)),
            );

        Widget numberField(TextEditingController c, String label) => Expanded(
          child: TextField(
            controller: c,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        );

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filtres', style: GoogleFonts.poppins(
                    fontSize: 17, fontWeight: FontWeight.w700, color: txt)),
                title('Surface (m²)'),
                Row(children: [
                  numberField(surfMinCtrl, 'Min'),
                  const SizedBox(width: 12),
                  numberField(surfMaxCtrl, 'Max'),
                ]),
                title('Nombre de pièces'),
                Wrap(spacing: 8, children: [
                  choice<int>('Toutes', null, pieces, (v) => pieces = v),
                  for (final n in [1, 2, 3, 4, 5])
                    choice<int>('$n+', n, pieces, (v) => pieces = v),
                ]),
                title('Confirmées par l\'annonceur'),
                Wrap(spacing: 8, children: [
                  choice<int>('Toutes', null, fresh, (v) => fresh = v),
                  choice<int>('7 jours', 7, fresh, (v) => fresh = v),
                  choice<int>('30 jours', 30, fresh, (v) => fresh = v),
                  choice<int>('90 jours', 90, fresh, (v) => fresh = v),
                ]),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Vérifiées sur le terrain uniquement',
                      style: GoogleFonts.poppins(fontSize: 13, color: txt)),
                  value: verified,
                  onChanged: (v) => setSheet(() => verified = v),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setSheet(() {
                        surfMinCtrl.clear();
                        surfMaxCtrl.clear();
                        pieces = null;
                        fresh = null;
                        verified = false;
                      }),
                      child: const Text('Réinitialiser'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Appliquer'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        );
      }),
    );

    if (applied != true || !mounted) return;

    var minS = double.tryParse(surfMinCtrl.text.trim().replaceAll(',', '.'));
    var maxS = double.tryParse(surfMaxCtrl.text.trim().replaceAll(',', '.'));
    if (minS != null && maxS != null && minS > maxS) {
      final t = minS; minS = maxS; maxS = t;
    }
    setState(() {
      _surfaceMin   = minS;
      _surfaceMax   = maxS;
      _piecesMin    = pieces;
      _freshDays    = fresh;
      _verifiedOnly = verified;
    });

    final q = _searchCtrl.text.trim();
    if (_hasFilters || q.length >= 2) {
      _debounce?.cancel();
      await _search(q);
    } else {
      setState(() { _users = []; _properties = []; _hasSearched = false; _lastQuery = ''; });
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf   = AppTheme.adaptiveSurface(context);
    final hint   = isDark ? AppTheme.darkTxtSec : AppTheme.textHint;
    final txt    = AppTheme.adaptiveText(context);

    return Scaffold(
      backgroundColor: AppTheme.adaptiveBg(context),
      appBar: AppBar(
        backgroundColor: surf,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: txt),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchCtrl,
          focusNode:  _focusNode,
          onChanged:  _onChanged,
          style: GoogleFonts.poppins(fontSize: 15, color: txt),
          decoration: InputDecoration(
            hintText:  'Bien, ville, utilisateur…',
            hintStyle: GoogleFonts.poppins(fontSize: 13, color: hint),
            border:    InputBorder.none,
            isDense:   true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close_rounded, color: hint, size: 20),
                    onPressed: _clear,
                  )
                : null,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Filtres',
            icon: Icon(Icons.tune_rounded, color: _hasFilters ? AppTheme.primary : txt),
            onPressed: _openFilters,
          ),
        ],
        bottom: _hasSearched
            ? TabBar(
                controller: _tabCtrl,
                labelColor:          AppTheme.primary,
                unselectedLabelColor: hint,
                indicatorColor:      AppTheme.primary,
                indicatorWeight:     2.5,
                labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                tabs: [
                  Tab(text: 'Utilisateurs (${_users.length})'),
                  Tab(text: 'Annonces (${_properties.length})'),
                ],
              )
            : null,
      ),
      body: _buildBody(isDark, surf, hint),
    );
  }

  Widget _buildBody(bool isDark, Color surf, Color hint) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2),
      );
    }
    if (!_hasSearched) return _buildEmptyState(hint);
    if (_users.isEmpty && _properties.isEmpty) return _buildNoResult(hint);

    return TabBarView(
      controller: _tabCtrl,
      children: [
        _buildUserList(hint),
        _buildPropertyList(isDark, surf, hint),
      ],
    );
  }

  // ─── État initial ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState(Color hint) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.search_rounded, size: 64, color: hint.withOpacity(0.35)),
      const SizedBox(height: 16),
      Text('Tapez au moins 2 caractères',
          style: GoogleFonts.poppins(fontSize: 15, color: hint)),
      const SizedBox(height: 6),
      Text('biens, villes, utilisateurs…',
          style: GoogleFonts.poppins(fontSize: 12, color: hint.withOpacity(0.6))),
    ]),
  );

  // ─── Aucun résultat ───────────────────────────────────────────────────────────
  Widget _buildNoResult(Color hint) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.search_off_rounded, size: 64, color: hint.withOpacity(0.35)),
      const SizedBox(height: 16),
      Text('Aucun résultat pour', style: GoogleFonts.poppins(fontSize: 15, color: hint)),
      const SizedBox(height: 4),
      Text('"$_lastQuery"',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700,
              color: AppTheme.adaptiveText(context))),
      const SizedBox(height: 10),
      Text('Essayez un autre mot-clé',
          style: GoogleFonts.poppins(fontSize: 12, color: hint.withOpacity(0.6))),
    ]),
  );

  // ─── Onglet vide ─────────────────────────────────────────────────────────────
  Widget _buildTabEmpty(String label, IconData icon, Color hint) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 48, color: hint.withOpacity(0.35)),
      const SizedBox(height: 12),
      Text(label, style: GoogleFonts.poppins(fontSize: 14, color: hint)),
    ]),
  );

  // ─── Convertir JSON → UserModel ──────────────────────────────────────────────
  UserModel _userModelFromJson(Map<String, dynamic> u) => UserModel(
    id:           u['id']?.toString() ?? '',
    nom:          u['nom']    ?? '',
    prenom:       u['prenom'] ?? '',
    email:        u['email']  ?? '',
    telephone:    u['telephone'] ?? '',
    avatarUrl:    u['avatarUrl'],
    isVerified:   u['isVerified'] == true,
    rating:       (u['rating'] as num?)?.toDouble() ?? 0.0,
    totalAvis:    u['totalAvis'] ?? 0,
    createdAt:    DateTime.tryParse(u['createdAt'] ?? '') ?? DateTime.now(),
    role:         u['role'] ?? 'client',
    isPremium:    u['isPremium'] == true,
    accountType:  u['accountType'] ?? 'personal',
    nomEntreprise: u['nomEntreprise'],
  );

  // ─── Liste utilisateurs ───────────────────────────────────────────────────────
  Widget _buildUserList(Color hint) {
    if (_users.isEmpty) return _buildTabEmpty('Aucun utilisateur trouvé', Icons.person_off_rounded, hint);

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _users.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: AppTheme.adaptiveBorder(context)),
      itemBuilder: (_, i) {
        final u        = _users[i] as Map<String, dynamic>;
        final name     = '${u['prenom'] ?? ''} ${u['nom'] ?? ''}'.trim();
        final email    = u['email']    ?? '';
        final avatar   = u['avatarUrl'] as String?;
        final verified = u['isVerified'] == true;
        final isBiz    = u['accountType'] == 'business';
        final rating   = (u['rating'] as num?)?.toDouble() ?? 0.0;
        final initials = name.split(' ').where((s) => s.isNotEmpty).take(2)
            .map((s) => s[0].toUpperCase()).join();
        final txt = AppTheme.adaptiveText(context);
        final sec = AppTheme.adaptiveTextSec(context);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primary.withOpacity(0.12),
            backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
            child: (avatar == null || avatar.isEmpty)
                ? Text(initials,
                    style: GoogleFonts.poppins(color: AppTheme.primary,
                        fontWeight: FontWeight.w700, fontSize: 13))
                : null,
          ),
          title: Row(children: [
            Flexible(child: Text(name,
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: txt),
                overflow: TextOverflow.ellipsis)),
            if (verified) ...[
              const SizedBox(width: 4),
              const Icon(Icons.verified_rounded, size: 14, color: AppTheme.info),
            ],
          ]),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(email, style: GoogleFonts.poppins(fontSize: 11, color: sec)),
            if (isBiz && (u['nomEntreprise'] ?? '').isNotEmpty) ...[
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(u['nomEntreprise'],
                    style: GoogleFonts.poppins(fontSize: 9,
                        color: const Color(0xFFF59E0B), fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            // Note étoile
            if (rating > 0) ...[
              const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
              const SizedBox(width: 2),
              Text(rating.toStringAsFixed(1),
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: txt)),
              const SizedBox(width: 8),
            ],
            // Bouton message
            GestureDetector(
              onTap: () {
                final userModel = _userModelFromJson(u);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChatScreen(user: userModel),
                ));
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.chat_bubble_outline_rounded,
                    size: 18, color: AppTheme.primary),
              ),
            ),
          ]),
        );
      },
    );
  }

  // ─── Liste annonces ───────────────────────────────────────────────────────────
  Widget _buildPropertyList(bool isDark, Color surf, Color hint) {
    if (_properties.isEmpty) {
      return _buildTabEmpty('Aucune annonce trouvée', Icons.home_work_outlined, hint);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _properties.length,
      itemBuilder: (_, i) {
        final p = _properties[i] as Map<String, dynamic>;
        return _PropertyCard(
          data:     p,
          surf:     surf,
          onTap: () {
            final property = _propertyFromJson(p);
            Navigator.push(context,
              MaterialPageRoute(builder: (_) => PropertyDetailScreen(property: property)));
          },
        );
      },
    );
  }
}

// ─── Card annonce ─────────────────────────────────────────────────────────────
class _PropertyCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color surf;
  final VoidCallback onTap;

  const _PropertyCard({required this.data, required this.surf, required this.onTap});

  String _formatPrice(num prix) => prix.toInt().toString()
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');

  @override
  Widget build(BuildContext context) {
    final titre      = data['titre']     ?? '';
    final ville      = data['ville']     ?? data['adresse'] ?? '';
    final prix       = (data['prix']     ?? 0) as num;
    final categorie  = data['categorie'] ?? '';
    final images     = (data['images']   as List?)?.cast<String>() ?? [];
    final firstImg   = images.isNotEmpty ? images.first : null;
    final listingType = data['listingType'] ?? '';
    final txt = AppTheme.adaptiveText(context);
    final sec = AppTheme.adaptiveTextSec(context);
    final border = AppTheme.adaptiveBorder(context);

    Color listingColor() {
      switch (listingType) {
        case 'vente':    return AppTheme.success;
        case 'location': return AppTheme.info;
        default:         return AppTheme.accent;
      }
    }

    String listingLabel() {
      switch (listingType) {
        case 'vente':    return 'Vente';
        case 'location': return 'Location';
        default:         return 'Vente / Location';
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            child: SizedBox(
              width: 100, height: 100,
              child: firstImg != null
                  ? Image.network(optimizeImageUrl(firstImg, displayWidth: 100), fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imgFallback())
                  : _imgFallback(),
            ),
          ),
          // Infos
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Badges
                Row(children: [
                  _Badge(label: listingLabel(), color: listingColor()),
                  const SizedBox(width: 6),
                  _Badge(label: categorie, color: AppTheme.primary),
                ]),
                const SizedBox(height: 6),
                Text(titre,
                    style: GoogleFonts.poppins(fontSize: 13,
                        fontWeight: FontWeight.w600, color: txt),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.location_on_rounded, size: 12, color: sec),
                  const SizedBox(width: 3),
                  Expanded(child: Text(ville,
                      style: GoogleFonts.poppins(fontSize: 11, color: sec),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 6),
                Text('${_formatPrice(prix)} FCFA',
                    style: GoogleFonts.poppins(fontSize: 14,
                        fontWeight: FontWeight.w700, color: AppTheme.primary)),
              ]),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.chevron_right_rounded, color: AppTheme.primary, size: 20),
          ),
        ]),
      ),
    );
  }

  Widget _imgFallback() => Container(
    color: AppTheme.primary.withOpacity(0.07),
    child: const Center(
      child: Icon(Icons.home_work_rounded, color: AppTheme.primary, size: 32)),
  );
}

// ─── Badge pill ───────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label,
        style: GoogleFonts.poppins(fontSize: 9,
            fontWeight: FontWeight.w700, color: color)),
  );
}
