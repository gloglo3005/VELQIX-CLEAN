import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../models/models.dart';
// import '../services/mock_data.dart'; // 🚫 DÉSACTIVÉ (25/08/2026) : plus de données factices
import '../services/api_service.dart';
import '../services/platform_knowledge.dart';
import '../services/plan_service.dart';
import '../services/premium_plan_service.dart';
import '../services/zone_service.dart';
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
  // Initialisation paresseuse : la permission micro n'est demandée qu'au
  // premier appui sur le bouton micro, pas au lancement de l'application.
  bool _speechInitStarted = false;
  bool _startVoiceAfterInit = false;
  String _voicePartial = '';
  // Dernier texte reconnu pendant l'écoute en cours + garde « une seule soumission ».
  String _voiceTranscript = '';
  bool _awaitingResult = false;
  Timer? _finalizeTimer;
  String? _resolvedLocale; // locale de reconnaissance réellement disponible sur l'appareil
  late AnimationController _micPulseAnim;
  final stt.SpeechToText _speech = stt.SpeechToText();

  // ── Mode vocal : TOIT D’OR IA répond À VOIX HAUTE ───────────────────────────
  // _voiceMode  = conversation mains libres (j'écoute, je réponds, j'écoute…).
  // _speakNext  = la prochaine question vient du micro : on y répond oralement.
  final FlutterTts _tts = FlutterTts();
  // File d'attente de la lecture : la réponse est lue PHRASE PAR PHRASE.
  // Les moteurs vocaux (Chrome ~15 s, Android ~4000 car.) coupent les longs blocs.
  List<String> _ttsQueue = [];
  DateTime _ttsLastSpeakAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _ttsReady = false;
  bool _voiceMode = false;
  bool _speakNext = false;
  bool _isSpeaking = false;
  int _emptyListens = 0; // écoutes sans voix d'affilée (mode vocal)

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
    {'label': '🏢 Appartement meublé', 'query': 'Appartement meublé'},
    {'label': '🌍 Bien au Togo', 'query': 'Bien disponible au Togo'},
    {'label': '💎 Premium', 'query': 'Que comprend Premium ?'},
    {'label': '🌐 Dans quels pays ?', 'query': 'TOIT D’OR est disponible dans quels pays ?'},
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
    // La reconnaissance vocale est initialisée au premier appui sur le
    // micro (voir _toggleVoice).
  }

  /// Termine l'écoute en cours et envoie UNE SEULE fois la phrase reconnue.
  /// Appelée soit par le résultat final du moteur, soit (après un court délai de
  /// grâce) par le statut « done » : sur Android/Web le statut « done » arrive
  /// souvent AVANT le résultat final, et envoyer à ce moment-là coupait la phrase.
  void _finishListening() {
    _finalizeTimer?.cancel();
    if (!mounted || !_awaitingResult) return;
    _awaitingResult = false;
    final captured = _voiceTranscript.trim();
    _voiceTranscript = '';
    try { _speech.stop(); } catch (_) {}
    setState(() { _isListening = false; _voicePartial = ''; });
    _micPulseAnim.stop();
    _micPulseAnim.reset();
    if (captured.isNotEmpty) {
      _inputCtrl.clear();
      _emptyListens = 0;
      // Envoi automatique ; la réponse sera dite à voix haute
      _speakNext = true;
      Future.microtask(() => _handleQuery(captured));
    } else if (_voiceMode) {
      // Mode vocal : personne n'a parlé. On réécoute 1 fois, puis on s'arrête.
      _emptyListens++;
      if (_emptyListens >= 2) {
        _stopVoiceMode();
        _addAiMessage(_uiLang == 'en'
            ? 'Voice mode stopped: I did not hear anything. Tap the voice button to start again.'
            : 'Mode vocal arrêté : je n\'ai rien entendu. Appuyez sur le bouton vocal pour reprendre.');
      } else {
        Future.delayed(const Duration(milliseconds: 300), _resumeListening);
      }
    }
  }

  /// Annule l'écoute sans rien envoyer.
  void _cancelListening() {
    _finalizeTimer?.cancel();
    _awaitingResult = false;
    _voiceTranscript = '';
    try { _speech.cancel(); } catch (_) {}
  }

  /// Choisit la locale de reconnaissance réellement supportée (ex. fr_FR, fr_TG, fr-FR…)
  /// au lieu d'imposer « fr_FR » : un localeId inconnu donne une reconnaissance approximative.
  Future<void> _resolveSpeechLocale() async {
    final wanted = _speechLocale(); // ex. fr_FR
    final lang = wanted.split('_').first.toLowerCase();
    try {
      final locales = await _speech.locales();
      String norm(String id) => id.replaceAll('-', '_').toLowerCase();
      for (final l in locales) {
        if (norm(l.localeId) == norm(wanted)) { _resolvedLocale = l.localeId; return; }
      }
      for (final l in locales) {
        if (norm(l.localeId).startsWith('${lang}_') || norm(l.localeId) == lang) {
          _resolvedLocale = l.localeId;
          return;
        }
      }
    } catch (_) {}
    _resolvedLocale = null; // moteur par défaut de l'appareil
  }

  /// Initialise la reconnaissance vocale
  void _initSpeech() {
    _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == stt.SpeechToText.doneStatus ||
            status == stt.SpeechToText.notListeningStatus) {
          if (!_awaitingResult) return; // déjà traité (résultat final reçu)
          // On laisse 700 ms au moteur pour livrer le résultat FINAL avant de conclure.
          _finalizeTimer?.cancel();
          _finalizeTimer = Timer(const Duration(milliseconds: 700), _finishListening);
        }
      },
      onError: (error) {
        if (!mounted) return;
        // Erreurs « normales » (aucune voix / silence) : on conclut avec ce qui a été capté.
        if (_awaitingResult && _voiceTranscript.trim().isNotEmpty) {
          _finishListening();
          return;
        }
        _cancelListening();
        setState(() { _isListening = false; _voicePartial = ''; });
        _micPulseAnim.stop();
        _micPulseAnim.reset();
        if (_voiceMode) _stopVoiceMode(); // micro refusé / erreur : on évite de boucler
      },
    ).then((available) {
      if (!mounted) return;
      setState(() => _speechAvailable = available);
      if (available) _resolveSpeechLocale();
      // L'appui sur le micro qui a déclenché l'initialisation démarre
      // maintenant l'écoute (ou affiche « micro indisponible »).
      if (_startVoiceAfterInit) {
        _startVoiceAfterInit = false;
        _toggleVoice();
      }
    });
  }

  @override
  void dispose() {
    _fabAnim.dispose();
    _pulseAnim.dispose();
    _panelAnim.dispose();
    _finalizeTimer?.cancel();
    _micPulseAnim.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    if (_isListening) {
      _speech.stop();
    }
    _voiceMode = false;
    _ttsQueue = []; _tts.stop();
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
      _stopVoiceMode(); // on se tait et on arrête d'écouter quand le panneau se ferme
    }
  }

  void _sendGreeting() {
    _addAiMessage(
      tr('ai_hello_reply'),
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
    // 🚫 Biens factices retirés (25/08/2026) : seuls les vrais biens approuvés
    // sont maintenant proposés par l'assistant.
    final all = publishedPropertiesNotifier.value.cast<PropertyModel>();

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
      'chambre':     ['chambre', 'colocation', 'piece'],
      'studio':      ['studio', 'garconniere'],
      'appartement': ['appartement', 'appart', 'flat'],
      'terrain':     ['terrain', 'parcelle', 'lot', 'foncier', 'hectare'],
      'bureau':      ['bureau', 'office'],
      'local_commercial': ['local', 'localcommercial', 'boutique', 'magasin', 'commerce'],
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
      final pTitle = _normalize(p.titre);
      final pCity  = _normalize(p.adresse.ville);
      final pPays  = _normalize(p.adresse.pays);
      final pCat   = _normalize(p.categorieLabel);
      final pDesc  = _normalize(p.description);
      final pCarac = p.caracteristiques.map(_normalize).join(' ');
      final pAll   = '$pTitle $pCity $pPays $pCat $pDesc $pCarac';

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

      // ── Recherche générale si aucun filtre ───────────────────────────────
      if (!hasFilters) {
        return pAll.contains(q) || words.every((w) => pAll.contains(w));
      }

      return true;
    }).toList();
  }

  // ─── Base de connaissances de la plateforme ──────────────────────────────
  // Réponses précises aux questions sur le fonctionnement de TOIT D’OR, adaptées
  // au lieu cité (Lomé, une ville du Togo, un autre pays, un continent,
  // « l'étranger »…) — voir lib/services/platform_knowledge.dart.
  // Les chiffres qui bougent (tarif Premium, zones desservies) sont lus sur
  // le serveur. Les recherches de biens ne passent JAMAIS par ici : elles
  // partent vers l'IA du serveur (Gemini + recherche en base).
  String get _uiLang =>
      localeNotifier.value.languageCode == 'en' ? 'en' : 'fr';

  Future<String> _answerFromKnowledge(PlatformMatch m) async {
    String? premiumLine;
    String? coverageLine;
    if (m.topic == 'premium') {
      premiumLine = await _premiumPriceLine(m.lang);
    }
    if (m.topic == 'services' || m.topic == 'coverage' || m.topic == 'diaspora') {
      coverageLine = await _zonesLine(m);
    }
    return PlatformKnowledge.render(
      m,
      premiumLine: premiumLine,
      coverageLine: coverageLine,
    );
  }

  /// Tarifs Premium lus sur le serveur (GET /premium/plan), avec repli sur
  /// le tarif de référence de l'application.
  Future<String?> _premiumPriceLine(String lang) async {
    final fr = lang == 'fr';
    try {
      final periods = await PlanService.instance
          .getPremiumPeriods()
          .timeout(const Duration(seconds: 5));
      if (periods.isNotEmpty) {
        final list = periods
            .map((p) => "${p.label} : ${_fmt(p.priceFcfa)} FCFA")
            .join(' · ');
        return fr ? "Tarifs actuels : $list." : "Current prices: $list.";
      }
    } catch (_) {
      // serveur injoignable : on retombe sur le tarif de référence
    }
    final plan = PremiumPlanService.instance.plan.value;
    final price =
        "${_fmt(plan.priceFcfa)} FCFA / ${plan.durationDays} ${fr ? 'jours' : 'days'}";
    return fr
        ? "Tarif de référence : $price (le montant exact est confirmé sur l'écran de paiement)."
        : "Reference price: $price (the exact amount is confirmed on the payment screen).";
  }

  /// Zones desservies lues sur le serveur (GET /zones) : permet de répondre
  /// précisément à « le service de vérification existe-t-il à X ? ».
  Future<String?> _zonesLine(PlatformMatch m) async {
    final fr = m.lang == 'fr';
    try {
      final res = await ZoneService.instance
          .getPublicZones()
          .timeout(const Duration(seconds: 5));
      // Pas de limite définie ou aucune zone : rien de précis à ajouter,
      // le serveur reste juge au moment de la demande.
      if (!res.limited || res.zones.isEmpty) return null;

      final names = res.zones
          .map((z) => z.name)
          .where((n) => n.isNotEmpty)
          .take(8)
          .join(', ');
      final g = m.geo;
      final placeLevel =
          g != null && (g.kind == 'togo' || g.kind == 'wa' || g.kind == 'africa');

      // Le lieu cité n'est un critère que pour un bien situé en Afrique ;
      // pour « je vis en France » ou « à l'étranger », on liste simplement.
      if (g == null || !placeLevel) {
        return fr
            ? "📌 Zones desservies actuellement : $names."
            : "📌 Currently served zones: $names.";
      }

      PublicZone? byName;
      for (final z in res.zones) {
        final zn = PlatformKnowledge.normalize(z.name);
        if (zn.isNotEmpty && (zn.contains(g.token) || g.token.contains(zn))) {
          byName = z;
          break;
        }
      }
      if (byName != null) {
        final price = byName.verificationPrice > 0
            ? (fr
                ? " (vérification dès ${_fmt(byName.verificationPrice.toDouble())} FCFA)"
                : " (verification from ${_fmt(byName.verificationPrice.toDouble())} FCFA)")
            : '';
        return fr
            ? "✅ ${byName.name} fait partie des zones desservies$price."
            : "✅ ${byName.name} is one of the served zones$price.";
      }

      final inCountry = g.code == null
          ? <PublicZone>[]
          : res.zones.where((z) => z.country.toUpperCase() == g.code).toList();
      final label = fr ? g.labelFr : g.labelEn;
      if (inCountry.isNotEmpty) {
        final list = inCountry.map((z) => z.name).take(8).join(', ');
        return fr
            ? "📌 Zones desservies pour $label : $list. Si votre ville n'y figure pas, les services terrain n'y sont pas proposés pour l'instant."
            : "📌 Served zones for $label: $list. If your city is not listed, field services are not offered there yet.";
      }
      return fr
          ? "⚠️ Je ne vois pas $label parmi les zones desservies actuellement ($names). Vous pouvez y consulter et publier des annonces, mais les services terrain n'y sont pas proposés pour l'instant."
          : "⚠️ I don't see $label among the currently served zones ($names). You can still browse and post listings there, but field services are not offered yet.";
    } catch (_) {
      return null;
    }
  }

  // ─── Moteur IA — /api/ai/chat ────────────────────────────────────────────
  final List<Map<String, String>> _history = []; // historique de conversation

  Future<void> _handleQuery(String text) async {
    if (text.trim().isEmpty) return;
    final q = text.trim();
    _inputCtrl.clear();

    // Réponse parlée si la question vient du micro ou si le mode vocal est actif.
    final speak = _speakNext || _voiceMode;
    _speakNext = false;

    setState(() => _messages.add(_ChatMessage(type: _MsgType.user, text: q)));
    _scrollToBottom();

    // Questions sur la plateforme → base de connaissances (réponse exacte,
    // adaptée au lieu cité). Les recherches de biens ne sont jamais
    // interceptées : elles partent vers l'IA du serveur.
    final kb = PlatformKnowledge.match(q, defaultLang: _uiLang);
    if (kb != null) {
      setState(() => _isTyping = true);
      _scrollToBottom();
      String reply;
      try {
        reply = await _answerFromKnowledge(kb);
      } catch (_) {
        reply = PlatformKnowledge.render(kb);
      }
      if (!mounted) return;
      setState(() => _isTyping = false);
      _addAiMessage(reply);
      if (speak) _speak(reply);
      _history.add({'role': 'user', 'content': q});
      _history.add({'role': 'assistant', 'content': reply});
      if (_history.length > 20) {
        _history.removeRange(0, _history.length - 20);
      }
      return;
    }

    setState(() => _isTyping = true);
    _scrollToBottom();

    // Ajouter à l'historique
    _history.add({'role': 'user', 'content': q});
    if (_history.length > 20) _history.removeAt(0); // garder les 20 derniers

    try {
      final token = await ApiService.instance.getValidToken();
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/ai/chat'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'message': q,
          'history': _history.length > 1
              ? _history.sublist(0, _history.length - 1) // tout sauf le dernier (déjà dans message)
              : [],
        }),
      ).timeout(const Duration(seconds: 35));

      setState(() => _isTyping = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final d         = data['data'] as Map<String, dynamic>;
          final aiText    = d['text'] as String?;
          final propsJson = (d['properties'] as List?) ?? [];

          // Réponse textuelle
          if (aiText != null && aiText.isNotEmpty) {
            _addAiMessage(aiText);
            if (speak) _speak(aiText);
            _history.add({'role': 'assistant', 'content': aiText});
          }

          // Biens retournés depuis la base
          if (propsJson.isNotEmpty) {
            final props = propsJson
                .map((p) => PropertyModel.fromJson(p as Map<String, dynamic>))
                .toList();
            await Future.delayed(const Duration(milliseconds: 150));
            _addAiMessage('✅ ${props.length} bien${props.length > 1 ? 's' : ''} trouvé${props.length > 1 ? 's' : ''} :');
            _addPropertiesMessage(props.take(5).toList());
          } else if (aiText == null || aiText.isEmpty) {
            const none = 'Je n\'ai pas pu trouver de réponse. Reformulez votre question.';
            _addAiMessage(none);
            if (speak) _speak(none);
          }
        } else {
          _fallbackOrGuess(q, speak);
        }
      } else if (response.statusCode == 503) {
        // Gemini temporairement surchargé (voir backend: GEMINI_UNAVAILABLE).
        // On l'affiche clairement au lieu de faire croire qu'aucun bien n'existe.
        String msg = '⏳ L\'assistant est temporairement surchargé, réessayez dans quelques instants.';
        try {
          final data = jsonDecode(response.body);
          if (data['message'] is String && (data['message'] as String).isNotEmpty) {
            msg = data['message'] as String;
          }
        } catch (_) {
          // corps non-JSON ou inattendu, on garde le message par défaut
        }
        if (!_answerFromGuess(q, speak)) {
          _addAiMessage(msg);
          if (speak) _speak(msg);
        }
      } else {
        _fallbackOrGuess(q, speak);
      }
    } catch (_) {
      if (mounted) setState(() => _isTyping = false);
      _fallbackOrGuess(q, speak);
    }
  }

  /// Secours quand l'IA du serveur est injoignable : on devine d'abord le
  /// sujet (fautes de frappe, autre formulation), puis on cherche des biens.
  bool _answerFromGuess(String q, bool speak) {
    final guess = PlatformKnowledge.bestGuess(q, defaultLang: _uiLang);
    if (guess == null) return false;
    final reply = PlatformKnowledge.render(guess);
    _addAiMessage(reply);
    if (speak) _speak(reply);
    return true;
  }

  void _fallbackOrGuess(String q, bool speak) {
    if (_answerFromGuess(q, speak)) return;
    _fallbackSearch(q, speak: speak);
  }

  /// Recherche locale de fallback si l'API Claude n'est pas disponible
  void _fallbackSearch(String q, {bool speak = false}) {
    final ql = q.toLowerCase()
        .replaceAll('é', 'e').replaceAll('è', 'e').replaceAll('ê', 'e')
        .replaceAll('à', 'a').replaceAll('â', 'a')
        .replaceAll('ô', 'o').replaceAll('û', 'u').replaceAll('î', 'i');

    final results = _searchProperties(ql);
    if (results.isNotEmpty) {
      final found = '✅ J\'ai trouvé **${results.length} bien${results.length > 1 ? 's' : ''}** correspondant à votre recherche :';
      _addAiMessage(found);
      if (speak) _speak(found);
      _addPropertiesMessage(results.take(5).toList());
    } else {
      final none = '🔍 Aucun bien trouvé pour **"$q"**.\n\n'
          'Essayez : *maison Lomé*, *terrain Kpalimé*, *appartement meublé Bénin*...';
      _addAiMessage(none);
      if (speak) _speak('Aucun bien trouvé pour $q. Essayez maison Lomé, terrain Kpalimé ou appartement meublé Bénin.');
    }
  }

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
            // top + bottom : le panneau reste dans la zone visible, même
            // quand le clavier réduit la hauteur disponible.
            top: 8,
            bottom: 90,
            right: 16,
            child: Align(
              alignment: Alignment.bottomRight,
              child: FadeTransition(
                opacity: _panelOpacity,
                child: ScaleTransition(
                  scale: _panelScale,
                  alignment: Alignment.bottomRight,
                  child: _buildPanel(context),
                ),
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
                    colors: [Color(0xFF0A3622), Color(0xFF1B7A4E)],
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
          color: const Color(0xFF0A2418),
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
          colors: [Color(0xFF0A3622), Color(0xFF0F5132)],
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
                Text('TOIT D’OR IA',
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
            colors: [Color(0xFF1B7A4E), Color(0xFF0F5132)],
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
                color: const Color(0xFFE5E7EB),
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
              color: const Color(0xFFE5E7EB),
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
          color: const Color(0xFF0A3622),
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
                            color: const Color(0xFFE6C766),
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
                          color: Color(0xFFD4AF37), size: 13),
                      const SizedBox(width: 3),
                      Text('${p.rating}',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFFD4AF37),
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
                                      color: const Color(0xFFF7F3EB))),
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
      PropertyCategory.chambre: Icons.bed_rounded,
      PropertyCategory.studio: Icons.single_bed_rounded,
      PropertyCategory.localCommercial: Icons.storefront_rounded,
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
          colors: [Color(0xFF0A3622), Color(0xFF0F5132)],
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
                            color: const Color(0xFFF7F3EB))),
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
        // ── Bandeau "mode vocal" ───────────────────────────────────────
        if (_voiceMode && !_isListening)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1B7A4E).withOpacity(0.12),
              border: Border(
                top: BorderSide(color: const Color(0xFF1B7A4E).withOpacity(0.3), width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(_isSpeaking ? Icons.volume_up_rounded : Icons.graphic_eq_rounded,
                    size: 18, color: const Color(0xFF1B7A4E)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isSpeaking
                        ? (_uiLang == 'en' ? 'TOIT D’OR IA is speaking…' : 'TOIT D’OR IA vous répond…')
                        : (_uiLang == 'en' ? 'Voice mode on: thinking…' : 'Mode vocal activé…'),
                    style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textPrimary),
                  ),
                ),
                GestureDetector(
                  onTap: _stopVoiceMode,
                  child: Text(
                    _uiLang == 'en' ? 'Stop' : 'Arrêter',
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600, color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ),
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
                        _cancelListening();
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
                      _cancelListening();
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
                      fontSize: 13, color: const Color(0xFFE5E7EB)),
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
          // Bouton « mode vocal » : je parle, TOIT D’OR IA répond à voix haute, puis je réécoute
          GestureDetector(
            onTap: _toggleVoiceMode,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _voiceMode
                    ? const Color(0xFF1B7A4E).withOpacity(0.25)
                    : AppTheme.primary.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _voiceMode
                      ? const Color(0xFF1B7A4E)
                      : AppTheme.primary.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Icon(
                _voiceMode ? Icons.record_voice_over_rounded : Icons.headset_mic_rounded,
                color: _voiceMode ? const Color(0xFF1B7A4E) : const Color(0xFFE6C766),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 6),
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
                            : const Color(0xFFE6C766),
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
                  colors: [Color(0xFF1B7A4E), Color(0xFF0F5132)],
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
    // Première utilisation : on initialise la reconnaissance vocale (c'est
    // là que le système demande l'accès au micro), puis l'écoute démarre.
    if (!_speechInitStarted) {
      _speechInitStarted = true;
      _startVoiceAfterInit = true;
      _initSpeech();
      return;
    }

    if (!_speechAvailable) {
      _addAiMessage(tr('ai_mic_unavailable'));
      return;
    }

    if (_isListening) {
      // Appui sur le micro pendant l'écoute = « j'ai fini » : on envoie ce qui a été dit.
      _speech.stop();
      _finalizeTimer?.cancel();
      _finalizeTimer = Timer(const Duration(milliseconds: 700), _finishListening);
      return;
    }

    _voiceTranscript = '';
    _awaitingResult = true;
    setState(() { _isListening = true; _voicePartial = ''; });
    _micPulseAnim.repeat(reverse: true);

    _speech.listen(
      localeId: _listenLocaleId(),
      onResult: (result) {
        if (!mounted || !_awaitingResult) return;
        final transcript = result.recognizedWords;
        // On garde toujours le texte le plus récent (le résultat final remplace les partiels).
        if (transcript.isNotEmpty) _voiceTranscript = transcript;
        setState(() => _voicePartial = _voiceTranscript);
        if (result.finalResult) {
          _finishListening(); // envoi unique, phrase complète
        }
      },
      listenFor: const Duration(seconds: 60),
      // Pause plus longue : 2 s coupait la phrase dès qu'on reprenait son souffle.
      pauseFor: const Duration(seconds: 4),
      listenOptions: stt.SpeechListenOptions(
        // WEB : le plugin passe alors la reconnaissance du navigateur en mode « continu » et
        // concatène TOUS les résultats intermédiaires. Sur Chrome Android chaque révision de la
        // phrase devient une entrée : « cherche » + « cherche maison » + « cherche maison au »
        // → phrase répétée. On désactive donc les partiels sur le web : un seul résultat propre.
        partialResults: !kIsWeb,
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation,
      ),
    );
  }

  // ─── Mode vocal : TOIT D’OR IA parle ───────────────────────────────────────────
  Future<void> _initTts() async {
    if (_ttsReady) return;
    _ttsReady = true;
    try {
      // Fin de la lecture : en mode vocal, on repart à l'écoute (conversation mains libres).
      _tts.setCompletionHandler(() {
        if (!mounted) return;
        // Événement tardif de la lecture qu'on vient d'interrompre : on l'ignore.
        if (DateTime.now().difference(_ttsLastSpeakAt).inMilliseconds < 250) return;
        // Il reste des phrases à lire : on enchaîne.
        if (_ttsQueue.isNotEmpty) {
          _speakNextChunk();
          return;
        }
        setState(() => _isSpeaking = false);
        if (_voiceMode) Future.delayed(const Duration(milliseconds: 350), _resumeListening);
      });
      _tts.setCancelHandler(() {
        if (mounted) setState(() => _isSpeaking = false);
      });
      _tts.setErrorHandler((_) {
        if (!mounted) return;
        // Une phrase a échoué : on passe à la suivante plutôt que de couper toute la réponse.
        if (_ttsQueue.isNotEmpty) {
          _speakNextChunk();
          return;
        }
        setState(() => _isSpeaking = false);
        if (_voiceMode) Future.delayed(const Duration(milliseconds: 350), _resumeListening);
      });
    } catch (_) {
      // synthèse vocale indisponible sur cet appareil : l'app reste utilisable à l'écrit
    }
  }

  /// Texte propre pour la voix : sans markdown, emojis, liens ni symboles.
  String _cleanForSpeech(String text) {
    var t = text
        .replaceAll(RegExp(r'https?://\S+'), ' ')
        .replaceAll(RegExp(r'[*_`#>]+'), '')
        .replaceAll(RegExp(r'[\u{1F000}-\u{1FAFF}\u{2190}-\u{21FF}\u{2300}-\u{23FF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}]', unicode: true), ' ')
        .replaceAll('•', '. ')
        .replaceAll(RegExp(r'\s*\n+\s*'), '. ')
        .replaceAll(RegExp(r'(\.\s*){2,}'), '. ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    return t;
  }

  /// Découpe le texte en morceaux courts (≤ ~150 caractères) aux fins de phrases.
  List<String> _splitForSpeech(String text) {
    const maxLen = 150;
    final sentences = text
        .split(RegExp(r'(?<=[.!?…;:])\s+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    final chunks = <String>[];
    var cur = '';
    void flush() {
      if (cur.trim().isNotEmpty) chunks.add(cur.trim());
      cur = '';
    }
    for (final sen in sentences) {
      if (sen.length > maxLen) {
        // phrase très longue : on coupe aux virgules / espaces
        flush();
        var rest = sen;
        while (rest.length > maxLen) {
          var cut = rest.lastIndexOf(RegExp(r'[,،]\s'), maxLen);
          if (cut < 40) cut = rest.lastIndexOf(' ', maxLen);
          if (cut < 40) cut = maxLen;
          chunks.add(rest.substring(0, cut + 1).trim());
          rest = rest.substring(cut + 1).trim();
        }
        cur = rest;
        continue;
      }
      if (cur.isEmpty) {
        cur = sen;
      } else if (cur.length + 1 + sen.length <= maxLen) {
        cur = '$cur $sen';
      } else {
        flush();
        cur = sen;
      }
    }
    flush();
    return chunks;
  }

  /// Arrête la lecture ET vide la file (sinon la phrase suivante repartirait).
  Future<void> _stopTts() async {
    _ttsQueue = [];
    try { await _tts.stop(); } catch (_) {}
  }

  Future<void> _speakNextChunk() async {
    if (_ttsQueue.isEmpty) return;
    final chunk = _ttsQueue.removeAt(0);
    _ttsLastSpeakAt = DateTime.now();
    try {
      await _tts.speak(chunk);
    } catch (_) {
      if (_ttsQueue.isNotEmpty) {
        _speakNextChunk();
      } else if (mounted) {
        setState(() => _isSpeaking = false);
        if (_voiceMode) Future.delayed(const Duration(milliseconds: 300), _resumeListening);
      }
    }
  }

  Future<void> _speak(String text) async {
    final clean = _cleanForSpeech(text);
    if (clean.isEmpty) {
      if (_voiceMode) Future.delayed(const Duration(milliseconds: 300), _resumeListening);
      return;
    }
    try {
      await _initTts();
      await _stopTts();
      await _tts.setLanguage(_speechLocale().replaceAll('_', '-'));
      if (mounted) setState(() => _isSpeaking = true);
      // La réponse est lue EN ENTIER, phrase par phrase.
      _ttsQueue = _splitForSpeech(clean);
      _ttsLastSpeakAt = DateTime.now();
      await _speakNextChunk();
    } catch (_) {
      _ttsQueue = [];
      if (mounted) setState(() => _isSpeaking = false);
      // la voix a échoué : en mode vocal on continue quand même à écouter
      if (_voiceMode) Future.delayed(const Duration(milliseconds: 300), _resumeListening);
    }
  }

  /// Reprend l'écoute en mode vocal (jamais pendant que TOIT D’OR IA parle ou réfléchit).
  void _resumeListening() {
    if (!mounted || !_voiceMode || !_isOpen) return;
    if (_isListening || _isSpeaking || _isTyping) return;
    _toggleVoice();
  }

  /// Bouton « mode vocal » : lance ou arrête la conversation mains libres.
  void _toggleVoiceMode() {
    if (_voiceMode) {
      _stopVoiceMode();
      return;
    }
    setState(() {
      _voiceMode = true;
      _emptyListens = 0;
    });
    _ttsQueue = []; _tts.stop();
    if (!_isListening) _toggleVoice();
  }

  void _stopVoiceMode() {
    if (!_voiceMode && !_isSpeaking && !_isListening) return;
    _voiceMode = false;
    _speakNext = false;
    _emptyListens = 0;
    _ttsQueue = []; _tts.stop();
    if (_isListening) {
      _cancelListening();
      _micPulseAnim.stop();
      _micPulseAnim.reset();
    }
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _isListening = false;
        _voicePartial = '';
      });
    }
  }

  /// Identifiant de langue passé au moteur vocal.
  /// ⚠️ Sur le WEB, l'API du navigateur exige le format « fr-FR » (tiret). Avec « fr_FR »
  /// (underscore) Chrome ignore la langue et reconnaît dans la langue du navigateur/système
  /// (souvent l'anglais) : c'est ce qui écrivait du texte anglais sans rapport avec ce qui est dit.
  /// En local ça « marchait » seulement parce que le navigateur de développement était en français.
  String _listenLocaleId() {
    final id = _resolvedLocale ?? _speechLocale();
    return kIsWeb ? id.replaceAll('_', '-') : id;
  }

  /// Langue de la dictée = langue de l'application (et non plus toujours
  /// le français).
  String _speechLocale() {
    switch (localeNotifier.value.languageCode) {
      case 'en':
        return 'en_US';
      case 'es':
        return 'es_ES';
      case 'pt':
        return 'pt_PT';
      case 'de':
        return 'de_DE';
      case 'ar':
        return 'ar_SA';
      default:
        return 'fr_FR';
    }
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