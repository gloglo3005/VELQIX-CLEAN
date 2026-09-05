import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
// import '../services/mock_data.dart'; // 🚫 DÉSACTIVÉ (25/08/2026) : plus de biens factices
import '../theme/app_theme.dart';
import '../services/app_translations.dart';
import '../services/property_service.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart' show followersUpdateNotifier;
import '../widgets/widgets.dart';
import '../main.dart' show localeNotifier;

/// Profil public d'un propriétaire — accessible depuis une annonce.
class OwnerProfileScreen extends StatefulWidget {
  final UserModel owner;
  const OwnerProfileScreen({super.key, required this.owner});

  @override
  State<OwnerProfileScreen> createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends State<OwnerProfileScreen> {

  // ── Getters dynamiques ────────────────────────────────────────────────────
  String get _ownerId => widget.owner.id;

  /// Annonces publiées de ce propriétaire
  int get _annoncesCount {
    return publishedPropertiesNotifier.value
        .whereType<PropertyModel>()
        .where((p) => p.proprietaire.id == _ownerId)
        .length;
  }

  /// Total des vues de toutes ses annonces
  int get _views {
    return publishedPropertiesNotifier.value
        .whereType<PropertyModel>()
        .where((p) => p.proprietaire.id == _ownerId)
        .fold<int>(0, (sum, p) => sum + p.vues);
  }

  // ⚠️ Avant : _isFollowing / followers / following venaient de ValueNotifier
  // locaux (followedOwnersNotifier, followersMapNotifier...), jamais envoyés
  // au serveur — l'abonnement ne survivait pas à un redémarrage de l'app et
  // n'était visible par personne d'autre. Maintenant : état réel chargé
  // depuis GET /api/users/:id, et toggle avec vrai appel API
  // (POST/DELETE /api/users/:id/follow), mise à jour optimiste + rollback.
  bool _isFollowing = false;
  int _followersCount = 0;
  int _followingCount = 0;
  bool _followBusy = false;

  @override
  void initState() {
    super.initState();
    // widget.owner est parfois un snapshot embarqué dans une annonce (pas
    // forcément à jour) : on l'utilise en attendant la réponse fraîche du backend.
    _isFollowing = widget.owner.isFollowedByMe;
    _followersCount = widget.owner.followersCount;
    _followingCount = widget.owner.followingCount;
    _loadProfile();
    followersUpdateNotifier.addListener(_onFollowersUpdate);
  }

  @override
  void dispose() {
    followersUpdateNotifier.removeListener(_onFollowersUpdate);
    super.dispose();
  }

  void _onFollowersUpdate() {
    final update = followersUpdateNotifier.value;
    if (update == null) return;
    if (update.userId != _ownerId) return;
    if (mounted) setState(() => _followersCount = update.followersCount);
  }

  Future<void> _loadProfile() async {
    final fresh = await PropertyService.instance.fetchUserProfile(
      _ownerId,
      auth: AuthService.instance.isLoggedIn,
    );
    if (fresh != null && mounted) {
      setState(() {
        _isFollowing = fresh.isFollowedByMe;
        _followersCount = fresh.followersCount;
        _followingCount = fresh.followingCount;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_followBusy) return;
    final currentUserId = AuthService.instance.currentUser?.id;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecte-toi pour suivre ce propriétaire.')),
      );
      return;
    }

    final wasFollowing = _isFollowing;
    setState(() {
      _followBusy = true;
      _isFollowing = !wasFollowing;
      _followersCount += wasFollowing ? -1 : 1;
    });

    try {
      if (wasFollowing) {
        await PropertyService.instance.unfollowUser(_ownerId);
      } else {
        await PropertyService.instance.followUser(_ownerId);
        final ownerName = widget.owner.nomEntreprise?.isNotEmpty == true
            ? widget.owner.nomEntreprise!
            : '${widget.owner.prenom} ${widget.owner.nom}'.trim();
        pushNotification(
          titre: '✅ Vous suivez $ownerName',
          message: 'Vous serez notifié dès que $ownerName publie une nouvelle annonce.',
          type: 'info',
        );
      }
    } catch (_) {
      // Rollback en cas d'échec réseau
      if (mounted) {
        setState(() {
          _isFollowing = wasFollowing;
          _followersCount += wasFollowing ? 1 : -1;
        });
      }
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  String _timeAgo() {
    final diff = DateTime.now().difference(widget.owner.createdAt);
    if (diff.inDays >= 365) {
      final y = (diff.inDays / 365).floor();
      return "Il y a ${y} an${y > 1 ? 's' : ''}";
    } else if (diff.inDays >= 30) {
      final m = (diff.inDays / 30).floor();
      return 'Il y a \$m mois';
    } else if (diff.inDays > 0) {
      return "Il y a ${diff.inDays} jour${diff.inDays > 1 ? 's' : ''}";
    } else {
      return "Aujourd'hui";
    }
  }

  @override
  Widget build(BuildContext context) {
    final ownerListings = publishedPropertiesNotifier.value
        .cast<PropertyModel>()
        .where((p) => p.proprietaire.id == widget.owner.id)
        .toList();

    return ValueListenableBuilder(
      valueListenable: localeNotifier,
      builder: (_, __, ___) => Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: CustomScrollView(
            slivers: [
              // ── AppBar ──────────────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 0,
                floating: true,
                snap: true,
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                title: Text(
                  tr('owner_profile_title'),
                  style: GoogleFonts.poppins(
                      fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),

              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header gradient ────────────────────────────────────────
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // ── Avatar centré + grand ──────────────────────────────
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: UserAvatar(user: widget.owner, radius: 52, showBadge: false),
                              ),
                              if (widget.owner.isPremium)
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.accentGradient,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(
                                        Icons.workspace_premium_rounded,
                                        size: 14,
                                        color: Colors.white),
                                  ),
                                ),
                              if (widget.owner.isVerified)
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: Colors.lightBlueAccent,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(Icons.verified_rounded,
                                        size: 12, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // ── Nom ───────────────────────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  widget.owner.fullName,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white),
                                ),
                              ),
                              if (widget.owner.isVerified) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.verified_rounded,
                                    size: 18, color: Colors.lightBlueAccent),
                              ],
                            ],
                          ),

                          const SizedBox(height: 6),

                          // ── Badge type de compte (agence / particulier) ────────
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.owner.nomEntreprise != null
                                      ? Icons.business_rounded
                                      : Icons.person_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  widget.owner.nomEntreprise != null
                                      ? widget.owner.nomEntreprise!
                                      : tr('owner_role_label'),
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      letterSpacing: 0.4),
                                ),
                              ],
                            ),
                          ),

                          if (widget.owner.typeActivite != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.owner.typeActivite!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.75)),
                            ),
                          ],

                          const SizedBox(height: 8),

                          // ── Étoiles ─────────────────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ...List.generate(5, (i) {
                                final full = i < widget.owner.rating.floor();
                                return Icon(
                                  full ? Icons.star_rounded : Icons.star_border_rounded,
                                  size: 18,
                                  color: const Color(0xFFFFC107),
                                );
                              }),
                              const SizedBox(width: 6),
                              Text(
                                '${widget.owner.rating.toStringAsFixed(1)} (${widget.owner.totalAvis} ${tr("owner_reviews")})',
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.85)),
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),

                          // ── Date d'inscription ────────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.access_time_rounded,
                                  size: 13, color: Colors.white.withOpacity(0.6)),
                              const SizedBox(width: 4),
                              Text(
                                _timeAgo(),
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: Colors.white.withOpacity(0.6)),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // ── Stats row ─────────────────────────────────────────
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _StatItem(label: tr('owner_followers'), value: '$_followersCount'),
                                _Divider(),
                                _StatItem(label: tr('owner_following'), value: '$_followingCount'),
                                _Divider(),
                                _StatItem(label: tr('owner_listings'), value: '$_annoncesCount'),
                                _Divider(),
                                _StatItem(label: tr('owner_views'), value: '$_views'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Bouton Suivre ──────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                      child: SizedBox(
                        width: double.infinity,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          child: ElevatedButton.icon(
                            onPressed: _toggleFollow,
                            icon: Icon(
                              _isFollowing
                                  ? Icons.person_remove_rounded
                                  : Icons.person_add_rounded,
                              size: 18,
                            ),
                            label: Text(
                              _isFollowing ? tr('owner_following_btn') : tr('owner_follow_btn'),
                              style: GoogleFonts.poppins(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _isFollowing ? AppTheme.surface : AppTheme.primary,
                              foregroundColor:
                                  _isFollowing ? AppTheme.textPrimary : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: _isFollowing
                                    ? const BorderSide(color: AppTheme.border)
                                    : BorderSide.none,
                              ),
                              elevation: _isFollowing ? 0 : 2,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Annonces du propriétaire ──────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Text(
                        tr('owner_listings_section'),
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary),
                      ),
                    ),

                    if (ownerListings.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            tr('owner_no_listings'),
                            style: GoogleFonts.poppins(
                                fontSize: 14, color: AppTheme.textSecondary),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.78,
                          ),
                          itemCount: ownerListings.length,
                          itemBuilder: (_, i) =>
                              PropertyCard(property: ownerListings[i]),
                        ),
                      ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 11, color: Colors.white.withOpacity(0.75))),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: Colors.white.withOpacity(0.25));
  }
}