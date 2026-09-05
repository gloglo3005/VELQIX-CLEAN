import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/property_service.dart';
import '../theme/app_theme.dart';
import 'property_detail_screen.dart';

/// Point d'entrée des liens partagés (ex: https://velqix.vercel.app/bien/xyz).
/// Accessible sans connexion : charge le bien correspondant puis affiche la
/// fiche complète (PropertyDetailScreen gère déjà l'usage anonyme). Si le
/// bien n'existe plus / id invalide, affiche un message clair avec un moyen
/// de rejoindre l'app plutôt qu'un écran blanc ou une erreur brute.
class SharedPropertyScreen extends StatefulWidget {
  final String propertyId;
  const SharedPropertyScreen({super.key, required this.propertyId});

  @override
  State<SharedPropertyScreen> createState() => _SharedPropertyScreenState();
}

class _SharedPropertyScreenState extends State<SharedPropertyScreen> {
  PropertyModel? _property;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final property = await PropertyService.instance.getProperty(widget.propertyId);
    if (mounted) setState(() { _property = property; _loading = false; });
  }

  void _goToApp() {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_property == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textHint),
              const SizedBox(height: 16),
              Text('Cette annonce est introuvable ou n\'est plus disponible.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _goToApp,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                child: Text('Découvrir VelQix',
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ),
      );
    }

    // Bandeau discret rappelant qu'on est sur un lien partagé, avec un accès
    // direct au reste de l'app (recherche, connexion, etc.).
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(children: [
        SafeArea(
          bottom: false,
          child: Material(
            color: AppTheme.primary,
            child: InkWell(
              onTap: _goToApp,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  const Icon(Icons.home_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Voir toutes les annonces sur VelQix',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                ]),
              ),
            ),
          ),
        ),
        Expanded(child: PropertyDetailScreen(property: _property!)),
      ]),
    );
  }
}