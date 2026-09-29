import 'package:flutter/material.dart';
import '../services/app_translations.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../models/models.dart';
import '../services/property_service.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart' show followersUpdateNotifier, propertyViewsUpdateNotifier;
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../main.dart' show currencyNotifier, localeNotifier;
// import 'payment_screen.dart'; // 🚫 DÉSACTIVÉ (25/08/2026) : plus de transaction directe
import 'messages_screen.dart';
import 'owner_profile_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class PropertyDetailScreen extends StatefulWidget {
  final PropertyModel property;
  const PropertyDetailScreen({super.key, required this.property});

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  int _imgIndex = 0;
  bool get _isFav => globalFavorites.contains(widget.property.id);
  bool _favBusy = false;
  bool _showFullDesc = false;

  // ⚠️ Avant : les avis venaient de MockDataService.avis (100% factice).
  // Maintenant : chargés depuis GET /api/properties/:id/avis.
  List<AvisModel> _avis = [];
  bool _avisLoading = true;

  // ⚠️ Avant : le bouton "Suivre" et les stats Abonnés/Suivi(e)s lisaient
  // followersMapNotifier/userFollowingMapNotifier — des ValueNotifier
  // jamais initialisés depuis le backend, donc toujours vides au démarrage
  // de l'app (état "pas abonné" même si on l'était déjà). Maintenant : état
  // réel chargé une fois depuis GET /api/users/:id.
  bool _ownerIsFollowing = false;
  int _ownerFollowersCount = 0;
  int _ownerFollowingCount = 0;
  bool _followBusy = false;
  List<PropertyModel> _ownerListings = [];

  // Mis à jour en direct via propertyViewsUpdateNotifier (voir _onViewsUpdate).
  // null tant qu'aucun event n'est arrivé → on affiche widget.property.vues.
  int? _liveVues;

  @override
  void initState() {
    super.initState();
    _loadAvis();
    _registerView();
    _loadOwnerFollowState();
    followersUpdateNotifier.addListener(_onFollowersUpdate);
    propertyViewsUpdateNotifier.addListener(_onViewsUpdate);
  }

  @override
  void dispose() {
    followersUpdateNotifier.removeListener(_onFollowersUpdate);
    propertyViewsUpdateNotifier.removeListener(_onViewsUpdate);
    super.dispose();
  }

  void _onFollowersUpdate() {
    final update = followersUpdateNotifier.value;
    if (update == null) return;
    if (update.userId != widget.property.proprietaire.id) return;
    if (mounted) setState(() => _ownerFollowersCount = update.followersCount);
  }

  void _onViewsUpdate() {
    final update = propertyViewsUpdateNotifier.value;
    if (update == null) return;
    if (update.propertyId != widget.property.id) return;
    if (mounted) setState(() => _liveVues = update.vues);
  }

  // Incrémente le compteur de vues côté backend (POST /properties/:id/views).
  // Le backend dédup déjà par IP sur 30 min (viewDedupe.ts), donc pas besoin
  // de logique anti-spam ici. Échec silencieux : une vue ratée ne doit pas
  // gêner l'utilisateur ni bloquer l'affichage de la fiche.
  void _registerView() {
    PropertyService.instance.incrementViews(widget.property.id).catchError((_) {});
  }

  Future<void> _loadOwnerFollowState() async {
    final ownerId = widget.property.proprietaire.id;
    PropertyService.instance.getUserProperties(ownerId).then((list) {
      if (mounted) setState(() => _ownerListings = list);
    });
    final fresh = await PropertyService.instance.fetchUserProfile(
      ownerId,
      auth: AuthService.instance.isLoggedIn,
    );
    if (fresh != null && mounted) {
      setState(() {
        _ownerIsFollowing = fresh.isFollowedByMe;
        _ownerFollowersCount = fresh.followersCount;
        _ownerFollowingCount = fresh.followingCount;
      });
      // Garde followedOwnersNotifier cohérent pour les autres écrans
      // (owner_profile_screen.dart, etc.) qui l'écoutent aussi.
      final followed = Set<String>.from(followedOwnersNotifier.value);
      if (fresh.isFollowedByMe) {
        followed.add(ownerId);
      } else {
        followed.remove(ownerId);
      }
      followedOwnersNotifier.value = followed;
    }
  }

  Future<void> _toggleOwnerFollow() async {
    if (_followBusy) return;
    final ownerId = widget.property.proprietaire.id;
    final currentUserId = AuthService.instance.currentUser?.id;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecte-toi pour suivre ce propriétaire.')),
      );
      return;
    }

    final wasFollowing = _ownerIsFollowing;
    setState(() {
      _followBusy = true;
      _ownerIsFollowing = !wasFollowing;
      _ownerFollowersCount += wasFollowing ? -1 : 1;
    });
    final followed = Set<String>.from(followedOwnersNotifier.value);
    wasFollowing ? followed.remove(ownerId) : followed.add(ownerId);
    followedOwnersNotifier.value = followed;

    try {
      final ok = wasFollowing
          ? await PropertyService.instance.unfollowUser(ownerId)
          : await PropertyService.instance.followUser(ownerId);
      if (!ok) throw Exception('follow');
      if (!wasFollowing) {
        pushNotification(
          titre: '✅ Vous suivez ${widget.property.proprietaire.fullName}',
          message: 'Vous serez notifié dès qu\'il publie une nouvelle annonce.',
          type: 'info',
        );
      }
    } catch (_) {
      // Rollback en cas d'échec réseau
      if (mounted) {
        setState(() {
          _ownerIsFollowing = wasFollowing;
          _ownerFollowersCount += wasFollowing ? 1 : -1;
        });
        final rolledBack = Set<String>.from(followedOwnersNotifier.value);
        wasFollowing ? rolledBack.add(ownerId) : rolledBack.remove(ownerId);
        followedOwnersNotifier.value = rolledBack;
      }
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  Future<void> _toggleFav() async {
    if (_favBusy) return;
    if (!AuthService.instance.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecte-toi pour ajouter aux favoris.')),
      );
      return;
    }
    final id = widget.property.id;
    final wasFav = _isFav;
    setState(() {
      _favBusy = true;
      wasFav ? globalFavorites.remove(id) : globalFavorites.add(id);
    });
    final ok = wasFav
        ? await PropertyService.instance.removeFavorite(id)
        : await PropertyService.instance.addFavorite(id);
    if (!ok) wasFav ? globalFavorites.add(id) : globalFavorites.remove(id);
    if (mounted) setState(() => _favBusy = false);
  }

  Future<void> _loadAvis() async {
    try {
      final list = await PropertyService.instance.getAvis(widget.property.id);
      if (mounted) setState(() { _avis = list; _avisLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _avisLoading = false);
    }
  }

  void _openFullscreen(BuildContext context, List<String> images, int startIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      builder: (_) => _FullscreenImageViewer(images: images, initialIndex: startIndex),
    );
  }


  void _showShareSheet(BuildContext ctx, PropertyModel p) {
    final lang = localeNotifier.value.languageCode;
    final alreadyPending = p.status == 'en_attente';
    final alreadyPublished = p.status == 'approuve';

    void _doWhatsApp() async {
      final encoded = Uri.encodeComponent(p.shareText);
      final uri = Uri.parse('https://wa.me/?text=$encoded');
      if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    void _doEmail() async {
      final subject = Uri.encodeComponent(p.getLocalizedTitre(lang));
      final body = Uri.encodeComponent(p.shareText);
      final uri = Uri.parse('mailto:?subject=$subject&body=$body');
      if (await canLaunchUrl(uri)) launchUrl(uri);
    }

    void _doCopy() {
      Clipboard.setData(ClipboardData(text: p.shareText));
      Navigator.pop(ctx);
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(tr('detail_copied')),
        backgroundColor: const Color(0xFF6366F1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
    }

    _showFallbackSheet(ctx, p, lang, alreadyPending, alreadyPublished, _doCopy, _doWhatsApp, _doEmail);
  }

  void _showFallbackSheet(
    BuildContext ctx, PropertyModel p, String lang,
    bool alreadyPending, bool alreadyPublished,
    VoidCallback onCopy, VoidCallback onWhatsApp, VoidCallback onEmail,
  ) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),

          if (alreadyPublished)
            _StatusBanner(color: AppTheme.success, icon: Icons.check_circle_rounded,
                text: 'Ce bien est publié et visible par tous ✓')
          else if (alreadyPending)
            _StatusBanner(color: AppTheme.warning, icon: Icons.hourglass_top_rounded,
                text: 'En attente de validation par l\'admin…')
          else
            _StatusBanner(color: AppTheme.error, icon: Icons.block_rounded,
                text: 'Ce bien n\'est pas visible publiquement.'),

          const SizedBox(height: 16),

          // Aperçu du lien
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.getLocalizedTitre(lang), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 4),
              Text(p.adresse.full, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.link_rounded, size: 14, color: Color(0xFF6366F1)),
                const SizedBox(width: 4),
                Expanded(child: Text(p.shareUrl, style: const TextStyle(color: Color(0xFF6366F1), fontSize: 12, decoration: TextDecoration.underline), overflow: TextOverflow.ellipsis)),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          Text('Share via', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          // Row 1 : Copy, WhatsApp, Email, Telegram
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _ShareOption(icon: Icons.copy_rounded,   label: tr('detail_copy'), color: const Color(0xFF6366F1), onTap: onCopy),
            _ShareOption(icon: Icons.chat_rounded,   label: 'WhatsApp',  color: const Color(0xFF25D366), onTap: () { Navigator.pop(ctx); onWhatsApp(); }),
            _ShareOption(icon: Icons.email_rounded,  label: 'Email',     color: const Color(0xFF0EA5E9), onTap: () { Navigator.pop(ctx); onEmail(); }),
            _ShareOption(icon: Icons.send_rounded,   label: 'Telegram',  color: const Color(0xFF2AABEE),
              onTap: () {
                Navigator.pop(ctx);
                final encoded = Uri.encodeComponent(p.shareText);
                launchUrl(Uri.parse('https://t.me/share/url?url=${Uri.encodeComponent(p.shareUrl)}&text=$encoded'), mode: LaunchMode.externalApplication);
              }),
          ]),
          const SizedBox(height: 16),
          // Row 2 : Facebook, Instagram, X/Twitter, SMS
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _ShareOption(
              customIcon: _SocialIcon(color: const Color(0xFF1877F2), letter: 'f', fontSize: 20),
              label: 'Facebook',
              color: const Color(0xFF1877F2),
              onTap: () {
                Navigator.pop(ctx);
                final encoded = Uri.encodeComponent(p.shareUrl);
                launchUrl(Uri.parse('https://www.facebook.com/sharer/sharer.php?u=$encoded'), mode: LaunchMode.externalApplication);
              }),
            _ShareOption(
              customIcon: const _InstagramIcon(),
              label: 'Instagram',
              color: const Color(0xFFE1306C),
              onTap: () {
                Navigator.pop(ctx);
                // Instagram ne supporte pas le partage web direct — copier le lien
                Clipboard.setData(ClipboardData(text: p.shareUrl));
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                  content: Text('Lien copié — collez-le dans Instagram'),
                  backgroundColor: const Color(0xFFE1306C),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 3),
                ));
              }),
            _ShareOption(
              customIcon: _SocialIcon(color: Colors.black, letter: 'X', fontSize: 16, fontWeight: FontWeight.w900),
              label: 'X / Twitter',
              color: Colors.black,
              onTap: () {
                Navigator.pop(ctx);
                final encoded = Uri.encodeComponent(p.shareText);
                launchUrl(Uri.parse('https://twitter.com/intent/tweet?text=$encoded'), mode: LaunchMode.externalApplication);
              }),
            _ShareOption(icon: Icons.sms_rounded, label: 'SMS', color: const Color(0xFF34A853),
              onTap: () {
                Navigator.pop(ctx);
                final encoded = Uri.encodeComponent(p.shareText);
                launchUrl(Uri.parse('sms:?body=$encoded'), mode: LaunchMode.externalApplication);
              }),
          ]),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: localeNotifier,
      builder: (context, _, __) {
    final p = widget.property;
    final lang = localeNotifier.value.languageCode;
    final avis = _avis;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ─ Image Sliver ─
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.textPrimary),
              ),
            ),
            actions: [
              GestureDetector(
                onTap: _toggleFav,
                child: Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                  child: Icon(_isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 20, color: _isFav ? AppTheme.error : AppTheme.textPrimary),
                ),
              ),
              GestureDetector(
                onTap: () => _showShareSheet(context, p),
                child: Container(
                  margin: const EdgeInsets.only(top: 10, right: 16, bottom: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                  child: const Icon(Icons.share_rounded, size: 20, color: AppTheme.textPrimary),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  PageView.builder(
                    itemCount: p.images.length,
                    onPageChanged: (i) => setState(() => _imgIndex = i),
                    itemBuilder: (_, i) {
                      final url = p.images[i];
                      final Widget img = Image.network(url, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: AppTheme.divider));
                      return GestureDetector(
                        onTap: () => _openFullscreen(context, p.images, i),
                        child: img,
                      );
                    },
                  ),
                  Positioned(
                    bottom: 16,
                    left: 0, right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(p.images.length, (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _imgIndex ? 20 : 6, height: 6,
                        decoration: BoxDecoration(
                          color: i == _imgIndex ? Colors.white : Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      )),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─ Content ─
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: p.listingType == ListingType.vente ? AppTheme.success.withOpacity(0.1) : AppTheme.info.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(p.listingLabel, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600,
                                    color: p.listingType == ListingType.vente ? AppTheme.success : AppTheme.info)),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.09), borderRadius: BorderRadius.circular(6)),
                                child: Text(p.typeLabel, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            Text(p.getLocalizedTitre(lang), style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                      ValueListenableBuilder<String>(
                        valueListenable: currencyNotifier,
                        builder: (context, _, __) => Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(formatFcfa(p.prix), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                            if (p.prixParJour != null)
                              Text(formatPrixParJour(p.prixParJour), style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.textHint),
                    const SizedBox(width: 4),
                    Expanded(child: Text(p.adresse.full, style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary))),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.remove_red_eye_outlined, size: 14, color: AppTheme.textHint),
                    const SizedBox(width: 4),
                    Text('${_liveVues ?? p.vues} ${tr("detail_views")}', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(width: 12),
                    const Icon(Icons.star_rounded, size: 14, color: AppTheme.accentLight),
                    const SizedBox(width: 3),
                    Text('${p.rating} (${p.totalAvis} ${tr("detail_reviews")})', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                  ]),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Characteristics
                  if (p.caracteristiques.isNotEmpty) ...[
                    Text(tr('detail_features'), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: p.getLocalizedCaracteristiques(lang).map((c) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.success),
                          const SizedBox(width: 5),
                          Text(c, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                        ]),
                      )).toList(),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 16),
                  ],

                  // Description
                  Text(tr('detail_description'), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  Text(
                    p.getLocalizedDescription(lang),
                    style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary, height: 1.65),
                    maxLines: _showFullDesc ? null : 3,
                    overflow: _showFullDesc ? null : TextOverflow.ellipsis,
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _showFullDesc = !_showFullDesc),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(_showFullDesc ? tr('detail_see_less') : tr('detail_see_more'),
                          style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),

                  // ── Propriétaire ──────────────────────────────────────────
                  Text(tr('detail_owner'), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OwnerProfileScreen(owner: p.proprietaire))),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        children: [
                          // ── Date membre ──────────────────────────────────────
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.access_time_rounded, size: 13, color: AppTheme.textHint),
                            const SizedBox(width: 4),
                            Text(
                              () {
                                final diff = DateTime.now().difference(p.proprietaire.createdAt);
                                if (diff.inDays >= 365) return 'il y a ${(diff.inDays / 365).floor()} an(s)';
                                if (diff.inDays >= 30)  return 'il y a ${(diff.inDays / 30).floor()} mois';
                                if (diff.inDays >= 1)   return 'il y a ${diff.inDays} jour(s)';
                                return 'aujourd\'hui';
                              }(),
                              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
                            ),
                          ]),
                          const SizedBox(height: 14),

                          // ── Stats ligne ──────────────────────────────────────
                          Builder(builder: (_) {
                            final annonces = _ownerListings.length;
                            final vues = _ownerListings.fold<int>(0, (s, a) => s + a.vues);
                            return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                              _OwnerStat(label: 'Abonnés',   value: '$_ownerFollowersCount'),
                              _OwnerStatDivider(),
                              _OwnerStat(label: 'Suivi(e)s', value: '$_ownerFollowingCount'),
                              _OwnerStatDivider(),
                              _OwnerStat(label: 'Annonces',  value: '$annonces'),
                              _OwnerStatDivider(),
                              _OwnerStat(label: 'Vues',      value: '$vues'),
                            ]);
                          }),
                          const SizedBox(height: 18),

                          // ── Avatar centré ────────────────────────────────────
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 2.5),
                                ),
                                child: UserAvatar(user: p.proprietaire, radius: 36, showBadge: false),
                              ),
                              if (p.proprietaire.isVerified)
                                Positioned(
                                  bottom: 0, right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(color: Colors.lightBlueAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                    child: const Icon(Icons.verified_rounded, size: 11, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // ── Nom ──────────────────────────────────────────────
                          Text(
                            p.proprietaire.fullName,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 4),

                          // ── Badge PROPRIÉTAIRE ────────────────────────────────
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                            ),
                            child: Text(
                              p.proprietaire.nomEntreprise != null ? p.proprietaire.nomEntreprise! : 'PROPRIÉTAIRE',
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary, letterSpacing: 0.5),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // ── Étoiles ──────────────────────────────────────────
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            ...List.generate(5, (i) => Icon(
                              i < p.proprietaire.rating.floor() ? Icons.star_rounded : Icons.star_border_rounded,
                              size: 18, color: const Color(0xFFFFC107),
                            )),
                            const SizedBox(width: 6),
                            Text(
                              '${p.proprietaire.rating.toStringAsFixed(1)} (${p.proprietaire.totalAvis} Avis)',
                              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ]),
                          const SizedBox(height: 16),

                          // ── Bouton Suivre pleine largeur ──────────────────────
                          Row(children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _followBusy ? null : _toggleOwnerFollow,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _ownerIsFollowing ? AppTheme.surface : AppTheme.primary,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _ownerIsFollowing ? AppTheme.border : AppTheme.primary),
                                  ),
                                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    Icon(
                                      _ownerIsFollowing ? Icons.check_rounded : Icons.person_add_outlined,
                                      size: 16,
                                      color: _ownerIsFollowing ? AppTheme.textSecondary : Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _ownerIsFollowing ? tr('owner_following_btn') : tr('owner_follow_btn'),
                                      style: GoogleFonts.poppins(
                                        fontSize: 14, fontWeight: FontWeight.w600,
                                        color: _ownerIsFollowing ? AppTheme.textSecondary : Colors.white,
                                      ),
                                    ),
                                  ]),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Bouton chat
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => ChatScreen(user: p.proprietaire, propertyTitre: p.titre),
                              )),
                              child: Container(
                                width: 46, height: 46,
                                decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.chat_bubble_rounded, size: 20, color: Colors.white),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Reviews
                  if (avis.isNotEmpty) ...[
                    Row(children: [
                      Text(tr('detail_reviews_title'), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(width: 8),
                      RatingBarIndicator(rating: p.rating, itemBuilder: (_, __) => const Icon(Icons.star_rounded, color: AppTheme.accentLight), itemCount: 5, itemSize: 16),
                      const SizedBox(width: 6),
                      Text('${p.rating}', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 12),
                    ...avis.map((a) => _AvisCard(avis: a)),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),

      // ─ Bottom CTA ─ 🚫 Louer/Acheter DÉSACTIVÉS (25/08/2026) : plus de
      // transaction directe dans l'app — remplacé par un accès direct à la
      // discussion avec le propriétaire.
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, -3))],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ChatScreen(user: p.proprietaire, propertyTitre: p.titre),
            )),
            icon: const Icon(Icons.chat_bubble_rounded, size: 18),
            label: Text(tr('detail_contact_owner')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),

      // ── Ancienne barre Louer/Acheter (désactivée) ──────────────────────
      // bottomNavigationBar: Container(
      //   padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      //   decoration: BoxDecoration(
      //     color: AppTheme.surface,
      //     boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, -3))],
      //   ),
      //   child: Row(
      //     children: [
      //       if (p.listingType == ListingType.location || p.listingType == ListingType.les_deux)
      //         Expanded(
      //           child: ElevatedButton.icon(
      //             onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentScreen(property: p, type: 'location'))),
      //             icon: const Icon(Icons.calendar_month_rounded, size: 18),
      //             label: Text(tr('detail_reserve')),
      //             style: ElevatedButton.styleFrom(backgroundColor: AppTheme.info),
      //           ),
      //         ),
      //       if (p.listingType == ListingType.les_deux) const SizedBox(width: 10),
      //       if (p.listingType == ListingType.vente || p.listingType == ListingType.les_deux)
      //         Expanded(
      //           child: ElevatedButton.icon(
      //             onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentScreen(property: p, type: 'achat'))),
      //             icon: const Icon(Icons.shopping_cart_rounded, size: 18),
      //             label: Text(tr('detail_buy')),
      //             style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
      //           ),
      //         ),
      //     ],
      //   ),
      // ),
    );
      }, // ferme builder
    ); // ferme ValueListenableBuilder
  }
}


class _ShareOption extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ShareOption({this.icon, this.customIcon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: customIcon != null
              ? Center(child: customIcon)
              : Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 6),
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textPrimary, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
      ]),
    );
  }
}

/// Icône lettre pour Facebook / X
class _SocialIcon extends StatelessWidget {
  final Color color;
  final String letter;
  final double fontSize;
  final FontWeight fontWeight;
  const _SocialIcon({required this.color, required this.letter, this.fontSize = 20, this.fontWeight = FontWeight.w700});
  @override
  Widget build(BuildContext context) => Text(letter,
    style: TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: Colors.white));
}

/// Icône Instagram (dégradé)
class _InstagramIcon extends StatelessWidget {
  const _InstagramIcon();
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFFFCAF45), Color(0xFFDD2A7B), Color(0xFF8134AF), Color(0xFF515BD4)],
        begin: Alignment.bottomLeft, end: Alignment.topRight,
      ).createShader(bounds),
      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 24),
    );
  }
}

// ─── Bannière de statut (publié / en attente) ─────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  const _StatusBanner({required this.color, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text,
            style: GoogleFonts.poppins(fontSize: 13, color: color, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}


class _AvisCard extends StatelessWidget {
  final AvisModel avis;
  const _AvisCard({required this.avis});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            UserAvatar(user: avis.auteur, radius: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(avis.auteur.fullName, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                  RatingBarIndicator(rating: avis.note, itemBuilder: (_, __) => const Icon(Icons.star_rounded, color: AppTheme.accentLight), itemCount: 5, itemSize: 12),
                ],
              ),
            ),
            Text('${avis.createdAt.day}/${avis.createdAt.month}/${avis.createdAt.year}', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint)),
          ]),
          const SizedBox(height: 8),
          Text(avis.commentaire, style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
        ],
      ),
    );
  }
}

// ─── Visionneuse plein écran ──────────────────────────────────────────────────
class _FullscreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const _FullscreenImageViewer({required this.images, required this.initialIndex});
  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late int _index;
  late PageController _ctrl;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _ctrl = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            PageView.builder(
              controller: _ctrl,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                final url = widget.images[i];
                final Widget img = Image.network(url, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 60));
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(child: img),
                );
              },
            ),
            // Bouton fermer
            Positioned(
              top: 40, right: 20,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                ),
              ),
            ),
            // Indicateur page
            if (widget.images.length > 1)
              Positioned(
                bottom: 30, left: 0, right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.images.length, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 20 : 6, height: 6,
                    decoration: BoxDecoration(
                      color: i == _index ? Colors.white : Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  )),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Stat item pour la section propriétaire ────────────────────────────────────
class _OwnerStat extends StatelessWidget {
  final String label;
  final String value;
  const _OwnerStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
      Text(label,  style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
    ]);
  }
}

class _OwnerStatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: AppTheme.border);
}
