import '../services/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../services/web_file_picker.dart';
import '../widgets/smart_image.dart';
import '../services/auth_service.dart';
import '../widgets/widgets.dart' show kycPendingNotifier, KycEntry;

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});
  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  int _step = 0;
  bool _loading = false;
  String _docType = 'cni';
  final _nomCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _dateNaissCtrl = TextEditingController();
  final _numDocCtrl = TextEditingController();

  // URLs blob des images sélectionnées (pour affichage)
  String? _frontImageUrl;
  String? _backImageUrl;
  String? _selfieImageUrl;

  // Noms des fichiers sélectionnés (pour la validation)
  String? _frontFileName;
  String? _backFileName;
  String? _selfieFileName;

  bool get _frontUploaded => _frontImageUrl != null;
  bool get _backUploaded => _backImageUrl != null;
  bool get _selfieUploaded => _selfieImageUrl != null;

  bool _pickingFront = false;
  bool _pickingBack = false;
  bool _pickingSelfie = false;
  bool _capturingFront = false;
  bool _capturingBack = false;

  final _steps = ['Informations', 'Document', 'Selfie', 'Confirmation'];

  Future<void> _pickFront() async {
    setState(() => _pickingFront = true);
    try {
      final url = await WebFilePicker.pickImage();
      if (url != null && mounted) {
        setState(() {
          _frontImageUrl = url;
          _frontFileName = url.split('/').last.isNotEmpty ? url.split('/').last : 'recto_doc.jpg';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _frontFileName = 'recto_doc.jpg');
    }
    if (mounted) setState(() => _pickingFront = false);
  }

  Future<void> _pickBack() async {
    setState(() => _pickingBack = true);
    try {
      final url = await WebFilePicker.pickImage();
      if (url != null && mounted) {
        setState(() {
          _backImageUrl = url;
          _backFileName = url.split('/').last.isNotEmpty ? url.split('/').last : 'verso_doc.jpg';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _backFileName = 'verso_doc.jpg');
    }
    if (mounted) setState(() => _pickingBack = false);
  }

  Future<void> _captureFront() async {
    setState(() => _capturingFront = true);
    try {
      final url = await WebFilePicker.pickImage(capture: true);
      if (url != null && mounted) {
        setState(() {
          _frontImageUrl = url;
          _frontFileName = 'recto_photo.jpg';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _frontFileName = 'recto_doc.jpg');
    }
    if (mounted) setState(() => _capturingFront = false);
  }

  Future<void> _captureBack() async {
    setState(() => _capturingBack = true);
    try {
      final url = await WebFilePicker.pickImage(capture: true);
      if (url != null && mounted) {
        setState(() {
          _backImageUrl = url;
          _backFileName = 'verso_photo.jpg';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _backFileName = 'verso_doc.jpg');
    }
    if (mounted) setState(() => _capturingBack = false);
  }

  Future<void> _pickSelfie() async {
    setState(() => _pickingSelfie = true);
    try {
      final url = await WebFilePicker.pickImage(capture: true);
      if (url != null && mounted) {
        setState(() {
          _selfieImageUrl = url;
          _selfieFileName = 'selfie.jpg';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _selfieFileName = 'selfie.jpg');
    }
    if (mounted) setState(() => _pickingSelfie = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(title: 'Vérification d\'identité (KYC)'),
      body: Column(
        children: [
          // Step bar
          Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
            child: Row(
              children: List.generate(_steps.length, (i) {
                final done = i < _step;
                final active = i == _step;
                return Expanded(
                  child: Row(
                    children: [
                      Expanded(child: Column(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: done ? AppTheme.success : active ? AppTheme.primary : AppTheme.divider,
                            shape: BoxShape.circle,
                          ),
                          child: Center(child: done
                              ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                              : Text('${i + 1}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white : AppTheme.textHint))),
                        ),
                        const SizedBox(height: 4),
                        Text(_steps[i], style: GoogleFonts.poppins(fontSize: 9, color: active ? AppTheme.primary : done ? AppTheme.success : AppTheme.textHint, fontWeight: active ? FontWeight.w600 : FontWeight.w400), textAlign: TextAlign.center),
                      ])),
                      if (i < _steps.length - 1)
                        Expanded(child: Container(height: 2, color: done ? AppTheme.success : AppTheme.divider, margin: const EdgeInsets.only(bottom: 14))),
                    ],
                  ),
                );
              }),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: [_buildStep0(), _buildStep1(), _buildStep2(), _buildStep3()][_step],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Row(children: [
              if (_step > 0) ...[
                Expanded(child: PrimaryButton(label: 'Précédent', onPressed: () => setState(() => _step--), outline: true)),
                const SizedBox(width: 12),
              ],
              Expanded(child: PrimaryButton(
                label: _step == 3 ? 'Soumettre' : 'Continuer',
                isLoading: _loading,
                icon: _step == 3 ? Icons.verified_user_rounded : Icons.arrow_forward_rounded,
                onPressed: _step == 3 ? _submit : _validateAndNext,
              )),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildStep0() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _InfoBanner(icon: Icons.info_outline_rounded, color: AppTheme.info, message: 'La vérification d\'identité permet de sécuriser les transactions et d\'obtenir le badge ✔️ Vérifié sur votre profil.'),
      const SizedBox(height: 20),
      Text('Informations personnelles', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 14),
      AppTextField(label: 'Nom *', hint: 'Kofi', controller: _nomCtrl, prefixIcon: Icons.person_outline_rounded),
      const SizedBox(height: 12),
      AppTextField(label: 'Prénom *', hint: 'Ama', controller: _prenomCtrl, prefixIcon: Icons.person_outline_rounded),
      const SizedBox(height: 12),
      AppTextField(label: 'Date de naissance *', hint: 'JJ/MM/AAAA', controller: _dateNaissCtrl, prefixIcon: Icons.calendar_today_rounded, readOnly: true,
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: DateTime(1990), firstDate: DateTime(1940), lastDate: DateTime(2005),
                builder: (_, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: AppTheme.primary)), child: child!));
            if (d != null) _dateNaissCtrl.text = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
          }),
    ],
  );

  Widget _buildStep1() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(tr('kyc_doc_type'), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      ...[
        {'value': 'cni', 'label': 'Carte nationale d\'identité', 'icon': Icons.badge_rounded},
        {'value': 'passeport', 'label': 'Passeport', 'icon': Icons.menu_book_rounded},
        {'value': 'permis', 'label': 'Permis de conduire', 'icon': Icons.drive_eta_rounded},
      ].map((doc) => GestureDetector(
        onTap: () => setState(() => _docType = doc['value'] as String),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _docType == doc['value'] ? AppTheme.primary.withOpacity(0.06) : AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _docType == doc['value'] ? AppTheme.primary : AppTheme.border, width: 1.5),
          ),
          child: Row(children: [
            Icon(doc['icon'] as IconData, size: 22, color: _docType == doc['value'] ? AppTheme.primary : AppTheme.textHint),
            const SizedBox(width: 12),
            Text(doc['label'] as String, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: _docType == doc['value'] ? AppTheme.primary : AppTheme.textPrimary)),
            const Spacer(),
            Radio(value: doc['value'], groupValue: _docType, onChanged: (_) => setState(() => _docType = doc['value'] as String), activeColor: AppTheme.primary),
          ]),
        ),
      )),
      const SizedBox(height: 16),
      AppTextField(label: 'Numéro du document *', hint: 'Ex: TG-123456789', controller: _numDocCtrl, prefixIcon: Icons.numbers_rounded),
      const SizedBox(height: 20),
      Text(tr('kyc_photos'), style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _UploadBox(
          label: tr('kyc_recto'),
          uploaded: _frontUploaded,
          imageUrl: _frontImageUrl,
          filename: _frontFileName,
          loading: _pickingFront || _capturingFront,
          onTap: (_pickingFront || _capturingFront) ? null : _pickFront,
          onCamera: (_pickingFront || _capturingFront) ? null : _captureFront,
        )),
        const SizedBox(width: 12),
        Expanded(child: _UploadBox(
          label: tr('kyc_verso'),
          uploaded: _backUploaded,
          imageUrl: _backImageUrl,
          filename: _backFileName,
          loading: _pickingBack || _capturingBack,
          onTap: (_pickingBack || _capturingBack) ? null : _pickBack,
          onCamera: (_pickingBack || _capturingBack) ? null : _captureBack,
        )),
      ]),
    ],
  );

  Widget _buildStep2() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _InfoBanner(icon: Icons.lightbulb_outline_rounded, color: AppTheme.accent, message: 'Prenez un selfie dans un endroit bien éclairé en tenant votre document d\'identité visible.'),
      const SizedBox(height: 20),
      Text(tr('kyc_selfie'), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 14),
      Center(
        child: GestureDetector(
          onTap: _pickingSelfie ? null : _pickSelfie,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 200, height: 200,
            decoration: BoxDecoration(
              color: _selfieUploaded
                  ? AppTheme.success.withOpacity(0.1)
                  : AppTheme.primary.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(
                  color: _selfieUploaded ? AppTheme.success : AppTheme.primary,
                  width: 2),
            ),
            child: _pickingSelfie
                ? const Center(child: SizedBox(width: 32, height: 32,
                    child: CircularProgressIndicator(strokeWidth: 2)))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _selfieUploaded ? Icons.check_circle_rounded : Icons.camera_alt_rounded,
                        size: 50,
                        color: _selfieUploaded ? AppTheme.success : AppTheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selfieUploaded ? 'Selfie ajouté ✔' : 'Prendre un selfie',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: _selfieUploaded ? AppTheme.success : AppTheme.primary,
                            fontWeight: FontWeight.w600),
                      ),
                      if (_selfieFileName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _selfieFileName!,
                          style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textHint),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
      const SizedBox(height: 20),
      ...[
        '👁️ Visage entièrement visible',
        '💡 Bonne luminosité',
        '📄 Document lisible et bien tenu',
        '🚫 Pas de lunettes de soleil',
      ].map((tip) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Text(tip.substring(0, 2), style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Text(tip.substring(3), style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
        ]),
      )),
    ],
  );

  Widget _buildStep3() => Column(
    children: [
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.08), shape: BoxShape.circle),
        child: const Icon(Icons.verified_user_rounded, size: 60, color: AppTheme.success),
      ),
      const SizedBox(height: 20),
      Text(tr('kyc_recap'), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Vérifiez vos informations avant de soumettre.', style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary), textAlign: TextAlign.center),
      const SizedBox(height: 24),
      _SummaryItem(label: 'Nom complet', value: '${_prenomCtrl.text.isNotEmpty ? _prenomCtrl.text : "Ama"} ${_nomCtrl.text.isNotEmpty ? _nomCtrl.text : "Kofi"}'),
      _SummaryItem(label: 'Date de naissance', value: _dateNaissCtrl.text.isNotEmpty ? _dateNaissCtrl.text : '01/01/1990'),
      _SummaryItem(label: 'Type de document', value: _docType == 'cni' ? 'Carte nationale d\'identité' : _docType == 'passeport' ? 'Passeport' : 'Permis de conduire'),
      _SummaryItem(label: 'Numéro du document', value: _numDocCtrl.text.isNotEmpty ? _numDocCtrl.text : 'TG-123456789'),
      _SummaryItem(label: 'Recto', value: _frontUploaded ? '✅ Téléchargé' : '❌ Manquant', valueColor: _frontUploaded ? AppTheme.success : AppTheme.error),
      _SummaryItem(label: 'Verso', value: _backUploaded ? '✅ Téléchargé' : '❌ Manquant', valueColor: _backUploaded ? AppTheme.success : AppTheme.error),
      _SummaryItem(label: 'Selfie', value: _selfieUploaded ? '✅ Téléchargé' : '❌ Manquant', valueColor: _selfieUploaded ? AppTheme.success : AppTheme.error),
      const SizedBox(height: 16),
      _InfoBanner(icon: Icons.schedule_rounded, color: AppTheme.info, message: 'Votre dossier sera examiné dans un délai de 24 à 48h. Vous recevrez une notification dès la validation.'),
    ],
  );

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: GoogleFonts.poppins(color: Colors.white, fontSize: 13))),
      ]),
      backgroundColor: AppTheme.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  void _validateAndNext() {
    if (_step == 0) {
      // Étape 1 : Informations personnelles
      if (_nomCtrl.text.trim().isEmpty) {
        _showValidationError('Le nom est obligatoire.');
        return;
      }
      if (_prenomCtrl.text.trim().isEmpty) {
        _showValidationError('Le prénom est obligatoire.');
        return;
      }
      if (_dateNaissCtrl.text.trim().isEmpty) {
        _showValidationError('La date de naissance est obligatoire.');
        return;
      }
    } else if (_step == 1) {
      // Étape 2 : Document
      if (_numDocCtrl.text.trim().isEmpty) {
        _showValidationError('Le numéro du document est obligatoire.');
        return;
      }
      if (!_frontUploaded) {
        _showValidationError('Veuillez télécharger le recto de votre document.');
        return;
      }
      if (!_backUploaded) {
        _showValidationError('Veuillez télécharger le verso de votre document.');
        return;
      }
    } else if (_step == 2) {
      // Étape 3 : Selfie
      if (!_selfieUploaded) {
        _showValidationError('Veuillez prendre un selfie avec votre document.');
        return;
      }
    }
    // Tout est valide → passer à l'étape suivante
    setState(() => _step++);
  }

  void _submit() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _loading = false);

    // ✅ Enregistrer dans la file KYC admin
    final user = AuthService.instance.currentUser;
    final docLabel = _docType == 'cni'
        ? 'CNI'
        : _docType == 'passeport'
            ? 'Passeport'
            : 'Permis';
    final entry = KycEntry(
      userId: user?.id ?? 'unknown',
      nom: _nomCtrl.text.trim(),
      prenom: _prenomCtrl.text.trim(),
      docType: docLabel,
      numDoc: _numDocCtrl.text.trim(),
      soumisLabel: 'À l\'instant',
      soumisAt: DateTime.now(),
    );
    // Éviter les doublons (même userId)
    kycPendingNotifier.value = [
      ...kycPendingNotifier.value.where((e) => e.userId != entry.userId),
      entry,
    ];

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_rounded, size: 50, color: AppTheme.success)),
              const SizedBox(height: 20),
              Text(tr('kyc_done'), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Votre demande de vérification a bien été reçue. Vous serez notifié sous 24-48h.', style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              PrimaryButton(label: tr('kyc_understood'), onPressed: () { Navigator.pop(context); Navigator.pop(context); }),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  const _InfoBanner({required this.icon, required this.color, required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.2))),
    child: Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: GoogleFonts.poppins(fontSize: 12, color: color, height: 1.4))),
    ]),
  );
}

class _UploadBox extends StatelessWidget {
  final String label;
  final bool uploaded;
  final String? imageUrl;
  final String? filename;
  final bool loading;
  final VoidCallback? onTap;
  final VoidCallback? onCamera;
  const _UploadBox({
    required this.label,
    required this.uploaded,
    this.imageUrl,
    this.filename,
    this.loading = false,
    this.onTap,
    this.onCamera,
  });

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    decoration: BoxDecoration(
      color: uploaded
          ? AppTheme.success.withOpacity(0.07)
          : AppTheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: uploaded ? AppTheme.success : AppTheme.border,
      ),
    ),
    child: loading
        ? const SizedBox(
            height: 110,
            child: Center(child: SizedBox(width: 28, height: 28,
                child: CircularProgressIndicator(strokeWidth: 2))))
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top section: image preview OR icon + label
              if (uploaded && imageUrl != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                      child: SmartImage(
                              src: imageUrl!,
                              height: 90,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 90,
                                color: AppTheme.success.withOpacity(0.1),
                                child: const Icon(Icons.broken_image_outlined, color: AppTheme.success),
                              ),
                            ),
                    ),
                    Positioned(
                      top: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                      ),
                    ),
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.zero),
                        ),
                        child: Text(
                          label,
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
                  child: Column(children: [
                    Icon(
                      uploaded ? Icons.check_circle_rounded : Icons.image_outlined,
                      size: 28,
                      color: uploaded ? AppTheme.success : AppTheme.textHint,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: uploaded ? AppTheme.success : AppTheme.textSecondary),
                    ),
                    if (filename != null) ...[
                      const SizedBox(height: 2),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          filename!,
                          style: GoogleFonts.poppins(fontSize: 9, color: AppTheme.textHint),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ]),
                ),
              // Bottom action buttons
              if (!uploaded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                  child: Row(children: [
                    // Galerie button
                    Expanded(
                      child: GestureDetector(
                        onTap: onTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                          ),
                          child: Column(children: [
                            Icon(Icons.upload_file_rounded, size: 16, color: AppTheme.primary),
                            const SizedBox(height: 2),
                            Text(tr('kyc_gallery'), style: GoogleFonts.poppins(fontSize: 9, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Caméra button
                    Expanded(
                      child: GestureDetector(
                        onTap: onCamera,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                          ),
                          child: Column(children: [
                            Icon(Icons.camera_alt_rounded, size: 16, color: AppTheme.accent),
                            const SizedBox(height: 2),
                            Text(tr('kyc_camera'), style: GoogleFonts.poppins(fontSize: 9, color: AppTheme.accent, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                    ),
                  ]),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                  child: GestureDetector(
                    onTap: onTap,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.success.withOpacity(0.2)),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.refresh_rounded, size: 14, color: AppTheme.success),
                        const SizedBox(width: 4),
                        Text(tr('kyc_change'), style: GoogleFonts.poppins(fontSize: 9, color: AppTheme.success, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ),
            ],
          ),
  );
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _SummaryItem({required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
    child: Row(children: [
      Text(label, style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
      const Spacer(),
      Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor ?? AppTheme.textPrimary)),
    ]),
  );
}
