import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/mock_data.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../services/app_translations.dart';
import '../widgets/widgets.dart';
import 'property_detail_screen.dart';
import 'notifications_screen.dart';
import 'premium_screen.dart';
import 'add_listing_screen.dart';
import 'kyc_screen.dart';
import 'explore_screen.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  const HomeScreen({super.key, this.username = 'Utilisateur'});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategoryKey = 'cat_all';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSearchFocused = false;

  int _currentBannerIndex = 0;
  late PageController _bannerController;
  bool _autoScrollActive = true;

  // ─── Filtre pays ───────────────────────────────────────────────────────────
  String? _filterCountryCode; // null = tous les pays
  String? _filterCountryName;

  // ─── Recherche vocale ───────────────────────────────────────────────────────
  bool _isListening = false;
  bool _speechAvailable = false;

  // Clés de traduction des catégories (résolues dynamiquement dans build())
  final _categoryKeys = [
    'cat_all', 'cat_maisons', 'cat_voitures', 'cat_appartements',
    'cat_equipements', 'cat_terrains', 'cat_bureaux', 'cat_motos', 'cat_autre'
  ];
  // Correspondance clé → PropertyCategory pour le filtrage
  final _categoryFilters = {
    'cat_maisons':      PropertyCategory.maison,
    'cat_voitures':     PropertyCategory.voiture,
    'cat_appartements': PropertyCategory.appartement,
    'cat_equipements':  PropertyCategory.equipement,
    'cat_terrains':     PropertyCategory.terrain,
    'cat_bureaux':      PropertyCategory.bureau,
    'cat_motos':        PropertyCategory.moto,
    'cat_autre':        PropertyCategory.autre,
  };

  // _banners calculé dans build() pour réagir aux changements de locale
  void _onNewProperty() => setState(() {});

  @override
  void initState() {
    super.initState();
    _bannerController = PageController();

    _focusNode.addListener(() => setState(() => _isSearchFocused = _focusNode.hasFocus));
    publishedPropertiesNotifier.addListener(_onNewProperty);
    // Reconnaissance vocale désactivée sur mobile (disponible sur Edge/Chrome via IA)
    _speechAvailable = false;

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted || !_autoScrollActive) return false;
      final next = ((_currentBannerIndex + 1) % 5).toInt(); // 5 banières fixes
      if (_bannerController.hasClients) {
        _bannerController.animateToPage(next,
            duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      }
      return true;
    });
  }

  @override
  void dispose() {
    _autoScrollActive = false;
    publishedPropertiesNotifier.removeListener(_onNewProperty);
    _searchCtrl.dispose();
    _focusNode.dispose();
    _bannerController.dispose();
    super.dispose();
  }

  List<PropertyModel> get _searchResults {
    final q = _searchQuery.trim();
    if (q.length < 2) return [];
    final tokens = q.toLowerCase().split(RegExp(r'\s+'));
    final allProps = [...MockDataService.properties, ...publishedProperties.cast<PropertyModel>()];
    return allProps.where((p) {
      final blob = [
        p.titre, p.description, p.adresse.ville, p.adresse.rue,
        p.adresse.pays, p.categorieLabel, p.typeLabel, p.listingLabel,
        ...p.caracteristiques,
        if (p.annee != null) '${p.annee}',
        if (p.surface != null) p.surface!,
        if (p.nombrePieces != null) '${p.nombrePieces} chambres',
      ].join(' ').toLowerCase();
      return tokens.every((token) => blob.contains(token));
    }).toList();
  }

  List<PropertyModel> get _filteredProps {
    var allProps = [...MockDataService.properties, ...publishedProperties.cast<PropertyModel>()];

    // ── Filtre par pays sélectionné ──
    if (_filterCountryCode != null) {
      allProps = allProps.where((p) =>
        p.adresse.pays.toLowerCase() == (_filterCountryName ?? '').toLowerCase()
      ).toList();
    }

    if (_selectedCategoryKey == 'cat_all') return allProps;
    final cat = _categoryFilters[_selectedCategoryKey];
    if (cat == null) return allProps;
    return allProps.where((p) => p.categorie == cat).toList();
  }

  bool get _isActiveSearch => _searchQuery.trim().length >= 2;

  // ─── Reconnaissance vocale pour la barre de recherche ────────────────────
  Future<void> _startVoiceSearch() async {
    // Reconnaissance vocale mobile non disponible sans speech_to_text
    // Utiliser le bouton micro dans l'assistant IA à la place
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.mic_off_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text('Utilisez le micro dans l\'assistant IA 🤖',
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
      ]),
      backgroundColor: AppTheme.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  void _stopVoiceSearch() {
    setState(() => _isListening = false);
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() => _searchQuery = '');
    _focusNode.unfocus();
  }

  String _getFlag(String code) {
    if (code.length != 2) return '🌍';
    return code.toUpperCase().runes.map((r) => String.fromCharCode(r + 127397)).join();
  }

  // ─── Sélecteur de pays pour filtre ─────────────────────────────────────────
  static const List<Map<String, String>> _allCountries = [
    {'code': 'TG', 'name': 'Togo'},
    {'code': 'BJ', 'name': 'Bénin'},
    {'code': 'GH', 'name': 'Ghana'},
    {'code': 'CI', 'name': "Côte d'Ivoire"},
    {'code': 'SN', 'name': 'Sénégal'},
    {'code': 'ML', 'name': 'Mali'},
    {'code': 'BF', 'name': 'Burkina Faso'},
    {'code': 'NE', 'name': 'Niger'},
    {'code': 'NG', 'name': 'Nigeria'},
    {'code': 'CM', 'name': 'Cameroun'},
    {'code': 'GA', 'name': 'Gabon'},
    {'code': 'CD', 'name': 'Congo (RDC)'},
    {'code': 'CG', 'name': 'Congo'},
    {'code': 'KE', 'name': 'Kenya'},
    {'code': 'TZ', 'name': 'Tanzanie'},
    {'code': 'RW', 'name': 'Rwanda'},
    {'code': 'ET', 'name': 'Éthiopie'},
    {'code': 'ZA', 'name': 'Afrique du Sud'},
    {'code': 'EG', 'name': 'Égypte'},
    {'code': 'MA', 'name': 'Maroc'},
    {'code': 'TN', 'name': 'Tunisie'},
    {'code': 'DZ', 'name': 'Algérie'},
    {'code': 'FR', 'name': 'France'},
    {'code': 'DE', 'name': 'Allemagne'},
    {'code': 'GB', 'name': 'Royaume-Uni'},
    {'code': 'US', 'name': 'États-Unis'},
    {'code': 'CA', 'name': 'Canada'},
    {'code': 'BR', 'name': 'Brésil'},
    {'code': 'CN', 'name': 'Chine'},
    {'code': 'IN', 'name': 'Inde'},
    {'code': 'JP', 'name': 'Japon'},
    {'code': 'AU', 'name': 'Australie'},
    {'code': 'SA', 'name': 'Arabie Saoudite'},
    {'code': 'AE', 'name': 'Émirats arabes unis'},
    {'code': 'AF', 'name': 'Afghanistan'},
    {'code': 'AL', 'name': 'Albanie'},
    {'code': 'AM', 'name': 'Arménie'},
    {'code': 'AO', 'name': 'Angola'},
    {'code': 'AR', 'name': 'Argentine'},
    {'code': 'AT', 'name': 'Autriche'},
    {'code': 'AZ', 'name': 'Azerbaïdjan'},
    {'code': 'BA', 'name': 'Bosnie-Herzégovine'},
    {'code': 'BD', 'name': 'Bangladesh'},
    {'code': 'BE', 'name': 'Belgique'},
    {'code': 'BG', 'name': 'Bulgarie'},
    {'code': 'BH', 'name': 'Bahreïn'},
    {'code': 'BI', 'name': 'Burundi'},
    {'code': 'BN', 'name': 'Brunei'},
    {'code': 'BO', 'name': 'Bolivie'},
    {'code': 'BS', 'name': 'Bahamas'},
    {'code': 'BT', 'name': 'Bhoutan'},
    {'code': 'BW', 'name': 'Botswana'},
    {'code': 'BY', 'name': 'Biélorussie'},
    {'code': 'BZ', 'name': 'Belize'},
    {'code': 'CF', 'name': 'Rép. centrafricaine'},
    {'code': 'CH', 'name': 'Suisse'},
    {'code': 'CL', 'name': 'Chili'},
    {'code': 'CO', 'name': 'Colombie'},
    {'code': 'CR', 'name': 'Costa Rica'},
    {'code': 'CU', 'name': 'Cuba'},
    {'code': 'CV', 'name': 'Cap-Vert'},
    {'code': 'CY', 'name': 'Chypre'},
    {'code': 'CZ', 'name': 'Tchéquie'},
    {'code': 'DJ', 'name': 'Djibouti'},
    {'code': 'DK', 'name': 'Danemark'},
    {'code': 'DM', 'name': 'Dominique'},
    {'code': 'EC', 'name': 'Équateur'},
    {'code': 'EE', 'name': 'Estonie'},
    {'code': 'ER', 'name': 'Érythrée'},
    {'code': 'ES', 'name': 'Espagne'},
    {'code': 'FI', 'name': 'Finlande'},
    {'code': 'FJ', 'name': 'Fidji'},
    {'code': 'GD', 'name': 'Grenade'},
    {'code': 'GM', 'name': 'Gambie'},
    {'code': 'GN', 'name': 'Guinée'},
    {'code': 'GQ', 'name': 'Guinée équatoriale'},
    {'code': 'GR', 'name': 'Grèce'},
    {'code': 'GT', 'name': 'Guatemala'},
    {'code': 'GW', 'name': 'Guinée-Bissau'},
    {'code': 'GY', 'name': 'Guyana'},
    {'code': 'HN', 'name': 'Honduras'},
    {'code': 'HR', 'name': 'Croatie'},
    {'code': 'HT', 'name': 'Haïti'},
    {'code': 'HU', 'name': 'Hongrie'},
    {'code': 'ID', 'name': 'Indonésie'},
    {'code': 'IE', 'name': 'Irlande'},
    {'code': 'IL', 'name': 'Israël'},
    {'code': 'IQ', 'name': 'Irak'},
    {'code': 'IR', 'name': 'Iran'},
    {'code': 'IS', 'name': 'Islande'},
    {'code': 'IT', 'name': 'Italie'},
    {'code': 'JM', 'name': 'Jamaïque'},
    {'code': 'JO', 'name': 'Jordanie'},
    {'code': 'KG', 'name': 'Kirghizistan'},
    {'code': 'KH', 'name': 'Cambodge'},
    {'code': 'KI', 'name': 'Kiribati'},
    {'code': 'KM', 'name': 'Comores'},
    {'code': 'KP', 'name': 'Corée du Nord'},
    {'code': 'KR', 'name': 'Corée du Sud'},
    {'code': 'KW', 'name': 'Koweït'},
    {'code': 'KZ', 'name': 'Kazakhstan'},
    {'code': 'LA', 'name': 'Laos'},
    {'code': 'LB', 'name': 'Liban'},
    {'code': 'LI', 'name': 'Liechtenstein'},
    {'code': 'LK', 'name': 'Sri Lanka'},
    {'code': 'LR', 'name': 'Libéria'},
    {'code': 'LS', 'name': 'Lesotho'},
    {'code': 'LT', 'name': 'Lituanie'},
    {'code': 'LU', 'name': 'Luxembourg'},
    {'code': 'LV', 'name': 'Lettonie'},
    {'code': 'LY', 'name': 'Libye'},
    {'code': 'MC', 'name': 'Monaco'},
    {'code': 'MD', 'name': 'Moldavie'},
    {'code': 'ME', 'name': 'Monténégro'},
    {'code': 'MG', 'name': 'Madagascar'},
    {'code': 'MH', 'name': 'Marshall'},
    {'code': 'MK', 'name': 'Macédoine du Nord'},
    {'code': 'MM', 'name': 'Myanmar'},
    {'code': 'MN', 'name': 'Mongolie'},
    {'code': 'MR', 'name': 'Mauritanie'},
    {'code': 'MT', 'name': 'Malte'},
    {'code': 'MU', 'name': 'Maurice'},
    {'code': 'MV', 'name': 'Maldives'},
    {'code': 'MW', 'name': 'Malawi'},
    {'code': 'MX', 'name': 'Mexique'},
    {'code': 'MY', 'name': 'Malaisie'},
    {'code': 'MZ', 'name': 'Mozambique'},
    {'code': 'NA', 'name': 'Namibie'},
    {'code': 'NL', 'name': 'Pays-Bas'},
    {'code': 'NO', 'name': 'Norvège'},
    {'code': 'NP', 'name': 'Népal'},
    {'code': 'NR', 'name': 'Nauru'},
    {'code': 'NZ', 'name': 'Nouvelle-Zélande'},
    {'code': 'OM', 'name': 'Oman'},
    {'code': 'PA', 'name': 'Panama'},
    {'code': 'PE', 'name': 'Pérou'},
    {'code': 'PG', 'name': 'Papouasie-Nouvelle-Guinée'},
    {'code': 'PH', 'name': 'Philippines'},
    {'code': 'PK', 'name': 'Pakistan'},
    {'code': 'PL', 'name': 'Pologne'},
    {'code': 'PT', 'name': 'Portugal'},
    {'code': 'PY', 'name': 'Paraguay'},
    {'code': 'QA', 'name': 'Qatar'},
    {'code': 'RO', 'name': 'Roumanie'},
    {'code': 'RS', 'name': 'Serbie'},
    {'code': 'RU', 'name': 'Russie'},
    {'code': 'SC', 'name': 'Seychelles'},
    {'code': 'SD', 'name': 'Soudan'},
    {'code': 'SE', 'name': 'Suède'},
    {'code': 'SG', 'name': 'Singapour'},
    {'code': 'SI', 'name': 'Slovénie'},
    {'code': 'SK', 'name': 'Slovaquie'},
    {'code': 'SL', 'name': 'Sierra Leone'},
    {'code': 'SM', 'name': 'Saint-Marin'},
    {'code': 'SO', 'name': 'Somalie'},
    {'code': 'SR', 'name': 'Suriname'},
    {'code': 'SS', 'name': 'Soudan du Sud'},
    {'code': 'ST', 'name': 'Sao Tomé-et-Principe'},
    {'code': 'SV', 'name': 'Salvador'},
    {'code': 'SY', 'name': 'Syrie'},
    {'code': 'SZ', 'name': 'Eswatini'},
    {'code': 'TD', 'name': 'Tchad'},
    {'code': 'TH', 'name': 'Thaïlande'},
    {'code': 'TJ', 'name': 'Tadjikistan'},
    {'code': 'TL', 'name': 'Timor-Leste'},
    {'code': 'TM', 'name': 'Turkménistan'},
    {'code': 'TO', 'name': 'Tonga'},
    {'code': 'TR', 'name': 'Turquie'},
    {'code': 'TT', 'name': 'Trinité-et-Tobago'},
    {'code': 'TV', 'name': 'Tuvalu'},
    {'code': 'UA', 'name': 'Ukraine'},
    {'code': 'UG', 'name': 'Ouganda'},
    {'code': 'UY', 'name': 'Uruguay'},
    {'code': 'UZ', 'name': 'Ouzbékistan'},
    {'code': 'VE', 'name': 'Venezuela'},
    {'code': 'VN', 'name': 'Viêt Nam'},
    {'code': 'VU', 'name': 'Vanuatu'},
    {'code': 'YE', 'name': 'Yémen'},
    {'code': 'ZM', 'name': 'Zambie'},
    {'code': 'ZW', 'name': 'Zimbabwe'},
  ];

  void _showCountryFilterPicker() {
    final searchCtrl = TextEditingController();
    List<Map<String, String>> filtered = List.from(_allCountries);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                      Text(tr('home_country_filter'), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
                      const Spacer(),
                      if (_filterCountryCode != null)
                        TextButton(
                          onPressed: () {
                            setState(() { _filterCountryCode = null; _filterCountryName = null; });
                            Navigator.pop(ctx);
                          },
                          child: Text(tr('home_see_all'), style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                        ),
                      IconButton(icon: Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx), color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: tr('home_search_country'),
                      hintStyle: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textHint),
                      prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textHint),
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (q) {
                      setModalState(() {
                        filtered = _allCountries.where((c) =>
                          c['name']!.toLowerCase().contains(q.toLowerCase()) ||
                          c['code']!.toLowerCase().contains(q.toLowerCase())
                        ).toList();
                      });
                    },
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final c = filtered[i];
                      final isSelected = _filterCountryCode == c['code'];
                      return ListTile(
                        leading: Text(_getFlag(c['code']!), style: const TextStyle(fontSize: 28)),
                        title: Text(c['name']!, style: GoogleFonts.poppins(fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: isSelected ? AppTheme.primary : AppTheme.textPrimary)),
                        trailing: isSelected ? Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20) : null,
                        onTap: () {
                          setState(() {
                            _filterCountryCode = c['code'];
                            _filterCountryName = c['name'];
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ CORRECTIF : écouter userStateNotifier pour se reconstruire
    // quand l'utilisateur passe premium → featured se recalcule immédiatement
    return ValueListenableBuilder(
      valueListenable: userStateNotifier,
      builder: (context, _, __) {
    final featured = [...MockDataService.properties, ...publishedProperties.cast<PropertyModel>()]
        .where((p) => p.isFeatured).toList();
    final results = _searchResults;

    // ✅ Banières recalculées à chaque build → tr() utilise la locale courante
    final banners = [
      _BannerSlide(icon: Icons.home_work_rounded,
        title: tr('banner1_title'), subtitle: tr('banner1_sub'),
        gradient: const [Color(0xFF0D47A1), Color(0xFF1976D2)],
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExploreScreen()))),
      _BannerSlide(icon: Icons.directions_car_rounded,
        title: tr('banner2_title'), subtitle: tr('banner2_sub'),
        gradient: const [Color(0xFF0A237A), Color(0xFF1565C0)],
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExploreScreen()))),
      _BannerSlide(icon: Icons.verified_user_rounded,
        title: tr('banner3_title'), subtitle: tr('banner3_sub'),
        gradient: const [Color(0xFF1B5E20), Color(0xFF2E7D32)],
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()))),
      _BannerSlide(icon: Icons.star_rounded,
        title: tr('banner4_title'), subtitle: tr('banner4_sub'),
        gradient: const [Color(0xFFE65100), Color(0xFFFF6F00)],
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()))),
      _BannerSlide(icon: Icons.add_circle_rounded,
        title: tr('banner5_title'), subtitle: tr('banner5_sub'),
        gradient: const [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddListingScreen()))),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [

            // ── HEADER ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Logo rond avec vraie image
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(
                              color: AppTheme.primary.withOpacity(0.35),
                              blurRadius: 10, offset: const Offset(0, 4),
                            )],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text('VQ', style: GoogleFonts.poppins(
                                  fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white,
                                )),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Nom bicolore
                        RichText(
                          text: TextSpan(children: [
                            TextSpan(text: 'VEL', style: GoogleFonts.poppins(
                              fontSize: 24, fontWeight: FontWeight.w800,
                              color: AppTheme.primary, letterSpacing: -0.5,
                            )),
                            TextSpan(text: 'QIX', style: GoogleFonts.poppins(
                              fontSize: 24, fontWeight: FontWeight.w800,
                              color: AppTheme.accent, letterSpacing: -0.5,
                            )),
                          ]),
                        ),

                        const Spacer(),

                        // ── Sélecteur de pays (drapeau) ──────────────────────
                        GestureDetector(
                          onTap: _showCountryFilterPicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: _filterCountryCode != null ? AppTheme.primary.withOpacity(0.1) : AppTheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _filterCountryCode != null ? AppTheme.primary : Colors.transparent,
                                width: 1.5,
                              ),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Builder(builder: (_) {
                                  // Drapeau du pays filtré ou du pays de l'utilisateur
                                  final user = AuthService.instance.currentUserOrEmpty;
                                  String? flagEmoji;
                                  String? label;
                                  if (_filterCountryCode != null) {
                                    flagEmoji = _getFlag(_filterCountryCode!);
                                    label = _filterCountryName;
                                  } else if (user.countryCode != null) {
                                    flagEmoji = _getFlag(user.countryCode!);
                                    label = user.countryName;
                                  }
                                  if (flagEmoji != null) {
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(flagEmoji, style: const TextStyle(fontSize: 20)),
                                        const SizedBox(width: 5),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 70),
                                          child: Text(
                                            label ?? '',
                                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: _filterCountryCode != null ? AppTheme.primary : AppTheme.textPrimary),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: _filterCountryCode != null ? AppTheme.primary : AppTheme.textHint),
                                      ],
                                    );
                                  }
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('🌍', style: TextStyle(fontSize: 20)),
                                      const SizedBox(width: 4),
                                      Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppTheme.textHint),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // ✅ Notif badge temps réel (se met à jour quand l'admin approuve)
                        ValueListenableBuilder(
                          valueListenable: appNotificationsNotifier,
                          builder: (context, notifs, _) {
                            final unread = (notifs as List).where((n) => n['lu'] == false).length;
                            return Stack(children: [
                              GestureDetector(
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
                                  ),
                                  child: Icon(Icons.notifications_outlined, size: 22, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary),
                                ),
                              ),
                              if (unread > 0)
                                Positioned(
                                  top: 6, right: 6,
                                  child: Container(
                                    width: 16, height: 16,
                                    decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
                                    child: Center(
                                      child: Text('$unread',
                                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                            ]);
                          },
                        ),

                      ],
                    ),

                    const SizedBox(height: 18),

                    // ── BANNIÈRES DÉFILANTES CLIQUABLES ──────────────────────
                    SizedBox(
                      height: 112,
                      child: PageView.builder(
                        controller: _bannerController,
                        onPageChanged: (i) => setState(() => _currentBannerIndex = i),
                        itemCount: banners.length,
                        itemBuilder: (_, i) => _AdBannerCard(slide: banners[i]),
                      ),
                    ),

                    // Dots
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(banners.length, (i) {
                        final active = i == _currentBannerIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: active ? banners[_currentBannerIndex].gradient.first : AppTheme.border,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 18),

                    // ── Recherche ─────────────────────────────────────────────
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isSearchFocused ? AppTheme.primary : Colors.transparent,
                          width: 1.5,
                        ),
                        boxShadow: [BoxShadow(
                          color: _isSearchFocused
                              ? AppTheme.primary.withOpacity(0.12)
                              : Colors.black.withOpacity(0.06),
                          blurRadius: 12, offset: const Offset(0, 3),
                        )],
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        focusNode: _focusNode,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: GoogleFonts.poppins(fontSize: 14, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: tr('home_search_hint'),
                          hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textHint),
                          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textHint, size: 22),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? GestureDetector(
                                  onTap: _clearSearch,
                                  child: Container(
                                    margin: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                        color: AppTheme.textHint.withOpacity(0.15),
                                        shape: BoxShape.circle),
                                    child: Icon(Icons.close_rounded, color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary, size: 16),
                                  ),
                                )
                              : _speechAvailable
                                  ? GestureDetector(
                                      onTap: _isListening ? _stopVoiceSearch : _startVoiceSearch,
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        margin: const EdgeInsets.all(8),
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: _isListening
                                              ? AppTheme.error.withOpacity(0.15)
                                              : AppTheme.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                                          size: 18,
                                          color: _isListening ? AppTheme.error : AppTheme.primary,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      margin: const EdgeInsets.all(8),
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                          color: AppTheme.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8)),
                                      child: const Icon(Icons.tune_rounded, size: 18, color: AppTheme.primary),
                                    ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),

                    if (_searchQuery.length == 1) ...[
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          _SuggestionChip(label: 'Lomé', onTap: _applySuggestion),
                          _SuggestionChip(label: 'Agoè', onTap: _applySuggestion),
                          _SuggestionChip(label: 'Maison', onTap: _applySuggestion),
                          _SuggestionChip(label: 'Voiture', onTap: _applySuggestion),
                          _SuggestionChip(label: 'Location', onTap: _applySuggestion),
                          _SuggestionChip(label: 'Vente', onTap: _applySuggestion),
                          _SuggestionChip(label: 'Appartement', onTap: _applySuggestion),
                        ]),
                      ),
                    ],

                    if (!_isActiveSearch) ...[
                      const SizedBox(height: 20),
                      Row(children: [
                        _QuickStat(
                            icon: Icons.home_work_rounded,
                            value: '${MockDataService.properties.length + publishedProperties.length}',
                            label: tr('home_annonces')),
                        const SizedBox(width: 10),
                        _QuickStat(
                            icon: Icons.directions_car_rounded,
                            value: '${[...MockDataService.properties, ...publishedProperties.cast<PropertyModel>()].where((p) => p.type == PropertyType.mobilier).length}',
                            label: tr('home_mobilier')),
                        const SizedBox(width: 10),
                        _QuickStat(
                            icon: Icons.apartment_rounded,
                            value: '${[...MockDataService.properties, ...publishedProperties.cast<PropertyModel>()].where((p) => p.type == PropertyType.immobilier).length}',
                            label: tr('home_immobilier')),
                      ]),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ══════════════════════════════════════════════════════════════
            // MODE RECHERCHE ACTIVE
            // ══════════════════════════════════════════════════════════════
            if (_isActiveSearch) ...[

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: results.isEmpty ? AppTheme.error.withOpacity(0.08) : AppTheme.success.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: results.isEmpty ? AppTheme.error.withOpacity(0.2) : AppTheme.success.withOpacity(0.2),
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          results.isEmpty ? Icons.search_off_rounded : Icons.check_circle_outline_rounded,
                          size: 14,
                          color: results.isEmpty ? AppTheme.error : AppTheme.success,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          results.isEmpty
                              ? 'Aucun résultat pour "$_searchQuery"'
                              : '${results.length} résultat${results.length > 1 ? 's' : ''} pour "$_searchQuery"',
                          style: GoogleFonts.poppins(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: results.isEmpty ? AppTheme.error : AppTheme.success,
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),

              if (results.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 40),
                    child: Column(children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.06), shape: BoxShape.circle),
                        child: const Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textHint),
                      ),
                      const SizedBox(height: 16),
                      Text(tr('home_no_results'), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                        'Essayez avec d\'autres mots.\nPar exemple : "villa", "lomé", "voiture 2022"',
                        style: GoogleFonts.poppins(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary, height: 1.6),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
                        children: ['Villa', 'Appartement', 'Voiture', 'Lomé', 'Agoè', 'Location', 'Terrain']
                            .map((s) => GestureDetector(
                              onTap: () => _applySuggestion(s),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface, borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Text(s, style: GoogleFonts.poppins(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary)),
                              ),
                            )).toList(),
                      ),
                    ]),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PropertyCard(property: results[i], horizontal: true, onTap: () => _openDetail(results[i])),
                      ),
                      childCount: results.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),

            // ══════════════════════════════════════════════════════════════
            // MODE NORMAL
            // ══════════════════════════════════════════════════════════════
            ] else ...[

              // ── Annonces vedettes (uniquement si la liste n'est pas vide) ──
              if (featured.isNotEmpty) SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SectionHeader(
                        title: tr('home_featured'),
                        actionLabel: tr('home_see_all'),
                        onAction: () {},
                      ),
                    ),
                    const SizedBox(height: 14),   // ← espacement correct
                    SizedBox(
                      height: 290,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: featured.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (_, i) => SizedBox(
                          width: 220,
                          child: PropertyCard(property: featured[i], onTap: () => _openDetail(featured[i])),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),   // ← espace avant la section suivante
                  ],
                ),
              ),

              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: SectionHeader(title: tr('home_categories'))),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _categoryKeys.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final key = _categoryKeys[i];
                          final sel = _selectedCategoryKey == key;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedCategoryKey = key),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                              decoration: BoxDecoration(
                                color: sel ? AppTheme.primary : AppTheme.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: sel ? AppTheme.primary : AppTheme.border),
                              ),
                              child: Text(tr(key), style: GoogleFonts.poppins(
                                  fontSize: 13, fontWeight: FontWeight.w500,
                                  color: sel ? Colors.white : AppTheme.textSecondary)),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: _filterCountryCode != null
                          ? "${tr('home_annonces')} · ${_filterCountryName ?? ''}"
                          : tr('home_all_listings'),
                        actionLabel: "${_filteredProps.length} ${tr('home_listings')}",
                        onAction: () {},
                      ),
                      if (_filterCountryCode != null) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => setState(() { _filterCountryCode = null; _filterCountryName = null; }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_filterCountryCode != null ? _getFlag(_filterCountryCode!) : '🌍', style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Text(_filterCountryName ?? '', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.primary)),
                                const SizedBox(width: 6),
                                Icon(Icons.close_rounded, size: 14, color: AppTheme.primary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),

              _filteredProps.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(padding: const EdgeInsets.all(40),
                        child: Column(children: [
                          const Icon(Icons.home_outlined, size: 48, color: AppTheme.textHint),
                          const SizedBox(height: 12),
                          Text(tr('home_no_cat'),
                              style: GoogleFonts.poppins(fontSize: 14, color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary)),
                        ]),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) {
                            final props = _filteredProps;
                            if (i >= props.length) return null;
                            return PropertyCard(property: props[i], onTap: () => _openDetail(props[i]));
                          },
                          childCount: _filteredProps.length,
                        ),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, crossAxisSpacing: 14,
                          mainAxisSpacing: 14, mainAxisExtent: 310,
                        ),
                      ),
                    ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ],
        ),
      ),
    );
      }, // ← ferme builder: de ValueListenableBuilder(userStateNotifier)
    );   // ← ferme ValueListenableBuilder
  }

  void _applySuggestion(String s) {
    _searchCtrl.text = s;
    setState(() => _searchQuery = s);
    _focusNode.unfocus();
  }

  void _openDetail(PropertyModel p) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => PropertyDetailScreen(property: p)));
}

// ─── Modèle slide ─────────────────────────────────────────────────────────────
class _BannerSlide {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _BannerSlide({
    required this.icon, required this.title, required this.subtitle,
    required this.gradient, required this.onTap,
  });
}

// ─── Carte bannière cliquable ─────────────────────────────────────────────────
class _AdBannerCard extends StatelessWidget {
  final _BannerSlide slide;
  const _AdBannerCard({required this.slide});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: slide.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: slide.gradient,
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
            color: slide.gradient.first.withOpacity(0.35),
            blurRadius: 14, offset: const Offset(0, 6),
          )],
        ),
        child: Stack(
          children: [
            Positioned(right: -20, top: -20,
              child: Container(width: 100, height: 100,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), shape: BoxShape.circle))),
            Positioned(right: 30, bottom: -30,
              child: Container(width: 80, height: 80,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle))),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14)),
                    child: Icon(slide.icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(slide.title,
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700,
                              color: Colors.white, height: 1.3),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(slide.subtitle,
                          style: GoogleFonts.poppins(fontSize: 11,
                              color: Colors.white.withOpacity(0.85), height: 1.4),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  // Flèche indicateur cliquable
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
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

// ─── Chip suggestion ──────────────────────────────────────────────────────────
class _SuggestionChip extends StatelessWidget {
  final String label;
  final Function(String) onTap;
  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(label),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.north_west_rounded, size: 11, color: AppTheme.textHint),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.poppins(
              fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

// ─── Stat rapide ──────────────────────────────────────────────────────────────
class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _QuickStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
        child: Row(children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
            Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary)),
          ]),
        ]),
      ),
    );
  }
}