// lib/services/zone_service.dart
// Zones de couverture et tarifs par zone (GEO-01, GEO-02).
//
// Public : GET /zones (zones desservies, pour l'afficher au client).
// Admin  : GET/POST /admin/zones, PUT/DELETE /admin/zones/:id, PUT /admin/zones/:id/rates,
//          GET /admin/zones/reference-rate (tarif de référence pour pré-remplir un devis).
//
// Le serveur décide de tout (couverture, prix, journal d'audit). L'app affiche et envoie.

import 'package:flutter/foundation.dart' show debugPrint;
import 'api_service.dart';

String _msg(Map<String, dynamic> res, String fallback) => (res['message'] ?? fallback).toString();

int _int(dynamic v) => v is num ? v.round() : int.tryParse('${v ?? ''}') ?? 0;

/// Tarif d'un type de mission dans une zone (FCFA).
class ZoneRate {
  final int price;
  final int agentPay;
  final int transport;
  const ZoneRate({required this.price, required this.agentPay, required this.transport});

  factory ZoneRate.fromJson(Map<String, dynamic> j) =>
      ZoneRate(price: _int(j['price']), agentPay: _int(j['agentPay']), transport: _int(j['transport']));

  Map<String, dynamic> toJson() => {'price': price, 'agentPay': agentPay, 'transport': transport};
}

/// Zone vue par l'administration.
class AdminZone {
  final String id;
  final String name;
  final String country;
  final List<String> aliases;
  final bool isActive;
  final String? note;
  final Map<String, ZoneRate> rates; // par type de mission

  const AdminZone({
    required this.id,
    required this.name,
    required this.country,
    required this.aliases,
    required this.isActive,
    required this.note,
    required this.rates,
  });

  factory AdminZone.fromJson(Map<String, dynamic> j) {
    final rawRates = j['rates'] is Map ? Map<String, dynamic>.from(j['rates'] as Map) : <String, dynamic>{};
    final note = (j['note'] ?? '').toString().trim();
    return AdminZone(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      country: (j['country'] ?? 'TG').toString(),
      aliases: j['aliases'] is List ? (j['aliases'] as List).map((e) => e.toString()).toList() : <String>[],
      isActive: j['isActive'] != false,
      note: note.isEmpty ? null : note,
      rates: {
        for (final e in rawRates.entries)
          if (e.value is Map) e.key: ZoneRate.fromJson(Map<String, dynamic>.from(e.value as Map)),
      },
    );
  }
}

/// Zone desservie, vue par le client.
class PublicZone {
  final String id;
  final String name;
  final String country;
  final int verificationPrice;
  const PublicZone({required this.id, required this.name, required this.country, required this.verificationPrice});
}

class PublicZones {
  /// false tant que l'administration n'a défini aucune zone : la couverture n'est pas limitée
  /// et l'app n'affiche aucune liste de zones.
  final bool limited;
  final List<PublicZone> zones;
  const PublicZones({required this.limited, required this.zones});

  static const none = PublicZones(limited: false, zones: <PublicZone>[]);
}

class ZoneService {
  ZoneService._();
  static final ZoneService instance = ZoneService._();
  final _api = ApiService.instance;

  // ─── Client ────────────────────────────────────────────────────────────────
  /// Ne lève jamais : en cas d'échec, aucune limite n'est affichée (le serveur reste le juge).
  Future<PublicZones> getPublicZones() async {
    try {
      final res = await _api.get('/zones');
      if (res['success'] == true && res['data'] is Map) {
        final d = Map<String, dynamic>.from(res['data'] as Map);
        final list = d['zones'] is List ? d['zones'] as List : const [];
        return PublicZones(
          limited: d['coverageLimited'] == true,
          zones: [
            for (final z in list.whereType<Map>())
              PublicZone(
                id: (z['id'] ?? '').toString(),
                name: (z['name'] ?? '').toString(),
                country: (z['country'] ?? 'TG').toString(),
                verificationPrice: _int(z['verificationPrice']),
              ),
          ],
        );
      }
    } catch (e) {
      debugPrint('Zones load error: $e');
    }
    return PublicZones.none;
  }

  // ─── Administration ────────────────────────────────────────────────────────
  Future<List<AdminZone>> adminList() async {
    final res = await _api.get('/admin/zones', auth: true);
    if (res['success'] != true) throw Exception(_msg(res, 'Impossible de charger les zones.'));
    final list = res['data'] is List ? res['data'] as List : const [];
    return list.whereType<Map>().map((m) => AdminZone.fromJson(Map<String, dynamic>.from(m))).toList();
  }

  /// Retourne null en cas de succès, sinon le message d'erreur.
  Future<String?> createZone({
    required String name,
    required String country,
    required List<String> aliases,
    required bool isActive,
    String? note,
  }) async {
    final res = await _api.post('/admin/zones', {
      'name': name,
      'country': country,
      'aliases': aliases,
      'isActive': isActive,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    }, auth: true);
    return res['success'] == true ? null : _msg(res, 'Création impossible.');
  }

  Future<String?> updateZone(
    String id, {
    required String name,
    required String country,
    required List<String> aliases,
    required bool isActive,
    String? note,
  }) async {
    final res = await _api.put('/admin/zones/$id', {
      'name': name,
      'country': country,
      'aliases': aliases,
      'isActive': isActive,
      'note': note?.trim() ?? '',
    }, auth: true);
    return res['success'] == true ? null : _msg(res, 'Mise à jour impossible.');
  }

  Future<String?> setActive(String id, bool isActive) async {
    final res = await _api.put('/admin/zones/$id', {'isActive': isActive}, auth: true);
    return res['success'] == true ? null : _msg(res, 'Mise à jour impossible.');
  }

  Future<String?> deleteZone(String id) async {
    final res = await _api.delete('/admin/zones/$id', auth: true);
    return res['success'] == true ? null : _msg(res, 'Suppression impossible.');
  }

  /// [rates] : type de mission -> tarif, ou null pour revenir au tarif général.
  /// Un type absent n'est pas modifié.
  Future<String?> saveRates(String id, Map<String, ZoneRate?> rates) async {
    final res = await _api.put('/admin/zones/$id/rates', {
      'rates': {for (final e in rates.entries) e.key: e.value?.toJson()},
    }, auth: true);
    return res['success'] == true ? null : _msg(res, 'Enregistrement impossible.');
  }

  /// Tarif de référence de la zone pour un type de mission (pré-remplissage d'un devis).
  /// Null s'il n'y en a pas, ou en cas d'échec : l'admin saisit alors le devis à la main.
  Future<ZoneRate?> referenceRate({required String zone, required String type}) async {
    if (zone.trim().isEmpty) return null;
    try {
      final res = await _api.get(
        '/admin/zones/reference-rate?zone=${Uri.encodeQueryComponent(zone.trim())}&type=$type',
        auth: true,
      );
      if (res['success'] == true && res['data'] is Map) {
        final r = (res['data'] as Map)['rate'];
        if (r is Map) return ZoneRate.fromJson(Map<String, dynamic>.from(r));
      }
    } catch (e) {
      debugPrint('Reference rate error: $e');
    }
    return null;
  }
}
