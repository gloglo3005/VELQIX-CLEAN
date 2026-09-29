import '../services/app_translations.dart';
import '../main.dart' show localeNotifier;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/property_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'property_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  // ⚠️ Avant : filtrait MockDataService.properties via le Set local
  // globalFavorites (jamais persisté côté serveur). Maintenant : chargé
  // depuis GET /api/properties/favorites, la vraie source de vérité.
  List<PropertyModel> _favorites = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final favs = await PropertyService.instance.getFavorites();
      // Garde le Set local (utilisé par FavoriteButton sur les autres écrans) synchronisé
      globalFavorites
        ..clear()
        ..addAll(favs.map((p) => p.id));
      if (mounted) setState(() { _favorites = favs; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Impossible de charger les favoris'; _loading = false; });
    }
  }

  Future<void> _removeFav(PropertyModel p) async {
    setState(() {
      _favorites.removeWhere((f) => f.id == p.id);
      globalFavorites.remove(p.id);
    });
    final ok = await PropertyService.instance.removeFavorite(p.id);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        if (!_favorites.any((f) => f.id == p.id)) _favorites.add(p);
        globalFavorites.add(p.id);
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(tr('fav_removed'),
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
      backgroundColor: AppTheme.textSecondary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      action: SnackBarAction(
        label: tr('fav_undo'),
        textColor: Colors.white,
        onPressed: () async {
          setState(() {
            _favorites.add(p);
            globalFavorites.add(p.id);
          });
          final ok = await PropertyService.instance.addFavorite(p.id);
          if (!ok && mounted) {
            setState(() {
              _favorites.removeWhere((f) => f.id == p.id);
              globalFavorites.remove(p.id);
            });
          }
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: localeNotifier,
      builder: (context, _, __) {
    final favs = _favorites;
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
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.textPrimary),
          ),
        ),
        title: Text(tr('fav_title'),
            style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
                    const SizedBox(height: 12),
                    TextButton(onPressed: _load, child: Text(tr('common_retry'))),
                  ]),
                )
              : favs.isEmpty
              ? RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.7,
                      child: EmptyState(
                        icon: Icons.favorite_border_rounded,
                        title: tr('fav_no_fav'),
                        subtitle: tr('fav_no_fav_sub'),
                      ),
                    ),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(children: [
                    Text(
                      '${favs.length} bien${favs.length > 1 ? 's' : ''} sauvegardé${favs.length > 1 ? 's' : ''}',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ]),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: favs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _FavoriteCard(
                      property: favs[i],
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PropertyDetailScreen(property: favs[i]))),
                      onRemove: () => _removeFav(favs[i]),
                    ),
                  ),
                ),
              ],
            ),
                ),
    );
      }, // builder
    ); // ValueListenableBuilder
  }
}

class _FavoriteCard extends StatelessWidget {
  final PropertyModel property;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  const _FavoriteCard({required this.property, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final p = property;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
              child: Image.network(p.firstImage,
                  width: 110, height: 110, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(width: 110, height: 110, color: AppTheme.divider)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(p.titre,
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      // Bouton cœur branché sur globalFavorites
                      GestureDetector(
                        onTap: onRemove,
                        child: const Icon(Icons.favorite_rounded, color: AppTheme.error, size: 20),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: AppTheme.textHint),
                      const SizedBox(width: 3),
                      Text(p.adresse.short,
                          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.star_rounded, size: 13, color: AppTheme.accentLight),
                      const SizedBox(width: 3),
                      Text('${p.rating} (${p.totalAvis})',
                          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(
                        child: Text(formatFcfa(p.prix),
                            style: GoogleFonts.poppins(
                                fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: p.listingType == ListingType.vente
                              ? AppTheme.success.withOpacity(0.1)
                              : AppTheme.info.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(p.listingLabel,
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: p.listingType == ListingType.vente
                                    ? AppTheme.success
                                    : AppTheme.info)),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}