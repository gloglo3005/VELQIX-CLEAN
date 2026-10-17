// lib/services/listings_cache.dart
// Cache local de la liste d'annonces : l'accueil s'affiche instantanément avec
// les dernières annonces connues pendant que le serveur (parfois lent à
// répondre) envoie la liste à jour.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ListingsCache {
  static const _key = 'cache_properties_v1';
  static const _max = 40;

  static Future<List<Map<String, dynamic>>?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final list = jsonDecode(raw) as List;
      return list.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(List<dynamic> rawItems) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(rawItems.take(_max).toList()));
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
