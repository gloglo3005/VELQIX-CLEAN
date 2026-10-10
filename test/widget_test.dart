import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:VELQIX/main.dart';

// Tests unitaires des règles pures de main.dart (langue et devise). L'ancien
// test de fumée appelait VelQixApp(alreadyLoggedIn: ...), paramètre qui n'existe
// plus : la connexion automatique se fait désormais derrière l'écran de
// chargement (_startup).
void main() {
  group('countryCodeToLocale', () {
    test('retourne le français par défaut', () {
      expect(countryCodeToLocale(null), const Locale('fr'));
      expect(countryCodeToLocale('   '), const Locale('fr'));
      expect(countryCodeToLocale('TG'), const Locale('fr'));
      expect(countryCodeToLocale('XX'), const Locale('fr'));
    });

    test('retourne l\'anglais pour US et GB, sans tenir compte de la casse', () {
      expect(countryCodeToLocale('US'), const Locale('en'));
      expect(countryCodeToLocale('gb'), const Locale('en'));
    });
  });

  group('devises', () {
    tearDown(() => currencyNotifier.value = 'XOF');

    test('le XOF est la devise de référence (taux 1)', () {
      expect(supportedCurrencies.first.code, 'XOF');
      expect(supportedCurrencies.first.rateFromXof, 1.0);
    });

    test('activeCurrency suit currencyNotifier', () {
      currencyNotifier.value = 'EUR';
      expect(activeCurrency.code, 'EUR');
    });

    test('activeCurrency retombe sur le XOF si le code est inconnu', () {
      currencyNotifier.value = 'ZZZ';
      expect(activeCurrency.code, 'XOF');
    });
  });
}
