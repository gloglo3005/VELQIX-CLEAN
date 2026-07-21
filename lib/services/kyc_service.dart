// ═══════════════════════════════════════════════════════════════════
// KYC SERVICE — VelQix
// Soumission et suivi du statut de vérification d'identité
// ═══════════════════════════════════════════════════════════════════

import 'dart:io';
import 'api_service.dart';

enum KycStatus { nonSoumis, enAttente, approuve, rejete }

class KycService {
  KycService._();
  static final KycService instance = KycService._();

  final _api = ApiService.instance;

  // ─── Statut actuel ────────────────────────────────────────────────
  Future<({KycStatus status, String? rejectedReason, Map<String, dynamic>? doc})>
      getStatus() async {
    final res = await _api.get('/kyc/status', auth: true);
    if (res['success'] != true) {
      return (status: KycStatus.nonSoumis, rejectedReason: null, doc: null);
    }

    final data   = res['data'] as Map<String, dynamic>;
    final status = _parseStatus(data['status'] as String?);
    final doc    = data['doc'] as Map<String, dynamic>?;

    return (
      status: status,
      rejectedReason: doc?['rejectedReason'] as String?,
      doc: doc,
    );
  }

  // ─── Soumettre un document ────────────────────────────────────────
  /// Étapes :
  /// 1. Uploader le fichier via POST /upload/image
  /// 2. Soumettre l'URL via POST /kyc
  Future<({bool success, String? error})> submitDocument({
    required File file,
    required String type, // 'cni' | 'passeport' | 'permis'
  }) async {
    // 1. Upload
    final uploadRes = await _api.uploadFile('/upload/image', file);
    if (uploadRes['success'] != true) {
      return (success: false, error: (uploadRes['message'] as String?) ?? 'Erreur upload');
    }
    final fileUrl = uploadRes['data']['url'] as String?;
    if (fileUrl == null) return (success: false, error: 'URL introuvable');

    // 2. Soumettre
    final res = await _api.post('/kyc', {'type': type, 'fileUrl': fileUrl}, auth: true);
    if (res['success'] != true) {
      return (success: false, error: (res['message'] as String?) ?? 'Erreur soumission');
    }
    return (success: true, error: null);
  }

  KycStatus _parseStatus(String? s) {
    switch (s) {
      case 'approuve':    return KycStatus.approuve;
      case 'en_attente':  return KycStatus.enAttente;
      case 'rejete':      return KycStatus.rejete;
      default:            return KycStatus.nonSoumis;
    }
  }
}