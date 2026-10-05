import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'services/auth_service.dart';
import 'services/push_notification_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'utils/translations.dart';

/// ===============================================================
/// GLOBAL APP SETTINGS
/// ===============================================================

final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

final localeNotifier = ValueNotifier<Locale>(
  const Locale('fr'),
);

final currencyNotifier = ValueNotifier<String>('XOF');

/// ===============================================================
/// CURRENCIES
/// ===============================================================

class CurrencyInfo {
  final String code;
  final String symbol;
  final String name;

  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.name,
  });
}

const List<CurrencyInfo> supportedCurrencies = [
  CurrencyInfo(
    code: 'XOF',
    symbol: 'FCFA',
    name: 'Franc CFA BCEAO',
  ),
  CurrencyInfo(
    code: 'EUR',
    symbol: '€',
    name: 'Euro',
  ),
  CurrencyInfo(
    code: 'USD',
    symbol: '\$',
    name: 'Dollar américain',
  ),
  CurrencyInfo(
    code: 'GBP',
    symbol: '£',
    name: 'Livre sterling',
  ),
];

CurrencyInfo get activeCurrency {
  return supportedCurrencies.firstWhere(
    (currency) => currency.code == currencyNotifier.value,
    orElse: () => supportedCurrencies.first,
  );
}

/// ===============================================================
/// COUNTRY CODE -> LOCALE
/// ===============================================================

Locale countryCodeToLocale(String? countryCode) {
  if (countryCode == null || countryCode.trim().isEmpty) {
    return const Locale('fr');
  }

  switch (countryCode.toUpperCase()) {
    case 'US':
    case 'GB':
    case 'CA':
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
      return const Locale('fr');

    default:
      return const Locale('fr');
  }
}

/// ===============================================================
/// FIREBASE BACKGROUND MESSAGE HANDLER
/// ===============================================================

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  // Le handler s'exécute dans un isolate séparé.
  //
  // On initialise Firebase uniquement sur les plateformes natives.
  // Sur le Web, FirebaseMessaging est géré différemment.
  if (kIsWeb) {
    return;
  }

  try {
    // Pour le moment, on ne fait pas de traitement UI ici.
    //
    // Si le message contient un bloc "notification", Firebase/Android
    // peut afficher automatiquement la notification lorsque l'application
    // est en arrière-plan.
    //
    // Le traitement de l'appel sera effectué lorsque l'utilisateur ouvre
    // la notification via onMessageOpenedApp.
  } catch (e) {
    debugPrint(
      'Erreur dans firebaseMessagingBackgroundHandler: $e',
    );
  }
}

/// ===============================================================
/// MAIN
/// ===============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// -------------------------------------------------------------
  /// URL STRATEGY
  /// -------------------------------------------------------------
  ///
  /// Permet d'avoir des URLs propres sur Flutter Web :
  /// /login
  /// /properties
  /// etc.
  ///
  usePathUrlStrategy();

  /// -------------------------------------------------------------
  /// FIREBASE BACKGROUND HANDLER
  /// -------------------------------------------------------------
  ///
  /// On ne l'enregistre pas sur le Web.
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );
  }

  /// -------------------------------------------------------------
  /// DATE FORMATTING
  /// -------------------------------------------------------------
  await initializeDateFormatting();

  /// -------------------------------------------------------------
  /// SCREEN ORIENTATION
  /// -------------------------------------------------------------
  ///
  /// VELQIX est actuellement verrouillé en mode portrait.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  /// -------------------------------------------------------------
  /// SYSTEM UI
  /// -------------------------------------------------------------
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  /// -------------------------------------------------------------
  /// AUTO LOGIN
  /// -------------------------------------------------------------
  bool alreadyLoggedIn = false;

  try {
    alreadyLoggedIn = await AuthService.instance.tryAutoLogin();
  } catch (e) {
    debugPrint(
      'Erreur pendant le auto-login: $e',
    );

    alreadyLoggedIn = false;
  }

  /// -------------------------------------------------------------
  /// USER SETTINGS
  /// -------------------------------------------------------------
  ///
  /// Si l'utilisateur est connecté, on récupère sa langue/pays.
  if (alreadyLoggedIn) {
    try {
      final user = AuthService.instance.currentUserOrEmpty;

      localeNotifier.value = countryCodeToLocale(
        user.countryCode,
      );
    } catch (e) {
      debugPrint(
        'Erreur lors du chargement de la locale utilisateur: $e',
      );

      localeNotifier.value = const Locale('fr');
    }
  }

  /// -------------------------------------------------------------
  /// LOCAL NOTIFICATIONS
  /// -------------------------------------------------------------
  ///
  /// Cette partie est indépendante de Firebase.
  ///
  /// Elle permet notamment d'afficher une notification locale
  /// lorsqu'un événement arrive via Socket.IO ou FCM en foreground.
  try {
    await NotificationService.instance
        .initializeLocalNotifications();
  } catch (e) {
    debugPrint(
      'Erreur initialisation notifications locales: $e',
    );
  }

  /// -------------------------------------------------------------
  /// PUSH NOTIFICATIONS / FCM
  /// -------------------------------------------------------------
  ///
  /// FCM est initialisé uniquement si l'utilisateur est connecté.
  ///
  /// Sur Flutter Web, PushNotificationService.initialize()
  /// ignore volontairement FCM pour le moment.
  if (alreadyLoggedIn) {
    try {
      await PushNotificationService.instance.initialize();
    } catch (e) {
      debugPrint(
        'Erreur initialisation Push Notifications: $e',
      );
    }
  }

  /// -------------------------------------------------------------
  /// RUN APP
  /// -------------------------------------------------------------
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

              /// ---------------------------------------------------
              /// THEME
              /// ---------------------------------------------------
              theme: AppTheme.lightTheme,

              darkTheme: AppTheme.darkTheme,

              themeMode: themeMode,

              /// ---------------------------------------------------
              /// LOCALE
              /// ---------------------------------------------------
              locale: locale,

              supportedLocales: const [
                Locale('fr'),
                Locale('en'),
              ],

              /// ---------------------------------------------------
              /// LOCALIZATIONS
              /// ---------------------------------------------------
              localizationsDelegates: const [
                AppLocalizations.delegate,
                DefaultMaterialLocalizations.delegate,
                DefaultWidgetsLocalizations.delegate,
                DefaultCupertinoLocalizations.delegate,
              ],

              /// ---------------------------------------------------
              /// INITIAL ROUTE / HOME
              /// ---------------------------------------------------
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