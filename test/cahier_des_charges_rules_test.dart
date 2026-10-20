import 'package:flutter_test/flutter_test.dart';
import 'package:VELQIX/models/models.dart';

// Règles du cahier des charges v1.0 testées sur le modèle (sans réseau).

UserModel _owner({bool premium = false}) => UserModel(
      id: 'u1', nom: 'Doe', prenom: 'Jane', email: 'j@d.tg', telephone: '90000000',
      createdAt: DateTime(2026, 1, 1), isPremium: premium,
    );

PropertyModel _property({
  bool premium = false,
  bool fieldVerified = false,
  bool isAvailable = true,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? lastConfirmedAt,
  String? availabilityStatus,
}) =>
    PropertyModel(
      id: 'p1', titre: 'Chambre', description: '', type: PropertyType.immobilier,
      listingType: ListingType.location, categorie: PropertyCategory.chambre,
      prix: 20000, images: const [],
      adresse: AddressModel(rue: 'Rue 1', ville: 'Lomé', pays: 'Togo'),
      proprietaire: _owner(premium: premium),
      isAvailable: isAvailable,
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt,
      lastConfirmedAt: lastConfirmedAt,
      availabilityStatus: availabilityStatus,
      fieldVerified: fieldVerified,
    );

void main() {
  group('§10.3 — le paiement ne donne jamais le statut « vérifié »', () {
    test('un propriétaire Premium ne rend pas le bien vérifié', () {
      expect(_property(premium: true).isVelqixApproved, isFalse);
    });
    test('seule la vérification terrain donne le statut', () {
      expect(_property(fieldVerified: true).isVelqixApproved, isTrue);
    });
  });

  group('§7 — disponibilité', () {
    final old = DateTime.now().subtract(const Duration(days: 30));

    test('sans confirmation : « déclaré », jamais « confirmé »', () {
      expect(_property().availabilityState, AvailabilityState.declared);
    });
    test('confirmation récente', () {
      final p = _property(lastConfirmedAt: DateTime.now().subtract(const Duration(days: 1)));
      expect(p.availabilityState, AvailabilityState.confirmedRecently);
    });
    test('information ancienne : à reconfirmer', () {
      expect(_property(createdAt: old).availabilityState, AvailabilityState.toReconfirm);
      expect(_property(createdAt: old, lastConfirmedAt: old).availabilityState,
          AvailabilityState.toReconfirm);
    });
    test('statuts serveur', () {
      expect(_property(availabilityStatus: 'pending').availabilityState, AvailabilityState.pending);
      expect(_property(availabilityStatus: 'unavailable').availabilityState, AvailabilityState.unavailable);
      expect(_property(availabilityStatus: 'suspended').availabilityState, AvailabilityState.suspended);
      expect(_property(availabilityStatus: 'archived').availabilityState, AvailabilityState.archived);
      expect(_property(isAvailable: false).availabilityState, AvailabilityState.unavailable);
    });
  });

  group('§8.1 — catégories', () {
    test('valeur API de « local commercial »', () {
      expect(PropertyCategory.localCommercial.apiValue, 'local_commercial');
      expect(PropertyCategory.chambre.apiValue, 'chambre');
    });
  });
}
