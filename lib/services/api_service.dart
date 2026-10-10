// ═══════════════════════════════════════════════════════════════════
// API SERVICE — Couche réseau centrale VelQix
// ═══════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  // ── URL selon environnement ───────────────────────────────────────
  // Backend en production sur Render.
  static const String _envUrl = String.fromEnvironment('API_URL', defaultValue: '');

  static String get baseUrl {
    if (_envUrl.isNotEmpty) return _envUrl;
    return 'https://velqix.onrender.com/api';
  }

  // URL WebSocket (même hôte que l'API, sans /api)
  static String get wsUrl {
    if (_envUrl.isNotEmpty) return _envUrl.replaceFirst('/api', '');
    return 'https://velqix.onrender.com';
  }

  static const String _kToken        = 'jwt_token';
  static const String _kRefreshToken = 'jwt_refresh_token';

  // ── Gestion des tokens ───────────────────────────────────────────
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kToken);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRefreshToken);
  }

  Future<void> saveRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRefreshToken, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kRefreshToken);
  }

  // ── Headers ──────────────────────────────────────────────────────
  Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // ── Refresh automatique du token ─────────────────────────────────
  // Le backend fait tourner les refresh tokens : deux refresh simultanés
  // avec le même token feraient échouer le second. On mutualise donc la
  // requête en cours.
  Future<bool>? _refreshInFlight;

  Future<bool> _tryRefresh() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() => _refreshInFlight = null);
  }

  /// Rafraîchit l'access token (appelé par ChatService sur TOKEN_EXPIRED).
  Future<bool> refreshAccessToken() => _tryRefresh();

  /// Access token garanti non expiré (rafraîchi si besoin), pour les appels
  /// qui ne passent pas par get/post/put/delete (multipart, http direct, socket).
  Future<String?> getValidToken() async {
    final token = await getToken();
    if (token == null) return null;
    final exp = _jwtExpiry(token);
    if (exp != null && exp.isBefore(DateTime.now().add(const Duration(seconds: 30)))) {
      if (await _tryRefresh()) return getToken();
    }
    return token;
  }

  DateTime? _jwtExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final exp = payload['exp'];
      if (exp is! num) return null;
      return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _doRefresh() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) return false;

      final res = await http
          .post(
            Uri.parse('$baseUrl/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(const Duration(seconds: 60));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['success'] == true) {
        await saveToken(data['data']['accessToken']);
        if (data['data']['refreshToken'] != null) {
          await saveRefreshToken(data['data']['refreshToken']);
        }
        return true;
      }
      // Refus explicite du serveur (session expirée, compte banni…)
      if (res.statusCode == 401 || res.statusCode == 403) {
        await _expireSession();
      }
      return false;
    } catch (_) {
      // Erreur réseau : on garde la session, un prochain appel réessaiera
      return false;
    }
  }

  /// Incrémenté quand la session est définitivement perdue (refresh refusé) :
  /// AuthService l'écoute pour vider l'utilisateur courant.
  final sessionExpiredNotifier = ValueNotifier<int>(0);

  Future<void> _expireSession() async {
    await clearToken();
    sessionExpiredNotifier.value++;
  }

  // ── Parse + gestion TOKEN_EXPIRED ────────────────────────────────
  Future<Map<String, dynamic>> _parseWithRefresh(
    http.Response res,
    Future<http.Response> Function() retry,
  ) async {
    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 401 && data['error'] == 'TOKEN_EXPIRED') {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          final retryRes = await retry();
          return _parse(retryRes);
        }
        return {'success': false, 'message': 'Session expirée', 'error': 'SESSION_EXPIRED'};
      }
      if (res.statusCode == 403 && data['error'] == 'ACCOUNT_BANNED') {
        await _expireSession();
      }
      return _parse(res);
    } catch (_) {
      return _error('Réponse invalide du serveur (${res.statusCode})');
    }
  }

  // ── Gestion centralisée des erreurs réseau ───────────────────────
  // `on SocketException` seul ne fonctionne PAS sur Flutter Web : le navigateur
  // lève une http.ClientException. Le serveur Render gratuit peut aussi mettre
  // ~1 minute à se réveiller : un timeout de 40 s faisait échouer le premier
  // appel de la journée. On gère les trois cas et, pour les lectures (GET),
  // on réessaie une fois.
  static const Duration _timeout = Duration(seconds: 60);

  Future<Map<String, dynamic>> _guard(
    Future<Map<String, dynamic>> Function() action, {
    int retries = 0,
  }) async {
    for (var attempt = 0;; attempt++) {
      try {
        return await action();
      } on TimeoutException {
        if (attempt < retries) continue;
        return _error('Le serveur met du temps à répondre (il est peut-être en train de se réveiller). Réessaie dans quelques secondes.');
      } on SocketException {
        if (attempt < retries) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        return _error('Impossible de joindre le serveur. Vérifie ta connexion.');
      } on http.ClientException {
        if (attempt < retries) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        return _error('Impossible de joindre le serveur. Vérifie ta connexion.');
      } catch (e) {
        return _error('Erreur inattendue : $e');
      }
    }
  }

  // ── GET ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> get(String path, {bool auth = false}) {
    return _guard(() async {
      final uri = Uri.parse('$baseUrl$path');
      final res = await http.get(uri, headers: await _headers(auth: auth)).timeout(_timeout);
      if (auth) {
        return _parseWithRefresh(
          res,
          () async => await http.get(uri, headers: await _headers(auth: true)),
        );
      }
      return _parse(res);
    }, retries: 1);
  }

  // ── POST ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) {
    return _guard(() async {
      final uri      = Uri.parse('$baseUrl$path');
      final bodyJson = jsonEncode(body);
      final res = await http
          .post(uri, headers: await _headers(auth: auth), body: bodyJson)
          .timeout(_timeout);
      if (auth) {
        return _parseWithRefresh(
          res,
          () async => await http.post(uri, headers: await _headers(auth: true), body: bodyJson),
        );
      }
      return _parse(res);
    });
  }

  // ── PUT ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) {
    return _guard(() async {
      final uri      = Uri.parse('$baseUrl$path');
      final bodyJson = jsonEncode(body);
      final res = await http
          .put(uri, headers: await _headers(auth: auth), body: bodyJson)
          .timeout(_timeout);
      if (auth) {
        return _parseWithRefresh(
          res,
          () async => await http.put(uri, headers: await _headers(auth: true), body: bodyJson),
        );
      }
      return _parse(res);
    });
  }

  // ── DELETE ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>> delete(String path, {bool auth = false}) {
    return _guard(() async {
      final uri = Uri.parse('$baseUrl$path');
      final res = await http.delete(uri, headers: await _headers(auth: auth)).timeout(_timeout);
      if (auth) {
        return _parseWithRefresh(
          res,
          () async => await http.delete(uri, headers: await _headers(auth: true)),
        );
      }
      return _parse(res);
    });
  }

  // ── Upload multipart (images) ────────────────────────────────────
  // ⚠️ MultipartFile.fromBytes/fromPath n'infère PAS le type MIME depuis
  // l'extension : sans contentType explicite, le champ part en
  // "application/octet-stream", ce que le fileFilter Multer du backend
  // rejette systématiquement (il exige "image/*"). D'où l'échec silencieux
  // de tous les uploads de photos.
  MediaType _mediaTypeFromFilename(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':  return MediaType('image', 'png');
      case 'webp': return MediaType('image', 'webp');
      case 'gif':  return MediaType('image', 'gif');
      case 'jpg':
      case 'jpeg':
      default:     return MediaType('image', 'jpeg');
    }
  }

  Future<Map<String, dynamic>> uploadFile(String path, File file) {
    return _guard(() async {
      final token   = await getValidToken();
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: _mediaTypeFromFilename(file.path),
      ));
      final streamed = await request.send().timeout(const Duration(seconds: 120));
      final res      = await http.Response.fromStream(streamed);
      return _parse(res);
    });
  }

  Future<Map<String, dynamic>> uploadBytes(
    String path,
    List<int> bytes,
    String filename,
  ) {
    return _guard(() async {
      final token   = await getValidToken();
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: _mediaTypeFromFilename(filename),
      ));
      final streamed = await request.send().timeout(const Duration(seconds: 120));
      final res      = await http.Response.fromStream(streamed);
      return _parse(res);
    });
  }

  // ── Upload vidéo (multipart, timeout long) ───────────────────────
  MediaType _videoMediaType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'mov':  return MediaType('video', 'quicktime');
      case 'webm': return MediaType('video', 'webm');
      case '3gp':  return MediaType('video', '3gpp');
      case 'm4v':  return MediaType('video', 'x-m4v');
      case 'mp4':
      default:     return MediaType('video', 'mp4');
    }
  }

  Future<Map<String, dynamic>> uploadVideoBytes(
    String path,
    List<int> bytes,
    String filename,
  ) {
    return _guard(() async {
      final token   = await getValidToken();
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: _videoMediaType(filename),
      ));
      // Une vidéo peut être longue à envoyer sur un réseau mobile.
      final streamed = await request.send().timeout(const Duration(minutes: 5));
      final res      = await http.Response.fromStream(streamed);
      return _parse(res);
    });
  }

  // ── Helpers ──────────────────────────────────────────────────────
  Map<String, dynamic> _parse(http.Response res) {
    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400) {
        return {
          'success': false,
          'message': data['message'] ?? 'Erreur ${res.statusCode}',
          'error': data['error'],
          ...data,
        };
      }
      return data;
    } catch (_) {
      return _error('Réponse invalide du serveur (${res.statusCode})');
    }
  }

  Map<String, dynamic> _error(String message) => {'success': false, 'message': message};
}
