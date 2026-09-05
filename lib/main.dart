import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme/app_theme.dart';
import 'screens/auth_screens.dart';
import 'screens/main_shell.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/shared_property_screen.dart';
import 'services/auth_service.dart';

// ── Notifiers globaux accessibles partout ────────────────────────────────────
final themeModeNotifier  = ValueNotifier<ThemeMode>(ThemeMode.light);
final localeNotifier     = ValueNotifier<Locale>(const Locale('fr'));

/// Code de devise actif : 'XOF' | 'EUR' | 'USD' | 'GHS' | ...
final currencyNotifier   = ValueNotifier<String>('XOF');

/// Données d'une devise : symbole, nom, taux vs XOF
class CurrencyInfo {
  final String code;
  final String symbol;
  final String name;
  final double rateFromXof; // 1 XOF = X devise
  const CurrencyInfo({required this.code, required this.symbol, required this.name, required this.rateFromXof});
}

const List<CurrencyInfo> supportedCurrencies = [
  CurrencyInfo(code: 'XOF', symbol: 'FCFA', name: 'Franc CFA (BCEAO)', rateFromXof: 1.0),
  CurrencyInfo(code: 'EUR', symbol: '€',    name: 'Euro',               rateFromXof: 0.001524),
  CurrencyInfo(code: 'USD', symbol: '\$',   name: 'Dollar US',          rateFromXof: 0.001651),
  CurrencyInfo(code: 'GHS', symbol: '₵',    name: 'Cedi ghanéen',       rateFromXof: 0.02410),
  CurrencyInfo(code: 'NGN', symbol: '₦',    name: 'Naira nigérian',     rateFromXof: 2.5612),
];

CurrencyInfo get activeCurrency =>
    supportedCurrencies.firstWhere((c) => c.code == currencyNotifier.value,
        orElse: () => supportedCurrencies.first);

/// Mapping code pays ISO → locale Flutter
Locale countryCodeToLocale(String? code) {
  final map = {
    'GH': Locale('en'),      // Ghana → anglais
    'US': Locale('en'),
    'GB': Locale('en'),
    'NG': Locale('en'),      // Nigeria
    'ZA': Locale('en'),      // Afrique du Sud
    'ES': Locale('es'),      // Espagne
    'MX': Locale('es'),
    'CO': Locale('es'),
    'PT': Locale('pt'),      // Portugal
    'BR': Locale('pt'),
    'DE': Locale('de'),      // Allemagne
    'IT': Locale('it'),      // Italie
    'FR': Locale('fr'),      // France
    'BE': Locale('fr'),
    'CH': Locale('fr'),
    'SN': Locale('fr'),      // Sénégal
    'CI': Locale('fr'),      // Côte d'Ivoire
    'TG': Locale('fr'),      // Togo
    'BJ': Locale('fr'),      // Bénin
    'CM': Locale('fr'),      // Cameroun
    'ML': Locale('fr'),      // Mali
    'BF': Locale('fr'),      // Burkina Faso
    'MA': Locale('ar'),      // Maroc → arabe
    'DZ': Locale('ar'),      // Algérie
    'TN': Locale('ar'),      // Tunisie
    'SA': Locale('ar'),      // Arabie Saoudite
    'CN': Locale('zh'),
    'JP': Locale('ja'),
    'KR': Locale('ko'),
    'RU': Locale('ru'),
  };
  return map[code?.toUpperCase()] ?? const Locale('fr');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // URLs propres sur le web (https://.../bien/xyz au lieu de .../#/bien/xyz)
  // — indispensable pour que les liens partagés soient cliquables tels quels.
  usePathUrlStrategy();
  await initializeDateFormatting();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  final alreadyLoggedIn = await AuthService.instance.tryAutoLogin();

  // Appliquer la locale du pays enregistré au démarrage
  if (alreadyLoggedIn) {
   final code = AuthService.instance.currentUserOrEmpty.countryCode;
    localeNotifier.value = countryCodeToLocale(code);
  }

  runApp(VelQixApp(alreadyLoggedIn: alreadyLoggedIn));
}

class VelQixApp extends StatelessWidget {
  final bool alreadyLoggedIn;
  const VelQixApp({super.key, required this.alreadyLoggedIn});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (_, mode, __) => ValueListenableBuilder<Locale>(
        valueListenable: localeNotifier,
        builder: (_, locale, __) => MaterialApp(
          title: 'VelQix',
          debugShowCheckedModeBanner: false,
          theme:      AppTheme.lightTheme,
          darkTheme:  AppTheme.darkTheme,
          themeMode:  mode,
          locale:     locale,
          supportedLocales: const [
            Locale('fr'), Locale('en'), Locale('es'), Locale('pt'),
            Locale('de'), Locale('it'), Locale('ar'), Locale('zh'),
            Locale('ja'), Locale('ko'), Locale('ru'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            final isDark = mode == ThemeMode.dark ||
                (mode == ThemeMode.system &&
                    MediaQuery.platformBrightnessOf(context) == Brightness.dark);
            if (!isDark) return child ?? const SizedBox.shrink();
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1A1F2E), // fond sombre haut
                    Color(0xFF1A1F2E), // fond sombre milieu
                    Color(0xFF1E2433), // fond sombre bas
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: alreadyLoggedIn
              ? (AuthService.instance.currentUserOrEmpty.role == 'admin'
                  ? const AdminDashboardScreen()
                  : MainShell(username: AuthService.instance.loggedUsername))
              : const OnboardingScreen(),
          // Uniquement pour les routes non gérées par `home` (donc web : un
          // lien partagé ouvert directement, ex. /bien/xyz123) — le flux de
          // connexion normal (route '/') n'est pas affecté.
          onGenerateRoute: (settings) {
            final name = settings.name ?? '';
            final match = RegExp(r'^/bien/([^/]+)/?$').firstMatch(name);
            if (match != null) {
              final propertyId = match.group(1)!;
              return MaterialPageRoute(
                builder: (_) => SharedPropertyScreen(propertyId: propertyId),
                settings: settings,
              );
            }
            return null; // route inconnue → comportement par défaut de Flutter
          },
        ),
      ),
    );
  }
}