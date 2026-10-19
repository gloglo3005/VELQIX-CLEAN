// lib/models/mission_model.dart
// Missions terrain : vérification d'un bien, visite accompagnée, entretien.
// Une mission est demandée par un client, réalisée par un démarcheur (vérification,
// visite) ou un agent d'entretien, puis validée avant paiement de l'agent.

import 'package:flutter/material.dart';

class MissionType {
  static const verification = 'verification';
  static const visite = 'visite';
  static const entretien = 'entretien';

  static String label(String t) {
    switch (t) {
      case verification: return 'Vérification terrain';
      case visite:       return 'Visite accompagnée';
      case entretien:    return 'Entretien / nettoyage';
      default:           return t;
    }
  }

  static IconData icon(String t) {
    switch (t) {
      case verification: return Icons.fact_check_rounded;
      case visite:       return Icons.directions_walk_rounded;
      case entretien:    return Icons.cleaning_services_rounded;
      default:           return Icons.assignment_rounded;
    }
  }

  /// Types de missions traités par un rôle opérationnel.
  static List<String> forRole(String role) =>
      role == 'agent_entretien' ? const [entretien] : const [verification, visite];
}

class MissionStatus {
  static const devis = 'devis';                 // en attente du devis VelQix
  static const devisPropose = 'devis_propose';  // devis prêt : le client accepte et paie
  static const attentePaiement = 'attente_paiement';
  static const disponible = 'disponible';       // payée, visible par les agents
  static const acceptee = 'acceptee';
  static const rapportSoumis = 'rapport_soumis';
  static const validee = 'validee';
  static const contestee = 'contestee';
  static const annulee = 'annulee';
  static const rejetee = 'rejetee';

  static String label(String s) {
    switch (s) {
      case devis:            return 'Devis en préparation';
      case devisPropose:     return 'Devis à valider';
      case attentePaiement:  return 'Paiement en attente';
      case disponible:       return 'En recherche d\'agent';
      case acceptee:         return 'Agent assigné';
      case rapportSoumis:    return 'Rapport en validation';
      case validee:          return 'Terminée';
      case contestee:        return 'Contestée';
      case annulee:          return 'Annulée';
      case rejetee:          return 'Rapport refusé';
      default:               return s;
    }
  }

  static Color color(String s) {
    switch (s) {
      case validee:                          return const Color(0xFF10B981);
      case annulee:
      case rejetee:
      case contestee:                        return const Color(0xFFEF4444);
      case acceptee:
      case rapportSoumis:                    return const Color(0xFF3B82F6);
      default:                               return const Color(0xFFF59E0B);
    }
  }
}

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

class MissionModel {
  final String id;
  final String type;
  final String status;
  final String? propertyId;
  final String propertyTitle;
  final String address;
  final String zone;
  final String clientName;
  final String contactName;   // visible seulement une fois la mission acceptée
  final String contactPhone;  // idem
  final double price;         // prix payé par le client / devis
  final double agentPay;      // rémunération de l'agent (hors transport)
  final double transport;
  final String paymentStatus; // non_paye | en_attente | paye | rembourse
  final String payoutStatus;  // aucun | du | paye
  final DateTime? scheduledAt;
  final DateTime createdAt;
  final String notes;
  final String reportNote;
  final List<String> evidence;
  final Map<String, dynamic> details; // surface, type de nettoyage, matériel…

  const MissionModel({
    required this.id,
    required this.type,
    required this.status,
    this.propertyId,
    this.propertyTitle = '',
    this.address = '',
    this.zone = '',
    this.clientName = '',
    this.contactName = '',
    this.contactPhone = '',
    this.price = 0,
    this.agentPay = 0,
    this.transport = 0,
    this.paymentStatus = 'non_paye',
    this.payoutStatus = 'aucun',
    this.scheduledAt,
    required this.createdAt,
    this.notes = '',
    this.reportNote = '',
    this.evidence = const [],
    this.details = const {},
  });

  double get agentTotal => agentPay + transport;
  bool get isPaid => paymentStatus == 'paye';
  bool get isPayable =>
      !isPaid && (status == MissionStatus.attentePaiement || status == MissionStatus.devisPropose);
  bool get isOpenForAgents => status == MissionStatus.disponible;
  bool get isActiveForAgent => status == MissionStatus.acceptee || status == MissionStatus.rejetee;
  String get title => propertyTitle.isNotEmpty ? propertyTitle : MissionType.label(type);

  factory MissionModel.fromJson(Map<String, dynamic> j) {
    final p = j['property'] is Map ? j['property'] as Map : const {};
    return MissionModel(
      id: (j['id'] ?? j['_id'] ?? '').toString(),
      type: (j['type'] ?? MissionType.verification).toString(),
      status: (j['status'] ?? MissionStatus.disponible).toString(),
      propertyId: (j['propertyId'] ?? p['id'])?.toString(),
      propertyTitle: (j['propertyTitle'] ?? p['titre'] ?? '').toString(),
      address: (j['address'] ?? p['address'] ?? '').toString(),
      zone: (j['zone'] ?? '').toString(),
      clientName: (j['clientName'] ?? '').toString(),
      contactName: (j['contactName'] ?? '').toString(),
      contactPhone: (j['contactPhone'] ?? '').toString(),
      price: _num(j['price']),
      agentPay: _num(j['agentPay']),
      transport: _num(j['transport']),
      paymentStatus: (j['paymentStatus'] ?? 'non_paye').toString(),
      payoutStatus: (j['payoutStatus'] ?? 'aucun').toString(),
      scheduledAt: j['scheduledAt'] != null ? DateTime.tryParse(j['scheduledAt'].toString()) : null,
      createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()) ?? DateTime.now(),
      notes: (j['notes'] ?? '').toString(),
      reportNote: (j['reportNote'] ?? '').toString(),
      evidence: (j['evidence'] is List)
          ? (j['evidence'] as List).map((e) => e.toString()).toList()
          : const [],
      details: j['details'] is Map ? Map<String, dynamic>.from(j['details'] as Map) : const {},
    );
  }
}
