import 'dart:async';
import 'package:flutter/material.dart';
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
    if (q.length < 2) {
      setState(() { _users = []; _properties = []; _hasSearched = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (!mounted) return;
    setState(() { _loading = true; _lastQuery = q; });
    try {
      final res = await ApiService.instance.get(
        '/search?q=${Uri.encodeComponent(q)}',
        auth: true,
      );
      if (!mounted) return;
      final data = res['data'] ?? {};
      setState(() {
        _users      = (data['users']      as List?) ?? [];
        _properties = (data['properties'] as List?) ?? [];
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
  PropertyModel _propertyFromJson(Map<String, dynamic> p) {
    // Propriétaire (inclus via Prisma include)
    final propData   = p['proprietaire'] as Map<String, dynamic>? ?? {};
    final proprietaire = UserModel(
      id:        propData['id']       ?? '',
      nom:       propData['nom']      ?? '',
      prenom:    propData['prenom']   ?? '',
      email:     propData['email']    ?? '',
      telephone: propData['telephone'] ?? '',
      avatarUrl: propData['avatarUrl'],
      createdAt: DateTime.tryParse(propData['createdAt'] ?? '') ?? DateTime.now(),
      role:      propData['role']     ?? 'client',
    );

    // Type / ListingType / Catégorie
    PropertyType type;
    switch ((p['type'] ?? '').toString().toLowerCase()) {
      case 'mobilier': type = PropertyType.mobilier; break;
      default:         type = PropertyType.immobilier;
    }

    ListingType listingType;
    switch ((p['listingType'] ?? '').toString().toLowerCase()) {
      case 'vente':    listingType = ListingType.vente;    break;
      case 'les_deux': listingType = ListingType.les_deux; break;
      default:         listingType = ListingType.location;
    }

    PropertyCategory categorie;
    switch ((p['categorie'] ?? '').toString().toLowerCase()) {
      case 'maison':      categorie = PropertyCategory.maison;      break;
      case 'appartement': categorie = PropertyCategory.appartement; break;
      case 'terrain':     categorie = PropertyCategory.terrain;     break;
      case 'bureau':      categorie = PropertyCategory.bureau;      break;
      case 'entrepot':    categorie = PropertyCategory.entrepot;    break;
      case 'voiture':     categorie = PropertyCategory.voiture;     break;
      case 'moto':        categorie = PropertyCategory.moto;        break;
      case 'camion':      categorie = PropertyCategory.camion;      break;
      case 'equipement':  categorie = PropertyCategory.equipement;  break;
      default:            categorie = PropertyCategory.autre;
    }

    return PropertyModel(
      id:              p['id']          ?? '',
      titre:           p['titre']       ?? '',
      description:     p['description'] ?? '',
      type:            type,
      listingType:     listingType,
      categorie:       categorie,
      prix:            (p['prix'] ?? 0).toDouble(),
      prixParJour:     p['prixParJour'],
      images:          (p['images'] as List?)?.cast<String>() ?? [],
      adresse: AddressModel(
        rue:       p['adresse'] ?? '',
        ville:     p['ville']   ?? '',
        pays:      p['pays']    ?? 'Togo',
        latitude:  (p['latitude']  as num?)?.toDouble(),
        longitude: (p['longitude'] as num?)?.toDouble(),
      ),
      proprietaire:    proprietaire,
      caracteristiques:(p['caracteristiques'] as List?)?.cast<String>() ?? [],
      rating:          (p['rating']    ?? 0).toDouble(),
      totalAvis:       (p['totalAvis'] ?? 0) as int,
      isAvailable:     p['isAvailable'] ?? true,
      isFeatured:      p['isFeatured']  ?? false,
      vues:            (p['vues']       ?? 0) as int,
      surface:         p['surface'],
      nombrePieces:    p['nombrePieces'] as int?,
      annee:           p['annee']        as int?,
      status:          p['status']       ?? 'approuve',
      createdAt: DateTime.tryParse(p['createdAt'] ?? '') ?? DateTime.now(),
    );
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
                  ? Image.network(firstImg, fit: BoxFit.cover,
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