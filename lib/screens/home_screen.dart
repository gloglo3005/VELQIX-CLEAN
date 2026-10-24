import 'package:flutter/material.dart';
import '../services/listings_cache.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart'; // NEW : vraie source des annonces publiques
import '../theme/app_theme.dart';
import '../services/app_translations.dart';
import '../widgets/widgets.dart';
import 'property_detail_screen.dart';
import 'notifications_screen.dart';
import 'plans_screen.dart';
import 'add_listing_screen.dart';
import 'explore_screen.dart';
import 'staff_directory_screen.dart';
import 'auth_screens.dart' show LoginScreen, RegisterScreen;
import 'support_screen.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  const HomeScreen({super.key, this.username = 'Utilisateur'});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategoryKey = 'cat_all';
  String _searchQuery = '';
  // Recherche du hero (maquette) : type de logement + budget max.
  String _heroCategoryKey = 'cat_all';
  final _budgetCtrl = TextEditingController();
  double? _maxBudget;
  bool _heroFilterActive = false;
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
  // Immobilier et mobilier sont séparés : l'utilisateur choisit d'abord le type
  // de bien, puis une catégorie propre à ce type.
  PropertyType _selectedType = PropertyType.immobilier;
  static const _immoCategoryKeys = [
    'cat_all', 'cat_chambres', 'cat_studios', 'cat_maisons', 'cat_appartements',
    'cat_terrains', 'cat_locaux', 'cat_bureaux', 'cat_hotels',
  ];
  static const _mobilCategoryKeys = [
    'cat_all', 'cat_voitures', 'cat_motos', 'cat_camions',
  ];
  List<String> get _categoryKeys =>
      _selectedType == PropertyType.immobilier ? _immoCategoryKeys : _mobilCategoryKeys;
  // Correspondance clé → PropertyCategory pour le filtrage
  final _categoryFilters = {
    'cat_chambres':     PropertyCategory.chambre,
    'cat_studios':      PropertyCategory.studio,
    'cat_locaux':       PropertyCategory.localCommercial,
    'cat_maisons':      PropertyCategory.maison,
    'cat_appartements': PropertyCategory.appartement,
    'cat_hotels':       PropertyCategory.hotel,
    'cat_terrains':     PropertyCategory.terrain,
    'cat_bureaux':      PropertyCategory.bureau,
    'cat_voitures':     PropertyCategory.voiture,
    'cat_motos':        PropertyCategory.moto,
    'cat_camions':      PropertyCategory.camion,
  };

  // NOTE : remplace MockDataService + publishedProperties (session-local) par
  // les vraies annonces approuvées, chargées depuis GET /properties.
  List<PropertyModel> _serverProps = [];
  bool _loadingProps = true;
  bool _offline = false; // serveur injoignable : on affiche les annonces enregistrées

  Future<void> _loadProperties() async {
    // 1) Affichage INSTANTANÉ : dernières annonces connues (cache local)
    if (_serverProps.isEmpty) {
      final cached = await ListingsCache.read();
      if (!mounted) return;
      if (cached != null && cached.isNotEmpty) {
        try {
          _serverProps = cached.map(PropertyModel.fromJson).toList();
          setState(() => _loadingProps = false);
        } catch (_) {}
      }
    }
    if (mounted && _serverProps.isEmpty) setState(() => _loadingProps = true);

    // 2) Mise à jour depuis le serveur (peut être lent s'il dormait)
    final res = await ApiService.instance.get('/properties');
    if (!mounted) return;
    _offline = res['success'] != true;
    if (res['success'] == true) {
      final raw = res['data'] as List;
      _serverProps = raw
          .map((j) => PropertyModel.fromJson(j as Map<String, dynamic>))
          .toList();
      ListingsCache.write(raw);
    }
    setState(() => _loadingProps = false);
  }

  // _banners calculé dans build() pour réagir aux changements de locale
  void _onNewProperty() => _loadProperties();

  @override
  void initState() {
    super.initState();
    _bannerController = PageController();
    // Précharge les images du hero pour que le fondu soit fluide
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final a in _heroSlideImages) {
        precacheImage(AssetImage(a), context).catchError((_) {});
      }
    });

    _focusNode.addListener(() => setState(() => _isSearchFocused = _focusNode.hasFocus));
    _loadProperties();
    publishedPropertiesNotifier.addListener(_onNewProperty);
    // Reconnaissance vocale désactivée sur mobile (disponible sur Edge/Chrome via IA)
    _speechAvailable = false;

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted || !_autoScrollActive) return false;
      final next = (_currentBannerIndex + 1) % _heroSlideImages.length; // 1 slide d'origine + 5 bannières
      if (mounted) setState(() => _currentBannerIndex = next);
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
    _budgetCtrl.dispose();
    super.dispose();
  }

  List<PropertyModel> get _searchResults {
    final q = _searchQuery.trim();
    if (q.length < 2 && !_heroFilterActive) return [];
    final tokens = q.length >= 2 ? q.toLowerCase().split(RegExp(r'\s+')) : <String>[];
    final cat = _selectedCategoryKey == 'cat_all' ? null : _categoryFilters[_selectedCategoryKey];
    final allProps = _serverProps;
    return allProps.where((p) {
      if (cat != null && p.categorie != cat) return false;
      if (_maxBudget != null && p.prix > _maxBudget!) return false;
      if (tokens.isEmpty) return true;
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
    var allProps = _serverProps;

    // ── Filtre par pays sélectionné ──
    if (_filterCountryCode != null) {
      allProps = allProps.where((p) {
        final pays = p.adresse.pays.toLowerCase();
        return pays == _filterCountryCode!.toLowerCase() ||
            pays == (_filterCountryName ?? '').toLowerCase();
      }).toList();
    }

    // ── Filtre par type de bien (immobilier OU mobilier, jamais les deux) ──
    allProps = allProps.where((p) => p.type == _selectedType).toList();

    if (_selectedCategoryKey == 'cat_all') return allProps;
    final cat = _categoryFilters[_selectedCategoryKey];
    if (cat == null) return allProps;
    return allProps.where((p) => p.categorie == cat).toList();
  }

  bool get _isActiveSearch => _searchQuery.trim().length >= 2 || _heroFilterActive;

  String get _searchLabel =>
      _searchQuery.trim().isEmpty ? 'vos critères' : '"$_searchQuery"';

  void _runHeroSearch() {
    FocusScope.of(context).unfocus();
    final budget = double.tryParse(_budgetCtrl.text.replaceAll(RegExp(r'[^0-9.]'), ''));
    setState(() {
      _searchQuery = _searchCtrl.text;
      _selectedType = PropertyType.immobilier;
      _selectedCategoryKey = _heroCategoryKey;
      _maxBudget = (budget != null && budget > 0) ? budget : null;
      _heroFilterActive = _heroCategoryKey != 'cat_all' || _maxBudget != null;
    });
  }

  // ─── Bandeau « hors connexion » ──────────────────────────────────────────
  Widget _buildOfflineBanner() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: AppTheme.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withOpacity(0.35)),
      ),
      child: Row(children: [
        const Icon(Icons.wifi_off_rounded, size: 18, color: AppTheme.warning),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Hors connexion : dernières annonces enregistrées.',
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textPrimary)),
        ),
        TextButton(
          onPressed: _loadProperties,
          child: Text('Réessayer', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  // ─── Sélecteur Immobilier / Mobilier ─────────────────────────────────────
  Widget _buildTypeToggle() {
    Widget seg(PropertyType type, String label, IconData icon) {
      final sel = _selectedType == type;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() {
            _selectedType = type;
            _selectedCategoryKey = 'cat_all';
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: sel ? AppTheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: sel ? Colors.white : AppTheme.textSecondary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : AppTheme.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        seg(PropertyType.immobilier, tr('add_type_immo'), Icons.home_work_rounded),
        seg(PropertyType.mobilier, tr('add_type_mobilier'), Icons.directions_car_rounded),
      ]),
    );
  }

  // ─── Accès aux démarcheurs et agents d'entretien ─────────────────────────
  Widget _buildStaffEntry() {
    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const StaffDirectoryScreen())),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.support_agent_rounded, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('staff_title'),
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              Text(tr('staff_subtitle'),
                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: AppTheme.textHint),
        ]),
      ),
    );
  }

  // ─── Reconnaissance vocale pour la barre de recherche ────────────────────
  Future<void> _startVoiceSearch() async {
    // Reconnaissance vocale mobile non disponible sans speech_to_text
    // Utiliser le bouton micro dans l'assistant IA à la place
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.mic_off_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text('Utilisez le micro dans VelqIA 🤖',
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
    _budgetCtrl.clear();
    setState(() {
      _searchQuery = '';
      _heroFilterActive = false;
      _maxBudget = null;
      _heroCategoryKey = 'cat_all';
      _selectedCategoryKey = 'cat_all';
    });
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
    final results = _searchResults;

    // « Les plus populaires » (web) / « Coups de cœur » (mobile) : biens
    // immobiliers disponibles les plus consultés, hors annonces mises en avant
    // (affichées dans leur propre section).
    // Les annonces en vedette (mises en avant) s'affichent ici. S'il n'y en a
    // pas encore, on retombe sur les biens les plus consultés.
    final immoDispo = _serverProps
        .where((p) => p.type == PropertyType.immobilier && p.isAvailable)
        .toList();
    final vedettes = immoDispo.where((p) => p.isFeatured).toList()
      ..sort((a, b) => b.vues.compareTo(a.vues));
    final populaires = immoDispo.toList()
      ..sort((a, b) => b.vues.compareTo(a.vues));
    final popularTop = (vedettes.isNotEmpty ? vedettes : populaires).take(8).toList();

    // ✅ Banières recalculées à chaque build → tr() utilise la locale courante
    final banners = [
      _BannerSlide(icon: Icons.home_work_rounded,
        title: tr('banner1_title'), subtitle: tr('banner1_sub'),
        gradient: const [Color(0xFF0F5132), Color(0xFF1B7A4E)],
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExploreScreen()))),
      _BannerSlide(icon: Icons.directions_car_rounded,
        title: tr('banner2_title'), subtitle: tr('banner2_sub'),
        gradient: const [Color(0xFF0A3622), Color(0xFF0F5132)],
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExploreScreen()))),
      _BannerSlide(icon: Icons.verified_user_rounded,
        title: tr('banner3_title'), subtitle: tr('banner3_sub'),
        gradient: const [Color(0xFF0A3622), Color(0xFF1B7A4E)],
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlansScreen()))),
      _BannerSlide(icon: Icons.star_rounded,
        title: tr('banner4_title'), subtitle: tr('banner4_sub'),
        gradient: const [Color(0xFFB8922A), Color(0xFFD4AF37)],
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlansScreen()))),
      _BannerSlide(icon: Icons.add_circle_rounded,
        title: tr('banner5_title'), subtitle: tr('banner5_sub'),
        gradient: const [Color(0xFF1F2937), Color(0xFF374151)],
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddListingScreen()))),
      // Slide d'origine du hero : photo + accroche « logements d'exception »
      _BannerSlide(icon: Icons.home_rounded,
        title: tr('hero_title'), accent: tr('hero_title_accent'), subtitle: tr('hero_sub'),
        gradient: const [Color(0xFF0F5132), Color(0xFF1B7A4E)],
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExploreScreen()))),
    ];

    // En-tête (logo, connexion, pays, notifications) : posé par-dessus le hero
    final headerRow = Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Logo Velqix
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'assets/images/logo.png',
                            height: MediaQuery.of(context).size.width >= 900 ? 64 : 52,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Text('VELQIX',
                                style: GoogleFonts.poppins(
                                    fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                          ),
                        ),
                        const Spacer(),
                        if (MediaQuery.of(context).size.width >= 900 && !AuthService.instance.isLoggedIn) ...[
                          TextButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                            child: Text(tr('hero_nav_login'),
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accent, foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                            ),
                            child: Text(tr('hero_nav_register'),
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 12),
                        ],

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
                    );

    // Contrôles du diaporama du hero (flèches + points), posés sur l'image
    void goTo(int i) => setState(() => _currentBannerIndex = (i + banners.length) % banners.length);
    Widget arrow(IconData ic, VoidCallback f) => InkWell(
          onTap: f,
          customBorder: const CircleBorder(),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
            child: Icon(ic, color: Colors.white, size: 18),
          ),
        );
    final bannerCarousel = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        arrow(Icons.chevron_left_rounded, () => goTo(_currentBannerIndex - 1)),
        const SizedBox(width: 10),
        ...List.generate(banners.length, (i) {
          final active = i == _currentBannerIndex;
          return GestureDetector(
            onTap: () => goTo(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 22 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? AppTheme.accent : Colors.white.withOpacity(0.45),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
        const SizedBox(width: 10),
        arrow(Icons.chevron_right_rounded, () => goTo(_currentBannerIndex + 1)),
      ],
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        top: false, // le hero couvre le haut de l'écran (jusqu'au logo)
        child: CustomScrollView(
          slivers: [

            // ── HERO plein cadre (en-tête par-dessus) + contenu ─────────────
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHero(context, header: headerRow, carousel: bannerCarousel,
                      slide: banners[_currentBannerIndex % banners.length]),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                    if (!_isActiveSearch) ...[
                      const SizedBox(height: 20),
                      Row(children: [
                        _QuickStat(
                            icon: Icons.home_work_rounded,
                            value: '${_serverProps.length}',
                            label: tr('home_annonces')),
                        const SizedBox(width: 10),
                        _QuickStat(
                            icon: Icons.directions_car_rounded,
                            value: '${_serverProps.where((p) => p.type == PropertyType.mobilier).length}',
                            label: tr('home_mobilier')),
                        const SizedBox(width: 10),
                        _QuickStat(
                            icon: Icons.apartment_rounded,
                            value: '${_serverProps.where((p) => p.type == PropertyType.immobilier).length}',
                            label: tr('home_immobilier')),
                      ]),
                    ],
                    const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
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
                              ? 'Aucun résultat pour $_searchLabel'
                              : '${results.length} résultat${results.length > 1 ? 's' : ''} pour $_searchLabel',
                          style: GoogleFonts.poppins(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: results.isEmpty ? AppTheme.error : AppTheme.success,
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    TextButton(onPressed: _clearSearch, child: const Text('Effacer')),
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
                        child: Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textHint),
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

              // ── Nos logements les plus populaires / Nos coups de cœur ──────
              if (popularTop.isNotEmpty) SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SectionHeader(
                        title: MediaQuery.of(context).size.width >= 900
                            ? tr('home_popular')
                            : tr('home_hearts'),
                        actionLabel: tr('home_see_all'),
                        onAction: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const ExploreScreen())),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (MediaQuery.of(context).size.width >= 900)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        // Les cartes s'étirent pour remplir toute la largeur (plus de vide à droite)
                        child: LayoutBuilder(builder: (context, c) {
                          const gap = 18.0;
                          final cols = ((c.maxWidth + gap) / (260 + gap)).floor().clamp(2, 6);
                          final cardW = ((c.maxWidth - gap * (cols - 1)) / cols).floorToDouble();
                          return Wrap(
                            spacing: gap, runSpacing: gap,
                            children: [
                              for (final p in popularTop)
                                SizedBox(
                                  width: cardW, height: 345,
                                  child: PropertyCard(property: p, onTap: () => _openDetail(p)),
                                ),
                            ],
                          );
                        }),
                      )
                    else
                      SizedBox(
                        height: 345,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: popularTop.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 14),
                          itemBuilder: (_, i) => SizedBox(
                            width: 230,
                            child: PropertyCard(property: popularTop[i], onTap: () => _openDetail(popularTop[i])),
                          ),
                        ),
                      ),
                    const SizedBox(height: 28),
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
                    if (_offline) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildOfflineBanner(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildTypeToggle(),
                    ),
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
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildStaffEntry(),
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
                          Icon(Icons.home_outlined, size: 48, color: AppTheme.textHint),
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
                        // Grand écran : autant de colonnes que la largeur le permet, cartes étirées
                        gridDelegate: MediaQuery.of(context).size.width >= 900
                            ? const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 320, crossAxisSpacing: 18,
                                mainAxisSpacing: 18, mainAxisExtent: 345,
                              )
                            : const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2, crossAxisSpacing: 14,
                                mainAxisSpacing: 14, mainAxisExtent: 345,
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

  // ─── Hero : image de fond, accroche et recherche en 3 champs ──────────────
  // Une image par bannière (même ordre que `banners` dans build()) :
  // Même ordre que `banners` dans build()
  static const _heroSlideImages = <String>[
    'assets/images/hero_slide_1.jpg', // terrain  → Louez & Vendez
    'assets/images/hero_slide_2.jpg', // moto     → Voitures, motos & équipements
    'assets/images/hero_slide_4.jpg', // terrasse → Transactions sécurisées
    'assets/images/hero_slide_5.jpg', // hôtel    → Premium
    'assets/images/hero_slide_3.jpg', // voiture  → Publiez votre annonce
    'assets/images/hero.jpg',         // photo d'origine + accroche d'origine (repli en ligne)
  ];

  static const _heroImageUrl =
      'https://images.unsplash.com/photo-1600210492486-724fe5c67fb0?w=1600';

  Widget _heroField({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Row(children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.15), shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: AppTheme.accent),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label.toUpperCase(),
              style: GoogleFonts.poppins(
                  fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF1F2937), letterSpacing: 0.3)),
          child,
        ]),
      ),
    ]);
  }

  Widget _buildHero(BuildContext context, {Widget? header, Widget? carousel, required _BannerSlide slide}) {
    final wide = MediaQuery.of(context).size.width >= 900;
    // Hauteur réservée à l'en-tête posé sur l'image (marge haute + logo + respiration)
    final topInset = MediaQuery.of(context).padding.top;
    final logoH = wide ? 64.0 : 52.0;
    final headerSpace = header == null ? 0.0 : topInset + 16 + logoH + (wide ? 36 : 20);
    const ink = Color(0xFF1F2937);
    const hintColor = Color(0xFF9CA3AF);
    final fieldStyle = GoogleFonts.poppins(fontSize: 13, color: ink);
    final hintStyle = GoogleFonts.poppins(fontSize: 13, color: hintColor);

    final placeField = _heroField(
      icon: Icons.location_on_rounded,
      label: tr('hero_where'),
      child: TextField(
        controller: _searchCtrl,
        focusNode: _focusNode,
        onChanged: (v) => setState(() => _searchQuery = v),
        onSubmitted: (_) => _runHeroSearch(),
        style: fieldStyle,
        decoration: InputDecoration(
          isDense: true,
          hintText: tr('hero_where_hint'),
          hintStyle: hintStyle,
          border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          suffixIcon: _speechAvailable
              ? GestureDetector(
                  onTap: _isListening ? _stopVoiceSearch : _startVoiceSearch,
                  child: Icon(_isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      size: 18, color: _isListening ? AppTheme.error : AppTheme.primary),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ),
    );

    final typeField = _heroField(
      icon: Icons.home_rounded,
      label: tr('hero_type'),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isDense: true,
          isExpanded: true,
          value: _heroCategoryKey,
          dropdownColor: Colors.white,
          style: fieldStyle,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: hintColor),
          items: [
            for (final k in _immoCategoryKeys)
              DropdownMenuItem(
                value: k,
                child: Text(k == 'cat_all' ? tr('hero_type_hint') : tr(k),
                    style: k == 'cat_all' ? hintStyle : fieldStyle, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setState(() => _heroCategoryKey = v ?? 'cat_all'),
        ),
      ),
    );

    final budgetField = _heroField(
      icon: Icons.account_balance_wallet_rounded,
      label: tr('hero_budget'),
      child: TextField(
        controller: _budgetCtrl,
        keyboardType: TextInputType.number,
        onSubmitted: (_) => _runHeroSearch(),
        style: fieldStyle,
        decoration: InputDecoration(
          isDense: true,
          hintText: tr('hero_budget_hint'),
          hintStyle: hintStyle,
          suffixText: 'FCFA',
          suffixStyle: hintStyle,
          border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
        ),
      ),
    );

    final searchBtn = ElevatedButton.icon(
      onPressed: _runHeroSearch,
      icon: const Icon(Icons.search_rounded, size: 18),
      label: Text(tr('hero_search'), style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.accent, foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );

    Widget divider() => Container(
        width: 1, height: 36, margin: const EdgeInsets.symmetric(horizontal: 16),
        color: const Color(0xFFE5E7EB));

    final searchCard = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: wide
          ? Row(children: [
              Expanded(child: placeField), divider(),
              Expanded(child: typeField), divider(),
              Expanded(child: budgetField),
              const SizedBox(width: 16),
              searchBtn,
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              placeField,
              const Divider(height: 18),
              typeField,
              const Divider(height: 18),
              budgetField,
              const SizedBox(height: 12),
              searchBtn,
            ]),
    );

    final titleSize = wide ? 46.0 : 26.0;
    String titleHead(String t) {
      final i = t.trim().lastIndexOf(' ');
      return i <= 0 ? '' : t.trim().substring(0, i);
    }
    String titleAccent(String t) {
      final i = t.trim().lastIndexOf(' ');
      return i <= 0 ? t.trim() : t.trim().substring(i + 1);
    }
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: Stack(children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xFF1A1A1A)),
            // Photo de la maquette : déposez `assets/images/hero.jpg` pour
            // l'utiliser ; à défaut, image en ligne, puis dégradé vert.
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 900),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child: SizedBox.expand(
                key: ValueKey(_currentBannerIndex),
                child: Image.asset(
                  _heroSlideImages[_currentBannerIndex % _heroSlideImages.length],
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => Image.network(_heroImageUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                ),
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft, end: Alignment.centerRight,
                colors: [Color(0xB3000000), Color(0x80000000), Color(0x40000000)], // voile noir neutre (sans teinte verte)
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(wide ? 40 : 18, headerSpace + (header == null ? (wide ? 56 : 28) : 0), wide ? 40 : 18, wide ? 40 : 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            // Texte de la bannière (Annonce, Premium…) : change avec l'image
            SizedBox(
              height: wide ? 250 : 205,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 700),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                layoutBuilder: (cur, prev) => Stack(
                  alignment: Alignment.topLeft,
                  children: [...prev, if (cur != null) cur],
                ),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(anim),
                    child: child,
                  ),
                ),
                child: Column(
                  key: ValueKey('hero_txt_$_currentBannerIndex'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: wide ? 640 : 340),
                      child: RichText(
                        text: TextSpan(children: [
                          TextSpan(
                            text: '${slide.accent == null ? titleHead(slide.title) : slide.title} ',
                            style: GoogleFonts.poppins(
                                fontSize: titleSize, fontWeight: FontWeight.w800, color: Colors.white, height: 1.12),
                          ),
                          TextSpan(
                            text: slide.accent ?? titleAccent(slide.title),
                            style: GoogleFonts.poppins(
                                fontSize: titleSize, fontWeight: FontWeight.w800, color: AppTheme.accent, height: 1.12),
                          ),
                        ]),
                      ),
                    ),
                    SizedBox(height: wide ? 14 : 10),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: wide ? 560 : 340),
                      child: Text(slide.subtitle,
                          style: GoogleFonts.poppins(
                              fontSize: wide ? 16 : 12.5, color: Colors.white.withOpacity(0.92), height: 1.5)),
                    ),
                    SizedBox(height: wide ? 18 : 14),
                    ElevatedButton.icon(
                      onPressed: slide.onTap,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: Text(tr('home_see_all'), style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent, foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: wide ? 22 : 16, vertical: wide ? 14 : 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (carousel != null) ...[
              SizedBox(height: wide ? 12 : 8),
              carousel,
              SizedBox(height: wide ? 24 : 16),
            ],
            searchCard,
          ]),
        ),
        if (header != null)
          Positioned(
            top: topInset + 16, left: 20, right: 20,
            child: header,
          ),
      ]),
    );
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
  final String? accent; // partie du titre en or (sinon : dernier mot)
  final List<Color> gradient;
  final VoidCallback onTap;
  const _BannerSlide({
    required this.icon, required this.title, required this.subtitle, this.accent,
    required this.gradient, required this.onTap,
  });
}

// ─── Carte bannière cliquable ─────────────────────────────────────────────────
class _AdBannerCard extends StatelessWidget {
  final _BannerSlide slide;
  final bool glass; // true = translucide, posée sur l'image du hero
  const _AdBannerCard({required this.slide, this.glass = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: slide.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: glass
                  ? [for (final c in slide.gradient) c.withOpacity(0.82)]
                  : slide.gradient,
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          border: glass ? Border.all(color: Colors.white.withOpacity(0.25)) : null,
          boxShadow: [BoxShadow(
            color: glass ? Colors.black.withOpacity(0.25) : slide.gradient.first.withOpacity(0.35),
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
          Icon(Icons.north_west_rounded, size: 11, color: AppTheme.textHint),
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
