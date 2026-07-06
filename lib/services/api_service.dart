// ═══════════════════════════════════════════════════════════════════
// API SERVICE — Couche réseau centrale VelQix
// ═══════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
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
  Future<bool> _tryRefresh() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) return false;

      final res = await http
          .post(
            Uri.parse('$baseUrl/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['success'] == true) {
        await saveToken(data['data']['accessToken']);
        if (data['data']['refreshToken'] != null) {
          await saveRefreshToken(data['data']['refreshToken']);
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
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
        // Refresh échoué → déconnexion
        await clearToken();
        return {'success': false, 'message': 'Session expirée', 'error': 'SESSION_EXPIRED'};
      }
      return _parse(res);
    } catch (_) {
      return _error('Réponse invalide du serveur (${res.statusCode})');
    }
  }

  // ── GET ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> get(String path, {bool auth = false}) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final res = await http
          .get(uri, headers: await _headers(auth: auth))
          .timeout(const Duration(seconds: 15));
      if (auth) {
        return _parseWithRefresh(
          res,
          () async => await http.get(uri, headers: await _headers(auth: true)),
        );
      }
      return _parse(res);
    } on SocketException {
      return _error('Impossible de joindre le serveur. Vérifie ta connexion.');
    } catch (e) {
      return _error('Erreur inattendue : $e');
    }
  }

  // ── POST ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    try {
      final uri      = Uri.parse('$baseUrl$path');
      final bodyJson = jsonEncode(body);
      final res = await http
          .post(uri, headers: await _headers(auth: auth), body: bodyJson)
          .timeout(const Duration(seconds: 15));
      if (auth) {
        return _parseWithRefresh(
          res,
          () async => await http.post(uri, headers: await _headers(auth: true), body: bodyJson),
        );
      }
      return _parse(res);
    } on SocketException {
      return _error('Impossible de joindre le serveur. Vérifie ta connexion.');
    } catch (e) {
      return _error('Erreur inattendue : $e');
    }
  }

  // ── PUT ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    try {
      final uri      = Uri.parse('$baseUrl$path');
      final bodyJson = jsonEncode(body);
      final res = await http
          .put(uri, headers: await _headers(auth: auth), body: bodyJson)
          .timeout(const Duration(seconds: 15));
      if (auth) {
        return _parseWithRefresh(
          res,
          () async => await http.put(uri, headers: await _headers(auth: true), body: bodyJson),
        );
      }
      return _parse(res);
    } on SocketException {
      return _error('Impossible de joindre le serveur. Vérifie ta connexion.');
    } catch (e) {
      return _error('Erreur inattendue : $e');
    }
  }

  // ── DELETE ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>> delete(String path, {bool auth = false}) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final res = await http
          .delete(uri, headers: await _headers(auth: auth))
          .timeout(const Duration(seconds: 15));
      if (auth) {
        return _parseWithRefresh(
          res,
          () async => await http.delete(uri, headers: await _headers(auth: true)),
        );
      }
      return _parse(res);
    } on SocketException {
      return _error('Impossible de joindre le serveur. Vérifie ta connexion.');
    } catch (e) {
      return _error('Erreur inattendue : $e');
    }
  }

  // ── Upload multipart (images) ────────────────────────────────────
  Future<Map<String, dynamic>> uploadFile(String path, File file) async {
    try {
      final token   = await getToken();
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final res      = await http.Response.fromStream(streamed);
      return _parse(res);
    } on SocketException {
      return _error('Impossible de joindre le serveur.');
    } catch (e) {
      return _error('Erreur upload : $e');
    }
  }

  Future<Map<String, dynamic>> uploadBytes(
    String path,
    List<int> bytes,
    String filename,
  ) async {
    try {
      final token   = await getToken();
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final res      = await http.Response.fromStream(streamed);
      return _parse(res);
    } catch (e) {
      return _error('Erreur upload : $e');
    }
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