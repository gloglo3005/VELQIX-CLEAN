import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/models.dart';
import '../services/mock_data.dart';
import '../theme/app_theme.dart';
import '../screens/property_detail_screen.dart';
// ignore: unused_import
import '../services/app_translations.dart';
import '../main.dart' show localeNotifier;
import 'widgets.dart'; // publishedPropertiesNotifier

// ─────────────────────────────────────────────────────────────────────────────
// Modèle de message
// ─────────────────────────────────────────────────────────────────────────────
enum _MsgType { user, ai, properties, typing }

class _ChatMessage {
  final _MsgType type;
  final String? text;
  final List<PropertyModel>? properties;
  final DateTime time;

  _ChatMessage({required this.type, this.text, this.properties})
      : time = DateTime.now();
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget principal – bouton flottant + panneau
// ─────────────────────────────────────────────────────────────────────────────
class AiAssistantWidget extends StatefulWidget {
  const AiAssistantWidget({super.key});

  @override
  State<AiAssistantWidget> createState() => _AiAssistantWidgetState();
}

class _AiAssistantWidgetState extends State<AiAssistantWidget>
    with TickerProviderStateMixin {
  bool _isOpen = false;
  bool _hasGreeted = false;
  bool _isTyping = false;

  // ── Reconnaissance vocale Web Speech API ──────────────────────────────
  bool _isListening = false;
  bool _speechAvailable = false;
  String _voicePartial = '';
  late AnimationController _micPulseAnim;
  final stt.SpeechToText _speech = stt.SpeechToText();

  final List<_ChatMessage> _messages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  late AnimationController _fabAnim;
  late AnimationController _pulseAnim;
  late AnimationController _panelAnim;
  late Animation<double> _panelScale;
  late Animation<double> _panelOpacity;

  // Suggestions rapides
  final List<Map<String, String>> _suggestions = [
    {'label': '🏠 Maison à Lomé', 'query': 'Maison à Lomé'},
    {'label': '🚗 Voiture à louer', 'query': 'Voiture à louer'},
    {'label': '🏢 Appartement meublé', 'query': 'Appartement meublé'},
    {'label': '🌍 Bien au Togo', 'query': 'Bien disponible au Togo'},
  ];

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _pulseAnim = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _panelAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _panelScale = CurvedAnimation(parent: _panelAnim, curve: Curves.easeOutBack);
    _panelOpacity = CurvedAnimation(parent: _panelAnim, curve: Curves.easeOut);
    _micPulseAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fabAnim.forward();
    _initSpeech();
  }

  /// Initialise la reconnaissance vocale
  void _initSpeech() {
    _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == stt.SpeechToText.doneStatus ||
            status == stt.SpeechToText.notListeningStatus) {
          final captured = _voicePartial.isNotEmpty ? _voicePartial : _inputCtrl.text.trim();
          setState(() { _isListening = false; _voicePartial = ''; });
          _micPulseAnim.stop();
          _micPulseAnim.reset();
          if (captured.isNotEmpty) {
            _inputCtrl.clear();
            // ✅ Envoi automatique dès que la voix est capturée
            Future.microtask(() => _handleQuery(captured));
          }
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() { _isListening = false; _voicePartial = ''; });
        _micPulseAnim.stop();
        _micPulseAnim.reset();
      },
    ).then((available) {
      if (mounted) setState(() => _speechAvailable = available);
    });
  }

  @override
  void dispose() {
    _fabAnim.dispose();
    _pulseAnim.dispose();
    _panelAnim.dispose();
    _micPulseAnim.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    if (_isListening) {
      _speech.stop();
    }
    super.dispose();
  }

  void _togglePanel() {
    setState(() => _isOpen = !_isOpen);
    if (_isOpen) {
      _panelAnim.forward();
      if (!_hasGreeted) {
        _hasGreeted = true;
        Future.delayed(const Duration(milliseconds: 350), _sendGreeting);
      }
    } else {
      _panelAnim.reverse();
    }
  }

  void _sendGreeting() {
    _addAiMessage(
      tr('ai_greeting'),
    );
  }

  void _addAiMessage(String text) {
    setState(() => _messages.add(_ChatMessage(type: _MsgType.ai, text: text)));
    _scrollToBottom();
  }

  void _addPropertiesMessage(List<PropertyModel> props) {
    setState(() => _messages
        .add(_ChatMessage(type: _MsgType.properties, properties: props)));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── Logique de recherche ────────────────────────────────────────────────
  // Normalise une chaîne : minuscules + suppression des accents
  String _normalize(String s) => s.toLowerCase()
      .replaceAll('é', 'e').replaceAll('è', 'e').replaceAll('ê', 'e').replaceAll('ë', 'e')
      .replaceAll('à', 'a').replaceAll('â', 'a').replaceAll('ä', 'a')
      .replaceAll('ô', 'o').replaceAll('ö', 'o')
      .replaceAll('û', 'u').replaceAll('ù', 'u').replaceAll('ü', 'u')
      .replaceAll('î', 'i').replaceAll('ï', 'i')
      .replaceAll('ç', 'c');

  List<PropertyModel> _searchProperties(String query) {
    final q = _normalize(query);
    final all = [
      ...MockDataService.properties,
      ...publishedPropertiesNotifier.value.cast<PropertyModel>(),
    ];

    // Mots vides à ignorer
    final stopWords = {'a', 'au', 'aux', 'le', 'la', 'les', 'de', 'du', 'des',
        'en', 'dans', 'sur', 'pour', 'avec', 'et', 'ou', 'un', 'une', 'ce',
        'qui', 'que', 'est', 'mon', 'ton', 'son', 'ma', 'ta', 'sa', 'nos',
        'vos', 'ses', 'par', 'si', 'il', 'je', 'tu', 'nous', 'vous', 'ils'};

    final words = q.split(' ')
        .where((w) => w.length > 2 && !stopWords.contains(w))
        .toList();

    // Mots-clés par type de bien
    final typeMap = {
      'voiture':     ['voiture', 'auto', 'automobile', 'vehicule', 'car', 'berline', 'suv', 'pickup', '4x4'],
      'moto':        ['moto', 'motocycle', 'scooter', 'bike', 'tricycle'],
      'camion':      ['camion', 'truck', 'poids lourd', 'semi'],
      'maison':      ['maison', 'villa', 'residence', 'bungalow', 'duplex', 'triplex'],
      'appartement': ['appartement', 'appart', 'studio', 'flat', 'chambre'],
      'terrain':     ['terrain', 'parcelle', 'lot', 'foncier', 'hectare'],
      'bureau':      ['bureau', 'office', 'local', 'boutique', 'magasin', 'commerce'],
      'entrepot':    ['entrepot', 'hangar', 'depot', 'stockage', 'usine'],
      'equipement':  ['equipement', 'materiel', 'machine', 'outil', 'engin'],
      'hotel':       ['hotel', 'motel', 'auberge', 'lodge', 'resort', 'hebergement'],
    };

    // Caractéristiques recherchées
    final featureWords = ['piscin', 'plage', 'mer', 'ocean', 'jardin', 'garage',
        'clim', 'meuble', 'gardien', 'generateur', 'groupe', 'neuf', 'moderne',
        'luxe', 'standing', 'securise', 'cloture', 'balcon', 'terrasse'];

    // Détecter type demandé
    String? requestedType;
    for (final entry in typeMap.entries) {
      if (entry.value.any((kw) => q.contains(kw))) {
        requestedType = entry.key;
        break;
      }
    }

    // Détecter mots géographiques (ni type ni feature ni stop)
    final allTypeWords = typeMap.values.expand((v) => v).toSet();
    final geoWords = words.where((w) =>
        !allTypeWords.any((t) => t.contains(w) || w.contains(t)) &&
        !featureWords.any((f) => f.contains(w) || w.contains(f))
    ).toList();

    // Caractéristiques demandées
    final wantsPiscine    = q.contains('piscin');
    final wantsMer        = q.contains('mer') || q.contains('plage') || q.contains('ocean') || q.contains('bord');
    final wantsJardin     = q.contains('jardin');
    final wantsGarage     = q.contains('garage');
    final wantsClimat     = q.contains('clim');
    final wantsMeuble     = q.contains('meuble');
    final wantsGardien    = q.contains('gardien');
    final wantsGenerateur = q.contains('generateur') || q.contains('groupe electro');
    final wantsLuxe       = q.contains('luxe') || q.contains('standing') || q.contains('haut gamme');
    final wantsNeuf       = q.contains('neuf') || q.contains('moderne') || q.contains('recent');

    final hasFilters = requestedType != null || geoWords.isNotEmpty ||
        wantsPiscine || wantsMer || wantsJardin || wantsGarage ||
        wantsClimat || wantsMeuble || wantsGardien || wantsGenerateur ||
        wantsLuxe || wantsNeuf;

    return all.where((p) {
      final pTitle  = _normalize(p.titre);
      final pCity   = _normalize(p.adresse.ville);
      final pPays   = _normalize(p.adresse.pays);
      final pCat    = _normalize(p.categorieLabel);
      final pDesc   = _normalize(p.description);
      final pCarac  = p.caracteristiques.map(_normalize).join(' ');
      final pOwner  = _normalize(p.proprietaire.fullName); // ← nom du propriétaire
      final pAll    = '$pTitle $pCity $pPays $pCat $pDesc $pCarac $pOwner';

      // ── Filtre TYPE (strict si type détecté) ─────────────────────────────
      if (requestedType != null) {
        final typeKws = typeMap[requestedType]!;
        final matchesType = typeKws.any((kw) =>
            pCat.contains(kw) || pTitle.contains(kw));
        if (!matchesType) return false;
      }

      // ── Filtre LIEU ───────────────────────────────────────────────────────
      bool passesGeo = true;
      if (geoWords.isNotEmpty) {
        passesGeo = geoWords.any((geo) =>
            pCity.contains(geo) || pPays.contains(geo) ||
            pTitle.contains(geo) || pDesc.contains(geo));
      }
      if (!passesGeo) return false;

      // ── Filtres CARACTÉRISTIQUES (stricts) ────────────────────────────────
      if (wantsPiscine    && !pAll.contains('piscin'))                        return false;
      if (wantsMer        && !pAll.contains('mer') && !pAll.contains('plage') && !pAll.contains('ocean')) return false;
      if (wantsJardin     && !pAll.contains('jardin'))                        return false;
      if (wantsGarage     && !pAll.contains('garage'))                        return false;
      if (wantsClimat     && !pAll.contains('clim'))                          return false;
      if (wantsMeuble     && !pAll.contains('meuble'))                        return false;
      if (wantsGardien    && !pAll.contains('gardien'))                       return false;
      if (wantsGenerateur && !pAll.contains('generateur') && !pAll.contains('groupe')) return false;
      if (wantsLuxe       && !pAll.contains('luxe') && !pAll.contains('standing') && !pAll.contains('prestige')) return false;
      if (wantsNeuf       && !pAll.contains('neuf') && !pAll.contains('moderne') && !pAll.contains('recent')) return false;

      // ── Recherche par nom de propriétaire ────────────────────────────────
      if (words.any((w) => pOwner.contains(w) && w.length > 3)) return true;

      // ── Recherche générale si aucun filtre ───────────────────────────────
      if (!hasFilters) {
        return pAll.contains(q) || words.every((w) => pAll.contains(w));
      }

      return true;
    }).toList();
  }

    // ─── Moteur IA — Claude API + Recherche locale ────────────────────────────
  Future<void> _handleQuery(String text) async {
    if (text.trim().isEmpty) return;
    final q = text.trim();
    _inputCtrl.clear();

    setState(() => _messages.add(_ChatMessage(type: _MsgType.user, text: q)));
    _scrollToBottom();
    setState(() => _isTyping = true);
    _scrollToBottom();

    // ── Détecter les questions plateforme (bypass recherche locale) ──────
    final ql = _normalize(q);
    final isPlatformQuestion = [
      'comment', 'publier', 'publication', 'paiement', 'payer',
      'premium', 'abonnement', 'inscrire', 'inscription', 'connexion',
      'connecter', 'contacter', 'signaler', 'avis', 'notification',
      'support', 'aide', 'fonctionne', 'utiliser', 'fonctionnement',
      'message', 'rechercher', 'favoris', 'profil', 'compte', 'kyc',
      'verification', 'annonce', 'supprimer', 'modifier', 'valider'
    ].any((kw) => ql.contains(kw));

    // ── Recherche locale IMMÉDIATE (seulement si pas une question plateforme) ──
    if (!isPlatformQuestion) {
      final quickResults = _searchProperties(text.trim());
      if (quickResults.isNotEmpty) {
        setState(() => _isTyping = false);
        final count = quickResults.length;
        _addAiMessage("✅ J'ai trouvé **$count bien${count > 1 ? 's' : ''}** :");
        await Future.delayed(const Duration(milliseconds: 100));
        _addPropertiesMessage(quickResults.take(5).toList());
        return;
      }
    }

    try {
      // ── Construire le catalogue des biens disponibles ──────────────────
      final allProps = [
        ...MockDataService.properties,
        ...publishedPropertiesNotifier.value.cast<PropertyModel>(),
      ];

      // Catalogue complet avec toutes les infos nécessaires
      final catalog = allProps.map((p) {
        final carac = p.caracteristiques.isNotEmpty ? p.caracteristiques.join(', ') : 'aucune';
        final desc = p.description.length > 120 ? p.description.substring(0, 120) : p.description;
        return '[ID:${p.id}] ${p.titre} | Type: ${p.categorieLabel} | '
            'Lieu: ${p.adresse.ville}, ${p.adresse.pays} | '
            '${p.listingLabel} | Prix: ${formatFcfa(p.prix)} | '
            'Caractéristiques: $carac | '
            'Description: $desc';
      }).join('\n');

      // ── Appel Claude API ────────────────────────────────────────────────
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'claude-sonnet-4-20250514',
          'max_tokens': 1000,
          'system': """Tu es l'assistant IA de VelQix, une plateforme de location et vente de biens immobiliers et mobiliers en Afrique de l'Ouest.

CATALOGUE COMPLET (${allProps.length} biens disponibles):
$catalog

RÈGLES STRICTES:
1. Réponds TOUJOURS en français, de façon amicale et concise
2. Pour toute recherche de bien (maison, villa, appartement, studio, terrain, bureau, entrepôt, hôtel, motel, voiture, moto, camion, équipement, etc.):
   - Cherche dans le catalogue par titre, ville, pays, description, caractéristiques ET nom du propriétaire
   - Si trouvé: commence par "BIENS_TROUVÉS:" puis les titres séparés par "|"
   - Si pas trouvé: dis-le clairement avec le nombre total de biens disponibles
3. Pour les lieux spécifiques locaux (quartier, fleuve, monument): cherche dans description et caractéristiques
4. Pays couverts: TOUS les pays du monde
5. Recherche par propriétaire: si on donne un nom de personne, cherche ses biens dans le catalogue
6. GUIDE PLATEFORME VELQIX — réponds précisément à ces questions:

📌 COMMENT PUBLIER UN BIEN:
→ Appuyer sur le bouton "+" (orange) en bas de l'écran
→ Choisir le type: Immobilier ou Mobilier
→ Remplir le formulaire: titre, description, prix, photos, adresse
→ Soumettre → l'annonce passe en attente de validation par l'admin
→ Une fois approuvée, elle apparaît sur la plateforme

💳 COMMENT FAIRE UN PAIEMENT:
→ Ouvrir la fiche d'un bien → cliquer "Réserver" ou "Acheter"
→ Choisir la durée (pour location) ou confirmer l'achat
→ Saisir son numéro de téléphone et email
→ Payer via Mobile Money (Flooz, T-Money, MTN MoMo) ou Carte bancaire
→ Un reçu est envoyé par email après confirmation

⭐ COMMENT PASSER À PREMIUM:
→ Aller dans Profil → "Passer Premium" (ou icône étoile)
→ Choisir un plan: Free (gratuit), Mensuel, Semestriel ou Annuel
→ Le plan Premium donne: badge vendeur, annonces en vedette, 30 photos/annonce, statistiques avancées, support prioritaire
→ Payer et le badge s'active immédiatement

📱 COMMENT CONTACTER UN PROPRIÉTAIRE:
→ Sur la fiche d'un bien → cliquer "Contacter"
→ Envoyer un message via la messagerie in-app
→ Ou appeler directement via le bouton téléphone/vidéo

👤 COMMENT S'INSCRIRE:
→ Ouvrir l'app → "S'inscrire"
→ Remplir: nom, prénom, email, téléphone, mot de passe
→ Ou s'inscrire avec Google / Facebook
→ Accepter les conditions d'utilisation

🔍 COMMENT RECHERCHER UN BIEN:
→ Utiliser la barre de recherche sur l'accueil
→ Ou l'assistant IA (bouton étoile) pour recherche en langage naturel
→ Ou l'onglet Explorer avec filtres (type, ville, prix...)
→ Microphone disponible pour recherche vocale

⭐ COMMENT LAISSER UN AVIS:
→ Après une transaction confirmée → aller sur le bien → "Laisser un avis"
→ Donner une note de 1 à 5 étoiles + commentaire

🔔 COMMENT GÉRER LES NOTIFICATIONS:
→ Icône cloche en haut de l'écran
→ Notifications: réservations, messages, paiements, approbations

📞 SUPPORT:
→ Profil → Aide & Support → contact: support@velqix.tg

7. Toujours proposer des alternatives si aucun résultat exact
8. Format réponse: direct, clair, max 3 phrases avant les biens""",
          'messages': [
            {'role': 'user', 'content': q}
          ]
        }),
      );

      setState(() => _isTyping = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiText = (data['content'] as List).firstWhere(
          (c) => c['type'] == 'text', orElse: () => {'text': ''})['text'] as String;

        // ── Extraire les titres de biens mentionnés par Claude ────────────
        if (aiText.contains('BIENS_TROUVÉS:')) {
          final parts = aiText.split('BIENS_TROUVÉS:');
          final beforeText = parts[0].trim();
          final titlesRaw = parts[1].split('\n')[0];
          final titles = titlesRaw.split('|').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

          // Trouver les vrais biens correspondants
          final matched = allProps.where((p) =>
            titles.any((t) => p.titre.toLowerCase().contains(t.toLowerCase()) ||
                              t.toLowerCase().contains(p.titre.toLowerCase().substring(0, p.titre.length > 5 ? 5 : p.titre.length)))
          ).toList();

          if (beforeText.isNotEmpty) _addAiMessage(beforeText);

          if (matched.isNotEmpty) {
            await Future.delayed(const Duration(milliseconds: 200));
            _addPropertiesMessage(matched.take(5).toList());
            if (matched.length > 5) {
              _addAiMessage('📋 Et ${matched.length - 5} autres biens disponibles. Affinez votre recherche pour en voir plus !');
            }
          } else {
            // Claude a trouvé des biens mais on n'arrive pas à les matcher → recherche locale
            final localResults = _searchProperties(q.toLowerCase());
            if (localResults.isNotEmpty) {
              _addPropertiesMessage(localResults.take(5).toList());
            }
          }
        } else {
          // Réponse textuelle normale
          _addAiMessage(aiText);

          // Tenter quand même une recherche locale si la réponse mentionne des biens
          if (aiText.contains('disponible') || aiText.contains('trouvé') || aiText.contains('résultat')) {
            final localResults = _searchProperties(q.toLowerCase());
            if (localResults.isNotEmpty) {
              await Future.delayed(const Duration(milliseconds: 300));
              _addPropertiesMessage(localResults.take(3).toList());
            }
          }
        }
      } else {
        // Fallback vers recherche locale si l'API échoue
        _fallbackSearch(q);
      }
    } catch (e) {
      setState(() => _isTyping = false);
      _fallbackSearch(q);
    }
  }

  /// Recherche locale de fallback si l'API Claude n'est pas disponible
  void _fallbackSearch(String q) {
    final ql = q.toLowerCase()
        .replaceAll('é', 'e').replaceAll('è', 'e').replaceAll('ê', 'e')
        .replaceAll('à', 'a').replaceAll('â', 'a')
        .replaceAll('ô', 'o').replaceAll('û', 'u').replaceAll('î', 'i');

    // ── Réponses plateforme (sans API) ──────────────────────────────────────
    if (ql.contains('premium') || ql.contains('abonnement')) {
      _addAiMessage('⭐ **Comment passer à Premium ?**\n\n'
          '1. Aller dans **Profil** → bouton "Passer Premium"\n'
          '2. Choisir un plan : Free (gratuit), Mensuel (\$5), Semestriel (\$26) ou Annuel (\$48.5)\n'
          '3. Payer → le badge Premium s\'active immédiatement\n\n'
          '**Avantages Premium :** badge vendeur doré, annonces en vedette, 30 photos/annonce, statistiques avancées, support prioritaire (2h).');
      return;
    }
    if (ql.contains('publier') || ql.contains('publication') || ql.contains('annonce') || ql.contains('publié')) {
      _addAiMessage('📌 **Comment publier un bien ?**\n\n'
          '1. Appuyer sur le bouton **"+"** (orange) en bas de l\'écran\n'
          '2. Choisir le type : Immobilier ou Mobilier\n'
          '3. Remplir : titre, description, prix, photos, adresse\n'
          '4. Soumettre → votre annonce passe en attente de validation\n'
          '5. Une fois approuvée par l\'admin, elle apparaît sur la plateforme.');
      return;
    }
    if (ql.contains('paiement') || ql.contains('payer') || ql.contains('payer')) {
      _addAiMessage('💳 **Comment faire un paiement ?**\n\n'
          '1. Ouvrir la fiche d\'un bien → cliquer **"Réserver"** ou **"Acheter"**\n'
          '2. Choisir la durée (location) ou confirmer l\'achat\n'
          '3. Saisir votre numéro de téléphone et email\n'
          '4. Payer via **Mobile Money** (Flooz, T-Money, MTN MoMo) ou **Carte bancaire**\n'
          '5. Un reçu est envoyé par email après confirmation.');
      return;
    }
    if (ql.contains('inscrire') || ql.contains('inscription') || ql.contains('creer') || ql.contains('compte')) {
      _addAiMessage('👤 **Comment s\'inscrire ?**\n\n'
          '1. Ouvrir l\'app → cliquer **"S\'inscrire"**\n'
          '2. Remplir : nom, prénom, email, téléphone, mot de passe\n'
          '3. Ou s\'inscrire avec **Google** ou **Facebook**\n'
          '4. Accepter les conditions d\'utilisation → c\'est fait !');
      return;
    }
    if (ql.contains('contacter') || ql.contains('contact') || ql.contains('message')) {
      _addAiMessage('📱 **Comment contacter un propriétaire ?**\n\n'
          '1. Ouvrir la fiche d\'un bien\n'
          '2. Cliquer **"Contacter"** → messagerie in-app\n'
          '3. Ou utiliser le bouton **téléphone** pour appel audio\n'
          '4. Ou le bouton **vidéo** pour appel vidéo (10 FCFA/min)');
      return;
    }
    if (ql.contains('rechercher') || ql.contains('recherche') || ql.contains('trouver')) {
      _addAiMessage('🔍 **Comment rechercher un bien ?**\n\n'
          '1. Barre de recherche sur l\'accueil\n'
          '2. Onglet **Explorer** avec filtres (type, ville, prix...)\n'
          '3. **Assistant IA** (ce chat) en langage naturel\n'
          '4. **Microphone** 🎙️ pour recherche vocale');
      return;
    }
    if (ql.contains('support') || ql.contains('aide') || ql.contains('help') || ql.contains('probleme')) {
      _addAiMessage('📞 **Support VelQix**\n\n'
          'Email : support@velqix.tg\n'
          'Profil → Aide & Support\n\n'
          'Nous répondons sous 48h (Support Standard) ou 2h (Premium).');
      return;
    }

    // ── Recherche de biens ────────────────────────────────────────────────
    final results = _searchProperties(ql);
    if (results.isNotEmpty) {
      _addAiMessage("✅ J'ai trouvé **\${results.length} bien\${results.length > 1 ? 's' : ''}** correspondant à votre recherche :");
      _addPropertiesMessage(results.take(5).toList());
    } else {
      _addAiMessage(
        '🔍 Aucun bien trouvé pour **"\$q"**.\n\n'
        'Essayez : *maison Lomé*, *voiture location*, *appartement meublé Bénin*...'
      );
    }
  }

  // ─── Helper : vérifier si une liste de mots-clés correspond ──────────────
  bool _matchAny(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));

  // ─── Helper : formater les prix ───────────────────────────────────────────
  String _fmt(double v) {
    return v.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
  }



  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, _, __) => Stack(
      children: [
        // Panneau chat
        if (_isOpen)
          Positioned(
            bottom: 90,
            right: 16,
            child: FadeTransition(
              opacity: _panelOpacity,
              child: ScaleTransition(
                scale: _panelScale,
                alignment: Alignment.bottomRight,
                child: _buildPanel(context),
              ),
            ),
          ),

        // FAB
        Positioned(
          bottom: 20,
          right: 20,
          child: ScaleTransition(
            scale: _fabAnim,
            child: _buildFab(),
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildFab() {
    return GestureDetector(
      onTap: _togglePanel,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, child) {
          final pulse = _isOpen ? 0.0 : _pulseAnim.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Anneau pulse
              Container(
                width: 60 + pulse * 18,
                height: 60 + pulse * 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary
                      .withOpacity(0.18 * (1 - pulse)),
                ),
              ),
              // Bouton principal
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0A2E6E), Color(0xFF1976D2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isOpen
                      ? const Icon(Icons.close_rounded,
                          key: ValueKey('close'), color: Colors.white, size: 26)
                      : const Icon(Icons.auto_awesome_rounded,
                          key: ValueKey('open'), color: Colors.white, size: 26),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final panelW = (screenW - 32).clamp(0.0, 360.0);

    return Material(
      elevation: 20,
      borderRadius: BorderRadius.circular(24),
      shadowColor: Colors.black26,
      child: Container(
        width: panelW,
        height: 520,
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B2A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: AppTheme.primary.withOpacity(0.25), width: 1),
        ),
        child: Column(
          children: [
            _buildPanelHeader(),
            Expanded(child: _buildChatArea()),
            if (_messages.length <= 1) _buildSuggestions(),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  // ── En-tête ──────────────────────────────────────────────────────────────
  Widget _buildPanelHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A2E6E), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
              border: Border.all(
                  color: Colors.white.withOpacity(0.4), width: 1.5),
            ),
            child: const Center(
              child: Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('VelQIA',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                Row(
                  children: [
                    Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                            color: Color(0xFF4ADE80),
                            shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('En ligne · IA active',
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.75))),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _togglePanel,
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.keyboard_arrow_down_rounded,
                  color: Colors.white.withOpacity(0.8), size: 22),
            ),
          ),
        ],
      ),
    );
  }

  // ── Zone de chat ─────────────────────────────────────────────────────────
  Widget _buildChatArea() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (_, i) {
        if (_isTyping && i == _messages.length) {
          return _buildTypingIndicator();
        }
        final msg = _messages[i];
        switch (msg.type) {
          case _MsgType.user:
            return _buildUserBubble(msg);
          case _MsgType.ai:
            return _buildAiBubble(msg);
          case _MsgType.properties:
            return _buildPropertyCards(msg.properties!);
          case _MsgType.typing:
            return _buildTypingIndicator();
        }
      },
    );
  }

  Widget _buildUserBubble(_ChatMessage msg) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, left: 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(msg.text ?? '',
            style: GoogleFonts.poppins(
                fontSize: 12.5, color: Colors.white, height: 1.4)),
      ),
    );
  }

  Widget _buildAiBubble(_ChatMessage msg) {
    // Parse **bold** markdown basique
    final raw = msg.text ?? '';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, right: 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          border: Border.all(
              color: AppTheme.primary.withOpacity(0.2), width: 1),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: _buildRichText(raw),
      ),
    );
  }

  Widget _buildRichText(String text) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    int last = 0;
    for (final m in regex.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(
            text: text.substring(last, m.start),
            style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: const Color(0xFFCBD5E0),
                height: 1.5)));
      }
      spans.add(TextSpan(
          text: m.group(1),
          style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              height: 1.5)));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(
          text: text.substring(last),
          style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: const Color(0xFFCBD5E0),
              height: 1.5)));
    }
    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          border: Border.all(
              color: AppTheme.primary.withOpacity(0.2), width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) {
                final offset = (((_pulseAnim.value * 3) - i) % 1.0).abs();
                return Container(
                  margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                  width: 7,
                  height: 7 + (offset < 0.3 ? 4 * (1 - offset / 0.3) : 0),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }

  // ── Cartes de biens ───────────────────────────────────────────────────────
  Widget _buildPropertyCards(List<PropertyModel> props) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: props.map((p) => _buildPropertyCard(p)).toList(),
      ),
    );
  }

  Widget _buildPropertyCard(PropertyModel p) {
    final formattedPrice = _formatPrice(p.prix);

    return GestureDetector(
      onTap: () {
        // Fermer le panel et naviguer vers le détail
        setState(() => _isOpen = false);
        _panelAnim.reverse();
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => PropertyDetailScreen(property: p)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F2D4A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppTheme.primary.withOpacity(0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(15)),
                  child: p.images.isNotEmpty
                      ? Image.network(
                          p.images.first,
                          height: 110,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _placeholderImage(p, 110),
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return _placeholderImage(p, 110);
                          },
                        )
                      : _placeholderImage(p, 110),
                ),
                // Badge type
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(p.listingLabel,
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                // Prix
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.72),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(formattedPrice,
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF63B3ED),
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            // Infos
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Note
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFF6AD55), size: 13),
                      const SizedBox(width: 3),
                      Text('${p.rating}',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFFF6AD55),
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Text('(${p.totalAvis} avis)',
                          style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.4))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Titre
                  Text(p.titre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  // Adresse
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded,
                          color: Colors.white.withOpacity(0.5), size: 12),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(p.adresse.short,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.55))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Caractéristiques
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: p.caracteristiques
                        .take(3)
                        .map((c) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color:
                                        AppTheme.primary.withOpacity(0.25)),
                              ),
                              child: Text(c,
                                  style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: const Color(0xFFA0C4E0))),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  // Bouton voir
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _isOpen = false);
                        _panelAnim.reverse();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  PropertyDetailScreen(property: p)),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: Text('Voir le bien →',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderImage(PropertyModel p, double h) {
    final icons = {
      PropertyCategory.maison: Icons.home_rounded,
      PropertyCategory.appartement: Icons.apartment_rounded,
      PropertyCategory.terrain: Icons.landscape_rounded,
      PropertyCategory.voiture: Icons.directions_car_rounded,
      PropertyCategory.moto: Icons.two_wheeler_rounded,
      PropertyCategory.bureau: Icons.business_rounded,
      PropertyCategory.entrepot: Icons.warehouse_rounded,
      PropertyCategory.equipement: Icons.build_rounded,
      PropertyCategory.camion: Icons.local_shipping_rounded,
      PropertyCategory.autre: Icons.category_rounded,
    };
    return Container(
      height: h,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A365D), Color(0xFF2A4A7F)],
        ),
      ),
      child: Icon(icons[p.categorie] ?? Icons.home_rounded,
          color: Colors.white.withOpacity(0.3), size: 40),
    );
  }

  // ── Suggestions ──────────────────────────────────────────────────────────
  Widget _buildSuggestions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _suggestions
            .map((s) => GestureDetector(
                  onTap: () => _handleQuery(s['query']!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppTheme.primary.withOpacity(0.25)),
                    ),
                    child: Text(s['label']!,
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFFA0C4E0))),
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ── Zone de saisie ────────────────────────────────────────────────────────
  Widget _buildInputArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Bandeau "écoute en cours" ──────────────────────────────────
        if (_isListening)
          AnimatedBuilder(
            animation: _micPulseAnim,
            builder: (_, __) => Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08 + _micPulseAnim.value * 0.08),
                border: Border(
                  top: BorderSide(color: Colors.red.withOpacity(0.25), width: 1),
                ),
              ),
              child: Row(
                children: [
                  // Ondes animées
                  SizedBox(
                    width: 32,
                    height: 22,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(4, (i) {
                        final h = ((_micPulseAnim.value + i * 0.25) % 1.0);
                        return Container(
                          width: 3,
                          height: 6 + h * 14,
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _voicePartial.isEmpty
                          ? 'Écoute en cours…'
                          : _voicePartial,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: _voicePartial.isEmpty
                            ? Colors.redAccent.withOpacity(0.8)
                            : Colors.white,
                        fontStyle: _voicePartial.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Bouton Envoyer (visible si texte capturé)
                  if (_voicePartial.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        final text = _voicePartial;
                        _speech.stop();
                        setState(() { _isListening = false; _voicePartial = ''; });
                        _micPulseAnim.stop();
                        _micPulseAnim.reset();
                        _inputCtrl.clear();
                        _handleQuery(text); // ✅ Envoyer directement depuis le bandeau
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.withOpacity(0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.send_rounded, color: Colors.greenAccent, size: 13),
                            const SizedBox(width: 4),
                            Text('Envoyer',
                                style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  // Bouton Annuler
                  GestureDetector(
                    onTap: () {
                      _speech.stop();
                      setState(() { _isListening = false; _voicePartial = ''; });
                      _micPulseAnim.stop();
                      _micPulseAnim.reset();
                      _inputCtrl.clear();
                    },
                    child: Icon(Icons.close_rounded,
                        color: Colors.redAccent.withOpacity(0.7), size: 18),
                  ),
                ],
              ),
            ),
          ),

        // ── Champ texte + boutons ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            border: Border(
                top: BorderSide(
                    color: AppTheme.primary.withOpacity(0.12), width: 1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: const Color(0xFFE2E8F0)),
                  decoration: InputDecoration(
                    hintText: _isListening
                        ? 'Parlez maintenant…'
                        : 'Décrivez ce que vous cherchez...',
                    hintStyle: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: _isListening
                            ? Colors.redAccent.withOpacity(0.5)
                            : Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: _isListening
                        ? Colors.red.withOpacity(0.06)
                        : Colors.white.withOpacity(0.07),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: AppTheme.primary.withOpacity(0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: _isListening
                              ? Colors.red.withOpacity(0.4)
                              : AppTheme.primary.withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: AppTheme.primary.withOpacity(0.6)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    isDense: true,
                  ),
                  onSubmitted: _handleQuery,
                  textInputAction: TextInputAction.send,
                  maxLines: 1,
                ),
              ),
          const SizedBox(width: 8),
          // Bouton micro – reconnaissance vocale réelle
          GestureDetector(
            onTap: _toggleVoice,
            child: AnimatedBuilder(
              animation: _micPulseAnim,
              builder: (_, __) {
                final pulse = _isListening ? _micPulseAnim.value : 0.0;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isListening)
                      Container(
                        width: 40 + pulse * 12,
                        height: 40 + pulse * 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withOpacity(0.15 * (1 - pulse)),
                        ),
                      ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _isListening
                            ? Colors.red.withOpacity(0.25)
                            : AppTheme.primary.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isListening
                              ? Colors.red.withOpacity(0.7)
                              : AppTheme.primary.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                        color: _isListening
                            ? Colors.redAccent
                            : const Color(0xFF63B3ED),
                        size: 20,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 6),
          // Bouton envoyer
          GestureDetector(
            onTap: () => _handleQuery(_inputCtrl.text),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    ), // fin Container champ texte
    ], // fin Column
    );
  }

  // ─── Reconnaissance vocale – Web Speech API (natif navigateur) ──────────
  void _toggleVoice() {
    if (!_speechAvailable) {
      _addAiMessage(tr('ai_mic_unavailable'));
      return;
    }

    if (_isListening) {
      _speech.stop();
      setState(() { _isListening = false; _voicePartial = ''; });
      _micPulseAnim.stop();
      _micPulseAnim.reset();
      return;
    }

    setState(() { _isListening = true; _voicePartial = ''; });
    _micPulseAnim.repeat(reverse: true);

    _speech.listen(
      localeId: 'fr_FR',
      onResult: (result) {
        if (!mounted) return;
        final transcript = result.recognizedWords;
        setState(() => _voicePartial = transcript);
        if (result.finalResult && transcript.isNotEmpty) {
          _speech.stop();
          setState(() { _isListening = false; _voicePartial = ''; });
          _micPulseAnim.stop();
          _micPulseAnim.reset();
          _inputCtrl.clear();
          // ✅ Soumission automatique dès que la voix est reconnue
          Future.microtask(() => _handleQuery(transcript));
        }
      },
      cancelOnError: true,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
    );
  }

  String _formatPrice(double prix) {
    final val = prix.toInt();
    final s = val.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(s[i]);
    }
    return '${buffer.toString()} FCFA';
  }
}
