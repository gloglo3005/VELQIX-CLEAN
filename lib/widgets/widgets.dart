import 'package:flutter/material.dart';
import '../services/app_translations.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../main.dart' show currencyNotifier, activeCurrency, localeNotifier;
import '../services/property_service.dart';

// ─── Helper pour ouvrir une URL (Mobile + Web) ────────────────────────────────
Future<void> _openUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ─── Currency Formatter ───────────────────────────────────────────────────────
/// Formate un montant (en XOF) selon la devise active globale.
String formatFcfa(double amount) {
  final cur = activeCurrency;
  final converted = amount * cur.rateFromXof;
  final f = NumberFormat('#,###', 'fr_FR');
  if (cur.code == 'XOF') {
    return '${f.format(amount.round())} ${cur.symbol}';
  }
  // Pour les autres devises, afficher 2 décimales
  final f2 = NumberFormat('#,##0.##', 'fr_FR');
  return '${cur.symbol} ${f2.format(converted)}';
}

/// Convertit un string brut de prix comme "15 000 FCFA/mois" ou "35 000 FCFA/jour"
/// vers la devise active, en conservant le suffixe (/mois, /jour, etc.).
String formatPrixParJour(String? prixStr) {
  if (prixStr == null || prixStr.isEmpty) return '';
  // Extraire le suffixe (/mois, /jour, /nuit, /semaine, etc.)
  String suffix = '';
  String cleaned = prixStr;
  final suffixMatch = RegExp(r'(/\S+)$').firstMatch(prixStr);
  if (suffixMatch != null) {
    suffix = suffixMatch.group(1)!;
    cleaned = prixStr.substring(0, suffixMatch.start).trim();
  }
  // Supprimer "FCFA" et les espaces, garder uniquement les chiffres
  final digitsOnly = cleaned.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsOnly.isEmpty) return prixStr; // fallback si parsing échoue
  final amount = double.tryParse(digitsOnly);
  if (amount == null) return prixStr;
  return '${formatFcfa(amount)}$suffix';
}

// ─── Smart Image — gère les URLs normales (Mobile & Web) ─────────────────────
Widget _smartImage({
  required String url,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget Function()? fallback,
}) {
  if (url.isEmpty) {
    return fallback?.call() ?? Container(width: width, height: height, color: AppTheme.divider);
  }
  return Image.network(
    url,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (_, __, ___) =>
        fallback?.call() ?? Container(width: width, height: height, color: AppTheme.divider,
            child: const Icon(Icons.image_not_supported, size: 40, color: AppTheme.textHint)),
  );
}

// ─── Property Card ────────────────────────────────────────────────────────────
class PropertyCard extends StatelessWidget {
  final PropertyModel property;
  final VoidCallback? onTap;
  final bool horizontal;

  const PropertyCard({super.key, required this.property, this.onTap, this.horizontal = false});

  @override
  Widget build(BuildContext context) {
    if (horizontal) return _HorizontalCard(property: property, onTap: onTap);
    return _VerticalCard(property: property, onTap: onTap);
  }
}

class _VerticalCard extends StatelessWidget {
  final PropertyModel property;
  final VoidCallback? onTap;
  const _VerticalCard({required this.property, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  child: _smartImage(
                    url: property.firstImage,
                    height: 155, width: double.infinity, fit: BoxFit.cover,
                    fallback: () => Container(height: 155, color: AppTheme.divider, child: const Icon(Icons.image_not_supported, size: 40, color: AppTheme.textHint)),
                  ),
                ),
                Positioned(
                  top: 10, left: 10,
                  child: _TypeBadge(label: property.listingLabel, isVente: property.listingType == ListingType.vente),
                ),
                if (property.isFeatured)
                  Positioned(
                    top: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.star_rounded, size: 12, color: Colors.white),
                        const SizedBox(width: 3),
                        Text(tr('card_featured'), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
                      ]),
                    ),
                  ),
                Positioned(
                  bottom: 10, right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.remove_red_eye_outlined, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text('${property.vues}', style: GoogleFonts.poppins(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.09), borderRadius: BorderRadius.circular(6)),
                      child: Text(property.categorieLabel, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w500)),
                    ),
                    const Spacer(),
                    const Icon(Icons.star_rounded, size: 14, color: AppTheme.accentLight),
                    const SizedBox(width: 3),
                    Text('${property.rating}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
                    Text(' (${property.totalAvis})', style: GoogleFonts.poppins(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary)),
                  ]),
                  const SizedBox(height: 6),
                  Text(property.getLocalizedTitre(localeNotifier.value.languageCode), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textHint),
                    const SizedBox(width: 3),
                    Expanded(child: Text(property.adresse.short, style: GoogleFonts.poppins(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<String>(
                    valueListenable: currencyNotifier,
                    builder: (context, _, __) => Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formatFcfa(property.prix),
                                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (property.listingType == ListingType.location || property.listingType == ListingType.les_deux)
                                Text(formatPrixParJour(property.prixParJour), style: GoogleFonts.poppins(fontSize: 10, color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary), maxLines: 1),
                            ],
                          ),
                        ),
                        ShareButton(property: property),
                        const SizedBox(width: 4),
                        FavoriteButton(propertyId: property.id),
                      ],
                    ),
                  ),
                ],
              ),
            ),   // fin Padding
          ],
        ),
      ),
    );
  }
}

class _HorizontalCard extends StatelessWidget {
  final PropertyModel property;
  final VoidCallback? onTap;
  const _HorizontalCard({required this.property, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
              child: _smartImage(
                url: property.firstImage,
                height: 110, width: 110, fit: BoxFit.cover,
                fallback: () => Container(height: 110, width: 110, color: AppTheme.divider),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _TypeBadge(label: property.listingLabel, isVente: property.listingType == ListingType.vente, small: true),
                      const Spacer(),
                      const Icon(Icons.star_rounded, size: 13, color: AppTheme.accentLight),
                      const SizedBox(width: 2),
                      Text('${property.rating}', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 4),
                    Text(property.getLocalizedTitre(localeNotifier.value.languageCode), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: AppTheme.textHint),
                      const SizedBox(width: 2),
                      Text(property.adresse.short, style: GoogleFonts.poppins(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary)),
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

class _TypeBadge extends StatelessWidget {
  final String label;
  final bool isVente;
  final bool small;
  const _TypeBadge({required this.label, required this.isVente, this.small = false});

  @override
  Widget build(BuildContext context) {
    final color = isVente ? AppTheme.success : AppTheme.info;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8, vertical: small ? 2 : 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: GoogleFonts.poppins(fontSize: small ? 9 : 10, fontWeight: FontWeight.w600, color: Colors.white)),
    );
  }
}

// ─── Global App Store ────────────────────────────────────────────────────────
final Set<String> globalFavorites = {};

// ✅ Recherche vocale IA → partagée avec HomeScreen
final ValueNotifier<String> voiceSearchNotifier = ValueNotifier('');

// ✅ Biens publiés (approuvés par l'admin) — visibles sur la home
final ValueNotifier<List<dynamic>> publishedPropertiesNotifier = ValueNotifier([]);
List<dynamic> get publishedProperties => publishedPropertiesNotifier.value;

// ✅ Biens en attente de validation admin
final ValueNotifier<List<dynamic>> pendingPropertiesNotifier = ValueNotifier([]);
List<dynamic> get pendingProperties => pendingPropertiesNotifier.value;

// ✅ Notifications in-app temps réel
final ValueNotifier<List<Map<String, dynamic>>> appNotificationsNotifier = ValueNotifier([]);

/// Envoyer une notification à l'utilisateur (appelé par l'admin à l'approbation/rejet)
void pushNotification({
  required String titre,
  required String message,
  required String type, // 'success' | 'error' | 'info' | 'warning'
  String? propertyId,
}) {
  final notif = {
    'id': DateTime.now().millisecondsSinceEpoch.toString(),
    'titre': titre,
    'message': message,
    'type': type,
    'lu': false,
    'date': DateTime.now(),
    if (propertyId != null) 'propertyId': propertyId,
  };
  appNotificationsNotifier.value = [notif, ...appNotificationsNotifier.value];
}

// Notifier pour forcer rebuild du profil quand user change (Premium/KYC)
final ValueNotifier<int> userStateNotifier = ValueNotifier(0);

/// Propriétaires suivis par l'utilisateur connecté : Set des owner.id
final ValueNotifier<Set<String>> followedOwnersNotifier = ValueNotifier({});

/// Map ownerID → Set<userID> : qui suit qui (pour notifications multi-abonnés)
final ValueNotifier<Map<String, Set<String>>> followersMapNotifier = ValueNotifier({});

/// Map userID → Set<ownerID> : les propriétaires que chaque utilisateur suit
final ValueNotifier<Map<String, Set<String>>> userFollowingMapNotifier = ValueNotifier({});

// ⚠️ Avant : followOwner/unfollowOwner ne touchaient que les ValueNotifier
// ci-dessus (Set/Map en mémoire), sans aucun appel réseau — l'abonnement ne
// survivait pas à un redémarrage et n'était visible par personne d'autre.
// Maintenant : mise à jour optimiste des notifiers + vrai appel
// POST/DELETE /api/users/:id/follow, avec rollback silencieux si ça échoue.

void _applyFollowLocally(String ownerId, String currentUserId, {required bool following}) {
  final fMap = Map<String, Set<String>>.from(followersMapNotifier.value);
  final uMap = Map<String, Set<String>>.from(userFollowingMapNotifier.value);
  final followed = Set<String>.from(followedOwnersNotifier.value);
  if (following) {
    fMap.putIfAbsent(ownerId, () => {}).add(currentUserId);
    uMap.putIfAbsent(currentUserId, () => {}).add(ownerId);
    followed.add(ownerId);
  } else {
    fMap[ownerId]?.remove(currentUserId);
    uMap[currentUserId]?.remove(ownerId);
    followed.remove(ownerId);
  }
  followersMapNotifier.value = fMap;
  userFollowingMapNotifier.value = uMap;
  followedOwnersNotifier.value = followed;
}

/// Abonner l'utilisateur courant à un propriétaire
Future<bool> followOwner(String ownerId, String currentUserId) async {
  _applyFollowLocally(ownerId, currentUserId, following: true);
  final ok = await PropertyService.instance.followUser(ownerId);
  if (!ok) _applyFollowLocally(ownerId, currentUserId, following: false);
  return ok;
}

/// Se désabonner
Future<bool> unfollowOwner(String ownerId, String currentUserId) async {
  _applyFollowLocally(ownerId, currentUserId, following: false);
  final ok = await PropertyService.instance.unfollowUser(ownerId);
  if (!ok) _applyFollowLocally(ownerId, currentUserId, following: true);
  return ok;
}

void notifyUserChanged() => userStateNotifier.value++;

// ─── Favorite Button ──────────────────────────────────────────────────────────
class FavoriteButton extends StatefulWidget {
  final String propertyId;
  const FavoriteButton({super.key, required this.propertyId});
  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}
class _FavoriteButtonState extends State<FavoriteButton> {
  bool get _isFav => globalFavorites.contains(widget.propertyId);
  bool _busy = false;

  // ⚠️ Avant : ne touchait que globalFavorites (Set en mémoire, perdu à
  // chaque redémarrage de l'app, jamais envoyé au serveur). Maintenant :
  // appel réel au backend (POST/DELETE /api/properties/:id/favorite),
  // avec mise à jour optimiste de l'UI et annulation si l'appel échoue.
  Future<void> _toggle() async {
    if (_busy) return;
    final wasFav = _isFav;
    setState(() {
      _busy = true;
      if (wasFav) {
        globalFavorites.remove(widget.propertyId);
      } else {
        globalFavorites.add(widget.propertyId);
      }
    });

    try {
      final ok = wasFav
          ? await PropertyService.instance.removeFavorite(widget.propertyId)
          : await PropertyService.instance.addFavorite(widget.propertyId);
      if (!ok) throw Exception('favorite');
    } catch (_) {
      // Rollback si l'appel a échoué
      if (mounted) {
        setState(() {
          if (wasFav) {
            globalFavorites.add(widget.propertyId);
          } else {
            globalFavorites.remove(widget.propertyId);
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: _isFav ? AppTheme.error.withOpacity(0.1) : AppTheme.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(_isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 18, color: _isFav ? AppTheme.error : AppTheme.textHint),
      ),
    );
  }
}

// ─── Share Button ─────────────────────────────────────────────────────────────
class ShareButton extends StatelessWidget {
  final PropertyModel property;
  const ShareButton({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showShareSheet(context),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.share_outlined, size: 18, color: AppTheme.textHint),
      ),
    );
  }

  void _showShareSheet(BuildContext context) {
    final text = property.shareText;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareSheet(property: property, shareText: text),
    );
  }
}

class _ShareSheet extends StatelessWidget {
  final PropertyModel property;
  final String shareText;
  const _ShareSheet({required this.property, required this.shareText});

  void _copyAndPop(BuildContext ctx) {
    Clipboard.setData(ClipboardData(text: shareText));
    Navigator.pop(ctx);
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text('Copié dans le presse-papier',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white))),
      ]),
      backgroundColor: AppTheme.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _openWhatsApp(BuildContext ctx) async {
    final encoded = Uri.encodeComponent(shareText);
    await _openUrl('https://wa.me/?text=$encoded');
  }

  Future<void> _openEmail(BuildContext ctx) async {
    final subject = Uri.encodeComponent('Annonce : ${property.titre}');
    final body = Uri.encodeComponent(shareText);
    await _openUrl('mailto:?subject=$subject&body=$body');
  }

  void _showMore(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoreShareSheet(shareText: shareText, shareUrl: property.shareUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom + 12;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _smartImage(url: property.firstImage, width: 52, height: 52, fit: BoxFit.cover,
                  fallback: () => Container(width: 52, height: 52, color: AppTheme.divider)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(property.getLocalizedTitre(localeNotifier.value.languageCode), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(formatFcfa(property.prix),
                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w700)),
            ])),
          ]),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(shareText,
                style: GoogleFonts.poppins(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary, height: 1.6),
                maxLines: 3, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _ShareOption(icon: Icons.copy_rounded, label: 'Copier', color: AppTheme.primary, onTap: () => _copyAndPop(context))),
            const SizedBox(width: 8),
            Expanded(child: _ShareOptionCustom(
              child: _WhatsAppIcon(),
              bgColor: const Color(0xFF25D366),
              label: 'WhatsApp',
              onTap: () => _openWhatsApp(context),
            )),
            const SizedBox(width: 8),
            Expanded(child: _ShareOption(icon: Icons.email_rounded, label: 'Email', color: AppTheme.info, onTap: () => _openEmail(context))),
            const SizedBox(width: 8),
            Expanded(child: _ShareOption(icon: Icons.more_horiz_rounded, label: 'Plus', color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary, onTap: () => _showMore(context))),
          ]),
        ],
      ),
    );
  }
}


// ─── Feuille "Plus" (Telegram, Instagram, Facebook, Twitter/X) ────────────────
class _MoreShareSheet extends StatelessWidget {
  final String shareText;
  final String shareUrl;
  const _MoreShareSheet({required this.shareText, required this.shareUrl});

  void _launch(String url) => _openUrl(url);

  @override
  Widget build(BuildContext context) {
    final encoded = Uri.encodeComponent(shareText);
    final url = Uri.encodeComponent(shareUrl);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(tr('detail_share'),
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ShareOptionCustom(
                bgColor: const Color(0xFF0088CC),
                label: 'Telegram',
                onTap: () => _launch('https://t.me/share/url?url=$url&text=$encoded'),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
              ),
              _ShareOptionCustom(
                bgColor: const Color(0xFFE1306C),
                label: 'Instagram',
                onTap: () => _launch('https://www.instagram.com/'),
                child: const _InstagramIcon(),
              ),
              _ShareOptionCustom(
                bgColor: const Color(0xFF1877F2),
                label: 'Facebook',
                onTap: () => _launch('https://www.facebook.com/sharer/sharer.php?u=$url&quote=$encoded'),
                child: const Text('f', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, fontFamily: 'Georgia', height: 1.1)),
              ),
              _ShareOptionCustom(
                bgColor: Colors.black,
                label: 'X / Twitter',
                onTap: () => _launch('https://twitter.com/intent/tweet?text=$encoded'),
                child: const Text('𝕏', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1.1)),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── ShareOption avec icône Flutter standard ──────────────────────────────────
class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ShareOption({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 6),
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

// ─── ShareOption avec widget enfant custom (pour logos colorés) ───────────────
class _ShareOptionCustom extends StatelessWidget {
  final Widget child;
  final Color bgColor;
  final String label;
  final VoidCallback onTap;
  const _ShareOptionCustom({required this.child, required this.bgColor, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(14)),
          child: Center(child: child),
        ),
        const SizedBox(height: 6),
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

// ─── Icône WhatsApp (vrai logo) ───────────────────────────────────────────────
class _WhatsAppIcon extends StatelessWidget {
  const _WhatsAppIcon();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28, height: 28,
      child: CustomPaint(painter: _WhatsAppPainter()),
    );
  }
}

class _WhatsAppPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // ── Bulle de chat ronde (fond blanc transparent — le container est déjà vert)
    final bubblePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Cercle principal de la bulle
    canvas.drawCircle(Offset(cx, cy - h * 0.04), w * 0.42, bubblePaint);

    // Queue de la bulle en bas à gauche
    final tail = Path()
      ..moveTo(w * 0.18, h * 0.72)
      ..lineTo(w * 0.10, h * 0.88)
      ..lineTo(w * 0.36, h * 0.78)
      ..close();
    canvas.drawPath(tail, bubblePaint);

    // ── Combiné téléphone vert à l'intérieur de la bulle
    final phonePaint = Paint()
      ..color = const Color(0xFF25D366)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.095
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final phone = Path();
    // Arrondi supérieur droit
    phone.moveTo(w * 0.62, h * 0.19);
    phone.cubicTo(w * 0.70, h * 0.19, w * 0.76, h * 0.26, w * 0.73, h * 0.35);
    phone.cubicTo(w * 0.71, h * 0.41, w * 0.65, h * 0.45, w * 0.60, h * 0.43);
    // Jonction centre
    phone.cubicTo(w * 0.55, h * 0.41, w * 0.50, h * 0.38, w * 0.45, h * 0.42);
    phone.cubicTo(w * 0.40, h * 0.46, w * 0.37, h * 0.52, w * 0.32, h * 0.55);
    // Arrondi bas gauche
    phone.cubicTo(w * 0.23, h * 0.59, w * 0.18, h * 0.53, w * 0.18, h * 0.45);
    phone.cubicTo(w * 0.18, h * 0.33, w * 0.30, h * 0.19, w * 0.43, h * 0.14);
    phone.cubicTo(w * 0.50, h * 0.11, w * 0.56, h * 0.13, w * 0.62, h * 0.19);
    canvas.drawPath(phone, phonePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── Icône Instagram dessinée manuellement ────────────────────────────────────
class _InstagramIcon extends StatelessWidget {
  const _InstagramIcon();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24, height: 24,
      child: CustomPaint(painter: _InstagramPainter()),
    );
  }
}

class _InstagramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Carré arrondi extérieur
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.06, h * 0.06, w * 0.88, h * 0.88),
        Radius.circular(w * 0.22),
      ),
      paint,
    );
    // Cercle central
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.22, paint);
    // Petit point haut-droite
    canvas.drawCircle(Offset(w * 0.73, h * 0.27), w * 0.07,
        Paint()..color = Colors.white..style = PaintingStyle.fill);
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── Section Header ───────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: Text(actionLabel!, style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

// ─── Custom App Bar ───────────────────────────────────────────────────────────
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final bool showBack;
  final Color? backgroundColor;

  const CustomAppBar({super.key, this.title, this.titleWidget, this.actions, this.showBack = true, this.backgroundColor});

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor ?? AppTheme.background,
      elevation: 0,
      leading: showBack
          ? GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)]),
                child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary),
              ),
            )
          : null,
      title: titleWidget ?? (title != null ? Text(title!, style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)) : null),
      actions: actions,
    );
  }
}

// ─── User Avatar ──────────────────────────────────────────────────────────────
class UserAvatar extends StatelessWidget {
  final UserModel user;
  final double radius;
  final bool showBadge;

  const UserAvatar({super.key, required this.user, this.radius = 20, this.showBadge = false});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: AppTheme.primary.withOpacity(0.15),
          child: user.avatarUrl != null
              ? ClipOval(child: Image.network(user.avatarUrl!, fit: BoxFit.cover, width: radius * 2, height: radius * 2))
              : Text(user.initials, style: GoogleFonts.poppins(fontSize: radius * 0.6, fontWeight: FontWeight.w700, color: AppTheme.primary)),
        ),
        if (showBadge && user.isVerified)
          Positioned(
            bottom: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.verified_rounded, size: 12, color: AppTheme.primary),
            ),
          ),
      ],
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? buttonLabel;
  final VoidCallback? onButton;

  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.buttonLabel, this.onButton});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), shape: BoxShape.circle),
              child: Icon(icon, size: 56, color: AppTheme.primary.withOpacity(0.5)),
            ),
            const SizedBox(height: 20),
            Text(title, style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary), textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: GoogleFonts.poppins(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary), textAlign: TextAlign.center),
            ],
            if (buttonLabel != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(onPressed: onButton, child: Text(buttonLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({super.key, required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 10),
          Text(value, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
          Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

// ─── Loading Shimmer ──────────────────────────────────────────────────────────
class LoadingCard extends StatelessWidget {
  const LoadingCard({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Container(height: 165, decoration: const BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)))),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 12, width: 80, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(6))),
                const SizedBox(height: 8),
                Container(height: 14, width: double.infinity, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(6))),
                const SizedBox(height: 6),
                Container(height: 12, width: 120, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(6))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Custom TextField ─────────────────────────────────────────────────────────
class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final int? maxLength;

  const AppTextField({
    super.key, required this.label, this.hint, this.controller,
    this.prefixIcon, this.suffix, this.obscureText = false,
    this.keyboardType, this.validator, this.maxLines = 1,
    this.readOnly = false, this.onTap, this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          maxLines: maxLines,
          maxLength: maxLength,
          readOnly: readOnly,
          onTap: onTap,
          style: GoogleFonts.poppins(fontSize: 14, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20, color: AppTheme.textHint) : null,
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

// ─── Primary Button ───────────────────────────────────────────────────────────
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool outline;

  const PrimaryButton({super.key, required this.label, this.onPressed, this.isLoading = false, this.icon, this.outline = false});

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
              Text(label),
            ],
          );

    if (outline) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(onPressed: isLoading ? null : onPressed, child: child),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(onPressed: isLoading ? null : onPressed, child: child),
    );
  }
}