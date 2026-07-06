// ═══════════════════════════════════════════════════════════════════
// API SERVICE — Couche réseau centrale VelQix
// Tous les appels HTTP vers le backend Node.js/Express
// ═══════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  // ── Configuration ────────────────────────────────────────────────
  // 🔧 Changer cette URL selon l'environnement :
  //   - Émulateur Android  → 'http://10.0.2.2:3000/api'
  //   - Vrai téléphone     → 'http://192.168.X.X:3000/api'  (IP locale du PC)
  //   - Production Render  → 'https://velqix-backend.onrender.com/api'
  static const String baseUrl = 'http://localhost:3000/api';

  static const String _kToken = 'jwt_token';

  // ── Token ────────────────────────────────────────────────────────
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kToken);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
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

  // ── Méthodes HTTP génériques ─────────────────────────────────────

  Future<Map<String, dynamic>> get(String path, {bool auth = false}) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl$path'), headers: await _headers(auth: auth))
          .timeout(const Duration(seconds: 15));
      return _parse(res);
    } on SocketException {
      return _error('Impossible de joindre le serveur. Vérifie ta connexion.');
    } on HttpException {
      return _error('Erreur réseau.');
    } catch (e) {
      return _error('Erreur inattendue : $e');
    }
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: await _headers(auth: auth),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      return _parse(res);
    } on SocketException {
      return _error('Impossible de joindre le serveur. Vérifie ta connexion.');
    } catch (e) {
      return _error('Erreur inattendue : $e');
    }
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    try {
      final res = await http
          .put(
            Uri.parse('$baseUrl$path'),
            headers: await _headers(auth: auth),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      return _parse(res);
    } on SocketException {
      return _error('Impossible de joindre le serveur. Vérifie ta connexion.');
    } catch (e) {
      return _error('Erreur inattendue : $e');
    }
  }

  Future<Map<String, dynamic>> delete(String path, {bool auth = false}) async {
    try {
      final res = await http
          .delete(Uri.parse('$baseUrl$path'), headers: await _headers(auth: auth))
          .timeout(const Duration(seconds: 15));
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
      final token = await getToken();
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));

      if (token != null) request.headers['Authorization'] = 'Bearer $token';

      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamed);
      return _parse(res);
    } on SocketException {
      return _error('Impossible de joindre le serveur.');
    } catch (e) {
      return _error('Erreur upload : $e');
    }
  }

  // Upload depuis bytes (pour le web ou camera)
  Future<Map<String, dynamic>> uploadBytes(
    String path,
    List<int> bytes,
    String filename,
  ) async {
    try {
      final token = await getToken();
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));

      if (token != null) request.headers['Authorization'] = 'Bearer $token';

      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamed);
      return _parse(res);
    } catch (e) {
      return _error('Erreur upload : $e');
    }
  }

  // ── Helpers privés ───────────────────────────────────────────────
  Map<String, dynamic> _parse(http.Response res) {
    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      // Si le serveur renvoie un code d'erreur HTTP mais success:true → corriger
      if (res.statusCode >= 400) {
        return {
          'success': false,
          'message': data['message'] ?? 'Erreur ${res.statusCode}',
          ...data,
        };
      }
      return data;
    } catch (_) {
      return _error('Réponse invalide du serveur (${res.statusCode})');
    }
  }

  Map<String, dynamic> _error(String message) => {
        'success': false,
        'message': message,
      };
}