// lib/services/report_service.dart
// Signalements d'annonces (onglet « Litiges » de l'espace admin).
// Routes : GET /api/admin/reports et PUT /api/admin/reports/:id
// (la permission « disputes.manage » est vérifiée côté serveur).

import 'package:flutter/foundation.dart' show ValueNotifier;

import 'api_service.dart';

/// Nombre de signalements à traiter (open, reviewing, needs_info).
final ValueNotifier<int> openReportsCountNotifier = ValueNotifier<int>(0);

class PropertyReportItem {
  final String id;
  final String reason;
  final String? details;
  final String status;
  final String? resolution;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final String reporterName;
  final String propertyId;
  final String propertyTitle;
  final String propertyCity;
  final String availabilityStatus;
  final String ownerName;
  final String ownerPhone;
  final int activeOnProperty;
  final int activeSameReason;

  const PropertyReportItem({
    required this.id,
    required this.reason,
    required this.details,
    required this.status,
    required this.resolution,
    required this.createdAt,
    required this.resolvedAt,
    required this.reporterName,
    required this.propertyId,
    required this.propertyTitle,
    required this.propertyCity,
    required this.availabilityStatus,
    required this.ownerName,
    required this.ownerPhone,
    required this.activeOnProperty,
    required this.activeSameReason,
  });

  bool get isActive =>
      status == 'open' || status == 'reviewing' || status == 'needs_info';
  bool get isSuspended => availabilityStatus == 'suspended';

  factory PropertyReportItem.fromJson(Map<String, dynamic> j) {
    String s(dynamic v) => v?.toString() ?? '';
    String? sn(dynamic v) {
      final t = v?.toString().trim() ?? '';
      return t.isEmpty ? null : t;
    }

    final reporter = (j['reporter'] as Map?) ?? const {};
    final property = (j['property'] as Map?) ?? const {};
    final owner = (property['proprietaire'] as Map?) ?? const {};

    return PropertyReportItem(
      id: s(j['id']),
      reason: s(j['reason']),
      details: sn(j['details']),
      status: s(j['status']),
      resolution: sn(j['resolution']),
      createdAt: DateTime.tryParse(s(j['createdAt']))?.toLocal(),
      resolvedAt: DateTime.tryParse(s(j['resolvedAt']))?.toLocal(),
      reporterName: s(reporter['name']),
      propertyId: s(property['id']),
      propertyTitle: s(property['titre']),
      propertyCity: s(property['ville']),
      availabilityStatus: s(property['availabilityStatus']),
      ownerName: s(owner['name']),
      ownerPhone: s(owner['telephone']),
      activeOnProperty: (j['activeReportsOnProperty'] as num?)?.toInt() ?? 0,
      activeSameReason: (j['activeReportsSameReason'] as num?)?.toInt() ?? 0,
    );
  }
}

class ReportListResult {
  final List<PropertyReportItem> items;
  final int total;
  final String? error;
  const ReportListResult({this.items = const [], this.total = 0, this.error});
}

class ReportUpdateResult {
  final bool ok;
  final String message;
  final String propertyAction; // none | suspend | restore (action réellement appliquée)
  const ReportUpdateResult({
    required this.ok,
    required this.message,
    this.propertyAction = 'none',
  });
}

class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();
  final _api = ApiService.instance;

  static const List<String> statuses = [
    'open', 'reviewing', 'needs_info', 'resolved', 'dismissed',
  ];

  static String statusLabel(String s) {
    switch (s) {
      case 'open':       return 'Ouvert';
      case 'reviewing':  return "En cours d'examen";
      case 'needs_info': return 'Infos demandées';
      case 'resolved':   return 'Résolu';
      case 'dismissed':  return 'Classé sans suite';
      default:           return s;
    }
  }

  static String reasonLabel(String r) {
    switch (r) {
      case 'already_rented':        return 'Déjà loué';
      case 'not_found':             return 'Bien introuvable';
      case 'misleading':            return 'Annonce trompeuse';
      case 'wrong_price':           return 'Prix incorrect';
      case 'suspicious_advertiser': return 'Annonceur suspect';
      case 'wrong_info_or_images':  return 'Infos ou photos erronées';
      default:                      return r;
    }
  }

  /// status == null : signalements à traiter ; 'all' : tous ; sinon un statut précis.
  Future<ReportListResult> list({String? status, int page = 1, int limit = 100}) async {
    final path = StringBuffer('/admin/reports?page=$page&limit=$limit');
    if (status != null) path.write('&status=$status');
    final res = await _api.get(path.toString(), auth: true);
    if (res['success'] != true) {
      return ReportListResult(
        error: (res['message'] ?? 'Impossible de charger les signalements').toString(),
      );
    }
    try {
      final raw = res['data'];
      final items = raw is List
          ? raw
              .whereType<Map>()
              .map((m) => PropertyReportItem.fromJson(Map<String, dynamic>.from(m)))
              .toList()
          : <PropertyReportItem>[];
      final total = (res['total'] as num?)?.toInt() ?? items.length;
      return ReportListResult(items: items, total: total);
    } catch (_) {
      return const ReportListResult(error: 'Réponse inattendue du serveur');
    }
  }

  /// Met à jour le compteur « à traiter » sans bruit (ex. admin sans permission).
  Future<void> refreshOpenCount() async {
    try {
      final res = await _api.get('/admin/reports?page=1&limit=1', auth: true);
      if (res['success'] == true) {
        openReportsCountNotifier.value = (res['total'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
  }

  Future<ReportUpdateResult> update(
    String id, {
    String? status,
    String? resolution,
    String? propertyAction,
  }) async {
    final body = <String, dynamic>{};
    if (status != null) body['status'] = status;
    if (resolution != null) body['resolution'] = resolution;
    if (propertyAction != null) body['propertyAction'] = propertyAction;
    final res = await _api.put('/admin/reports/$id', body, auth: true);
    final ok = res['success'] == true;
    return ReportUpdateResult(
      ok: ok,
      message: (res['message'] ?? (ok ? 'Signalement mis à jour' : 'Mise à jour impossible')).toString(),
      propertyAction: (res['propertyAction'] ?? 'none').toString(),
    );
  }
}