import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/property_service.dart'; // upload de la photo de profil (Cloudinary)
import '../services/web_file_picker.dart';   // sélection de la photo, compatible Web/Mobile
import '../widgets/smart_image.dart';        // aperçu local avant upload (data:/blob:)
import '../theme/app_theme.dart';
import '../services/app_translations.dart';
import '../widgets/widgets.dart';
import 'legal_screen.dart';
import 'auth_screens.dart';
import 'my_listings_screen.dart';
import 'favorites_screen.dart';
import 'premium_screen.dart';
import 'admin_dashboard_screen.dart';
import 'notifications_screen.dart';
import 'support_screen.dart';
import '../main.dart' show themeModeNotifier, localeNotifier, countryCodeToLocale, currencyNotifier, supportedCurrencies, CurrencyInfo;
import '../services/app_translations.dart' show tr;
import 'support_screen.dart';

// ✅ Converti en StatefulWidget pour se reconstruire après Premium/KYC
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  int _myListingsCount = 0;

  @override
  void initState() {
    super.initState();
    userStateNotifier.addListener(_onUserChanged);
    _loadMyListingsCount();
  }

  Future<void> _loadMyListingsCount() async {
    if (!AuthService.instance.isLoggedIn) return;
    final list = await PropertyService.instance.getMyProperties();
    if (mounted) {
      setState(() => _myListingsCount = list.where((p) => p.status == 'approuve').length);
    }
  }

  @override
  void dispose() {
    userStateNotifier.removeListener(_onUserChanged);
    super.dispose();
  }

  void _onUserChanged() {
    if (mounted) setState(() {});
  }

  // ─── Emoji drapeau depuis code ISO ─────────────────────────────────────────
  String _getFlag(String code) {
    if (code.length != 2) return '🌍';
    return code.toUpperCase().runes.map((r) => String.fromCharCode(r + 127397)).join();
  }

  // ─── Modifier le pays du profil ────────────────────────────────────────────
  static const List<Map<String, String>> _allCountries = [
    {'code': 'TG', 'name': 'Togo'}, {'code': 'BJ', 'name': 'Bénin'},
    {'code': 'GH', 'name': 'Ghana'}, {'code': 'CI', 'name': 'Côte d\'Ivoire'},
    {'code': 'SN', 'name': 'Sénégal'}, {'code': 'ML', 'name': 'Mali'},
    {'code': 'BF', 'name': 'Burkina Faso'}, {'code': 'NE', 'name': 'Niger'},
    {'code': 'NG', 'name': 'Nigeria'}, {'code': 'CM', 'name': 'Cameroun'},
    {'code': 'GA', 'name': 'Gabon'}, {'code': 'CD', 'name': 'Congo (RDC)'},
    {'code': 'CG', 'name': 'Congo'}, {'code': 'KE', 'name': 'Kenya'},
    {'code': 'TZ', 'name': 'Tanzanie'}, {'code': 'RW', 'name': 'Rwanda'},
    {'code': 'ET', 'name': 'Éthiopie'}, {'code': 'ZA', 'name': 'Afrique du Sud'},
    {'code': 'EG', 'name': 'Égypte'}, {'code': 'MA', 'name': 'Maroc'},
    {'code': 'TN', 'name': 'Tunisie'}, {'code': 'DZ', 'name': 'Algérie'},
    {'code': 'LY', 'name': 'Libye'}, {'code': 'SD', 'name': 'Soudan'},
    {'code': 'SS', 'name': 'Soudan du Sud'}, {'code': 'CF', 'name': 'Rép. centrafricaine'},
    {'code': 'TD', 'name': 'Tchad'}, {'code': 'AO', 'name': 'Angola'},
    {'code': 'MZ', 'name': 'Mozambique'}, {'code': 'ZM', 'name': 'Zambie'},
    {'code': 'ZW', 'name': 'Zimbabwe'}, {'code': 'MW', 'name': 'Malawi'},
    {'code': 'NA', 'name': 'Namibie'}, {'code': 'BW', 'name': 'Botswana'},
    {'code': 'LS', 'name': 'Lesotho'}, {'code': 'SZ', 'name': 'Eswatini'},
    {'code': 'SC', 'name': 'Seychelles'}, {'code': 'MU', 'name': 'Maurice'},
    {'code': 'CV', 'name': 'Cap-Vert'}, {'code': 'KM', 'name': 'Comores'},
    {'code': 'ST', 'name': 'Sao Tomé-et-Principe'}, {'code': 'DJ', 'name': 'Djibouti'},
    {'code': 'ER', 'name': 'Érythrée'}, {'code': 'UG', 'name': 'Ouganda'},
    {'code': 'BI', 'name': 'Burundi'}, {'code': 'GN', 'name': 'Guinée'},
    {'code': 'GW', 'name': 'Guinée-Bissau'}, {'code': 'GQ', 'name': 'Guinée équatoriale'},
    {'code': 'SL', 'name': 'Sierra Leone'}, {'code': 'LR', 'name': 'Libéria'},
    {'code': 'GM', 'name': 'Gambie'}, {'code': 'MG', 'name': 'Madagascar'},
    {'code': 'MR', 'name': 'Mauritanie'}, {'code': 'SO', 'name': 'Somalie'},
    {'code': 'FR', 'name': 'France'}, {'code': 'DE', 'name': 'Allemagne'},
    {'code': 'GB', 'name': 'Royaume-Uni'}, {'code': 'US', 'name': 'États-Unis'},
    {'code': 'CA', 'name': 'Canada'}, {'code': 'BR', 'name': 'Brésil'},
    {'code': 'CN', 'name': 'Chine'}, {'code': 'IN', 'name': 'Inde'},
    {'code': 'JP', 'name': 'Japon'}, {'code': 'AU', 'name': 'Australie'},
    {'code': 'SA', 'name': 'Arabie Saoudite'}, {'code': 'AE', 'name': 'Émirats arabes unis'},
    {'code': 'AR', 'name': 'Argentine'}, {'code': 'MX', 'name': 'Mexique'},
    {'code': 'RU', 'name': 'Russie'}, {'code': 'TR', 'name': 'Turquie'},
    {'code': 'ES', 'name': 'Espagne'}, {'code': 'IT', 'name': 'Italie'},
    {'code': 'PT', 'name': 'Portugal'}, {'code': 'BE', 'name': 'Belgique'},
    {'code': 'CH', 'name': 'Suisse'}, {'code': 'NL', 'name': 'Pays-Bas'},
    {'code': 'SE', 'name': 'Suède'}, {'code': 'NO', 'name': 'Norvège'},
    {'code': 'PL', 'name': 'Pologne'}, {'code': 'UA', 'name': 'Ukraine'},
    {'code': 'QA', 'name': 'Qatar'}, {'code': 'KW', 'name': 'Koweït'},
    {'code': 'SG', 'name': 'Singapour'}, {'code': 'MY', 'name': 'Malaisie'},
    {'code': 'ID', 'name': 'Indonésie'}, {'code': 'TH', 'name': 'Thaïlande'},
    {'code': 'VN', 'name': 'Viêt Nam'}, {'code': 'PH', 'name': 'Philippines'},
    {'code': 'KR', 'name': 'Corée du Sud'}, {'code': 'PK', 'name': 'Pakistan'},
    {'code': 'BD', 'name': 'Bangladesh'},
  ];

  Future<void> _showEditProfileModal(UserModel user) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditProfileSheet(user: user),
    );
    // Rafraîchir après fermeture
    if (mounted) userStateNotifier.value++;
  }

  Future<void> _showCountryEditPicker(UserModel user) async {
    final searchCtrl = TextEditingController();
    List<Map<String, String>> filtered = List.from(_allCountries);
    String? currentCode = user.countryCode;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text('Changer de pays', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
                    const Spacer(),
                    IconButton(icon: Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx), color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(
                    hintText: tr('prof_search_country'),
                    hintStyle: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textHint),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textHint),
                    filled: true, fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (q) => setModal(() {
                    filtered = _allCountries.where((c) =>
                      c['name']!.toLowerCase().contains(q.toLowerCase()) ||
                      c['code']!.toLowerCase().contains(q.toLowerCase())
                    ).toList();
                  }),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final c = filtered[i];
                    final isSel = currentCode == c['code'];
                    return ListTile(
                      leading: Text(_getFlag(c['code']!), style: const TextStyle(fontSize: 28)),
                      title: Text(c['name']!, style: GoogleFonts.poppins(fontSize: 14, fontWeight: isSel ? FontWeight.w600 : FontWeight.w400, color: isSel ? AppTheme.primary : AppTheme.textPrimary)),
                      trailing: isSel ? Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20) : null,
                      onTap: () async {
                        // ⚠️ Persiste réellement côté serveur (avant :
                        // AuthService.updateUser() = cache local uniquement).
                        final error = await AuthService.instance.updateProfile(
                          nom: user.nom,
                          prenom: user.prenom,
                          telephone: user.telephone,
                          countryCode: c['code'],
                          countryName: c['name'],
                        );
                        if (error != null) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(error, style: GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
                              backgroundColor: AppTheme.error,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ));
                          }
                          return;
                        }
                        // ✅ Changer la langue selon le pays sélectionné
                        localeNotifier.value = countryCodeToLocale(c['code']);
                        if (mounted) setState(() {});
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Row(children: [
                            Text(_getFlag(c['code']!), style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text('Pays mis à jour : ${c['name']}', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
                          ]),
                          backgroundColor: AppTheme.success,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ));
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Sélecteur de langue ────────────────────────────────────────────────────
  Future<void> _showLanguagePicker() async {
    final languages = [
      {'code': 'fr', 'label': 'Français',    'flag': '🇫🇷'},
      {'code': 'en', 'label': 'English',     'flag': '🇬🇧'},
      {'code': 'es', 'label': 'Español',     'flag': '🇪🇸'},
      {'code': 'pt', 'label': 'Português',   'flag': '🇵🇹'},
      {'code': 'de', 'label': 'Deutsch',     'flag': '🇩🇪'},
      {'code': 'it', 'label': 'Italiano',    'flag': '🇮🇹'},
      {'code': 'ar', 'label': 'العربية',     'flag': '🇸🇦'},
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Text(tr('settings_language'), style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
                const Spacer(),
                IconButton(icon: Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context), color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary),
              ]),
            ),
            const Divider(height: 1),
            ...languages.map((lang) {
              final isSelected = localeNotifier.value.languageCode == lang['code'];
              return ListTile(
                leading: Text(lang['flag']!, style: const TextStyle(fontSize: 26)),
                title: Text(lang['label']!, style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                )),
                trailing: isSelected ? Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20) : null,
                onTap: () {
                  localeNotifier.value = Locale(lang['code']!);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  // ─── Sélecteur de devise ────────────────────────────────────────────────────
  Future<void> _showCurrencyPicker() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ValueListenableBuilder<String>(
        valueListenable: currencyNotifier,
        builder: (ctx, activeCurrencyCode, __) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Text(tr('settings_currency'), style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
                  const Spacer(),
                  IconButton(icon: Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx), color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary),
                ]),
              ),
              const Divider(height: 1),
              ...supportedCurrencies.map((c) {
                final isSelected = activeCurrencyCode == c.code;
                return ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: Text(c.symbol, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primary))),
                  ),
                  title: Text(c.name, style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                  )),
                  subtitle: Text(c.code, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint)),
                  trailing: isSelected ? Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20) : null,
                  onTap: () {
                    currencyNotifier.value = c.code;
                    Navigator.pop(ctx);
                    if (mounted) setState(() {});
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Navigue vers une page et appelle setState au retour pour rafraîchir le profil
  Future<void> _navigateTo(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {}); // rafraîchit le profil après retour
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: localeNotifier,
      builder: (_, __, ___) => ValueListenableBuilder(
      valueListenable: userStateNotifier,
      builder: (context, _, __) {
    // ✅ Utilise AuthService — pas MockDataService
    final user = AuthService.instance.currentUserOrEmpty;
    final displayName = user.fullName.trim().isNotEmpty
        ? user.fullName
        : AuthService.instance.loggedUsername;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Header gradient
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                      child: Column(
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text(tr('profile_title'), style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                            IconButton(icon: const Icon(Icons.settings_outlined, color: Colors.white), onPressed: () {}),
                          ]),
                          const SizedBox(height: 16),
                          Stack(
                            children: [
                              UserAvatar(user: user, radius: 44),
                              // ✅ Badge Premium sur l'avatar dès que isPremium est vrai
                              if (user.isPremium)
                                Positioned(
                                  top: 0, right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.accentGradient,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(Icons.workspace_premium_rounded, size: 14, color: Colors.white),
                                  ),
                                ),
                              Positioned(
                                bottom: 0, right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
                                  child: const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(displayName, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                              if (user.isVerified) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.verified_rounded, size: 18, color: Colors.lightBlueAccent),
                              ],
                            ],
                          ),
                          Text(user.email, style: GoogleFonts.poppins(fontSize: 13, color: Colors.white.withOpacity(0.8))),
                          if (user.countryCode != null || user.countryName != null) ...[
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () => _showCountryEditPicker(user),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _getFlag(user.countryCode ?? ''),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    user.countryName ?? '',
                                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.edit_rounded, size: 11, color: Colors.white.withOpacity(0.6)),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          // ✅ Badge "Compte Premium" visible seulement si isPremium
                          if (user.isPremium)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(gradient: AppTheme.accentGradient, borderRadius: BorderRadius.circular(20)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.workspace_premium_rounded, size: 14, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(tr('prof_premium_badge'), style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                              ]),
                            ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _StatPill(label: 'Annonces', value: '$_myListingsCount'),
                              Container(width: 1, height: 30, color: Colors.white.withOpacity(0.3), margin: const EdgeInsets.symmetric(horizontal: 16)),
                              _StatPill(label: 'Note', value: '${user.rating} ⭐'),
                              Container(width: 1, height: 30, color: Colors.white.withOpacity(0.3), margin: const EdgeInsets.symmetric(horizontal: 16)),
                              _StatPill(label: 'Avis', value: '${user.totalAvis}'),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),


                const SizedBox(height: 20),

                // Menu items
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('profile_account'), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
                      const SizedBox(height: 12),
                      _MenuGroup(items: [
                        _MenuItem(icon: Icons.person_outline_rounded, label: tr('profile_edit'), onTap: () => _showEditProfileModal(user)),
                        _MenuItem(icon: Icons.home_outlined, label: tr('profile_listings'), onTap: () => _navigateTo(const MyListingsScreen())),
                        _MenuItem(icon: Icons.favorite_outline_rounded, label: tr('profile_favorites'), onTap: () => _navigateTo(const FavoritesScreen())),
                        _MenuItem(icon: Icons.notifications_outlined, label: tr('profile_notifs'), onTap: () => _navigateTo(const NotificationsScreen())),
                      ]),
                      const SizedBox(height: 16),
                      const SizedBox(height: 16),
                      Text(tr('profile_support'), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
                      const SizedBox(height: 12),
                      _MenuGroup(items: [
                        _MenuItem(icon: Icons.workspace_premium_rounded, label: tr('profile_premium'), onTap: () => _navigateTo(const PremiumScreen()), badge: 'Nouveau', badgeColor: AppTheme.accent),
                        if (user.role == 'admin')
                          _MenuItem(icon: Icons.admin_panel_settings_outlined, label: tr('profile_admin'), onTap: () => _navigateTo(const AdminDashboardScreen())),
                        _MenuItem(icon: Icons.help_outline_rounded, label: tr('profile_help'), onTap: () => _navigateTo(const SupportScreen())),
                        _MenuItem(icon: Icons.policy_outlined, label: tr('profile_terms'), onTap: () => _navigateTo(const LegalScreen(type: LegalType.terms))),
                      ].whereType<_MenuItem>().toList()),
                      const SizedBox(height: 16),
                      const SizedBox(height: 16),
                      Text(tr('profile_settings'), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
                      const SizedBox(height: 12),
                      // ─── Langue ───────────────────────────────────────────
                      ValueListenableBuilder<Locale>(
                        valueListenable: localeNotifier,
                        builder: (_, locale, __) {
                          final langMap = {
                            'fr': ('🇫🇷', 'Français'), 'en': ('🇬🇧', 'English'),
                            'es': ('🇪🇸', 'Español'),  'pt': ('🇵🇹', 'Português'),
                            'de': ('🇩🇪', 'Deutsch'),  'it': ('🇮🇹', 'Italiano'),
                            'ar': ('🇸🇦', 'العربية'),
                          };
                          final entry = langMap[locale.languageCode] ?? ('🌍', locale.languageCode);
                          return GestureDetector(
                            onTap: _showLanguagePicker,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.divider),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 38, height: 38,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.language_rounded, color: AppTheme.primary, size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(tr('settings_language'), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
                                  const SizedBox(height: 2),
                                  Text('${entry.$1}  ${entry.$2}', style: GoogleFonts.poppins(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary)),
                                ])),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textHint),
                              ]),
                            ),
                          );
                        },
                      ),
                      // ─── Devise ───────────────────────────────────────────
                      ValueListenableBuilder<String>(
                        valueListenable: currencyNotifier,
                        builder: (_, code, __) {
                          final cur = supportedCurrencies.firstWhere((c) => c.code == code, orElse: () => supportedCurrencies.first);
                          return GestureDetector(
                            onTap: _showCurrencyPicker,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.divider),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 38, height: 38,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(child: Text(cur.symbol, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primary))),
                                ),
                                const SizedBox(width: 14),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(tr('settings_currency'), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
                                  const SizedBox(height: 2),
                                  Text(cur.name, style: GoogleFonts.poppins(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary)),
                                ])),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textHint),
                              ]),
                            ),
                          );
                        },
                      ),
                      // ─── Thème clair / sombre (widget autonome, hors _MenuGroup) ───
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: themeModeNotifier,
                        builder: (_, mode, __) {
                          final isDark = mode == ThemeMode.dark;
                          return GestureDetector(
                            onTap: () => themeModeNotifier.value =
                                isDark ? ThemeMode.light : ThemeMode.dark,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.divider),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 38, height: 38,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.brightness_6_rounded, color: AppTheme.primary, size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(child: Text(
                                  isDark ? tr('profile_theme_dark') : tr('profile_theme_light'),
                                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                                )),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  width: 50, height: 26,
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppTheme.primary : AppTheme.divider,
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: AnimatedAlign(
                                    duration: const Duration(milliseconds: 250),
                                    alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                      width: 20, height: 20,
                                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                      child: Icon(
                                        isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                        size: 12,
                                        color: isDark ? AppTheme.primary : AppTheme.warning,
                                      ),
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      // Logout
                      GestureDetector(
                        onTap: () async {
                          await AuthService.instance.logout();
                          if (!context.mounted) return;
                          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.07), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.error.withOpacity(0.2))),
                          child: Row(children: [
                            const Icon(Icons.logout_rounded, color: AppTheme.error, size: 20),
                            const SizedBox(width: 12),
                            Text(tr('profile_logout'), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.error)),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
      },
    ),   // ← ferme ValueListenableBuilder(userStateNotifier)
  );     // ← ferme ValueListenableBuilder(localeNotifier)
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  const _StatPill({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
    Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.white.withOpacity(0.7))),
  ]);
}

class _MenuGroup extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuGroup({required this.items});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: Column(
        children: items.asMap().entries.map((e) => Column(children: [
          e.value,
          if (e.key < items.length - 1) const Divider(height: 1, indent: 52),
        ])).toList(),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;
  final Color? badgeColor;
  const _MenuItem({required this.icon, required this.label, required this.onTap, this.badge, this.badgeColor});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: AppTheme.primary),
      ),
      title: Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (badge != null) Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: (badgeColor ?? AppTheme.primary).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Text(badge!, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: badgeColor ?? AppTheme.primary)),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textHint),
      ]),
    );
  }
}


// ─── Modal d'édition du profil (StatefulWidget propre — évite assertion error) ─
class _EditProfileSheet extends StatefulWidget {
  final UserModel user;
  const _EditProfileSheet({required this.user});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _prenomCtrl;
  late final TextEditingController _nomCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _telCtrl;
  late final TextEditingController _nomEntrepriseCtrl;
  late final TextEditingController _typeActiviteCtrl;
  late final TextEditingController _oldPwdCtrl;
  late final TextEditingController _newPwdCtrl;
  late final TextEditingController _confirmPwdCtrl;
  final _formKeyInfo = GlobalKey<FormState>();
  final _formKeyPwd  = GlobalKey<FormState>();

  bool _savingInfo = false;
  bool _savingPwd  = false;
  bool _showOldPwd = false;
  bool _showNewPwd = false;
  bool _showConfirmPwd = false;
  int _tab = 0; // 0 = infos, 1 = mot de passe

  // ── Photo de profil ───────────────────────────────────────────────────
  // _avatarPreview : data URI locale de la photo tout juste choisie, pas
  // encore uploadée — affichée immédiatement via SmartImage pour un retour
  // instantané, avant même l'appel réseau.
  String? _avatarPreview;
  bool _pickingAvatar = false;

  @override
  void initState() {
    super.initState();
    _prenomCtrl   = TextEditingController(text: widget.user.prenom);
    _nomCtrl      = TextEditingController(text: widget.user.nom);
    _emailCtrl    = TextEditingController(text: widget.user.email);
    _telCtrl      = TextEditingController(text: widget.user.telephone ?? '');
    _nomEntrepriseCtrl = TextEditingController(text: widget.user.nomEntreprise ?? '');
    _typeActiviteCtrl  = TextEditingController(text: widget.user.typeActivite ?? '');
    _oldPwdCtrl   = TextEditingController();
    _newPwdCtrl   = TextEditingController();
    _confirmPwdCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _prenomCtrl.dispose();
    _nomCtrl.dispose();
    _emailCtrl.dispose();
    _telCtrl.dispose();
    _nomEntrepriseCtrl.dispose();
    _typeActiviteCtrl.dispose();
    _oldPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    setState(() => _pickingAvatar = true);
    try {
      final file = await WebFilePicker.pickImage();
      if (file != null && mounted) setState(() => _avatarPreview = file);
    } catch (_) {
      // Échec silencieux — l'utilisateur peut retenter, pas bloquant.
    }
    if (mounted) setState(() => _pickingAvatar = false);
  }

  void _showSnack(String msg, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(success ? Icons.check_circle_rounded : Icons.error_rounded,
            color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: GoogleFonts.poppins(color: Colors.white, fontSize: 13))),
      ]),
      backgroundColor: success ? AppTheme.success : AppTheme.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  /// Décode une data URI locale et l'upload vers Cloudinary (même pattern
  /// que add_listing_screen.dart pour les photos de biens).
  Future<String?> _uploadAvatarDataUri(String dataUri) async {
    try {
      // data URI sur le web, chemin de fichier local sur mobile
      final bytes = await WebFilePicker.readBytes(dataUri);
      if (bytes == null) return null;
      final ext = WebFilePicker.imageSubtype(dataUri);
      final result = await PropertyService.instance
          .uploadImageBytes(bytes, 'avatar.${ext == 'jpeg' ? 'jpg' : ext}');
      return result.url;
    } catch (e) {
      debugPrint('Erreur upload photo de profil : $e');
      return null;
    }
  }

  Future<void> _saveInfo() async {
    if (!(_formKeyInfo.currentState?.validate() ?? false)) return;
    setState(() => _savingInfo = true);

    // ── Photo de profil : upload d'abord si l'utilisateur en a choisi une ──
    String? avatarUrl;
    if (_avatarPreview != null) {
      avatarUrl = await _uploadAvatarDataUri(_avatarPreview!);
      if (avatarUrl == null) {
        if (!mounted) return;
        setState(() => _savingInfo = false);
        _showSnack('Échec de l\'envoi de la photo. Réessaie.', success: false);
        return;
      }
    }

    // ⚠️ Persiste réellement côté serveur (avant : sauvegarde locale
    // uniquement, jamais envoyée au backend — donc perdue à la
    // désinstallation/changement d'appareil, invisible pour les autres
    // utilisateurs et l'admin). Photo et champs entreprise inclus désormais.
    final error = await AuthService.instance.updateProfile(
      nom: _nomCtrl.text.trim(),
      prenom: _prenomCtrl.text.trim(),
      telephone: _telCtrl.text.trim(),
      avatarUrl: avatarUrl,
      nomEntreprise: widget.user.accountType == 'business' ? _nomEntrepriseCtrl.text.trim() : null,
      typeActivite: widget.user.accountType == 'business' ? _typeActiviteCtrl.text.trim() : null,
    );

    if (!mounted) return;
    setState(() => _savingInfo = false);

    if (error != null) {
      _showSnack(error, success: false);
      return;
    }

    userStateNotifier.value++;
    Navigator.pop(context);
    _showSnack('Profil mis à jour avec succès !');
  }

  Future<void> _savePassword() async {
    if (!(_formKeyPwd.currentState?.validate() ?? false)) return;
    setState(() => _savingPwd = true);

    // Déléguer la vérification ET la sauvegarde à AuthService
    // (met à jour _registeredPassword en mémoire + SharedPreferences en une seule opération)
    final error = await AuthService.instance.changePassword(
      oldPassword: _oldPwdCtrl.text,
      newPassword: _newPwdCtrl.text,
    );

    if (mounted) {
      setState(() => _savingPwd = false);
      if (error != null) {
        _showSnack(error, success: false);
      } else {
        Navigator.pop(context);
        _showSnack('Mot de passe modifié avec succès !');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppTheme.divider,
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              // Titre + fermer
              Row(children: [
                Text(tr('profile_edit'),
                    style: GoogleFonts.poppins(fontSize: 18,
                        fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                    color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary),
              ]),
              const SizedBox(height: 12),
              // Tabs
              Container(
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  _TabBtn(label: "👤 ${tr('prof_tab_info')}", selected: _tab == 0,
                      onTap: () => setState(() => _tab = 0)),
                  _TabBtn(label: "🔒 ${tr('prof_tab_pwd')}", selected: _tab == 1,
                      onTap: () => setState(() => _tab = 1)),
                ]),
              ),
              const SizedBox(height: 20),

              // ── Tab Infos ──────────────────────────────────────────────────
              if (_tab == 0) Form(
                key: _formKeyInfo,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // ── Photo de profil ────────────────────────────────────────
                  Center(
                    child: GestureDetector(
                      onTap: _pickingAvatar ? null : _pickAvatar,
                      child: Stack(children: [
                        ClipOval(
                          child: _avatarPreview != null
                              ? SmartImage(src: _avatarPreview!, width: 88, height: 88, fit: BoxFit.cover)
                              : SizedBox(width: 88, height: 88, child: UserAvatar(user: widget.user, radius: 44)),
                        ),
                        if (_pickingAvatar)
                          const Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                              child: Center(child: SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                            ),
                          ),
                        Positioned(
                          right: 0, bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Champs modifiables
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      const Icon(Icons.edit_outlined, size: 14, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Text(tr('prof_editable'), style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                  _EditField(ctrl: _prenomCtrl, label: tr('auth_field_prenom').replaceAll(' *',''),
                      icon: Icons.person_outline_rounded,
                      readOnly: false,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null),
                  const SizedBox(height: 12),
                  _EditField(ctrl: _nomCtrl, label: tr('auth_field_nom').replaceAll(' *',''),
                      icon: Icons.badge_outlined,
                      readOnly: false,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null),
                  const SizedBox(height: 12),
                  _EditField(ctrl: _telCtrl, label: tr('auth_field_phone').replaceAll(' *',''),
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      readOnly: false,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null),
                  if (widget.user.accountType == 'business') ...[
                    const SizedBox(height: 12),
                    _EditField(ctrl: _nomEntrepriseCtrl, label: 'Nom de l\'entreprise',
                        icon: Icons.storefront_outlined,
                        readOnly: false),
                    const SizedBox(height: 12),
                    _EditField(ctrl: _typeActiviteCtrl, label: 'Secteur d\'activité',
                        icon: Icons.work_outline_rounded,
                        readOnly: false),
                  ],
                  const SizedBox(height: 20),
                  // Champ verrouillé (email non modifiable côté backend)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      const Icon(Icons.lock_outline_rounded, size: 14, color: AppTheme.textHint),
                      const SizedBox(width: 6),
                      Text(tr('prof_non_editable'), style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint)),
                    ]),
                  ),
                  _EditField(ctrl: _emailCtrl, label: tr('auth_field_email').replaceAll(' *',''),
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      readOnly: true),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _savingInfo ? null : _saveInfo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _savingInfo
                          ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(tr('prof_save'),
                          style: GoogleFonts.poppins(fontSize: 15,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ),

              // ── Tab Mot de passe ───────────────────────────────────────────
              if (_tab == 1) Form(
                key: _formKeyPwd,
                child: Column(children: [
                  _PwdField(ctrl: _oldPwdCtrl, label: 'Ancien mot de passe',
                      show: _showOldPwd,
                      onToggle: () => setState(() => _showOldPwd = !_showOldPwd),
                      validator: (v) => (v == null || v.isEmpty) ? 'Champ requis' : null),
                  const SizedBox(height: 12),
                  _PwdField(ctrl: _newPwdCtrl, label: 'Nouveau mot de passe',
                      show: _showNewPwd,
                      onToggle: () => setState(() => _showNewPwd = !_showNewPwd),
                      validator: (v) => (v == null || v.length < 8)
                          ? 'Minimum 8 caractères' : null),
                  const SizedBox(height: 12),
                  _PwdField(ctrl: _confirmPwdCtrl, label: 'Confirmer le mot de passe',
                      show: _showConfirmPwd,
                      onToggle: () => setState(() => _showConfirmPwd = !_showConfirmPwd),
                      validator: (v) => v != _newPwdCtrl.text
                          ? 'Les mots de passe ne correspondent pas' : null),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _savingPwd ? null : _savePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _savingPwd
                          ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(tr('prof_change_pwd'),
                          style: GoogleFonts.poppins(fontSize: 15,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tab button ───────────────────────────────────────────────────────────────
class _TabBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppTheme.textSecondary)),
          ),
        ),
      ),
    );
  }
}

// ─── Champ mot de passe ───────────────────────────────────────────────────────
class _PwdField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final bool show;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;
  const _PwdField({required this.ctrl, required this.label,
      required this.show, required this.onToggle, this.validator});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      obscureText: !show,
      validator: validator,
      style: GoogleFonts.poppins(fontSize: 14, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textHint),
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppTheme.primary),
        suffixIcon: IconButton(
          icon: Icon(show ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              size: 18, color: AppTheme.textHint),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.divider, width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.error, width: 1)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.error, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ─── Champ texte réutilisable pour le formulaire d'édition ───────────────────
class _EditField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool readOnly;

  const _EditField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.validator,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: readOnly ? AppTheme.textHint : AppTheme.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textHint),
        prefixIcon: Icon(icon, size: 18, color: readOnly ? AppTheme.textHint : AppTheme.primary),
        suffixIcon: readOnly
            ? const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.lock_outline_rounded, size: 16, color: AppTheme.textHint),
              )
            : null,
        filled: true,
        fillColor: readOnly ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4) : Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.divider, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: readOnly ? AppTheme.divider : AppTheme.primary,
            width: readOnly ? 1 : 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
