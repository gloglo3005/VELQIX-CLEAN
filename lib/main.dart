import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/login_screen.dart';
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

  // Le message est traité par Firebase lorsque l'application
  // est en arrière-plan.
  //
  // Le traitement spécifique d'un appel sera effectué lorsque
  // l'utilisateur ouvre la notification.
}

/// ===============================================================
/// MAIN
/// ===============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// Flutter Web : URLs propres
  usePathUrlStrategy();

  /// FCM background uniquement sur mobile.
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );
  }

  /// Dates
  await initializeDateFormatting();

  /// Portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  /// Status/navigation bars
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
    alreadyLoggedIn =
        await AuthService.instance.tryAutoLogin();
  } catch (e) {
    debugPrint('Auto login error: $e');
    alreadyLoggedIn = false;
  }

  /// =============================================================
  /// USER LOCALE
  /// =============================================================

  if (alreadyLoggedIn) {
    try {
      final user =
          AuthService.instance.currentUserOrEmpty;

      localeNotifier.value =
          countryCodeToLocale(user.countryCode);
    } catch (e) {
      debugPrint('Locale loading error: $e');
    }
  }

  /// =============================================================
  /// LOCAL NOTIFICATIONS
  /// =============================================================

  try {
    await NotificationService.instance
        .initializeLocalNotifications();
  } catch (e) {
    debugPrint(
      'Local notification initialization error: $e',
    );
  }

  /// =============================================================
  /// PUSH NOTIFICATIONS
  /// =============================================================

  if (alreadyLoggedIn) {
    try {
      await PushNotificationService.instance.initialize();
    } catch (e) {
      debugPrint(
        'Push notification initialization error: $e',
      );
    }
  }

  /// =============================================================
  /// APP
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

              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeMode,

              locale: locale,

              supportedLocales: const [
                Locale('fr'),
                Locale('en'),
              ],

              home: alreadyLoggedIn
                  ? const MainShell()
                  : const LoginScreen(),
            );
          },
        );
      },
    );
  }
}