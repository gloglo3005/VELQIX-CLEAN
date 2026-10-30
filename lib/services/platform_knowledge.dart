// lib/services/platform_knowledge.dart
//
// Base de connaissances de VelqIA sur le FONCTIONNEMENT de la plateforme.
//
// Principes :
//  - Aucune dépendance Flutter : logique pure, testable (voir
//    test/platform_knowledge_test.dart).
//  - Les questions sur la plateforme reçoivent une réponse précise et
//    adaptée au lieu cité (Lomé, une ville du Togo, un autre pays, un
//    continent, « l'étranger »…).
//  - Les recherches de biens (« maison à Lomé », « voiture à louer »…) ne
//    sont JAMAIS interceptées : elles partent vers le serveur (Gemini).
//  - Les chiffres qui bougent (tarif Premium, zones desservies) ne sont pas
//    écrits en dur : le widget les lit sur le serveur et les injecte.
//  - Rien n'est promis au-delà de ce que dit le cahier des charges : Premium
//    ne donne pas le statut « vérifié », et VelQix ne garantit pas les
//    transactions entre utilisateurs.

class GeoMention {
  /// togo | wa (Afrique de l'Ouest) | africa | world | abroad
  final String kind;
  final String labelFr;
  final String labelEn;

  /// Code pays ISO (TG, BJ, GH…) quand c'est un pays ou une ville connue.
  final String? code;

  /// Texte normalisé trouvé dans la question (sert à comparer aux zones).
  final String token;

  const GeoMention({
    required this.kind,
    required this.labelFr,
    required this.labelEn,
    required this.code,
    required this.token,
  });
}

class PlatformMatch {
  final String topic;
  final String lang; // fr | en
  final GeoMention? geo;
  const PlatformMatch(this.topic, this.lang, this.geo);
}

class _Topic {
  final String id;
  final List<String> fr;
  final List<String> en;
  final String textFr;
  final String textEn;

  /// Ajoute le paragraphe « selon votre lieu » quand un lieu est cité.
  final bool geo;
  const _Topic(this.id, this.fr, this.en, this.textFr, this.textEn,
      {this.geo = false});
}

class PlatformKnowledge {
  PlatformKnowledge._();

  // ───────────────────────────────────────────────────────────────────────
  // Normalisation et recherche de mots
  // ───────────────────────────────────────────────────────────────────────
  static const _accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'î': 'i', 'ï': 'i', 'í': 'i',
    'ô': 'o', 'ö': 'o', 'ó': 'o', 'õ': 'o',
    'û': 'u', 'ù': 'u', 'ü': 'u', 'ú': 'u',
    'ç': 'c', 'ñ': 'n', 'œ': 'oe', 'æ': 'ae',
  };

  /// minuscules, sans accents, ponctuation → espace, espaces réduits.
  static String normalize(String s) {
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      b.write(_accents[ch] ?? ch);
    }
    return b
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// [padded] = ' texte normalisé '. Une expression finissant par « * » est
  /// un début de mot (publi* → publier, publication).
  static bool _has(String padded, String phrase) {
    if (phrase.endsWith('*')) {
      return padded.contains(' ${phrase.substring(0, phrase.length - 1)}');
    }
    return padded.contains(' $phrase ');
  }

  static int _score(String padded, List<String> phrases) {
    var total = 0;
    for (final p in phrases) {
      if (_has(padded, p)) {
        total += p.replaceAll('*', '').split(' ').length;
      }
    }
    return total;
  }

  static bool _any(String padded, List<String> phrases) =>
      phrases.any((p) => _has(padded, p));

  // ───────────────────────────────────────────────────────────────────────
  // Géographie
  // ───────────────────────────────────────────────────────────────────────
  // (jetons normalisés, nom fr, nom en, code, type) — les jetons les plus
  // longs sont testés d'abord (« afrique de l ouest » avant « afrique »,
  // « cote d ivoire » avant « ivoire »).
  static const List<
      ({
        List<String> tokens,
        String fr,
        String en,
        String? code,
        String kind
      })> _places = [
    // Togo : pays et villes
    (tokens: ['lome'], fr: 'Lomé', en: 'Lomé', code: 'TG', kind: 'togo'),
    (tokens: ['togo', 'togolais', 'togolaise'], fr: 'le Togo', en: 'Togo', code: 'TG', kind: 'togo'),
    (tokens: ['kara'], fr: 'Kara', en: 'Kara', code: 'TG', kind: 'togo'),
    (tokens: ['sokode'], fr: 'Sokodé', en: 'Sokodé', code: 'TG', kind: 'togo'),
    (tokens: ['kpalime'], fr: 'Kpalimé', en: 'Kpalimé', code: 'TG', kind: 'togo'),
    (tokens: ['atakpame'], fr: 'Atakpamé', en: 'Atakpamé', code: 'TG', kind: 'togo'),
    (tokens: ['aneho'], fr: 'Aného', en: 'Aného', code: 'TG', kind: 'togo'),
    (tokens: ['tsevie'], fr: 'Tsévié', en: 'Tsévié', code: 'TG', kind: 'togo'),
    (tokens: ['dapaong'], fr: 'Dapaong', en: 'Dapaong', code: 'TG', kind: 'togo'),
    (tokens: ['baguida'], fr: 'Baguida', en: 'Baguida', code: 'TG', kind: 'togo'),
    (tokens: ['agoe'], fr: 'Agoè', en: 'Agoè', code: 'TG', kind: 'togo'),
    (tokens: ['aflao'], fr: 'Aflao', en: 'Aflao', code: 'GH', kind: 'wa'),
    // Afrique de l'Ouest
    (tokens: ['benin', 'cotonou', 'porto novo', 'parakou'], fr: 'le Bénin', en: 'Benin', code: 'BJ', kind: 'wa'),
    (tokens: ['ghana', 'accra', 'kumasi'], fr: 'le Ghana', en: 'Ghana', code: 'GH', kind: 'wa'),
    (tokens: ['cote d ivoire', 'ivoire', 'abidjan', 'yamoussoukro'], fr: "la Côte d'Ivoire", en: 'Ivory Coast', code: 'CI', kind: 'wa'),
    (tokens: ['senegal', 'dakar'], fr: 'le Sénégal', en: 'Senegal', code: 'SN', kind: 'wa'),
    (tokens: ['nigeria', 'lagos', 'abuja'], fr: 'le Nigeria', en: 'Nigeria', code: 'NG', kind: 'wa'),
    (tokens: ['burkina', 'burkina faso', 'ouagadougou', 'bobo dioulasso'], fr: 'le Burkina Faso', en: 'Burkina Faso', code: 'BF', kind: 'wa'),
    (tokens: ['mali', 'bamako'], fr: 'le Mali', en: 'Mali', code: 'ML', kind: 'wa'),
    (tokens: ['niger', 'niamey'], fr: 'le Niger', en: 'Niger', code: 'NE', kind: 'wa'),
    (tokens: ['guinee', 'conakry'], fr: 'la Guinée', en: 'Guinea', code: 'GN', kind: 'wa'),
    (tokens: ['liberia', 'monrovia'], fr: 'le Liberia', en: 'Liberia', code: 'LR', kind: 'wa'),
    (tokens: ['sierra leone', 'freetown'], fr: 'la Sierra Leone', en: 'Sierra Leone', code: 'SL', kind: 'wa'),
    (tokens: ['gambie', 'gambia', 'banjul'], fr: 'la Gambie', en: 'Gambia', code: 'GM', kind: 'wa'),
    (tokens: ['mauritanie', 'nouakchott'], fr: 'la Mauritanie', en: 'Mauritania', code: 'MR', kind: 'wa'),
    (tokens: ['afrique de l ouest', 'west africa', 'cedeao', 'ecowas', 'uemoa'], fr: "l'Afrique de l'Ouest", en: 'West Africa', code: null, kind: 'wa'),
    // Reste de l'Afrique
    (tokens: ['cameroun', 'cameroon', 'douala', 'yaounde'], fr: 'le Cameroun', en: 'Cameroon', code: 'CM', kind: 'africa'),
    (tokens: ['gabon', 'libreville'], fr: 'le Gabon', en: 'Gabon', code: 'GA', kind: 'africa'),
    (tokens: ['congo', 'rdc', 'kinshasa', 'brazzaville'], fr: 'le Congo', en: 'Congo', code: 'CG', kind: 'africa'),
    (tokens: ['maroc', 'morocco', 'casablanca', 'rabat'], fr: 'le Maroc', en: 'Morocco', code: 'MA', kind: 'africa'),
    (tokens: ['algerie', 'algeria', 'alger'], fr: "l'Algérie", en: 'Algeria', code: 'DZ', kind: 'africa'),
    (tokens: ['tunisie', 'tunisia', 'tunis'], fr: 'la Tunisie', en: 'Tunisia', code: 'TN', kind: 'africa'),
    (tokens: ['egypte', 'egypt', 'le caire', 'cairo'], fr: "l'Égypte", en: 'Egypt', code: 'EG', kind: 'africa'),
    (tokens: ['kenya', 'nairobi'], fr: 'le Kenya', en: 'Kenya', code: 'KE', kind: 'africa'),
    (tokens: ['afrique du sud', 'south africa', 'johannesburg', 'le cap'], fr: "l'Afrique du Sud", en: 'South Africa', code: 'ZA', kind: 'africa'),
    (tokens: ['afrique', 'africa', 'africain', 'africaine', 'african'], fr: "l'Afrique", en: 'Africa', code: null, kind: 'africa'),
    // Reste du monde
    (tokens: ['france', 'paris', 'lyon', 'marseille'], fr: 'la France', en: 'France', code: 'FR', kind: 'world'),
    (tokens: ['belgique', 'belgium', 'bruxelles'], fr: 'la Belgique', en: 'Belgium', code: 'BE', kind: 'world'),
    (tokens: ['suisse', 'switzerland', 'geneve'], fr: 'la Suisse', en: 'Switzerland', code: 'CH', kind: 'world'),
    (tokens: ['allemagne', 'germany', 'berlin'], fr: "l'Allemagne", en: 'Germany', code: 'DE', kind: 'world'),
    (tokens: ['espagne', 'spain', 'madrid'], fr: "l'Espagne", en: 'Spain', code: 'ES', kind: 'world'),
    (tokens: ['italie', 'italy', 'rome'], fr: "l'Italie", en: 'Italy', code: 'IT', kind: 'world'),
    (tokens: ['portugal', 'lisbonne', 'lisbon'], fr: 'le Portugal', en: 'Portugal', code: 'PT', kind: 'world'),
    (tokens: ['royaume uni', 'united kingdom', 'uk', 'angleterre', 'england', 'londres', 'london'], fr: 'le Royaume-Uni', en: 'the United Kingdom', code: 'GB', kind: 'world'),
    (tokens: ['canada', 'montreal', 'quebec', 'toronto'], fr: 'le Canada', en: 'Canada', code: 'CA', kind: 'world'),
    (tokens: ['etats unis', 'usa', 'united states', 'new york'], fr: 'les États-Unis', en: 'the United States', code: 'US', kind: 'world'),
    (tokens: ['chine', 'china', 'pekin', 'beijing'], fr: 'la Chine', en: 'China', code: 'CN', kind: 'world'),
    (tokens: ['inde', 'india', 'delhi', 'mumbai'], fr: "l'Inde", en: 'India', code: 'IN', kind: 'world'),
    (tokens: ['dubai', 'emirats', 'uae'], fr: 'les Émirats', en: 'the UAE', code: 'AE', kind: 'world'),
    (tokens: ['bresil', 'brazil'], fr: 'le Brésil', en: 'Brazil', code: 'BR', kind: 'world'),
    // Continents et expressions génériques
    (tokens: ['europe', 'europeen', 'europeenne', 'european'], fr: "l'Europe", en: 'Europe', code: null, kind: 'world'),
    (tokens: ['asie', 'asia', 'asiatique'], fr: "l'Asie", en: 'Asia', code: null, kind: 'world'),
    (tokens: ['amerique', 'america', 'americas'], fr: "l'Amérique", en: 'the Americas', code: null, kind: 'world'),
    (tokens: ['oceanie', 'oceania', 'australie', 'australia'], fr: "l'Océanie", en: 'Oceania', code: null, kind: 'world'),
    (tokens: ['etranger', 'abroad', 'overseas', 'international', 'worldwide'], fr: "l'étranger", en: 'abroad', code: null, kind: 'abroad'),
  ];

  static const _kindPriority = {'togo': 4, 'wa': 3, 'africa': 2, 'world': 1, 'abroad': 0};

  /// Cherche un lieu dans la question. Si plusieurs lieux sont cités
  /// (« je vis en France, bien à Lomé »), le plus proche de la zone
  /// principale gagne (Togo > Afrique de l'Ouest > Afrique > reste du monde),
  /// puis le jeton le plus long.
  static GeoMention? detectGeo(String query) {
    final padded = ' ${normalize(query)} ';
    GeoMention? best;
    var bestPrio = -1;
    var bestLen = 0;
    for (final p in _places) {
      for (final t in p.tokens) {
        if (!_has(padded, t)) continue;
        final prio = _kindPriority[p.kind] ?? 0;
        if (prio > bestPrio || (prio == bestPrio && t.length > bestLen)) {
          bestPrio = prio;
          bestLen = t.length;
          best = GeoMention(
            kind: p.kind,
            labelFr: p.fr,
            labelEn: p.en,
            code: p.code,
            token: t,
          );
        }
      }
    }
    return best;
  }

  // ───────────────────────────────────────────────────────────────────────
  // Détection du sujet
  // ───────────────────────────────────────────────────────────────────────
  // Mots de type de bien : sert à ne PAS confondre une recherche de bien
  // (« appartement à Accra ») avec une question sur la plateforme.
  static const _propertyWords = [
    'maison', 'villa', 'appartement', 'studio', 'chambre', 'terrain', 'parcelle',
    'voiture', 'moto', 'camion', 'bureau', 'boutique', 'magasin', 'entrepot',
    'hotel', 'house', 'apartment', 'flat', 'car', 'land', 'office', 'shop',
    'room', 'warehouse',
  ];
  static const _platformWords = [
    'velqix', 'velqia', 'plateforme', 'platform', 'application', 'appli', 'app',
    'site', 'service', 'services', 'vous', 'you', 'premium', 'abonnement',
    'compte', 'account', 'inscription', 'paiement', 'publier',
  ];
  static const _coverageWords = [
    'disponible', 'disponibles', 'available', 'accepte', 'accepted', 'utiliser',
    'use', 'ouvert', 'possible', 'operate', 'operates', 'cover', 'covers',
  ];
  static const _coverageStrong = [
    'marche', 'fonctionne', 'fonctionnez', 'works', 'work', 'couvre', 'couvrez',
  ];
  static const _enCues = [
    'the', 'is', 'in', 'do', 'does', 'you', 'can', 'my', 'how', 'what', 'are',
    'available', 'work', 'works', 'to', 'for', 'of', 'i',
  ];
  static const _frCues = [
    'le', 'la', 'les', 'est', 'dans', 'vous', 'peut', 'mon', 'ma', 'comment',
    'quel', 'quels', 'quelle', 'au', 'en', 'de', 'des', 'je', 'ca', 'il',
  ];

  static String _guessLang(String normalized, {String defaultLang = 'fr'}) {
    final words = normalized.split(' ');
    final en = words.where(_enCues.contains).length;
    final fr = words.where(_frCues.contains).length;
    if (en > fr) return 'en';
    if (fr > en) return 'fr';
    return defaultLang;
  }

  /// Renvoie le sujet de plateforme correspondant à la question, ou null si
  /// c'est une recherche de bien / une question hors base (→ le serveur IA
  /// répond). [defaultLang] sert seulement à départager.
  static PlatformMatch? match(String query, {String defaultLang = 'fr'}) {
    final n = normalize(query);
    if (n.isEmpty) return null;
    final padded = ' $n ';
    final geo = detectGeo(query);

    // 1) Sujet explicite (expressions précises, pas de mots ambigus)
    String? bestTopic;
    String bestLang = defaultLang;
    var bestScore = 0;
    for (final t in _topics) {
      final sf = _score(padded, t.fr);
      final se = _score(padded, t.en);
      final s = sf >= se ? sf : se;
      if (s > bestScore) {
        bestScore = s;
        bestTopic = t.id;
        bestLang = sf >= se ? 'fr' : 'en';
        if (sf == se) bestLang = _guessLang(n, defaultLang: defaultLang);
      }
    }
    if (bestTopic != null && bestScore > 0) {
      return PlatformMatch(bestTopic, bestLang, geo);
    }

    // 2) « Est-ce que ça marche / est disponible à <lieu> ? »
    final hasProperty = _any(padded, _propertyWords);
    final hasPlatform = _any(padded, _platformWords);
    if (geo != null) {
      final strong = _any(padded, _coverageStrong);
      final weak = _any(padded, _coverageWords);
      final asksCoverage = (strong && (!hasProperty || hasPlatform)) ||
          (weak && hasPlatform);
      if (asksCoverage) {
        return PlatformMatch(
            'coverage', _guessLang(n, defaultLang: defaultLang), geo);
      }
    }
    return null;
  }

  // ───────────────────────────────────────────────────────────────────────
  // Rendu
  // ───────────────────────────────────────────────────────────────────────
  /// [premiumLine] : tarifs lus sur le serveur (ex. « 1 mois : 2 000 FCFA »).
  /// [coverageLine] : zones desservies lues sur le serveur.
  static String render(
    PlatformMatch m, {
    String? premiumLine,
    String? coverageLine,
  }) {
    final fr = m.lang == 'fr';
    final t = _topics.firstWhere((t) => t.id == m.topic);
    var out = fr ? t.textFr : t.textEn;

    out = out.replaceAll(
      '{premium}',
      premiumLine ??
          (fr
              ? 'Tarif : affiché dans Profil → Premium (il peut évoluer).'
              : 'Price: shown in Profile → Premium (it may change).'),
    );

    final g = m.geo;
    if (g != null && (t.geo || m.topic == 'coverage')) {
      out += '\n\n${_geoText(g, fr, m.topic)}';
    }
    if (coverageLine != null && coverageLine.isNotEmpty) {
      out += '\n\n$coverageLine';
    }
    return out;
  }

  static String _geoText(GeoMention g, bool fr, String topic) {
    final raw = fr ? g.labelFr : g.labelEn;
    final label = raw[0].toUpperCase() + raw.substring(1);
    final payNote = (topic == 'premium' || topic == 'payment')
        ? (fr
            ? '\nLes moyens de paiement proposés dépendent de votre pays : ils s\'affichent sur la page de paiement sécurisée.'
            : '\nThe payment methods offered depend on your country: they are shown on the secure payment page.')
        : '';

    switch (g.kind) {
      case 'togo':
        return fr
            ? '📍 **$label** : VelQix est soumise au droit togolais (litiges : tribunaux de Lomé). Les prix s\'affichent en FCFA par défaut, et vous pouvez chercher par ville. Les services terrain (vérification, visites, entretien) ne sont disponibles que dans les zones desservies : elles sont confirmées au moment de la demande.$payNote'
            : '📍 **$label**: VelQix is governed by Togolese law (disputes: Lomé courts). Prices show in FCFA by default and you can search by city. Field services (verification, visits, maintenance) are only available in served zones, confirmed when you make a request.$payNote';
      case 'wa':
        return fr
            ? '📍 **$label** : VelQix est conçue pour l\'Afrique de l\'Ouest. Choisissez votre pays à l\'inscription (Profil → Changer de pays ensuite), publiez et consultez des annonces, et affichez les prix dans votre devise. Je ne peux pas garantir qu\'il y a déjà des annonces dans votre ville : lancez une recherche pour le vérifier. Les services terrain dépendent des zones desservies.$payNote'
            : '📍 **$label**: VelQix is built for West Africa. Pick your country when signing up (Profile → Change country later), post and browse listings, and show prices in your currency. I can\'t promise listings already exist in your city: run a search to check. Field services depend on served zones.$payNote';
      case 'africa':
        return fr
            ? '📍 **$label** : vous pouvez créer un compte en choisissant votre pays dans la liste d\'inscription. La plateforme est d\'abord pensée pour l\'Afrique de l\'Ouest : les annonces et les services terrain (vérification, visites, entretien) peuvent y être limités ou absents.$payNote'
            : '📍 **$label**: you can create an account by picking your country in the sign-up list. The platform is designed first for West Africa: listings and field services (verification, visits, maintenance) may be limited or unavailable there.$payNote';
      case 'world':
        return fr
            ? '📍 **$label** : vous pouvez consulter VelQix et créer un compte depuis là-bas (diaspora comprise). Les biens et les services terrain concernent surtout l\'Afrique de l\'Ouest : pour un bien situé en Afrique, faites vérifier l\'annonce sur le terrain avant tout paiement.$payNote'
            : '📍 **$label**: you can browse VelQix and create an account from there (diaspora included). Listings and field services mostly concern West Africa: for a property in Africa, have the listing verified on the ground before paying anything.$payNote';
      default:
        return fr
            ? '📍 **Depuis l\'étranger** : le compte et la consultation fonctionnent depuis n\'importe quel pays. Les biens et les services terrain concernent surtout l\'Afrique de l\'Ouest. Faites vérifier le bien sur le terrain avant tout paiement.$payNote'
            : '📍 **From abroad**: your account and browsing work from any country. Listings and field services mostly concern West Africa. Have the property verified on the ground before paying anything.$payNote';
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // Sujets (l'ordre départage les égalités : le plus spécifique d'abord)
  // ───────────────────────────────────────────────────────────────────────
  static const List<_Topic> _topics = [
    _Topic(
      'report',
      ['signaler*', 'signalement*', 'annonce suspecte', 'annonce frauduleuse'],
      ['report a listing', 'report listing', 'report an ad', 'suspicious listing'],
      '🚩 **Signaler une annonce**\n'
          'Ouvrez la fiche du bien → « Signaler l\'annonce », puis choisissez un motif :\n'
          '• déjà loué\n• bien introuvable\n• annonce trompeuse\n• prix incorrect\n• annonceur suspect\n• infos ou photos erronées\n\n'
          'L\'équipe examine chaque signalement ; un signalement isolé n\'entraîne pas de sanction automatique.',
      '🚩 **Report a listing**\n'
          'Open the listing → « Report the listing », then pick a reason:\n'
          '• already rented\n• property not found\n• misleading listing\n• wrong price\n• suspicious advertiser\n• wrong info or photos\n\n'
          'The team reviews every report; a single report does not trigger an automatic sanction.',
    ),
    _Topic(
      'trust',
      [
        'annonce verifiee', 'bien verifie', 'badge verifie', 'verifie sur le terrain',
        'verifie par velqix', 'approuve par velqix', 'signifie verifie', 'que veut dire verifie',
      ],
      ['verified badge', 'verified listing', 'field verified', 'what does verified mean', 'verified by velqix'],
      '✅ **Annonce « vérifiée »**\n'
          'Le badge signifie qu\'un démarcheur VelQix a contrôlé le bien sur le terrain : il existe, les photos correspondent et l\'annonceur est identifié. La date, l\'agent et le périmètre sont affichés sur la fiche.\n\n'
          '⚠️ Ce n\'est pas une preuve de propriété ni une garantie contre la fraude. Premium ou un paiement ne donne jamais ce badge. Une annonce sans badge a simplement été validée par la modération avant publication.',
      '✅ **« Verified » listing**\n'
          'The badge means a VelQix field agent checked the property on site: it exists, the photos match and the advertiser is identified. The date, agent and scope are shown on the listing.\n\n'
          '⚠️ It is not proof of ownership nor a guarantee against fraud. Premium or any payment never gives this badge. A listing without a badge was simply approved by moderation before publication.',
      geo: true,
    ),
    _Topic(
      'premium',
      ['premium', 'abonnement*', 'forfait*', 'tarif*', 'souscrire', 'devenir premium'],
      ['premium', 'subscription', 'subscribe', 'pricing', 'membership'],
      '💎 **Premium**\n{premium}\n\n'
          'Ce que Premium apporte :\n'
          '• jusqu\'à 12 photos par annonce (2 en gratuit)\n'
          '• statistiques de consultation détaillées\n'
          '• alertes personnalisables, gestion étendue de plusieurs biens\n'
          '• avantages ou crédits de mise en avant selon le forfait\n\n'
          '⚠️ Premium ne rend pas une annonce « vérifiée » et n\'est pas une garantie : seule la vérification terrain donne ce statut.\n\n'
          'Où : Profil → Premium. Paiement en ligne via FedaPay ; le statut est activé par le serveur après confirmation du paiement. Entreprises et agences : formules dédiées dans le même écran (Plans).',
      '💎 **Premium**\n{premium}\n\n'
          'What Premium gives you:\n'
          '• up to 12 photos per listing (2 on the free plan)\n'
          '• detailed view statistics\n'
          '• customizable alerts, extended management of several properties\n'
          '• boost benefits or credits depending on the plan\n\n'
          '⚠️ Premium does not make a listing « verified » and is not a guarantee: only the field verification gives that status.\n\n'
          'Where: Profile → Premium. Paid online through FedaPay; the status is activated by the server once the payment is confirmed. Companies and agencies: dedicated plans in the same screen.',
      geo: true,
    ),
    _Topic(
      'services',
      [
        'verification*', 'verifier un bien', 'verifier une annonce', 'visite accompagnee',
        'visites accompagnees', 'entretien', 'demarcheur*', 'agent d entretien',
        'demander un service', 'services payants', 'mission*',
      ],
      [
        'verification*', 'verify a property', 'verify a listing', 'guided visit',
        'accompanied visit', 'maintenance', 'field agent', 'request a service', 'paid services',
      ],
      '🛠️ **Services VelQix (payants, à la prestation)**\n'
          '• **Vérification terrain** : un démarcheur contrôle que le bien existe, que les photos correspondent et que l\'annonceur est identifié. Prix fixe selon la zone.\n'
          '• **Visite accompagnée** et **entretien** : sur devis.\n\n'
          'Comment : bouton « Demander un service » sur la fiche d\'une annonce ; suivi dans Profil → Mes demandes de services ; paiement en ligne (FedaPay). Ces services sont séparés de l\'abonnement Premium. Le prix exact et la disponibilité dépendent de la zone.',
      '🛠️ **VelQix services (paid per service)**\n'
          '• **Field verification**: an agent checks the property exists, the photos match and the advertiser is identified. Fixed price depending on the zone.\n'
          '• **Guided visit** and **maintenance**: on quote.\n\n'
          'How: « Request a service » button on a listing; follow-up in Profile → My service requests; paid online (FedaPay). These services are separate from the Premium subscription. Exact price and availability depend on the zone.',
      geo: true,
    ),
    _Topic(
      'diaspora',
      [
        'diaspora', 'a l etranger', 'depuis l etranger', 'acheter a distance', 'a distance',
        'je vis en', 'je vis a', 'j habite en', 'je suis en france', 'vivant a l etranger',
      ],
      ['from abroad', 'overseas', 'abroad', 'remotely', 'buy remotely', 'i live in', 'i am abroad', 'i m abroad'],
      '✈️ **Chercher un bien depuis l\'étranger**\n'
          '1. Créez un compte (choisissez votre pays) et parcourez les annonces.\n'
          '2. Contactez l\'annonceur par messagerie ou appel vidéo dans l\'app.\n'
          '3. Avant tout paiement, demandez une **vérification terrain** et, si besoin, une **visite accompagnée** (si votre zone est desservie).\n'
          '4. Ne payez jamais d\'avance à quelqu\'un que vous n\'avez pas pu identifier ; Premium n\'est pas un gage de fiabilité.',
      '✈️ **Looking for a property from abroad**\n'
          '1. Create an account (pick your country) and browse listings.\n'
          '2. Contact the advertiser through messaging or video call in the app.\n'
          '3. Before any payment, request a **field verification** and, if needed, a **guided visit** (if the zone is served).\n'
          '4. Never pay in advance someone you could not identify; Premium is not a reliability guarantee.',
      geo: true,
    ),
    _Topic(
      'safety',
      [
        'arnaque*', 'fraude*', 'escroc*', 'plateforme fiable', 'plateforme securisee',
        'est ce fiable', 'est ce sur', 'faire confiance', 'garantie*', 'assurance',
        'securite de la plateforme',
      ],
      ['scam*', 'fraud*', 'is it safe', 'is velqix safe', 'is it reliable', 'can i trust', 'guarantee*', 'insurance'],
      '🛡️ **Rester en sécurité sur VelQix**\n'
          'Ce que VelQix fait : modération de chaque annonce avant publication, avis et notes, signalement des annonces, vérification terrain en option.\n'
          'Ce qu\'elle ne fait pas : elle ne garantit pas les transactions entre utilisateurs et ne propose pas d\'assurance sur les paiements.\n\n'
          'Bons réflexes :\n'
          '• ne payez rien avant d\'avoir vu le bien ou fait vérifier l\'annonce\n'
          '• méfiez-vous des prix anormalement bas et des demandes d\'avance urgentes\n'
          '• gardez vos échanges dans l\'app\n'
          '• signalez toute annonce suspecte',
      '🛡️ **Staying safe on VelQix**\n'
          'What VelQix does: moderation of every listing before publication, reviews and ratings, listing reports, optional field verification.\n'
          'What it does not do: it does not guarantee transactions between users and offers no payment insurance.\n\n'
          'Good habits:\n'
          '• pay nothing before seeing the property or having the listing verified\n'
          '• beware of unusually low prices and urgent advance-payment requests\n'
          '• keep your conversations in the app\n'
          '• report any suspicious listing',
      geo: true,
    ),
    _Topic(
      'publish',
      [
        'publier*', 'poster une annonce', 'poster un bien', 'ajouter un bien', 'ajouter une annonce',
        'deposer une annonce', 'mettre en location', 'mettre en vente', 'creer une annonce',
        'passer une annonce',
      ],
      ['publish', 'post a listing', 'post an ad', 'add a listing', 'list my property', 'create a listing', 'rent out', 'sell my'],
      '📝 **Publier une annonce**\n'
          'Connectez-vous → « + » (Ajouter un bien) → titre, catégorie, prix, adresse (pays et ville), photos (2 gratuites, 12 avec Premium), vidéo facultative (30 Mo max) → soumettez.\n\n'
          'L\'équipe valide l\'annonce avant sa mise en ligne. La publication de base est gratuite.\n'
          'Catégories : maison, appartement, hôtel, terrain, bureau, entrepôt, chambre, studio, local commercial ; véhicules : voiture, moto, camion.',
      '📝 **Post a listing**\n'
          'Sign in → « + » (Add a property) → title, category, price, address (country and city), photos (2 free, 12 with Premium), optional video (30 MB max) → submit.\n\n'
          'The team approves the listing before it goes live. Basic posting is free.\n'
          'Categories: house, apartment, hotel, land, office, warehouse, room, studio, commercial space; vehicles: car, motorbike, truck.',
      geo: true,
    ),
    _Topic(
      'support',
      [
        'contacter le support', 'contacter velqix', 'joindre velqix', 'service client',
        'probleme technique', 'besoin d aide', 'aide urgente', 'whatsapp', 'assistance',
        'numero de velqix', 'email de velqix',
      ],
      ['customer service', 'customer support', 'technical problem', 'need help', 'contact support', 'contact velqix', 'assistance'],
      '🆘 **Support VelQix**\n'
          'Profil → Support & Aide.\n'
          '• Email : smartinnovators294@gmail.com\n'
          '• WhatsApp : +228 99 42 40 87 (pour les urgences)\n'
          'Réponse en général sous 24 à 48 h. Pour une annonce douteuse, utilisez plutôt « Signaler l\'annonce ».',
      '🆘 **VelQix support**\n'
          'Profile → Support & Help.\n'
          '• Email: smartinnovators294@gmail.com\n'
          '• WhatsApp: +228 99 42 40 87 (for urgent matters)\n'
          'Usually answered within 24 to 48 h. For a doubtful listing, use « Report the listing » instead.',
      geo: true,
    ),
    _Topic(
      'contact',
      [
        'contacter le proprietaire', 'contacter un proprietaire', 'contacter le vendeur',
        'contacter un vendeur', 'contacter l annonceur', 'joindre le proprietaire',
        'joindre le vendeur', 'comment contacter', 'envoyer un message', 'appeler le proprietaire',
        'numero du proprietaire', 'messagerie', 'appel video', 'appel audio',
      ],
      [
        'contact the owner', 'contact the seller', 'contact owner', 'message the owner',
        'call the owner', 'messaging', 'video call', 'audio call', 'chat with',
      ],
      '💬 **Contacter un propriétaire ou un vendeur**\n'
          'Ouvrez la fiche du bien → « Contacter » : message texte ou vocal, et appels audio ou vidéo directement dans l\'app. Si l\'annonceur affiche son numéro, vous pouvez aussi l\'appeler.\n'
          'Toutes vos conversations sont dans l\'onglet Messagerie, avec notification en temps réel.',
      '💬 **Contacting an owner or seller**\n'
          'Open the listing → « Contact »: text or voice message, and audio or video calls right in the app. If the advertiser shows a phone number, you can call it too.\n'
          'All your conversations are in the Messages tab, with real-time notifications.',
    ),
    _Topic(
      'availability',
      [
        'disponibilite*', 'visite*', 'confirmer la disponibilite', 'demander une confirmation',
        'toujours disponible', 'statut de disponibilite', 'deja loue',
      ],
      [
        'availability status', 'request a visit', 'schedule a visit', 'book a visit',
        'still available', 'confirm availability',
      ],
      '📅 **Disponibilité et visites**\n'
          'Chaque annonce affiche un statut de disponibilité avec la date de l\'information. « Confirmée » n\'apparaît que si l\'annonceur l\'a confirmé : un silence n\'est jamais une confirmation.\n\n'
          'Depuis la fiche : « Demander une confirmation » ou « Organiser une visite ». Le suivi (demandes reçues et envoyées, créneaux proposés) est dans Profil → Visites et confirmations.',
      '📅 **Availability and visits**\n'
          'Every listing shows an availability status with the date of the information. « Confirmed » only appears if the advertiser confirmed it: silence is never a confirmation.\n\n'
          'From the listing: « Request confirmation » or « Arrange a visit ». Follow-up (received and sent requests, proposed slots) is in Profile → Visits and confirmations.',
      geo: true,
    ),
    _Topic(
      'payment',
      [
        'payer', 'paiement*', 'fedapay', 'mobile money', 'moyens de paiement', 'carte bancaire',
        'rembourse*', 'orange money', 'flooz', 'tmoney', 't money', 'mtn',
      ],
      ['payment*', 'pay', 'fedapay', 'mobile money', 'payment methods', 'bank card', 'refund*'],
      '💳 **Paiements**\n'
          'Dans l\'application, les paiements en ligne (FedaPay, page sécurisée hébergée) servent à régler Premium et les services VelQix (vérification, visite, entretien). Le montant est toujours calculé par le serveur.\n\n'
          'Le prix d\'un bien ou le loyer se convient avec l\'annonceur : ne payez jamais avant d\'avoir vu le bien ou fait vérifier l\'annonce.',
      '💳 **Payments**\n'
          'In the app, online payments (FedaPay, hosted secure page) are used for Premium and VelQix services (verification, visit, maintenance). The amount is always computed by the server.\n\n'
          'A property price or rent is agreed with the advertiser: never pay before seeing the property or having the listing verified.',
      geo: true,
    ),
    _Topic(
      'account_types',
      [
        'compte entreprise', 'compte professionnel', 'compte pro', 'espace entreprise',
        'espace professionnel', 'formule agence', 'devenir demarcheur', 'devenir proprietaire',
        'quels profils', 'quels roles', 'role*',
      ],
      ['business account', 'company account', 'become an owner', 'become an agent', 'roles', 'account types'],
      '👤 **Profils sur VelQix**\n'
          '• **Client** : cherche, contacte, met en favori.\n'
          '• **Propriétaire** : publie et gère des annonces.\n'
          '• **Entreprise / agence** : espace dédié et formules agence (écran Plans).\n'
          '• **Démarcheur** (VelQix Agent) et **Agent d\'entretien** (VelQix Services) : réalisent les missions payantes ; ces deux rôles sont attribués par l\'administration, pas à l\'inscription.',
      '👤 **Profiles on VelQix**\n'
          '• **Client**: searches, contacts, saves favorites.\n'
          '• **Owner**: posts and manages listings.\n'
          '• **Company / agency**: dedicated space and agency plans (Plans screen).\n'
          '• **Field agent** (VelQix Agent) and **Maintenance agent** (VelQix Services): carry out the paid missions; these two roles are assigned by the administration, not at sign-up.',
      geo: true,
    ),
    _Topic(
      'coverage',
      [
        'quels pays', 'dans quels pays', 'quelles villes', 'dans quelles villes', 'pays disponibles',
        'pays couverts', 'dans mon pays', 'mon pays', 'zones desservies', 'zone de couverture',
      ],
      ['which countries', 'what countries', 'which cities', 'my country', 'countries available', 'served zones', 'coverage'],
      '🌍 **Où VelQix est-il disponible ?**\n'
          '• Conçue pour l\'Afrique de l\'Ouest, avec le Togo comme point de départ (FCFA par défaut).\n'
          '• L\'inscription est possible depuis de nombreux pays : choisissez le vôtre dans la liste.\n'
          '• Les annonces visibles dépendent des biens publiés dans chaque ville : cherchez par ville ou par pays.\n'
          '• Les services terrain (vérification, visites, entretien) ne sont proposés que dans les zones desservies.',
      '🌍 **Where is VelQix available?**\n'
          '• Built for West Africa, with Togo as the starting point (FCFA by default).\n'
          '• Sign-up is possible from many countries: pick yours in the list.\n'
          '• Visible listings depend on the properties posted in each city: search by city or country.\n'
          '• Field services (verification, visits, maintenance) are only offered in served zones.',
    ),
    _Topic(
      'favorites',
      ['favori*', 'coup de coeur', 'sauvegarder une annonce', 'mettre de cote', 'liste de souhaits'],
      ['favorite*', 'favourite*', 'wishlist', 'save a listing', 'save listing'],
      '❤️ **Favoris**\nAppuyez sur le cœur d\'une fiche pour l\'ajouter. Retrouvez-les dans Profil → Favoris ; même geste pour les retirer.',
      '❤️ **Favorites**\nTap the heart on a listing to add it. Find them in Profile → Favorites; same gesture to remove them.',
    ),
    _Topic(
      'follow',
      ['suivre un proprietaire', 'suivre un vendeur', 'suivre un annonceur', 'ne plus suivre', 'abonner a un proprietaire'],
      ['follow an owner', 'follow a seller', 'follow owner', 'unfollow'],
      '👥 **Suivre un propriétaire**\nSur son profil, appuyez sur « Suivre » pour être informé de ses nouvelles annonces ; « Ne plus suivre » au même endroit pour arrêter.',
      '👥 **Following an owner**\nOn their profile, tap « Follow » to be informed of their new listings; « Unfollow » in the same place to stop.',
    ),
    _Topic(
      'reviews',
      [
        'laisser un avis', 'donner un avis', 'noter un bien', 'noter une annonce', 'avis et notes',
        'systeme d avis', 'note et avis', 'commentaire sur une annonce',
      ],
      ['leave a review', 'write a review', 'rate a listing', 'reviews and ratings', 'rating system'],
      '⭐ **Avis et notes**\nLes utilisateurs peuvent noter un bien et laisser un avis, visibles sur la fiche. C\'est un indice utile sur le sérieux d\'une annonce ou d\'un propriétaire, mais pas une garantie.',
      '⭐ **Reviews and ratings**\nUsers can rate a property and leave a review, visible on the listing. It is a useful hint about how serious a listing or owner is, but not a guarantee.',
    ),
    _Topic(
      'notifications',
      [
        'notification*', 'notifs', 'creer une alerte', 'recevoir une alerte',
        'recevoir des alertes', 'alertes personnalisees',
      ],
      ['notification*', 'alerts', 'get alerts'],
      '🔔 **Notifications**\nVous êtes notifié (badge sur la cloche, push sur mobile) des nouveaux messages, appels, demandes de visite et changements de statut. L\'historique est dans la cloche, en haut de l\'écran. Des alertes personnalisables sont incluses avec Premium.',
      '🔔 **Notifications**\nYou are notified (bell badge, mobile push) of new messages, calls, visit requests and status changes. The history is under the bell at the top of the screen. Customizable alerts come with Premium.',
    ),
    _Topic(
      'account',
      [
        'mot de passe', 'modifier mon profil', 'changer mon email', 'changer mon telephone',
        'gerer mon compte', 'supprimer mon compte', 'creer un compte', 'inscription', 's inscrire',
        'me connecter', 'changer de pays',
      ],
      [
        'password', 'edit my profile', 'change my email', 'delete my account', 'create an account',
        'sign up', 'register', 'log in', 'login', 'forgot password', 'change country',
      ],
      '🔐 **Mon compte**\n• Inscription : email, Google ou Facebook ; choisissez votre pays dans la liste.\n• Profil → Modifier le profil : nom, email, téléphone ; changement de mot de passe ; changement de pays.\n• Mot de passe oublié : lien sur l\'écran de connexion.',
      '🔐 **My account**\n• Sign-up: email, Google or Facebook; pick your country in the list.\n• Profile → Edit profile: name, email, phone; password change; country change.\n• Forgot password: link on the sign-in screen.',
      geo: true,
    ),
    _Topic(
      'language',
      ['langue*', 'devise*', 'monnaie', 'mode sombre', 'changer la langue', 'changer de devise'],
      ['language*', 'currency', 'currencies', 'dark mode', 'change language'],
      '🌐 **Langues et devises**\nL\'application existe en 6 langues (français, anglais, espagnol, portugais, allemand, arabe), avec 4 devises (FCFA par défaut) et un mode sombre. Les prix sont enregistrés en FCFA et convertis à l\'affichage ; la conversion est indicative.',
      '🌐 **Languages and currencies**\nThe app comes in 6 languages (French, English, Spanish, Portuguese, German, Arabic), with 4 currencies (FCFA by default) and a dark mode. Prices are stored in FCFA and converted for display; the conversion is indicative.',
      geo: true,
    ),
    _Topic(
      'about',
      [
        'c est quoi velqix', 'qu est ce que velqix', 'a quoi sert velqix', 'presentation de velqix',
        'qui est velqix', 'comment ca marche', 'comment fonctionne velqix', 'comment utiliser velqix',
        'que peut faire velqia', 'qui es tu',
      ],
      [
        'what is velqix', 'about velqix', 'how does velqix work', 'how does it work',
        'how to use velqix', 'who are you',
      ],
      '🏠 **VelQix** est une plateforme de location et de vente de biens (immobilier, véhicules) pour l\'Afrique de l\'Ouest : annonces modérées, messagerie et appels intégrés, avis et notes, vérification terrain en option, abonnement Premium.\n\nDites-moi ce que vous cherchez (type de bien, ville, budget), ou posez-moi une question sur le fonctionnement de la plateforme.',
      '🏠 **VelQix** is a rental and sales platform (real estate, vehicles) for West Africa: moderated listings, built-in messaging and calls, reviews and ratings, optional field verification, Premium subscription.\n\nTell me what you are looking for (property type, city, budget), or ask me anything about how the platform works.',
      geo: true,
    ),
  ];
}
