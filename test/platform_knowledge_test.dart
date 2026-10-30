import 'package:flutter_test/flutter_test.dart';

import 'package:VELQIX/services/platform_knowledge.dart';

void main() {
  group('Recherches de biens : jamais interceptées', () {
    const searches = [
      'Maison à Lomé',
      'Voiture à louer',
      'Appartement meublé',
      'Bien disponible au Togo',
      'maison sécurisée à Lomé avec piscine',
      'Quel est le prix de la maison avec jardin à Kara',
      'appartement à Accra',
      'terrain à vendre au Bénin',
    ];
    for (final q in searches) {
      test(q, () => expect(PlatformKnowledge.match(q), isNull));
    }
  });

  group('Questions plateforme + lieu', () {
    test('publier à Lomé', () {
      final m = PlatformKnowledge.match('Comment publier une annonce à Lomé ?');
      expect(m?.topic, 'publish');
      expect(m?.geo?.kind, 'togo');
      final out = PlatformKnowledge.render(m!);
      expect(out, contains('Publier une annonce'));
      expect(out, contains('Lomé'));
    });

    test('Premium sans lieu', () {
      final m = PlatformKnowledge.match('Que comprend Premium ?');
      expect(m?.topic, 'premium');
      expect(m?.geo, isNull);
      expect(m?.lang, 'fr');
    });

    test('Premium + tarif injecté depuis le serveur', () {
      final m = PlatformKnowledge.match('Premium à Kara')!;
      final out = PlatformKnowledge.render(m,
          premiumLine: 'Tarifs actuels : 1 mois : 2 000 FCFA.');
      expect(out, contains('2 000 FCFA'));
      expect(out, contains('Kara'));
      expect(out, contains('vérifiée'));
    });

    test('Premium au Canada : lieu hors Afrique', () {
      final m = PlatformKnowledge.match('Premium au Canada')!;
      expect(m.topic, 'premium');
      expect(m.geo?.kind, 'world');
      expect(PlatformKnowledge.render(m), contains('Canada'));
    });

    test('services de vérification au Ghana', () {
      final m = PlatformKnowledge.match('Faites-vous la vérification au Ghana ?')!;
      expect(m.topic, 'services');
      expect(m.geo?.kind, 'wa');
    });

    test('diaspora : le lieu africain prime sur le pays de résidence', () {
      final m = PlatformKnowledge.match(
          'Je vis en France, comment acheter à Lomé ?')!;
      expect(m.topic, 'diaspora');
      expect(m.geo?.kind, 'togo');
    });
  });

  group('Couverture géographique', () {
    test('quels pays', () {
      final m = PlatformKnowledge.match('VelQix est disponible dans quels pays ?');
      expect(m?.topic, 'coverage');
    });

    test('ça marche au Ghana ?', () {
      final m = PlatformKnowledge.match('Est-ce que ça marche au Ghana ?')!;
      expect(m.topic, 'coverage');
      expect(m.lang, 'fr');
      expect(m.geo?.code, 'GH');
    });

    test('anglais : Do you work in Ghana?', () {
      final m = PlatformKnowledge.match('Do you work in Ghana?')!;
      expect(m.topic, 'coverage');
      expect(m.lang, 'en');
      expect(PlatformKnowledge.render(m), contains('West Africa'));
    });

    test('continent : l\'application est-elle disponible en Europe ?', () {
      final m = PlatformKnowledge.match(
          'L\'application est disponible en Europe ?')!;
      expect(m.topic, 'coverage');
      expect(m.geo?.kind, 'world');
    });

    test('Niger et Nigeria ne se confondent pas', () {
      expect(PlatformKnowledge.detectGeo('Niger')?.code, 'NE');
      expect(PlatformKnowledge.detectGeo('Nigeria')?.code, 'NG');
      expect(PlatformKnowledge.detectGeo('Afrique de l\'Ouest')?.kind, 'wa');
      expect(PlatformKnowledge.detectGeo('Côte d\'Ivoire')?.code, 'CI');
    });
  });

  group('Sujets ambigus', () {
    test('contacter le propriétaire ≠ contacter le support', () {
      expect(PlatformKnowledge.match('Comment contacter le propriétaire ?')?.topic, 'contact');
      expect(PlatformKnowledge.match('Comment contacter le support ?')?.topic, 'support');
    });

    test('annonce vérifiée', () {
      expect(PlatformKnowledge.match('Que veut dire annonce vérifiée ?')?.topic, 'trust');
    });

    test('signaler une arnaque → signalement', () {
      expect(PlatformKnowledge.match('Comment signaler une arnaque ?')?.topic, 'report');
    });

    test('les réponses ne promettent pas de prise en charge des fraudes', () {
      final m = PlatformKnowledge.match('Est-ce fiable, y a-t-il des arnaques ?')!;
      final out = PlatformKnowledge.render(m).toLowerCase();
      expect(out, contains('ne garantit pas'));
      expect(out, isNot(contains('s\'en charge')));
    });
  });
}
