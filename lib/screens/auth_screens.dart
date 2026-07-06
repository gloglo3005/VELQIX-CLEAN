import '../services/app_translations.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../theme/app_theme.dart';
import '../main.dart' show localeNotifier, countryCodeToLocale;
import '../widgets/widgets.dart';
import 'legal_screen.dart';
import '../services/auth_service.dart';
import 'main_shell.dart';
import 'admin_dashboard_screen.dart';

// ─── Onboarding ───────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  final _pages = [
    _OnboardPage(
      icon: Icons.home_work_rounded,
      color: AppTheme.primary,
      title: 'Louez ou vendez\nen toute simplicité',
      subtitle: 'VelQix vous connecte propriétaires et acheteurs/locataires pour des transactions sécurisées.',
      bgColor: const Color(0xFFE8F0FE),
    ),
    _OnboardPage(
      icon: Icons.directions_car_filled_rounded,
      color: const Color(0xFF1B5E20),
      title: 'Biens mobiliers\net immobiliers',
      subtitle: 'Voitures, équipements, maisons, appartements… Publiez et trouvez tout sur une seule plateforme.',
      bgColor: const Color(0xFFE8F5E9),
    ),
    _OnboardPage(
      icon: Icons.mobile_friendly_rounded,
      color: AppTheme.accent,
      title: 'Paiement Mobile\nMoney inclus',
      subtitle: 'Transactions rapides et sécurisées via Mobile Money, carte bancaire ou PayPal.',
      bgColor: const Color(0xFFFFF3E0),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: TextButton(
                  onPressed: _goToLogin,
                  child: Text('Passer', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 14)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => _buildPage(_pages[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: i == _currentPage ? 24 : 8,
                      decoration: BoxDecoration(
                        color: i == _currentPage ? AppTheme.primary : AppTheme.divider,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )),
                  ),
                  const SizedBox(height: 28),
                  _currentPage == _pages.length - 1
                      ? PrimaryButton(label: 'Commencer', icon: Icons.arrow_forward_rounded, onPressed: _goToLogin)
                      : PrimaryButton(label: 'Suivant', icon: Icons.arrow_forward_rounded, onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)),
                  const SizedBox(height: 12),
                  if (_currentPage == _pages.length - 1)
                    PrimaryButton(label: 'J\'ai déjà un compte', onPressed: _goToLogin, outline: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 180, height: 180,
              decoration: BoxDecoration(color: page.bgColor, shape: BoxShape.circle),
              child: Icon(page.icon, size: 80, color: page.color),
            ),
            const SizedBox(height: 40),
            Text(page.title, style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, height: 1.25), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text(page.subtitle, style: GoogleFonts.poppins(fontSize: 15, color: AppTheme.textSecondary, height: 1.6), textAlign: TextAlign.center),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _goToLogin() => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
}

class _OnboardPage {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Color bgColor;
  const _OnboardPage({required this.icon, required this.color, required this.title, required this.subtitle, required this.bgColor});
}

// ─── Login Screen ─────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _login() async {
    final username = _usernameCtrl.text.trim();
    final password = _passCtrl.text;

    if (username.isEmpty || password.isEmpty) {
      _showError('Veuillez remplir tous les champs.');
      return;
    }

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _loading = false);

    final error = await AuthService.instance.login(username: username, password: password);
    if (error != null) {
      _showError(error);
      return;
    }

    // ✅ CORRECTIF Bug 2 : appliquer la locale du pays de l'utilisateur après login
    // Sans ça, localeNotifier reste 'fr' même si l'utilisateur est portugais/espagnol/etc.
    localeNotifier.value = countryCodeToLocale(
      AuthService.instance.currentUserOrEmpty.countryCode,
    );

    // ✅ Redirige admin vers le dashboard, utilisateur normal vers MainShell
    final dest = AuthService.instance.currentUserOrEmpty.role == 'admin'
        ? const AdminDashboardScreen()
        : MainShell(username: AuthService.instance.loggedUsername);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => dest));
  }

  // ─── Google Sign-In ──────────────────────────────────────────────────────
  void _loginWithGoogle() async {
    setState(() => _loading = true);
    final error = await AuthService.instance.loginWithGoogle();
    if (!mounted) return;

    // Effacer tout SnackBar résiduel
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() => _loading = false);

    // Si erreur annulation → afficher et stop
    if (error != null && error.contains('annulée')) {
      _showError(error);
      return;
    }

    // Si connecté → naviguer
    if (AuthService.instance.isLoggedIn) {
      localeNotifier.value = countryCodeToLocale(AuthService.instance.currentUserOrEmpty.countryCode);
      final dest = AuthService.instance.currentUserOrEmpty.role == 'admin'
          ? const AdminDashboardScreen()
          : MainShell(username: AuthService.instance.loggedUsername);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => dest));
      return;
    }

    // Dernier recours : vérifier encore après un bref délai (Android)
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    if (AuthService.instance.isLoggedIn) {
      final dest = AuthService.instance.currentUserOrEmpty.role == 'admin'
          ? const AdminDashboardScreen()
          : MainShell(username: AuthService.instance.loggedUsername);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => dest));
    }
  }

  // ─── Facebook Login ───────────────────────────────────────────────────────
  void _loginWithFacebook() async {
    // Sur web, Facebook Auth n'est pas disponible sans SDK JS
    // Afficher un message informatif
    setState(() => _loading = true);
    final error = await AuthService.instance.loginWithFacebook();
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      if (error.contains('non disponible sur le web')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text("Facebook disponible uniquement sur l'app mobile.",
                style: TextStyle(color: Colors.white, fontSize: 13))),
          ]),
          backgroundColor: const Color(0xFF1877F2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ));
        return;
      }
      _showError(error); return;
    }

    // ✅ CORRECTIF : locale après Facebook login
    localeNotifier.value = countryCodeToLocale(AuthService.instance.currentUserOrEmpty.countryCode);

    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => MainShell(username: AuthService.instance.loggedUsername),
    ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: GoogleFonts.poppins(color: Colors.white, fontSize: 13))),
      ]),
      backgroundColor: AppTheme.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      width: 110,
                      height: 110,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 8),
                    Text('Louez. Achetez. Gérez.', style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Text('Connexion', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              Text('Bienvenue ! Connectez-vous à votre compte.', style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 28),
              AppTextField(
                label: "Nom d'utilisateur",
                hint: 'ama_kofi',
                controller: _usernameCtrl,
                prefixIcon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: tr('auth_password'),
                hint: '••••••••',
                controller: _passCtrl,
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscure,
                suffix: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: AppTheme.textHint),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())), child: Text('Mot de passe oublié ?', style: GoogleFonts.poppins(fontSize: 13))),
              ),
              const SizedBox(height: 8),
              PrimaryButton(label: 'Se connecter', isLoading: _loading, onPressed: _login),
              const SizedBox(height: 20),
              Row(children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('ou', style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
                ),
                const Expanded(child: Divider()),
              ]),
              const SizedBox(height: 20),
              _SocialButton(provider: 'google', onTap: _loginWithGoogle),
              const SizedBox(height: 12),
              _SocialButton(provider: 'facebook', onTap: _loginWithFacebook),
              const SizedBox(height: 28),
              Center(
                child: RichText(
                  text: TextSpan(
                    text: 'Pas encore de compte ? ',
                    style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary),
                    children: [
                      WidgetSpan(child: GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                        child: Text("S'inscrire", style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                      )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String provider; // 'google' ou 'facebook'
  final VoidCallback onTap;
  const _SocialButton({required this.provider, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isGoogle = provider == 'google';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
        decoration: BoxDecoration(
          color: isGoogle ? Colors.white : const Color(0xFF1877F2),
          borderRadius: BorderRadius.circular(14),
          border: isGoogle ? Border.all(color: const Color(0xFFDADCE0), width: 1.5) : null,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isGoogle ? 0.10 : 0.07), blurRadius: isGoogle ? 8 : 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isGoogle) ...[
              _GoogleIcon(),
              const SizedBox(width: 10),
              Text(tr('auth_google'),
                  style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w500,
                      color: const Color(0xFF3C4043))),
            ] else ...[
              _FacebookIcon(),
              const SizedBox(width: 10),
              Text(tr('auth_facebook'),
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Icône Google officielle ──────────────────────────────────────────────────
class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22, height: 22,
      child: CustomPaint(painter: _GoogleSvgPainter()),
    );
  }
}

class _GoogleSvgPainter extends CustomPainter {
  static const double _deg = 3.14159265358979 / 180.0;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // Rayon extérieur et épaisseur du trait du "G"
    final outerR = w * 0.46;
    final thickness = w * 0.30;
    final innerR = outerR - thickness;

    // Dessine un segment d'anneau coloré
    void arc(Color color, double startDeg, double sweepDeg) {
      final start = startDeg * _deg;
      final sweep = sweepDeg * _deg;
      final outer = Rect.fromCircle(center: Offset(cx, cy), radius: outerR);
      final inner = Rect.fromCircle(center: Offset(cx, cy), radius: innerR);
      final path = Path()
        ..arcTo(outer, start, sweep, false)
        ..arcTo(inner, start + sweep, -sweep, false)
        ..close();
      canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill..isAntiAlias = true);
    }

    // Angles exacts du logo Google G
    arc(const Color(0xFFEA4335), -90, 150);  // Rouge  : haut → droite-bas
    arc(const Color(0xFFFBBC05),  60,  30);  // Jaune  : petit segment bas-droite
    arc(const Color(0xFF34A853),  90, 120);  // Vert   : bas → gauche
    arc(const Color(0xFF4285F4), 210,  60);  // Bleu   : gauche → haut-gauche
    arc(const Color(0xFFEA4335), 270,  60);  // Rouge  : haut-gauche → haut (fermeture)

    // Barre horizontale bleue (la traverse du "G")
    final barH = thickness;
    final barTop    = cy - barH / 2;
    final barBottom = cy + barH / 2;
    // D'abord effacer la zone avec du blanc
    canvas.drawRect(
      Rect.fromLTRB(cx, barTop, cx + outerR + 1, barBottom),
      Paint()..color = Colors.white..style = PaintingStyle.fill,
    );
    // Puis dessiner la barre bleue seulement sur la moitié droite de l'anneau
    canvas.drawRect(
      Rect.fromLTRB(cx, barTop, cx + outerR + 1, barBottom),
      Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill..isAntiAlias = true,
    );

    // Trou blanc central
    canvas.drawCircle(
      Offset(cx, cy), innerR,
      Paint()..color = Colors.white..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── Icône Facebook ───────────────────────────────────────────────────────────
class _FacebookIcon extends StatelessWidget {
  const _FacebookIcon();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22, height: 22,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: const Text('f',
          style: TextStyle(
            color: Color(0xFF1877F2),
            fontSize: 16,
            fontWeight: FontWeight.w900,
            fontFamily: 'Georgia',
            height: 1.15,
          )),
    );
  }
}

// ─── Register Screen ──────────────────────────────────────────────────────────
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _adresseCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  bool _acceptTerms = false;

  // ─── Type de compte ───────────────────────────────────────────────────────
  String _accountType = 'personal'; // 'personal' | 'business'
  final _nomEntrepriseCtrl = TextEditingController();
  String? _selectedTypeActivite;

  static const List<String> _typesActivite = [
    'Agence immobilière',
    'Promoteur immobilier',
    'Constructeur / BTP',
    'Location de véhicules',
    'Location d\'équipements',
    'Commerce général',
    'Hôtellerie / Tourisme',
    'Autre',
  ];

  // ─── Pays sélectionné ────────────────────────────────────────────────────────
  String? _selectedCountryCode;
  String? _selectedCountryName;

  // ─── Helper drapeau depuis code ISO ─────────────────────────────────────────
  String _getFlag(String code) {
    if (code.length != 2) return '🌍';
    return code.toUpperCase().runes.map((r) => String.fromCharCode(r + 127397)).join();
  }

  // ─── Liste complète des pays du monde (code ISO 2 lettres + nom) ─────────
  static const List<Map<String, String>> _worldCountries = [
    {'code': 'AF', 'name': 'Afghanistan'},
    {'code': 'ZA', 'name': 'Afrique du Sud'},
    {'code': 'AL', 'name': 'Albanie'},
    {'code': 'DZ', 'name': 'Algérie'},
    {'code': 'DE', 'name': 'Allemagne'},
    {'code': 'AD', 'name': 'Andorre'},
    {'code': 'AO', 'name': 'Angola'},
    {'code': 'AG', 'name': 'Antigua-et-Barbuda'},
    {'code': 'SA', 'name': 'Arabie Saoudite'},
    {'code': 'AR', 'name': 'Argentine'},
    {'code': 'AM', 'name': 'Arménie'},
    {'code': 'AU', 'name': 'Australie'},
    {'code': 'AT', 'name': 'Autriche'},
    {'code': 'AZ', 'name': 'Azerbaïdjan'},
    {'code': 'BS', 'name': 'Bahamas'},
    {'code': 'BH', 'name': 'Bahreïn'},
    {'code': 'BD', 'name': 'Bangladesh'},
    {'code': 'BB', 'name': 'Barbade'},
    {'code': 'BY', 'name': 'Biélorussie'},
    {'code': 'BE', 'name': 'Belgique'},
    {'code': 'BZ', 'name': 'Belize'},
    {'code': 'BJ', 'name': 'Bénin'},
    {'code': 'BT', 'name': 'Bhoutan'},
    {'code': 'BO', 'name': 'Bolivie'},
    {'code': 'BA', 'name': 'Bosnie-Herzégovine'},
    {'code': 'BW', 'name': 'Botswana'},
    {'code': 'BR', 'name': 'Brésil'},
    {'code': 'BN', 'name': 'Brunei'},
    {'code': 'BG', 'name': 'Bulgarie'},
    {'code': 'BF', 'name': 'Burkina Faso'},
    {'code': 'BI', 'name': 'Burundi'},
    {'code': 'CV', 'name': 'Cap-Vert'},
    {'code': 'KH', 'name': 'Cambodge'},
    {'code': 'CM', 'name': 'Cameroun'},
    {'code': 'CA', 'name': 'Canada'},
    {'code': 'CF', 'name': 'République centrafricaine'},
    {'code': 'CL', 'name': 'Chili'},
    {'code': 'CN', 'name': 'Chine'},
    {'code': 'CY', 'name': 'Chypre'},
    {'code': 'CO', 'name': 'Colombie'},
    {'code': 'KM', 'name': 'Comores'},
    {'code': 'CG', 'name': 'Congo'},
    {'code': 'CD', 'name': 'Congo (RDC)'},
    {'code': 'KP', 'name': 'Corée du Nord'},
    {'code': 'KR', 'name': 'Corée du Sud'},
    {'code': 'CR', 'name': 'Costa Rica'},
    {'code': 'HR', 'name': 'Croatie'},
    {'code': 'CU', 'name': 'Cuba'},
    {'code': 'CI', 'name': "Côte d'Ivoire"},
    {'code': 'DK', 'name': 'Danemark'},
    {'code': 'DJ', 'name': 'Djibouti'},
    {'code': 'DM', 'name': 'Dominique'},
    {'code': 'EG', 'name': 'Égypte'},
    {'code': 'AE', 'name': 'Émirats arabes unis'},
    {'code': 'EC', 'name': 'Équateur'},
    {'code': 'ER', 'name': 'Érythrée'},
    {'code': 'ES', 'name': 'Espagne'},
    {'code': 'EE', 'name': 'Estonie'},
    {'code': 'SZ', 'name': 'Eswatini'},
    {'code': 'ET', 'name': 'Éthiopie'},
    {'code': 'FJ', 'name': 'Fidji'},
    {'code': 'FI', 'name': 'Finlande'},
    {'code': 'FR', 'name': 'France'},
    {'code': 'GA', 'name': 'Gabon'},
    {'code': 'GM', 'name': 'Gambie'},
    {'code': 'GE', 'name': 'Géorgie'},
    {'code': 'GH', 'name': 'Ghana'},
    {'code': 'GR', 'name': 'Grèce'},
    {'code': 'GD', 'name': 'Grenade'},
    {'code': 'GT', 'name': 'Guatemala'},
    {'code': 'GN', 'name': 'Guinée'},
    {'code': 'GW', 'name': 'Guinée-Bissau'},
    {'code': 'GQ', 'name': 'Guinée équatoriale'},
    {'code': 'GY', 'name': 'Guyana'},
    {'code': 'HT', 'name': 'Haïti'},
    {'code': 'HN', 'name': 'Honduras'},
    {'code': 'HU', 'name': 'Hongrie'},
    {'code': 'IN', 'name': 'Inde'},
    {'code': 'ID', 'name': 'Indonésie'},
    {'code': 'IR', 'name': 'Iran'},
    {'code': 'IQ', 'name': 'Irak'},
    {'code': 'IE', 'name': 'Irlande'},
    {'code': 'IS', 'name': 'Islande'},
    {'code': 'IL', 'name': 'Israël'},
    {'code': 'IT', 'name': 'Italie'},
    {'code': 'JM', 'name': 'Jamaïque'},
    {'code': 'JP', 'name': 'Japon'},
    {'code': 'JO', 'name': 'Jordanie'},
    {'code': 'KZ', 'name': 'Kazakhstan'},
    {'code': 'KE', 'name': 'Kenya'},
    {'code': 'KG', 'name': 'Kirghizistan'},
    {'code': 'KI', 'name': 'Kiribati'},
    {'code': 'KW', 'name': 'Koweït'},
    {'code': 'LA', 'name': 'Laos'},
    {'code': 'LS', 'name': 'Lesotho'},
    {'code': 'LV', 'name': 'Lettonie'},
    {'code': 'LB', 'name': 'Liban'},
    {'code': 'LR', 'name': 'Libéria'},
    {'code': 'LY', 'name': 'Libye'},
    {'code': 'LI', 'name': 'Liechtenstein'},
    {'code': 'LT', 'name': 'Lituanie'},
    {'code': 'LU', 'name': 'Luxembourg'},
    {'code': 'MK', 'name': 'Macédoine du Nord'},
    {'code': 'MG', 'name': 'Madagascar'},
    {'code': 'MY', 'name': 'Malaisie'},
    {'code': 'MW', 'name': 'Malawi'},
    {'code': 'MV', 'name': 'Maldives'},
    {'code': 'ML', 'name': 'Mali'},
    {'code': 'MT', 'name': 'Malte'},
    {'code': 'MA', 'name': 'Maroc'},
    {'code': 'MH', 'name': 'Marshall'},
    {'code': 'MU', 'name': 'Maurice'},
    {'code': 'MR', 'name': 'Mauritanie'},
    {'code': 'MX', 'name': 'Mexique'},
    {'code': 'FM', 'name': 'Micronésie'},
    {'code': 'MD', 'name': 'Moldavie'},
    {'code': 'MC', 'name': 'Monaco'},
    {'code': 'MN', 'name': 'Mongolie'},
    {'code': 'ME', 'name': 'Monténégro'},
    {'code': 'MZ', 'name': 'Mozambique'},
    {'code': 'MM', 'name': 'Myanmar'},
    {'code': 'NA', 'name': 'Namibie'},
    {'code': 'NR', 'name': 'Nauru'},
    {'code': 'NP', 'name': 'Népal'},
    {'code': 'NI', 'name': 'Nicaragua'},
    {'code': 'NE', 'name': 'Niger'},
    {'code': 'NG', 'name': 'Nigeria'},
    {'code': 'NO', 'name': 'Norvège'},
    {'code': 'NZ', 'name': 'Nouvelle-Zélande'},
    {'code': 'OM', 'name': 'Oman'},
    {'code': 'UG', 'name': 'Ouganda'},
    {'code': 'UZ', 'name': 'Ouzbékistan'},
    {'code': 'PK', 'name': 'Pakistan'},
    {'code': 'PW', 'name': 'Palaos'},
    {'code': 'PA', 'name': 'Panama'},
    {'code': 'PG', 'name': 'Papouasie-Nouvelle-Guinée'},
    {'code': 'PY', 'name': 'Paraguay'},
    {'code': 'NL', 'name': 'Pays-Bas'},
    {'code': 'PE', 'name': 'Pérou'},
    {'code': 'PH', 'name': 'Philippines'},
    {'code': 'PL', 'name': 'Pologne'},
    {'code': 'PT', 'name': 'Portugal'},
    {'code': 'QA', 'name': 'Qatar'},
    {'code': 'RO', 'name': 'Roumanie'},
    {'code': 'GB', 'name': 'Royaume-Uni'},
    {'code': 'RU', 'name': 'Russie'},
    {'code': 'RW', 'name': 'Rwanda'},
    {'code': 'KN', 'name': 'Saint-Kitts-et-Nevis'},
    {'code': 'LC', 'name': 'Sainte-Lucie'},
    {'code': 'VC', 'name': 'Saint-Vincent-et-les-Grenadines'},
    {'code': 'SB', 'name': 'Salomon'},
    {'code': 'SV', 'name': 'Salvador'},
    {'code': 'WS', 'name': 'Samoa'},
    {'code': 'SM', 'name': 'Saint-Marin'},
    {'code': 'ST', 'name': 'Sao Tomé-et-Principe'},
    {'code': 'SN', 'name': 'Sénégal'},
    {'code': 'RS', 'name': 'Serbie'},
    {'code': 'SC', 'name': 'Seychelles'},
    {'code': 'SL', 'name': 'Sierra Leone'},
    {'code': 'SG', 'name': 'Singapour'},
    {'code': 'SK', 'name': 'Slovaquie'},
    {'code': 'SI', 'name': 'Slovénie'},
    {'code': 'SO', 'name': 'Somalie'},
    {'code': 'SD', 'name': 'Soudan'},
    {'code': 'SS', 'name': 'Soudan du Sud'},
    {'code': 'LK', 'name': 'Sri Lanka'},
    {'code': 'SE', 'name': 'Suède'},
    {'code': 'CH', 'name': 'Suisse'},
    {'code': 'SR', 'name': 'Suriname'},
    {'code': 'SY', 'name': 'Syrie'},
    {'code': 'TJ', 'name': 'Tadjikistan'},
    {'code': 'TZ', 'name': 'Tanzanie'},
    {'code': 'TD', 'name': 'Tchad'},
    {'code': 'CZ', 'name': 'Tchéquie'},
    {'code': 'TH', 'name': 'Thaïlande'},
    {'code': 'TL', 'name': 'Timor-Leste'},
    {'code': 'TG', 'name': 'Togo'},
    {'code': 'TO', 'name': 'Tonga'},
    {'code': 'TT', 'name': 'Trinité-et-Tobago'},
    {'code': 'TN', 'name': 'Tunisie'},
    {'code': 'TM', 'name': 'Turkménistan'},
    {'code': 'TR', 'name': 'Turquie'},
    {'code': 'TV', 'name': 'Tuvalu'},
    {'code': 'UA', 'name': 'Ukraine'},
    {'code': 'UY', 'name': 'Uruguay'},
    {'code': 'VU', 'name': 'Vanuatu'},
    {'code': 'VE', 'name': 'Venezuela'},
    {'code': 'VN', 'name': 'Viêt Nam'},
    {'code': 'YE', 'name': 'Yémen'},
    {'code': 'ZM', 'name': 'Zambie'},
    {'code': 'ZW', 'name': 'Zimbabwe'},
    {'code': 'US', 'name': 'États-Unis'},
  ];

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _telCtrl.dispose();
    _adresseCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  // ─── Sélecteur de pays ──────────────────────────────────────────────────────
  void _showCountryPicker() {
    final searchCtrl = TextEditingController();
    List<Map<String, String>> filtered = List.from(_worldCountries);

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
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text('Choisir un pays', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx), color: AppTheme.textSecondary),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: tr('auth_search_country'),
                      hintStyle: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textHint),
                      prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textHint),
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (q) {
                      setModalState(() {
                        filtered = _worldCountries.where((c) =>
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
                      final isSelected = _selectedCountryCode == c['code'];
                      return ListTile(
                        leading: Text(_getFlag(c['code']!), style: const TextStyle(fontSize: 28)),
                        title: Text(c['name']!, style: GoogleFonts.poppins(fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: isSelected ? AppTheme.primary : AppTheme.textPrimary)),
                        trailing: isSelected ? Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20) : null,
                        onTap: () {
                          setState(() {
                            _selectedCountryCode = c['code'];
                            _selectedCountryName = c['name'];
                          });
                          // ✅ Changer la langue immédiatement dès la sélection du pays
                          localeNotifier.value = countryCodeToLocale(c['code']);
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

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.shield_outlined, color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Conditions d\'utilisation', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: SingleChildScrollView(
                  child: Text(
                    'En utilisant VelQix, vous acceptez les conditions suivantes :\n\n'
                    '1. Utilisation licite\nVous vous engagez à utiliser la plateforme uniquement à des fins licites et à ne pas publier de contenu frauduleux ou trompeur.\n\n'
                    '2. Responsabilité des annonces\nChaque utilisateur est responsable de l\'exactitude des informations publiées dans ses annonces.\n\n'
                    '3. Confidentialité\nVos données personnelles sont protégées conformément à notre politique de confidentialité. Nous ne revendons jamais vos données à des tiers.\n\n'
                    '4. Transactions sécurisées\nVelQix facilite la mise en relation entre propriétaires et locataires/acheteurs, mais ne garantit pas les transactions effectuées hors plateforme.\n\n'
                    '5. Compte utilisateur\nVous êtes responsable de la confidentialité de vos identifiants. Signalez toute utilisation non autorisée de votre compte.\n\n'
                    '6. Résiliation\nVelQix se réserve le droit de suspendre ou supprimer tout compte qui viole ces conditions.\n\n'
                    'Pour toute question, contactez-nous à support@velqix.tg',
                    style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary, height: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppTheme.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Fermer', style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _acceptTerms = true);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(tr('auth_accept'), style: GoogleFonts.poppins(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(tr('auth_accept_terms'), style: GoogleFonts.poppins(color: Colors.white, fontSize: 13))),
        ]),
        backgroundColor: AppTheme.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ));
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _loading = false);

    // Pour les comptes entreprise : générer nom/prénom/username depuis le nom d'entreprise
    final isBusiness = _accountType == 'business';
    final nomFinal    = isBusiness ? _nomEntrepriseCtrl.text.trim() : _nomCtrl.text.trim();
    final prenomFinal = isBusiness ? '' : _prenomCtrl.text.trim();
    

    // Sauvegarder le compte avec persistance
    await AuthService.instance.register(
      password: _passCtrl.text,
      nom: nomFinal,
      prenom: prenomFinal,
      email: _emailCtrl.text.trim(),
      telephone: _telCtrl.text.trim(),
      countryCode: _selectedCountryCode,
      countryName: _selectedCountryName,
      accountType: _accountType,
      nomEntreprise: isBusiness ? _nomEntrepriseCtrl.text.trim() : null,
      typeActivite: isBusiness ? _selectedTypeActivite : null,
    );

    // ✅ Appliquer la langue selon le pays choisi à l'inscription
    localeNotifier.value = countryCodeToLocale(_selectedCountryCode);

    // Confirmation visuelle
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(tr('auth_welcome'), style: GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
      ]),
      backgroundColor: AppTheme.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) {
        final role = AuthService.instance.currentUserOrEmpty.role;
        return role == 'admin'
            ? const AdminDashboardScreen()
            : MainShell(username: AuthService.instance.loggedUsername);
      }),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(title: 'Créer un compte'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Type de compte ──
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _accountType = 'personal'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _accountType == 'personal' ? AppTheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_rounded, size: 16,
                                color: _accountType == 'personal' ? Colors.white : AppTheme.textSecondary),
                            const SizedBox(width: 6),
                            Text('Compte personnel',
                                style: GoogleFonts.poppins(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: _accountType == 'personal' ? Colors.white : AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _accountType = 'business'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _accountType == 'business' ? AppTheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.business_rounded, size: 16,
                                color: _accountType == 'business' ? Colors.white : AppTheme.textSecondary),
                            const SizedBox(width: 6),
                            Text('Entreprise',
                                style: GoogleFonts.poppins(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: _accountType == 'business' ? Colors.white : AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ]),
              ),

              // ── Champs entreprise (conditionnels) ──
              if (_accountType == 'business') ...[
                AppTextField(
                  label: "Nom de l\'entreprise *",
                  hint: "Ex: VelQix Sarl",
                  controller: _nomEntrepriseCtrl,
                  prefixIcon: Icons.business_outlined,
                  validator: (v) => (_accountType == 'business' && (v == null || v.trim().isEmpty))
                      ? 'Champ requis' : null,
                ),
                const SizedBox(height: 14),
                // Type d\'activité dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _selectedTypeActivite != null ? AppTheme.primary : AppTheme.border,
                      width: _selectedTypeActivite != null ? 1.5 : 1,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedTypeActivite,
                      isExpanded: true,
                      hint: Row(children: [
                        Icon(Icons.category_outlined, size: 20, color: AppTheme.textHint),
                        const SizedBox(width: 10),
                        Text("Type d\'activité *", style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textHint)),
                      ]),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textHint),
                      items: _typesActivite.map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t, style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textPrimary)),
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedTypeActivite = v),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // ── Nom & Prénom côte à côte (seulement compte personnel) ──
              if (_accountType != 'business') ...[
                Row(children: [
                  Expanded(
                    child: AppTextField(
                      label: tr('auth_field_nom'),
                      hint: 'Kofi',
                      controller: _nomCtrl,
                      prefixIcon: Icons.person_outline_rounded,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      label: tr('auth_field_prenom'),
                      hint: 'Ama',
                      controller: _prenomCtrl,
                      prefixIcon: Icons.person_outline_rounded,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 14),

                // ── Nom d'utilisateur ──
                AppTextField(
                  label: tr('auth_field_username'),
                  hint: 'ama_kofi',
                  controller: _usernameCtrl,
                  prefixIcon: Icons.alternate_email_rounded,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Champ requis';
                    if (v.contains(' ')) return 'Pas d\'espaces autorisés';
                    if (v.length < 3) return 'Minimum 3 caractères';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
              ],

              // ── Email ──
              AppTextField(
                label: tr('auth_field_email'),
                hint: 'ama@email.com',
                controller: _emailCtrl,
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Champ requis';
                  if (!v.contains('@') || !v.contains('.')) return 'Email invalide';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // ── Pays ──
              GestureDetector(
                onTap: _showCountryPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _selectedCountryCode != null ? AppTheme.primary : AppTheme.border,
                      width: _selectedCountryCode != null ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_selectedCountryCode != null) ...[
                        Text(
                          _getFlag(_selectedCountryCode!),
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_selectedCountryName!, style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
                        ),
                      ] else ...[
                        Icon(Icons.flag_outlined, size: 20, color: AppTheme.textHint),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('Choisir votre pays *', style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textHint)),
                        ),
                      ],
                      Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textHint, size: 22),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ── Téléphone ──
              AppTextField(
                label: tr('auth_field_phone'),
                hint: '+228 90 00 00 00',
                controller: _telCtrl,
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
              ),
              const SizedBox(height: 14),

              // ── Adresse ──
              AppTextField(
                label: tr('auth_field_address'),
                hint: 'Ex: Rue de la Paix, Lomé',
                controller: _adresseCtrl,
                prefixIcon: Icons.location_on_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 14),

              // ── Mot de passe ──
              AppTextField(
                label: tr('auth_pwd_label'),
                hint: 'Min. 8 caractères',
                controller: _passCtrl,
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscurePass,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20, color: AppTheme.textHint,
                  ),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Champ requis';
                  if (v.length < 8) return 'Minimum 8 caractères';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // ── Confirmer le mot de passe ──
              AppTextField(
                label: 'Confirmer le mot de passe *',
                hint: 'Répétez votre mot de passe',
                controller: _confirmPassCtrl,
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscureConfirm,
                suffix: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20, color: AppTheme.textHint,
                  ),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Champ requis';
                  if (v != _passCtrl.text) return 'Les mots de passe ne correspondent pas';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── Case à cocher conditions d'utilisation ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _acceptTerms ? AppTheme.primary.withOpacity(0.05) : AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _acceptTerms ? AppTheme.primary : AppTheme.border,
                    width: _acceptTerms ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _acceptTerms,
                        onChanged: (v) => setState(() => _acceptTerms = v ?? false),
                        activeColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
                          children: [
                            const TextSpan(text: 'J\'accepte les '),
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: () => _showTermsDialog(),
                                child: Text(
                                  'Conditions d\'utilisation',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                            const TextSpan(text: ' et la '),
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => const LegalScreen(type: LegalType.privacy))),
                                child: Text(
                                  'Politique de confidentialité',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                            const TextSpan(text: ' d\'VelQix *'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              PrimaryButton(
                label: "S'inscrire",
                isLoading: _loading,
                onPressed: _register,
                icon: Icons.how_to_reg_rounded,
              ),
              const SizedBox(height: 16),
              Center(
                child: RichText(
                  text: TextSpan(
                    text: 'Déjà un compte ? ',
                    style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary),
                    children: [
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            'Se connecter',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Forgot Password Screen ───────────────────────────────────────────────────
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  // Génère un code à 6 chiffres
  String _generateCode() {
    final rng = Random.secure();
    return (100000 + rng.nextInt(900000)).toString();
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    // Vérifier si l'email correspond au compte enregistré
    final prefs = await SharedPreferences.getInstance();
    final savedEmail    = prefs.getString('auth_email') ?? '';
    final savedUsername = prefs.getString('auth_username') ?? '';
    final inputEmail    = _emailCtrl.text.trim().toLowerCase();
    final emailMatch    = savedEmail.toLowerCase() == inputEmail ||
        '\$savedUsername@innorent.tg' == inputEmail;

    if (!emailMatch) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Aucun compte trouvé avec cet email.',
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }

    // Générer et sauvegarder le code + expiration
    final code    = _generateCode();
    final expires = DateTime.now().add(const Duration(minutes: 10));
    await prefs.setString('reset_code',    code);
    await prefs.setString('reset_email',   inputEmail);
    await prefs.setString('reset_expires', expires.toIso8601String());

    // Envoyer l'email via EmailJS REST API
    try {
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id':  'service_bg6qla9',
          'template_id': 'template_vmbant4',
          'user_id':     'gzB6UeYFQi7ql05f4',
          'template_params': {
            'to_email': inputEmail,
            'code':     code,
          },
        }),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() { _loading = false; _sent = true; });
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur envoi email. Réessayez.',
              style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur réseau. Vérifiez votre connexion.',
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  void _goToVerify() {
    Navigator.pushReplacement(context,
      MaterialPageRoute(builder: (_) => VerifyCodeScreen(email: _emailCtrl.text.trim())));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          child: _sent ? _buildSuccessView() : _buildFormView(),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_reset_rounded, size: 44, color: AppTheme.primary),
            ),
          ),
          const SizedBox(height: 28),
          Text('Mot de passe oublié ?', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Text(
            'Entrez votre adresse email et nous vous enverrons un lien pour réinitialiser votre mot de passe.',
            style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary, height: 1.6),
          ),
          const SizedBox(height: 32),
          AppTextField(
            label: 'Adresse email *',
            hint: 'ama@email.com',
            controller: _emailCtrl,
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Champ requis';
              if (!v.contains('@') || !v.contains('.')) return 'Email invalide';
              return null;
            },
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _sendReset,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('Envoyer le lien', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: RichText(
                text: TextSpan(
                  text: 'Retour à la ',
                  style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary),
                  children: [
                    TextSpan(
                      text: 'Connexion',
                      style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.primary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 48),
        Container(
          width: 110, height: 110,
          decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(Icons.mark_email_read_rounded, size: 56, color: AppTheme.success),
        ),
        const SizedBox(height: 32),
        Text('Email envoyé !', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary, height: 1.6),
            children: [
              const TextSpan(text: 'Un lien de réinitialisation a été envoyé à\n'),
              TextSpan(text: _emailCtrl.text.trim(), style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.primary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Vérifiez votre boîte mail (et vos spams si besoin). Le lien expire dans 30 minutes.',
          style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textHint, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text('Retour à la connexion', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: _goToVerify,
          child: Text('Entrer le code reçu', style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.primary, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ─── Verify Code Screen ───────────────────────────────────────────────────────
class VerifyCodeScreen extends StatefulWidget {
  final String email;
  const VerifyCodeScreen({super.key, required this.email});
  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  String get _enteredCode => _ctrls.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_enteredCode.length < 6) {
      setState(() => _error = 'Entrez les 6 chiffres du code.');
      return;
    }
    setState(() { _loading = true; _error = null; });

    final prefs = await SharedPreferences.getInstance();
    final savedCode    = prefs.getString('reset_code') ?? '';
    final savedEmail   = prefs.getString('reset_email') ?? '';
    final expiresStr   = prefs.getString('reset_expires') ?? '';
    final expires      = DateTime.tryParse(expiresStr);

    if (!mounted) return;

    if (expires == null || DateTime.now().isAfter(expires)) {
      setState(() { _loading = false; _error = 'Ce code a expiré. Recommencez.'; });
      return;
    }

    if (savedEmail != widget.email.toLowerCase()) {
      setState(() { _loading = false; _error = 'Email incorrect.'; });
      return;
    }

    if (_enteredCode != savedCode) {
      setState(() { _loading = false; _error = 'Code incorrect. Vérifiez votre email.'; });
      return;
    }

    // Code valide → aller à la réinitialisation
    setState(() => _loading = false);
    Navigator.pushReplacement(context,
      MaterialPageRoute(builder: (_) => ResetPasswordScreen(email: widget.email)));
  }

  void _onDigit(String val, int idx) {
    if (val.length == 1 && idx < 5) {
      _nodes[idx + 1].requestFocus();
    } else if (val.isEmpty && idx > 0) {
      _nodes[idx - 1].requestFocus();
    }
    setState(() => _error = null);
    // Auto-verify when all filled
    if (_enteredCode.length == 6) _verify();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mark_email_read_rounded, size: 44, color: AppTheme.primary),
                ),
              ),
              const SizedBox(height: 28),
              Text('Vérifiez votre email',
                  style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              RichText(text: TextSpan(
                style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary),
                children: [
                  const TextSpan(text: 'Entrez le code à 6 chiffres envoyé à\n'),
                  TextSpan(text: widget.email,
                      style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                ],
              )),
              const SizedBox(height: 36),

              // 6 digit boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => SizedBox(
                  width: 48, height: 58,
                  child: TextFormField(
                    controller: _ctrls[i],
                    focusNode: _nodes[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _error != null ? AppTheme.error : AppTheme.border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                    ),
                    onChanged: (val) => _onDigit(val, i),
                  ),
                )),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_error!,
                      style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.error))),
                ]),
              ],

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text('Vérifier le code',
                              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                        ]),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Renvoyer un code',
                      style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ─── Reset Password Screen ────────────────────────────────────────────────────
class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _codeCtrl    = TextEditingController();
  final _newPwdCtrl  = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading      = false;
  bool _done         = false;
  bool _showNew      = false;
  bool _showConfirm  = false;
  String? _codeError;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    setState(() => _codeError = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final prefs   = await SharedPreferences.getInstance();
    final saved   = prefs.getString('reset_code')    ?? '';
    final email   = prefs.getString('reset_email')   ?? '';
    final expires = prefs.getString('reset_expires') ?? '';

    // Vérifier expiration
    final expiresDt = DateTime.tryParse(expires);
    if (expiresDt == null || DateTime.now().isAfter(expiresDt)) {
      if (!mounted) return;
      setState(() { _loading = false; _codeError = 'Ce code a expiré. Recommencez.'; });
      return;
    }

    // Vérifier code
    if (_codeCtrl.text.trim() != saved || email != widget.email.toLowerCase()) {
      if (!mounted) return;
      setState(() { _loading = false; _codeError = 'Code incorrect. Vérifiez votre email.'; });
      return;
    }

    // Mettre à jour le mot de passe
    await prefs.setString('auth_password', _newPwdCtrl.text.trim());
    // Nettoyer le code utilisé
    await prefs.remove('reset_code');
    await prefs.remove('reset_email');
    await prefs.remove('reset_expires');

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() { _loading = false; _done = true; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          child: _done ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 90, height: 90,
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.lock_outline_rounded, size: 44, color: AppTheme.primary),
            ),
          ),
          const SizedBox(height: 28),
          Text('Réinitialiser le mot de passe',
              style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          RichText(text: TextSpan(
            style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary),
            children: [
              const TextSpan(text: 'Entrez le code reçu sur '),
              TextSpan(text: widget.email,
                  style: GoogleFonts.poppins(color: AppTheme.primary, fontWeight: FontWeight.w600)),
            ],
          )),
          const SizedBox(height: 32),

          // Code
          Text('Code de vérification *',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 8),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '000000',
              hintStyle: GoogleFonts.poppins(color: AppTheme.textHint, letterSpacing: 8, fontSize: 20),
              counterText: '',
              errorText: _codeError,
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.error, width: 1.5)),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Entrez le code reçu par email';
              if (v.trim().length != 6) return 'Le code doit avoir 6 chiffres';
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Nouveau mot de passe
          Text('Nouveau mot de passe *',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _newPwdCtrl,
            obscureText: !_showNew,
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: InputDecoration(
              hintText: '••••••••',
              hintStyle: GoogleFonts.poppins(color: AppTheme.textHint),
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.textHint, size: 20),
              suffixIcon: IconButton(
                icon: Icon(_showNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppTheme.textHint, size: 20),
                onPressed: () => setState(() => _showNew = !_showNew),
              ),
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Champ requis';
              if (v.trim().length < 6) return 'Minimum 6 caractères';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Confirmer
          Text('Confirmer le mot de passe *',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _confirmCtrl,
            obscureText: !_showConfirm,
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: InputDecoration(
              hintText: '••••••••',
              hintStyle: GoogleFonts.poppins(color: AppTheme.textHint),
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.textHint, size: 20),
              suffixIcon: IconButton(
                icon: Icon(_showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppTheme.textHint, size: 20),
                onPressed: () => setState(() => _showConfirm = !_showConfirm),
              ),
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Champ requis';
              if (v.trim() != _newPwdCtrl.text.trim()) return 'Les mots de passe ne correspondent pas';
              return null;
            },
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _resetPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text('Confirmer', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                    ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      children: [
        const SizedBox(height: 60),
        Center(
          child: Container(
            width: 100, height: 100,
            decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, size: 60, color: AppTheme.success),
          ),
        ),
        const SizedBox(height: 28),
        Text('Mot de passe mis à jour !',
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text('Vous pouvez maintenant vous connecter avec votre nouveau mot de passe.',
            style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary),
            textAlign: TextAlign.center),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text('Se connecter', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}
