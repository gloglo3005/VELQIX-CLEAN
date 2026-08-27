import 'package:flutter/material.dart';
import '../services/app_translations.dart';
import '../main.dart' show localeNotifier;
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
// import '../services/mock_data.dart'; // 🚫 DÉSACTIVÉ (25/08/2026) : plus de biens factices
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'property_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _search = '';
  String _sortBy = 'recent';
  RangeValues _priceRange = const RangeValues(0, 50000000);
  bool _onlyAvailable = true;
  String? _filterCountryCode;
  String? _filterCountryName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // ✅ Écoute les approbations admin en temps réel
    publishedPropertiesNotifier.addListener(_onPublished);
  }

  @override
  void dispose() {
    publishedPropertiesNotifier.removeListener(_onPublished);
    _tabController.dispose();
    super.dispose();
  }

  void _onPublished() {
    if (mounted) setState(() {});
  }

  List<PropertyModel> get _filtered {
    // ⚠️ Avant : combinait des biens factices (MockDataService) avec les
    // vrais biens approuvés, en permanence, pour tous les utilisateurs.
    final all = publishedPropertiesNotifier.value.cast<PropertyModel>();
    var list = all.where((p) {
      final matchSearch = _search.isEmpty ||
          p.titre.toLowerCase().contains(_search.toLowerCase()) ||
          p.adresse.ville.toLowerCase().contains(_search.toLowerCase()) ||
          p.categorieLabel.toLowerCase().contains(_search.toLowerCase());
      final matchAvailable = !_onlyAvailable || p.isAvailable;
      final matchPrice = p.prix >= _priceRange.start && p.prix <= _priceRange.end;
      final matchCountry = _filterCountryCode == null ||
          p.adresse.pays.toLowerCase() == (_filterCountryName ?? '').toLowerCase();
      bool matchTab = true;
      if (_tabController.index == 1) matchTab = p.type == PropertyType.immobilier;
      if (_tabController.index == 2) matchTab = p.type == PropertyType.mobilier;
      return matchSearch && matchAvailable && matchPrice && matchTab && matchCountry;
    }).toList();

    switch (_sortBy) {
      case 'prix_asc': list.sort((a, b) => a.prix.compareTo(b.prix));
      case 'prix_desc': list.sort((a, b) => b.prix.compareTo(a.prix));
      case 'note': list.sort((a, b) => b.rating.compareTo(a.rating));
      default: list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: localeNotifier,
      builder: (context, _, __) =>
    Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('explore_title'), style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w800, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
                  const SizedBox(height: 14),
                  // Search
                  Container(
                    decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)]),
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: tr('explore_search_hint'),
                        hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textHint),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textHint),
                        suffixIcon: GestureDetector(
                          onTap: _showFilters,
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.tune_rounded, size: 18, color: AppTheme.primary),
                          ),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Sort
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _SortChip(label: tr('explore_sort_recent'), value: 'recent', selected: _sortBy, onTap: (v) => setState(() => _sortBy = v)),
                        _SortChip(label: tr('explore_sort_price_asc'), value: 'prix_asc', selected: _sortBy, onTap: (v) => setState(() => _sortBy = v)),
                        _SortChip(label: tr('explore_sort_price_desc'), value: 'prix_desc', selected: _sortBy, onTap: (v) => setState(() => _sortBy = v)),
                        _SortChip(label: tr('explore_sort_rating'), value: 'note', selected: _sortBy, onTap: (v) => setState(() => _sortBy = v)),
                        // ── Chip pays actif ──
                        if (_filterCountryCode != null)
                          GestureDetector(
                            onTap: () => setState(() { _filterCountryCode = null; _filterCountryName = null; }),
                            child: Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_getFlag(_filterCountryCode!), style: const TextStyle(fontSize: 13)),
                                  const SizedBox(width: 5),
                                  Text(_filterCountryName ?? '', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white)),
                                  const SizedBox(width: 5),
                                  const Icon(Icons.close_rounded, size: 13, color: Colors.white),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Tabs
                  TabBar(
                    controller: _tabController,
                    onTap: (_) => setState(() {}),
                    labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
                    labelColor: AppTheme.primary,
                    unselectedLabelColor: AppTheme.textSecondary,
                    indicatorColor: AppTheme.primary,
                    indicatorWeight: 3,
                    tabs: [Tab(text: tr('explore_tab_all')), Tab(text: tr('explore_tab_immo')), Tab(text: tr('explore_tab_mobilier'))],
                  ),
                ],
              ),
            ),

            // Results
            Expanded(
              child: _filtered.isEmpty
                  ? EmptyState(
                      icon: Icons.search_off_rounded,
                      title: tr('explore_no_result'),
                      subtitle: tr('explore_no_result_sub'),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                          child: Row(children: [
                            Text("${_filtered.length} ${_filtered.length > 1 ? tr('explore_results_pl') : tr('explore_results')}",
                                style: GoogleFonts.poppins(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                            if (_filterCountryCode != null) ...[
                              const SizedBox(width: 6),
                              Text('· ${_getFlag(_filterCountryCode!)} ${_filterCountryName ?? ''}',
                                  style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                            ],
                          ]),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (_, i) => PropertyCard(
                              property: _filtered[i],
                              horizontal: true,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PropertyDetailScreen(property: _filtered[i]))),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    ));
  }

  // ─── Emoji drapeau depuis code ISO ─────────────────────────────────────────
  String _getFlag(String code) {
    return code.toUpperCase().runes.map((r) => String.fromCharCode(r + 127397)).join();
  }

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
    {'code': 'DK', 'name': 'Danemark'}, {'code': 'FI', 'name': 'Finlande'},
    {'code': 'PL', 'name': 'Pologne'}, {'code': 'UA', 'name': 'Ukraine'},
    {'code': 'QA', 'name': 'Qatar'}, {'code': 'KW', 'name': 'Koweït'},
    {'code': 'SG', 'name': 'Singapour'}, {'code': 'MY', 'name': 'Malaisie'},
    {'code': 'ID', 'name': 'Indonésie'}, {'code': 'TH', 'name': 'Thaïlande'},
    {'code': 'VN', 'name': 'Viêt Nam'}, {'code': 'PH', 'name': 'Philippines'},
    {'code': 'KR', 'name': 'Corée du Sud'}, {'code': 'PK', 'name': 'Pakistan'},
    {'code': 'BD', 'name': 'Bangladesh'}, {'code': 'MR', 'name': 'Mauritanie'},
    {'code': 'GN', 'name': 'Guinée'}, {'code': 'GW', 'name': 'Guinée-Bissau'},
    {'code': 'GQ', 'name': 'Guinée équatoriale'}, {'code': 'SL', 'name': 'Sierra Leone'},
    {'code': 'LR', 'name': 'Libéria'}, {'code': 'SO', 'name': 'Somalie'},
    {'code': 'SD', 'name': 'Soudan'}, {'code': 'SS', 'name': 'Soudan du Sud'},
    {'code': 'CF', 'name': 'Rép. centrafricaine'}, {'code': 'TD', 'name': 'Tchad'},
    {'code': 'MG', 'name': 'Madagascar'}, {'code': 'MZ', 'name': 'Mozambique'},
    {'code': 'ZM', 'name': 'Zambie'}, {'code': 'ZW', 'name': 'Zimbabwe'},
    {'code': 'MW', 'name': 'Malawi'}, {'code': 'NA', 'name': 'Namibie'},
    {'code': 'BW', 'name': 'Botswana'}, {'code': 'LS', 'name': 'Lesotho'},
    {'code': 'SZ', 'name': 'Eswatini'}, {'code': 'SC', 'name': 'Seychelles'},
    {'code': 'MU', 'name': 'Maurice'}, {'code': 'CV', 'name': 'Cap-Vert'},
    {'code': 'KM', 'name': 'Comores'}, {'code': 'ST', 'name': 'Sao Tomé-et-Principe'},
    {'code': 'DJ', 'name': 'Djibouti'}, {'code': 'ER', 'name': 'Érythrée'},
    {'code': 'UG', 'name': 'Ouganda'}, {'code': 'BI', 'name': 'Burundi'},
    {'code': 'AO', 'name': 'Angola'}, {'code': 'GM', 'name': 'Gambie'},
  ];

  void _showCountryFilterPicker() {
    final searchCtrl = TextEditingController();
    List<Map<String, String>> filtered = List.from(_allCountries);

    showModalBottomSheet(
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
                    Text(tr('explore_filter_country'), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary)),
                    const Spacer(),
                    if (_filterCountryCode != null)
                      TextButton(
                        onPressed: () { setState(() { _filterCountryCode = null; _filterCountryName = null; }); Navigator.pop(ctx); },
                        child: Text(tr('explore_all_countries'), style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600)),
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
                    hintText: tr('explore_search_country'),
                    hintStyle: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textHint),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textHint),
                    filled: true, fillColor: AppTheme.surface,
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
                    final isSel = _filterCountryCode == c['code'];
                    return ListTile(
                      leading: Text(_getFlag(c['code']!), style: const TextStyle(fontSize: 28)),
                      title: Text(c['name']!, style: GoogleFonts.poppins(fontSize: 14, fontWeight: isSel ? FontWeight.w600 : FontWeight.w400, color: isSel ? AppTheme.primary : AppTheme.textPrimary)),
                      trailing: isSel ? Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20) : null,
                      onTap: () {
                        setState(() { _filterCountryCode = c['code']; _filterCountryName = c['name']; });
                        Navigator.pop(ctx);
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

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(tr('explore_filters'), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            Text(tr('explore_price_range'), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            RangeSlider(
              values: _priceRange,
              min: 0, max: 50000000,
              divisions: 100,
              activeColor: AppTheme.primary,
              labels: RangeLabels(formatFcfa(_priceRange.start), formatFcfa(_priceRange.end)),
              onChanged: (v) => setState(() => _priceRange = v),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(formatFcfa(_priceRange.start), style: GoogleFonts.poppins(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary)),
              Text(formatFcfa(_priceRange.end), style: GoogleFonts.poppins(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Text(tr('explore_available_only'), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
              const Spacer(),
              Switch(value: _onlyAvailable, onChanged: (v) => setState(() => _onlyAvailable = v), activeColor: AppTheme.primary),
            ]),
            const SizedBox(height: 16),
            Text(tr('explore_country'), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () { Navigator.pop(context); _showCountryFilterPicker(); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _filterCountryCode != null ? AppTheme.primary : AppTheme.border, width: _filterCountryCode != null ? 1.5 : 1),
                ),
                child: Row(
                  children: [
                    if (_filterCountryCode != null) ...[
                      Text(_getFlag(_filterCountryCode!), style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_filterCountryName ?? '', style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.primary, fontWeight: FontWeight.w600))),
                    ] else ...[
                      const Text('🌍', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(tr('explore_all_countries_label'), style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textHint))),
                    ],
                    Icon(Icons.keyboard_arrow_right_rounded, color: AppTheme.textHint),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: tr('explore_apply_filters'),
              onPressed: () { Navigator.pop(context); setState(() {}); },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final Function(String) onTap;
  const _SortChip({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.border),
        ),
        child: Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: isSelected ? Colors.white : AppTheme.textSecondary)),
      ),
    );
  }
}