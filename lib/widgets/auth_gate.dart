// lib/widgets/auth_gate.dart
// Mode invité : l'app est utilisable sans compte (voir les annonces, explorer).
// La connexion n'est demandée que pour les actions qui en ont besoin
// (publier, écrire à un propriétaire, favoris, profil…).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/auth_screens.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'widgets.dart' show PrimaryButton, userStateNotifier;

/// Retourne true si l'utilisateur est connecté. Sinon affiche une feuille
/// « Connexion requise » ; après une connexion réussie, toute la pile de
/// navigation est remplacée (l'ancien écran n'existe plus → on retourne false
/// et l'appelant ne fait rien de plus).
Future<bool> requireLogin(BuildContext context, {String? reason}) async {
  if (AuthService.instance.isLoggedIn) return true;

  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.lock_outline_rounded, color: AppTheme.primary, size: 30),
          ),
          const SizedBox(height: 14),
          Text('Connexion requise',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            reason == null
                ? 'Connectez-vous ou créez un compte gratuit pour continuer.'
                : 'Connectez-vous ou créez un compte gratuit pour $reason.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          PrimaryButton(label: 'Se connecter', onPressed: () => Navigator.pop(ctx, 'login')),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'register'),
              child: const Text('Créer un compte'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Plus tard',
                style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
          ),
        ]),
      ),
    ),
  );

  if (choice == null || !context.mounted) return false;
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => choice == 'register' ? const RegisterScreen() : const LoginScreen(),
  ));
  return AuthService.instance.isLoggedIn && context.mounted;
}

/// Affiche [child] pour un utilisateur connecté, sinon un écran d'invitation à
/// se connecter. Réagit tout seul aux connexions / déconnexions.
class AuthGuard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget child;
  const AuthGuard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: userStateNotifier,
      builder: (context, _, __) => AuthService.instance.isLoggedIn
          ? child
          : GuestPlaceholder(icon: icon, title: title, message: message),
    );
  }
}

class GuestPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const GuestPlaceholder({super.key, required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: AppTheme.primary, size: 44),
              ),
              const SizedBox(height: 20),
              Text(title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Se connecter',
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const LoginScreen())),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  child: const Text('Créer un compte'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
