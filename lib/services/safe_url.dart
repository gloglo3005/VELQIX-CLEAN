// lib/services/safe_url.dart
//
// Garde-fou pour les liens fournis par le serveur (paiement, factures,
// exports) : seuls les liens https sont ouverts. Un lien javascript:, intent:,
// file: ou http: est refusé. Aucun autre comportement n'est modifié.

bool isSafeHttpsUrl(String? raw) {
  if (raw == null || raw.trim().isEmpty) return false;
  final uri = Uri.tryParse(raw.trim());
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
}

/// Comme Uri.parse, mais lève une Exception si le lien n'est pas en https.
Uri safeHttpsUri(String raw) {
  if (!isSafeHttpsUrl(raw)) {
    throw Exception('Lien non sécurisé refusé.');
  }
  return Uri.parse(raw.trim());
}
