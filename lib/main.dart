import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/admin_dashboard_screen.dart';
import 'screens/auth_screens.dart';
import 'screens/main_shell.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/push_notification_service.dart';
import 'theme/app_theme.dart';

/// ===============================================================
/// GLOBAL SETTINGS
/// ===============================================================

final themeModeNotifier = ValueNotifier<ThemeMode>(
  ThemeMode.light,
);

final localeNotifier = ValueNotifier<Locale>(
  const Locale('fr'),
);

final currencyNotifier = ValueNotifier<String>(
  'XOF',
);

/// ===============================================================
/// CURRENCY
/// ===============================================================

class CurrencyInfo {
  final String code;
  final String symbol;
  final String name;
  final double rateFromXof;

  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.name,
    required this.rateFromXof,
  });
}

const List<CurrencyInfo> supportedCurrencies = [
  CurrencyInfo(
    code: 'XOF',
    symbol: 'FCFA',
    name: 'Franc CFA BCEAO',
    rateFromXof: 1.0,
  ),
  CurrencyInfo(
    code: 'EUR',
    symbol: '€',
    name: 'Euro',
    rateFromXof: 655.957,
  ),
  CurrencyInfo(
    code: 'USD',
    symbol: '\$',
    name: 'Dollar américain',
    rateFromXof: 600.0,
  ),
  CurrencyInfo(
    code: 'GBP',
    symbol: '£',
    name: 'Livre sterling',
    rateFromXof: 760.0,
  ),
];

CurrencyInfo get activeCurrency {
  return supportedCurrencies.firstWhere(
    (currency) => currency.code == currencyNotifier.value,
    orElse: () => supportedCurrencies.first,
  );
}

/// ===============================================================
/// LOCALE
/// ===============================================================

Locale countryCodeToLocale(String? countryCode) {
  if (countryCode == null || countryCode.trim().isEmpty) {
    return const Locale('fr');
  }

  switch (countryCode.toUpperCase()) {
    case 'US':
    case 'GB':
      return const Locale('en');

    case 'FR':
    case 'TG':
    case 'BJ':
    case 'CI':
    case 'SN':
    case 'ML':
    case 'BF':
    case 'NE':
    case 'GN':
    default:
      return const Locale('fr');
  }
}

/// ===============================================================
/// FIREBASE BACKGROUND HANDLER
/// ===============================================================

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  if (kIsWeb) {
    return;
  }

  debugPrint(
    'FCM background message received: ${message.messageId}',
  );

  // Les notifications FCM contenant un bloc "notification"
  // sont prises en charge automatiquement par le système
  // lorsque l'application est en arrière-plan.
  //
  // Les données d'un éventuel appel seront traitées lorsque
  // l'utilisateur ouvre la notification.
}

/// ===============================================================
/// MAIN
/// ===============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// =============================================================
  /// FLUTTER WEB
  /// =============================================================

  usePathUrlStrategy();

  /// =============================================================
  /// FIREBASE MESSAGING
  /// =============================================================

  // Le handler background FCM n'est enregistré que sur mobile.
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );
  }

  /// =============================================================
  /// DATE FORMATTING
  /// =============================================================

  await initializeDateFormatting();

  /// =============================================================
  /// DEVICE ORIENTATION
  /// =============================================================

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  /// =============================================================
  /// SYSTEM UI
  /// =============================================================

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  bool alreadyLoggedIn = false;

  /// =============================================================
  /// AUTO LOGIN
  /// =============================================================

  try {
    alreadyLoggedIn = await AuthService.instance.tryAutoLogin();
  } catch (e, stackTrace) {
    debugPrint('Auto login error: $e');
    debugPrint('$stackTrace');

    alreadyLoggedIn = false;
  }

  /// =============================================================
  /// USER LOCALE
  /// =============================================================

  if (alreadyLoggedIn) {
    try {
      final user = AuthService.instance.currentUserOrEmpty;

      localeNotifier.value = countryCodeToLocale(
        user.countryCode,
      );
    } catch (e, stackTrace) {
      debugPrint('Locale loading error: $e');
      debugPrint('$stackTrace');
    }
  }

  /// =============================================================
  /// LOCAL NOTIFICATIONS
  /// =============================================================

  try {
    await NotificationService.instance
        .initializeLocalNotifications();
  } catch (e, stackTrace) {
    debugPrint(
      'Local notification initialization error: $e',
    );
    debugPrint('$stackTrace');
  }

  /// =============================================================
  /// PUSH NOTIFICATIONS
  /// =============================================================
  ///
  /// Initialisé ici uniquement si l'utilisateur est déjà connecté
  /// au démarrage. Après une connexion manuelle, l'initialisation
  /// est faite dans MainShell (voir initState).

  if (alreadyLoggedIn) {
    try {
      await PushNotificationService.instance.initialize();
    } catch (e, stackTrace) {
      debugPrint(
        'Push notification initialization error: $e',
      );
      debugPrint('$stackTrace');
    }
  }

  /// =============================================================
  /// RUN APP
  /// =============================================================

  runApp(
    VelQixApp(
      alreadyLoggedIn: alreadyLoggedIn,
    ),
  );
}

/// ===============================================================
/// VELQIX APP
/// ===============================================================

class VelQixApp extends StatelessWidget {
  final bool alreadyLoggedIn;

  const VelQixApp({
    super.key,
    required this.alreadyLoggedIn,
  });

  /// Écran d'accueil d'un utilisateur déjà connecté.
  /// Même logique que LoginScreen : l'admin va sur son dashboard,
  /// les autres sur MainShell.
  Widget _homeForLoggedUser() {
    final user = AuthService.instance.currentUserOrEmpty;

    if (user.role == 'admin') {
      return const AdminDashboardScreen();
    }

    return MainShell(
      username: AuthService.instance.loggedUsername,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (
        context,
        themeMode,
        child,
      ) {
        return ValueListenableBuilder<Locale>(
          valueListenable: localeNotifier,
          builder: (
            context,
            locale,
            child,
          ) {
            return MaterialApp(
              title: 'VELQIX',

              debugShowCheckedModeBanner: false,

              /// =================================================
              /// THEME
              /// =================================================

              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeMode,

              /// =================================================
              /// LOCALE
              /// =================================================

              locale: locale,

              // ✅ CORRIGÉ : sans ces délégués, les widgets Material
              // (TextField, etc.) plantent avec "No MaterialLocalizations
              // found" et s'affichent en zone grise.
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],

              supportedLocales: const [
                Locale('fr'),
                Locale('en'),
              ],

              /// =================================================
              /// INITIAL SCREEN
              /// =================================================

              home: alreadyLoggedIn
                  ? _homeForLoggedUser()
                  : const LoginScreen(),
            );
          },
        );
      },
    );
  }
}