import 'package:flutter/material.dart';
import '../services/app_translations.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart'; // NEW : appel réel au backend
import '../services/property_service.dart'; // NEW : upload d'images en multipart
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../services/web_file_picker.dart';
import '../widgets/smart_image.dart';

class AddListingScreen extends StatefulWidget {
  const AddListingScreen({super.key});
  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _titreCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _prixCtrl  = TextEditingController();
  final _villeCtrl = TextEditingController();
  final _rueCtrl   = TextEditingController();

  PropertyType     _type        = PropertyType.immobilier;
  ListingType      _listingType = ListingType.location;
  PropertyCategory _category    = PropertyCategory.appartement;
  bool _loading       = false;
  int  _currentStep   = 0;

  final List<String> _selectedPhotos = [];
  final List<String> _selectedVideos = [];
  bool _pickingPhotos  = false;
  bool _pickingVideo   = false;
  bool _showPhotoError = false;

  final _immoCats = [
    PropertyCategory.maison, PropertyCategory.appartement,
    PropertyCategory.terrain, PropertyCategory.bureau,
    PropertyCategory.entrepot, PropertyCategory.autre,
  ];
  final _mobilCats = [
    PropertyCategory.voiture, PropertyCategory.moto,
    PropertyCategory.camion, PropertyCategory.equipement,
    PropertyCategory.autre,
  ];

  List<PropertyCategory> get _currentCats =>
      _type == PropertyType.immobilier ? _immoCats : _mobilCats;

  // ✅ Clés de traduction (résolues dynamiquement via tr())
  Map<PropertyCategory, String> get catLabels => {
    PropertyCategory.maison:      tr('add_cat_maison'),
    PropertyCategory.appartement: tr('add_cat_appartement'),
    PropertyCategory.terrain:     tr('add_cat_terrain'),
    PropertyCategory.bureau:      tr('add_cat_bureau'),
    PropertyCategory.entrepot:    tr('add_cat_entrepot'),
    PropertyCategory.voiture:     tr('add_cat_voiture'),
    PropertyCategory.moto:        tr('add_cat_moto'),
    PropertyCategory.camion:      tr('add_cat_camion'),
    PropertyCategory.equipement:  tr('add_cat_equipement'),
    PropertyCategory.autre:       tr('add_cat_autre'),
  };

  // ─── Galerie ────────────────────────────────────────────────────────────────
  Future<void> _pickPhotos() async {
    if (_selectedPhotos.length >= 2) { _showMaxSnack(); return; }
    setState(() => _pickingPhotos = true);
    try {
      final files = await WebFilePicker.pickMultipleImages(maxCount: 2 - _selectedPhotos.length);
      if (files.isNotEmpty && mounted) {
        setState(() { _selectedPhotos.addAll(files); _showPhotoError = false; });
      }
    } catch (e) {
      debugPrint('Erreur sélection photos : $e');
    }
    if (mounted) setState(() => _pickingPhotos = false);
  }

  // ─── Caméra ─────────────────────────────────────────────────────────────────
  Future<void> _takePhoto() async {
    if (_selectedPhotos.length >= 2) { _showMaxSnack(); return; }
    setState(() => _pickingPhotos = true);
    try {
      // capture=true => ouvre UNIQUEMENT l'appareil photo (jamais la galerie)
      final file = await WebFilePicker.pickImage(capture: true);
      if (file != null && mounted) {
        setState(() { _selectedPhotos.add(file); _showPhotoError = false; });
      }
    } catch (_) {
      // Erreur silencieuse — ne pas fallback sur la galerie
      if (mounted) debugPrint('Erreur ouverture caméra');
    }
    if (mounted) setState(() => _pickingPhotos = false);
  }

  // ─── Vidéo depuis caméra ────────────────────────────────────────────────────
  Future<void> _recordVideo() async {
    setState(() => _pickingVideo = true);
    try {
      final file = await WebFilePicker.pickVideo(capture: true);
      if (file != null && mounted) {
        setState(() { _selectedVideos.add(file); });
      }
    } catch (_) {
      if (mounted) debugPrint('Erreur enregistrement vidéo');
    }
    if (mounted) setState(() => _pickingVideo = false);
  }

  // ─── Vidéo depuis galerie ────────────────────────────────────────────────────
  Future<void> _pickVideo() async {
    setState(() => _pickingVideo = true);
    try {
      final file = await WebFilePicker.pickVideo(capture: false);
      if (file != null && mounted) {
        setState(() { _selectedVideos.add(file); });
      }
    } catch (_) {
      if (mounted) debugPrint('Erreur sélection vidéo');
    }
    if (mounted) setState(() => _pickingVideo = false);
  }

  // ─── Menu choix photo/vidéo ─────────────────────────────────────────────────
  Future<void> _showCameraMenu() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Caméra', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _CameraMenuBtn(
                    icon: Icons.camera_alt_rounded,
                    label: 'Photo',
                    color: const Color(0xFF0EA5E9),
                    onTap: () { Navigator.pop(context); _takePhoto(); },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CameraMenuBtn(
                    icon: Icons.videocam_rounded,
                    label: 'Vidéo',
                    color: const Color(0xFFEF4444),
                    onTap: () { Navigator.pop(context); _recordVideo(); },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showMaxSnack() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(tr('add_photos_max'), style: GoogleFonts.poppins(color: Colors.white)),
      backgroundColor: AppTheme.warning,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─── Validation par étape ────────────────────────────────────────────────────
  bool _validateStep() {
    switch (_currentStep) {
      case 0: return true; // type/catégorie toujours sélectionnés
      case 1:
        final formOk  = _formKey.currentState?.validate() ?? false;
        final photoOk = _selectedPhotos.isNotEmpty;
        if (!photoOk) setState(() => _showPhotoError = true);
        return formOk && photoOk;
      case 2:
        return _formKey.currentState?.validate() ?? false;
      default: return true;
    }
  }

  void _nextOrSubmit() {
    if (!_validateStep()) return;
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _submit();
    }
  }

  // ─── Upload d'une data URI base64 → URL Cloudinary ──────────────────────────
  /// Les photos web arrivent en "data:image/jpeg;base64,...". On ne peut pas
  /// les envoyer telles quelles dans le JSON de /properties (trop volumineux,
  /// provoque une erreur 413 côté serveur). On les upload d'abord en
  /// multipart via /upload/image, et on récupère une URL Cloudinary courte.
  /// Sur mobile, la photo est un chemin de fichier local : même traitement.
  Future<String?> _uploadDataUri(String dataUri, int index) async {
    try {
      final bytes = await WebFilePicker.readBytes(dataUri);
      if (bytes == null) return null;
      final ext = WebFilePicker.imageSubtype(dataUri);
      final result = await PropertyService.instance.uploadImageBytes(
        bytes,
        'photo_$index.${ext == 'jpeg' ? 'jpg' : ext}',
      );
      return result.url;
    } catch (e) {
      debugPrint('Erreur upload photo $index : $e');
      return null;
    }
  }

  // ─── Soumission réelle au backend ───────────────────────────────────────────
  void _submit() async {
    if (!_validateStep()) return;
    setState(() => _loading = true);

    final prix = double.tryParse(
          _prixCtrl.text.replaceAll(' ', '').replaceAll(',', '.'),
        ) ??
        0;

    // ── Étape 1 : uploader chaque photo (base64 → Cloudinary) avant le JSON ──
    final List<String> uploadedImages = [];
    for (var i = 0; i < _selectedPhotos.length; i++) {
      final photo = _selectedPhotos[i];
      if (photo.startsWith('http://') || photo.startsWith('https://')) {
        uploadedImages.add(photo);
      } else {
        final url = await _uploadDataUri(photo, i);
        if (url != null) uploadedImages.add(url);
      }
    }

    if (!mounted) return;
    if (_selectedPhotos.isNotEmpty && uploadedImages.isEmpty) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Échec de l\'envoi des photos. Réessaie.'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
      return;
    }

    final images = uploadedImages.isNotEmpty
        ? uploadedImages
        : [_categoryImageUrl(_category)];

    // ── Étape 2 : créer l'annonce avec les URLs (légères) au lieu du base64 ──
    final res = await ApiService.instance.post(
      '/properties',
      {
        'titre': _titreCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'prix': prix,
        'images': images,
        'type': _type.name,
        'listingType': _listingType.name,
        'categorie': _category.name,
        'adresse': _rueCtrl.text.trim(),
        'ville': _villeCtrl.text.trim(),
        'pays': AuthService.instance.currentUserOrEmpty.countryName ?? 'Togo',
      },
      auth: true,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (res['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? 'Erreur lors de la soumission de l\'annonce'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    // Le backend a créé l'annonce et notifié l'admin (Socket.io + email).
    // On construit aussi un PropertyModel local pour un affichage optimiste
    // immédiat côté "Mes annonces" si l'écran l'utilise déjà ainsi.
    final data = res['data'] as Map<String, dynamic>;
    final newProperty = PropertyModel.fromJson(data);
    pendingPropertiesNotifier.value = [...pendingPropertiesNotifier.value, newProperty];

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(
          'Annonce soumise ! En attente de validation par l\'administration.',
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
        )),
      ]),
      backgroundColor: AppTheme.warning,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 4),
    ));
    Navigator.pop(context);
  }

  String _categoryImageUrl(PropertyCategory cat) {
    const imgs = {
      PropertyCategory.maison:      'https://images.unsplash.com/photo-1570129477492-45c003edd2be?w=800',
      PropertyCategory.appartement: 'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800',
      PropertyCategory.terrain:     'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=800',
      PropertyCategory.bureau:      'https://images.unsplash.com/photo-1497366216548-37526070297c?w=800',
      PropertyCategory.entrepot:    'https://images.unsplash.com/photo-1553413077-190dd305871c?w=800',
      PropertyCategory.voiture:     'https://images.unsplash.com/photo-1549317661-bd32c8ce0db2?w=800',
      PropertyCategory.moto:        'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800',
      PropertyCategory.camion:      'https://images.unsplash.com/photo-1601584115197-04ecc0da31d7?w=800',
      PropertyCategory.equipement:  'https://images.unsplash.com/photo-1581094794329-c8112a89af12?w=800',
      PropertyCategory.autre:       'https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=800',
    };
    return imgs[cat] ?? imgs[PropertyCategory.autre]!;
  }

  // ─── UI ──────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(title: tr('add_title')),
      body: Column(children: [
        // Barre de progression
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(children: List.generate(3, (i) => Expanded(
            child: Row(children: [
              Expanded(child: Container(height: 4,
                  decoration: BoxDecoration(
                    color: i <= _currentStep ? AppTheme.primary : AppTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ))),
              if (i < 2) const SizedBox(width: 4),
            ]),
          ))),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _stepLabel('Type', 0),
            _stepLabel(tr('add_step_details'), 1),
            _stepLabel(tr('add_step_price'), 2),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: [_buildStep1(), _buildStep2(), _buildStep3()][_currentStep],
            ),
          ),
        ),
        // Navigation
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Row(children: [
            if (_currentStep > 0) ...[
              Expanded(child: PrimaryButton(label: tr('add_prev'), onPressed: () => setState(() => _currentStep--), outline: true)),
              const SizedBox(width: 12),
            ],
            Expanded(child: PrimaryButton(
              label: _currentStep == 2 ? tr('add_publish') : tr('add_next'),
              isLoading: _loading,
              icon: _currentStep == 2 ? Icons.publish_rounded : null,
              onPressed: _nextOrSubmit,
            )),
          ]),
        ),
      ]),
    );
  }

  Widget _stepLabel(String label, int step) {
    final active = step == _currentStep;
    final done   = step < _currentStep;
    return Text(label, style: GoogleFonts.poppins(
      fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w400,
      color: active ? AppTheme.primary : done ? AppTheme.success : AppTheme.textHint,
    ));
  }

  // ── Étape 1 ───────────────────────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr('add_property_type'), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _TypeCard(label: tr('add_type_immo'), icon: Icons.home_work_rounded,
            value: PropertyType.immobilier, selected: _type,
            onTap: (v) => setState(() { _type = v; _category = _immoCats.first; }))),
        const SizedBox(width: 12),
        Expanded(child: _TypeCard(label: tr('add_type_mobilier'), icon: Icons.directions_car_rounded,
            value: PropertyType.mobilier, selected: _type,
            onTap: (v) => setState(() { _type = v; _category = _mobilCats.first; }))),
      ]),
      const SizedBox(height: 24),
      Text(tr('add_category'), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8,
        children: _currentCats.map((c) => GestureDetector(
          onTap: () => setState(() => _category = c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _category == c ? AppTheme.primary : AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _category == c ? AppTheme.primary : AppTheme.border),
            ),
            child: Text(catLabels[c]!, style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w500,
              color: _category == c ? Colors.white : AppTheme.textSecondary,
            )),
          ),
        )).toList(),
      ),
      const SizedBox(height: 24),
      Text(tr('add_listing_type'), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      Column(children: [
        _ListingTypeOption(label: tr('add_lt_location'), subtitle: tr('add_lt_location_sub'),   icon: Icons.key_rounded,        value: ListingType.location,  selected: _listingType, onTap: (v) => setState(() => _listingType = v)),
        const SizedBox(height: 8),
        _ListingTypeOption(label: tr('add_lt_vente'), subtitle: tr('add_lt_vente_sub'),  icon: Icons.sell_rounded,       value: ListingType.vente,     selected: _listingType, onTap: (v) => setState(() => _listingType = v)),
        const SizedBox(height: 8),
        _ListingTypeOption(label: tr('add_lt_les_deux'), subtitle: tr('add_lt_les_deux_sub'), icon: Icons.swap_horiz_rounded, value: ListingType.les_deux,  selected: _listingType, onTap: (v) => setState(() => _listingType = v)),
      ]),
    ]);
  }

  // ── Étape 2 ───────────────────────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr('add_info_title'), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      AppTextField(
        label: tr('add_field_titre'),
        hint: 'Ex: Villa moderne avec piscine',
        controller: _titreCtrl,
        prefixIcon: Icons.title_rounded,
        maxLength: 30,
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Le titre est obligatoire';
          if (v.trim().length < 5) return 'Minimum 5 caractères';
          if (v.trim().length > 30) return 'Maximum 30 caractères';
          return null;
        },
      ),
      const SizedBox(height: 14),
      AppTextField(
        label: tr('add_field_desc'),
        hint: 'Décrivez votre bien en détail...',
        controller: _descCtrl,
        maxLines: 5,
        maxLength: 255,
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'La description est obligatoire';
          if (v.trim().length < 20) return 'Minimum 20 caractères';
          if (v.trim().length > 255) return 'Maximum 255 caractères';
          return null;
        },
      ),
      const SizedBox(height: 20),
      // ── Photos ──────────────────────────────────────────────────────────
      Row(children: [
        Row(children: [
          Text(tr('add_photos'), style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(tr('add_photos_required'), style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.error, fontWeight: FontWeight.w600)),
          ),
        ]),
        const Spacer(),
        Text('${_selectedPhotos.length}/2',
            style: GoogleFonts.poppins(fontSize: 12,
                color: _selectedPhotos.isEmpty && _showPhotoError ? AppTheme.error : AppTheme.textSecondary,
                fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10, runSpacing: 10,
        children: [
          ..._selectedPhotos.asMap().entries.map((e) => _PhotoThumb(
            filename: e.value,
            onRemove: () => setState(() => _selectedPhotos.removeAt(e.key)),
          )),
          if (_selectedPhotos.length < 2) ...[
            // Bouton Galerie
            _MediaButton(
              icon: Icons.add_photo_alternate_rounded,
              label: tr('add_photos_gallery'),
              loading: _pickingPhotos,
              color: AppTheme.primary,
              onTap: _pickingPhotos ? null : _pickPhotos,
            ),
            // Bouton Caméra (photo OU vidéo)
            _MediaButton(
              icon: Icons.camera_alt_rounded,
              label: tr('add_photos_camera'),
              loading: _pickingPhotos || _pickingVideo,
              color: const Color(0xFF0EA5E9),
              onTap: (_pickingPhotos || _pickingVideo) ? null : _takePhoto,
            ),
          ],
        ],
      ),
      if (_showPhotoError && _selectedPhotos.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            const Icon(Icons.error_outline_rounded, size: 14, color: AppTheme.error),
            const SizedBox(width: 5),
            Text(tr('add_photos_hint'),
                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.error, fontWeight: FontWeight.w600)),
          ]),
        )
      else if (_selectedPhotos.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, size: 13, color: AppTheme.textHint),
            const SizedBox(width: 5),
            Text(tr('detail_add_listing_hint'),
                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint)),
          ]),
        ),

      const SizedBox(height: 20),

      // ── Vidéo (optionnelle) ────────────────────────────────────────────
      Row(children: [
        Text('Vidéo', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.textHint.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('Optionnel', style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textHint, fontWeight: FontWeight.w600)),
        ),
        const Spacer(),
        Text('${_selectedVideos.length}/1',
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10, runSpacing: 10,
        children: [
          ..._selectedVideos.asMap().entries.map((e) => _VideoThumb(
            filename: e.value,
            onRemove: () => setState(() => _selectedVideos.removeAt(e.key)),
          )),
          if (_selectedVideos.isEmpty) ...[
            _MediaButton(
              icon: Icons.videocam_rounded,
              label: 'Enregistrer',
              loading: _pickingVideo,
              color: const Color(0xFFEF4444),
              onTap: _pickingVideo ? null : _recordVideo,
            ),
            _MediaButton(
              icon: Icons.video_library_rounded,
              label: 'Galerie',
              loading: _pickingVideo,
              color: const Color(0xFF8B5CF6),
              onTap: _pickingVideo ? null : _pickVideo,
            ),
          ],
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, size: 13, color: AppTheme.textHint),
          const SizedBox(width: 5),
          Text('Une vidéo améliore la visibilité de votre annonce',
              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint)),
        ]),
      ),
    ]);
  }

  // ── Étape 3 ───────────────────────────────────────────────────────────────
  Widget _buildStep3() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr('add_field_prix'), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      AppTextField(
        label: tr('add_field_prix_label'),
        hint: 'Ex: 250 000',
        controller: _prixCtrl,
        prefixIcon: Icons.payments_rounded,
        keyboardType: TextInputType.number,
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Le prix est obligatoire';
          final n = double.tryParse(v.replaceAll(' ', '').replaceAll(',', '.'));
          if (n == null || n <= 0) return 'Entrez un prix valide (ex: 250000)';
          return null;
        },
      ),
      const SizedBox(height: 24),
      Text(tr('add_location_title'), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      AppTextField(
        label: tr('add_field_ville'),
        hint: 'Ex: Lomé',
        controller: _villeCtrl,
        prefixIcon: Icons.location_city_rounded,
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'La ville est obligatoire';
          return null;
        },
      ),
      const SizedBox(height: 12),
      AppTextField(
        label: tr('add_field_rue'),
        hint: 'Ex: Boulevard du 13 Janvier',
        controller: _rueCtrl,
        prefixIcon: Icons.place_rounded,
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Le quartier / rue est obligatoire';
          return null;
        },
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.info.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.info.withOpacity(0.2)),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, color: AppTheme.info, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(
            'Après publication, votre annonce sera examinée par notre équipe avant d\'être publiée (délai : 24h max).',
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.info),
          )),
        ]),
      ),
    ]);
  }
}

// ─── Bouton média (galerie / caméra) ─────────────────────────────────────────
class _MediaButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool loading;
  final Color color;
  final VoidCallback? onTap;
  const _MediaButton({required this.icon, required this.label, required this.loading, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 90, height: 90,
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: loading
            ? Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: color)))
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 28, color: color.withOpacity(0.85)),
                const SizedBox(height: 5),
                Text(label, style: GoogleFonts.poppins(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
              ]),
      ),
    );
  }
}

// ─── Miniature photo ─────────────────────────────────────────────────────────
class _PhotoThumb extends StatelessWidget {
  final String filename;
  final VoidCallback onRemove;
  const _PhotoThumb({required this.filename, required this.onRemove});

  bool get _isCam => filename.startsWith('camera_');
  // Les Object URLs commencent par "blob:" — on peut les afficher directement
  bool get _hasPreview => SmartImage.canDisplay(filename);

  @override
  Widget build(BuildContext context) {
    final color = _isCam ? const Color(0xFF0EA5E9) : AppTheme.primary;
    return SizedBox(width: 90, height: 90,
      child: Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(width: 90, height: 90,
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: _hasPreview
                ? SmartImage(
                    src: filename,
                    fit: BoxFit.cover,
                    width: 90,
                    height: 90,
                    errorBuilder: (_, __, ___) => _iconFallback(color),
                  )
                : _iconFallback(color),
          ),
        ),
        Positioned(top: 4, right: 4,
          child: GestureDetector(onTap: onRemove,
            child: Container(width: 20, height: 20,
              decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, size: 12, color: Colors.white)))),
        Positioned(bottom: 4, right: 4,
          child: Container(padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, size: 10, color: Colors.white))),
      ]),
    );
  }

  Widget _iconFallback(Color color) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(_isCam ? Icons.camera_alt_rounded : Icons.image_rounded, size: 28, color: color),
    const SizedBox(height: 4),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(filename.length > 12 ? '${filename.substring(0,10)}…' : filename,
          style: GoogleFonts.poppins(fontSize: 9, color: color),
          textAlign: TextAlign.center, maxLines: 2)),
  ]);
}

// ─── Type Card ────────────────────────────────────────────────────────────────
class _TypeCard extends StatelessWidget {
  final String label; final IconData icon; final PropertyType value;
  final PropertyType selected; final Function(PropertyType) onTap;
  const _TypeCard({required this.label, required this.icon, required this.value, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final s = value == selected;
    return GestureDetector(onTap: () => onTap(value),
      child: AnimatedContainer(duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: s ? AppTheme.primary.withOpacity(0.08) : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: s ? AppTheme.primary : AppTheme.border, width: 2),
        ),
        child: Column(children: [
          Icon(icon, size: 32, color: s ? AppTheme.primary : AppTheme.textHint),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600,
              color: s ? AppTheme.primary : AppTheme.textSecondary)),
        ]),
      ),
    );
  }
}

// ─── Listing Type Option ──────────────────────────────────────────────────────
class _ListingTypeOption extends StatelessWidget {
  final String label, subtitle; final IconData icon;
  final ListingType value, selected; final Function(ListingType) onTap;
  const _ListingTypeOption({required this.label, required this.subtitle, required this.icon, required this.value, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final s = value == selected;
    return GestureDetector(onTap: () => onTap(value),
      child: AnimatedContainer(duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: s ? AppTheme.primary.withOpacity(0.06) : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: s ? AppTheme.primary : AppTheme.border, width: 1.5),
        ),
        child: Row(children: [
          Icon(icon, size: 22, color: s ? AppTheme.primary : AppTheme.textHint),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: s ? AppTheme.primary : AppTheme.textPrimary)),
            Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
          ])),
          Radio(value: value, groupValue: selected, onChanged: (_) => onTap(value), activeColor: AppTheme.primary),
        ]),
      ),
    );
  }
}

// ─── Miniature vidéo avec preview ────────────────────────────────────────────
class _VideoThumb extends StatefulWidget {
  final String filename;
  final VoidCallback onRemove;
  const _VideoThumb({required this.filename, required this.onRemove});
  @override
  State<_VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<_VideoThumb> {
  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFEF4444);
    return SizedBox(width: 90, height: 90,
      child: Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(width: 90, height: 90,
              decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.35))),
              child: const Icon(Icons.videocam_rounded, size: 32, color: color)),
        ),
        // Label
        Positioned(bottom: 8, left: 0, right: 0,
          child: Text('Vidéo', textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 10, color: color, fontWeight: FontWeight.w600))),
        // Bouton supprimer
        Positioned(top: 4, right: 4,
          child: GestureDetector(onTap: widget.onRemove,
            child: Container(width: 20, height: 20,
              decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, size: 12, color: Colors.white)))),
        // Badge succès
        Positioned(bottom: 4, left: 4,
          child: Container(padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, size: 10, color: Colors.white))),
      ]),
    );
  }
}

// ─── Bouton menu caméra ───────────────────────────────────────────────────────
class _CameraMenuBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CameraMenuBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(height: 10),
          Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }
}