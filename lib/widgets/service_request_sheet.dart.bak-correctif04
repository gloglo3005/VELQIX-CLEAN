// lib/widgets/service_request_sheet.dart
// Demande de services payants (vérification terrain, visite accompagnée,
// entretien). Facturés à la prestation, séparément de l'abonnement Premium.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/mission_model.dart';
import '../models/models.dart';
import '../services/mission_service.dart';
import '../services/zone_service.dart';
import '../theme/app_theme.dart';
import 'auth_gate.dart';
import 'widgets.dart' show PrimaryButton, formatFcfa;

/// Ouvre la feuille de demande (connexion requise).
Future<void> showServiceRequestSheet(
  BuildContext context, {
  PropertyModel? property,
  String initialType = MissionType.verification,
}) async {
  if (!await requireLogin(context, reason: 'demander un service')) return;
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _ServiceSheet(property: property, initialType: initialType),
  );
}

/// Boutons « Services VelQix » affichés sur la page d'une annonce.
class ServiceActionsRow extends StatelessWidget {
  final PropertyModel property;
  const ServiceActionsRow({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      if (!property.isVelqixApproved)
        OutlinedButton.icon(
          onPressed: () => showServiceRequestSheet(context,
              property: property, initialType: MissionType.verification),
          icon: const Icon(Icons.fact_check_rounded, size: 16),
          label: const Text('Faire vérifier ce bien'),
        ),
      OutlinedButton.icon(
        onPressed: () =>
            showServiceRequestSheet(context, property: property, initialType: MissionType.visite),
        icon: const Icon(Icons.directions_walk_rounded, size: 16),
        label: const Text('Visite accompagnée'),
      ),
    ]);
  }
}

class _ServiceSheet extends StatefulWidget {
  final PropertyModel? property;
  final String initialType;
  const _ServiceSheet({required this.property, required this.initialType});

  @override
  State<_ServiceSheet> createState() => _ServiceSheetState();
}

class _ServiceSheetState extends State<_ServiceSheet> {
  late String _type = widget.initialType;
  ServicePricing _pricing = ServicePricing.fallback;
  PublicZones _zones = PublicZones.none;
  String? _zone; // zone choisie par le client (seulement quand aucun bien n'est sélectionné)
  final _address = TextEditingController();
  final _notes = TextEditingController();
  final _surface = TextEditingController();
  String _cleaning = 'Standard';
  bool _sending = false;
  bool _paying = false;
  String? _error;
  MissionModel? _created;

  @override
  void initState() {
    super.initState();
    _loadPricing();
    ZoneService.instance.getPublicZones().then((z) {
      if (mounted) setState(() => _zones = z);
    });
  }

  // Zone du bien (sa ville), sinon zone choisie par le client : elle détermine le prix affiché.
  String? get _propertyZone {
    final v = widget.property?.adresse.ville.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> _loadPricing() async {
    final p = await MissionService.instance.getPricing(zone: _propertyZone ?? _zone);
    if (mounted) setState(() => _pricing = p);
  }

  @override
  void dispose() {
    _address.dispose();
    _notes.dispose();
    _surface.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final property = widget.property;
    if (property == null && _address.text.trim().isEmpty) {
      setState(() => _error = "Indiquez l'adresse concernée.");
      return;
    }
    if (property == null && _zones.limited && _zones.zones.isNotEmpty && _zone == null) {
      setState(() => _error = 'Choisissez la zone concernée.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final m = await MissionService.instance.requestService(
        type: _type,
        propertyId: property?.id,
        address: property == null ? _address.text.trim() : null,
        notes: _notes.text.trim(),
        details: {
          if (_type == MissionType.entretien) ...{
            'prestation': _cleaning,
            if (_surface.text.trim().isNotEmpty) 'surface': _surface.text.trim(),
          },
          if (property == null && _zone != null) 'zone': _zone,
        },
      );
      if (!mounted) return;
      setState(() => _created = m);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pay(MissionModel m) async {
    setState(() {
      _paying = true;
      _error = null;
    });
    try {
      final url = await MissionService.instance.checkout(m.id);
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && mounted) setState(() => _error = "Impossible d'ouvrir la page de paiement.");
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  String _priceText(ServicePrice p) =>
      p.onQuote ? 'Sur devis' : formatFcfa(p.price!);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: _created == null ? _form() : _result(_created!),
        ),
      ),
    );
  }

  Widget _form() {
    final price = _pricing.of(_type);
    final property = widget.property;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Demander un service', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
      if (property != null) ...[
        const SizedBox(height: 4),
        Text(property.titre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
      ],
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 4, children: [
        for (final t in const [MissionType.verification, MissionType.visite, MissionType.entretien])
          ChoiceChip(
            avatar: Icon(MissionType.icon(t), size: 16),
            label: Text(MissionType.label(t), style: GoogleFonts.poppins(fontSize: 12)),
            selected: _type == t,
            onSelected: (_) => setState(() => _type = t),
          ),
      ]),
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Prix : ${_priceText(price)}',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primary)),
          const SizedBox(height: 2),
          Text(
            price.onQuote
                ? "VelQix vous envoie un devis selon la surface, l'état du bien et la durée. Vous êtes libre de l'accepter ou non."
                : 'Payé une seule fois, pour cette prestation. Indépendant de votre abonnement.',
            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ]),
      ),
      if (property == null) ...[
        const SizedBox(height: 12),
        TextField(
          controller: _address,
          decoration: const InputDecoration(labelText: 'Adresse du bien', prefixIcon: Icon(Icons.place_outlined)),
        ),
      ],
      if (property == null && _zones.limited && _zones.zones.isNotEmpty) ...[
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _zone,
          decoration: const InputDecoration(labelText: 'Zone', prefixIcon: Icon(Icons.map_outlined)),
          items: [for (final z in _zones.zones) DropdownMenuItem(value: z.name, child: Text(z.name))],
          onChanged: (v) {
            setState(() => _zone = v);
            _loadPricing();
          },
        ),
      ],
      if (_zones.limited) ...[
        const SizedBox(height: 8),
        Text(
          _zones.zones.isEmpty
              ? "Aucune zone n'est desservie pour le moment."
              : 'Zones desservies : ${_zones.zones.map((z) => z.name).join(', ')}.',
          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
      if (_type == MissionType.entretien) ...[
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _cleaning,
          decoration: const InputDecoration(labelText: 'Type de prestation'),
          items: const ['Standard', 'Approfondi', 'Après travaux', 'Entretien régulier']
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => setState(() => _cleaning = v ?? 'Standard'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _surface,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Surface approximative (m²)'),
        ),
      ],
      const SizedBox(height: 12),
      TextField(
        controller: _notes,
        maxLines: 2,
        decoration: const InputDecoration(labelText: 'Précisions (facultatif)', alignLabelWithHint: true),
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.error)),
      ],
      const SizedBox(height: 16),
      PrimaryButton(
        label: price.onQuote ? 'Demander un devis' : 'Demander (${formatFcfa(price.price!)})',
        isLoading: _sending,
        onPressed: _send,
      ),
    ]);
  }

  Widget _result(MissionModel m) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.check_circle_rounded, color: AppTheme.success),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Demande envoyée',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
      ]),
      const SizedBox(height: 8),
      Text('${MissionType.label(m.type)} · ${MissionStatus.label(m.status)}',
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      if (m.price > 0)
        Text('Montant : ${formatFcfa(m.price)}',
            style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(
        m.isPayable
            ? "Réglez pour lancer la mission : un agent VelQix sera assigné dès réception du paiement."
            : m.status == MissionStatus.devis
                ? 'Un devis vous sera envoyé. Retrouvez-le dans « Mes demandes de services » pour l\'accepter et payer.'
                : 'Suivez l\'avancement dans « Mes demandes de services ».',
        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.error)),
      ],
      const SizedBox(height: 16),
      if (m.isPayable)
        PrimaryButton(label: 'Payer ${formatFcfa(m.price)}', isLoading: _paying, onPressed: () => _pay(m)),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
      ),
    ]);
  }
}
