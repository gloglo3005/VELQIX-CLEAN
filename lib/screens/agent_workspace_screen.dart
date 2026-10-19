// lib/screens/agent_workspace_screen.dart
// Espace de travail des comptes opérationnels :
//   • Démarcheur VelQix  : vérifications terrain et visites accompagnées
//   • Agent d'entretien  : nettoyage / entretien
// Parcours : voir la mission ET sa rémunération → accepter → se rendre sur place
// → envoyer les preuves → suivre la validation et le paiement.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/mission_model.dart';
import '../services/auth_service.dart';
import '../services/mission_service.dart';
import '../services/property_service.dart';
import '../services/web_file_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart' show EmptyState, formatFcfa;
import 'main_shell.dart';

class AgentWorkspaceScreen extends StatefulWidget {
  const AgentWorkspaceScreen({super.key});
  @override
  State<AgentWorkspaceScreen> createState() => _AgentWorkspaceScreenState();
}

class _AgentWorkspaceScreenState extends State<AgentWorkspaceScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final Map<AgentScope, List<MissionModel>> _data = {};
  final Map<AgentScope, String?> _errors = {};
  final Set<AgentScope> _loading = {};
  String? _busyId;

  String get _role => AuthService.instance.currentUserOrEmpty.role;
  bool get _isCleaner => _role == 'agent_entretien';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _reloadMissions();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _reloadMissions() {
    _load(AgentScope.available);
    _load(AgentScope.mine);
  }

  Future<void> _load(AgentScope scope) async {
    setState(() {
      _loading.add(scope);
      _errors[scope] = null;
    });
    try {
      final all = await MissionService.instance.getAgentMissions(scope);
      final types = MissionType.forRole(_role);
      if (!mounted) return;
      setState(() => _data[scope] = all.where((m) => types.contains(m.type)).toList());
    } catch (e) {
      if (!mounted) return;
      setState(() => _errors[scope] = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading.remove(scope));
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.error : null,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainShell(username: '')),
      (_) => false,
    );
  }

  Future<void> _accept(MissionModel m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accepter cette mission ?'),
        content: Text(
          'Rémunération : ${formatFcfa(m.agentPay)}'
          '${m.transport > 0 ? ' + ${formatFcfa(m.transport)} de transport' : ''}.\n\n'
          'Elle vous est versée après validation de la mission.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Accepter')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busyId = m.id);
    final err = await MissionService.instance.accept(m.id);
    if (!mounted) return;
    setState(() => _busyId = null);
    if (err != null) {
      _snack(err, error: true);
    } else {
      _snack('Mission acceptée.');
      _tab.animateTo(1);
    }
    _reloadMissions();
  }

  Future<void> _openReport(MissionModel m) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ReportSheet(mission: m),
    );
    if (done == true && mounted) {
      _snack('Rapport envoyé : il sera validé avant le paiement.');
      _reloadMissions();
    }
  }

  Future<void> _call(String phone) async => launchUrl(Uri(scheme: 'tel', path: phone));

  @override
  Widget build(BuildContext context) {
    final me = AuthService.instance.currentUserOrEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_isCleaner ? 'Velqix Services' : 'Velqix Agent',
              style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700)),
          Text(me.fullName, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w400)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Parcourir les annonces',
            icon: const Icon(Icons.storefront_rounded),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => MainShell(username: AuthService.instance.loggedUsername))),
          ),
          IconButton(tooltip: 'Se déconnecter', icon: const Icon(Icons.logout_rounded), onPressed: _logout),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Missions'),
            Tab(text: 'Mes missions'),
            Tab(text: 'Mes gains'),
            Tab(text: 'Disponibilité'),
          ],
        ),
      ),
      body: TabBarView(controller: _tab, children: [
        _missionList(AgentScope.available),
        _missionList(AgentScope.mine),
        const _EarningsTab(),
        const _AvailabilityTab(),
      ]),
    );
  }

  Widget _missionList(AgentScope scope) {
    if (_loading.contains(scope) && !_data.containsKey(scope)) {
      return const Center(child: CircularProgressIndicator());
    }
    final err = _errors[scope];
    if (err != null && !_data.containsKey(scope)) {
      return EmptyState(icon: Icons.cloud_off_rounded, title: err, buttonLabel: 'Réessayer', onButton: () => _load(scope));
    }
    final list = _data[scope] ?? [];
    if (list.isEmpty) {
      return EmptyState(
        icon: scope == AgentScope.available ? Icons.task_alt_rounded : Icons.assignment_outlined,
        title: scope == AgentScope.available ? 'Aucune mission disponible' : "Vous n'avez aucune mission en cours",
        subtitle: scope == AgentScope.available
            ? 'Vérifiez vos zones dans l\'onglet Disponibilité.'
            : null,
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(scope),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _card(list[i], scope),
          ),
        ),
      ),
    );
  }

  Widget _card(MissionModel m, AgentScope scope) {
    final busy = _busyId == m.id;
    final color = MissionStatus.color(m.status);
    final d = m.details;
    final extra = [
      if ((d['prestation'] ?? '').toString().isNotEmpty) d['prestation'].toString(),
      if ((d['surface'] ?? '').toString().isNotEmpty) '${d['surface']} m²',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(MissionType.icon(m.type), color: AppTheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(MissionType.label(m.type),
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          if (scope == AgentScope.mine)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
              child: Text(MissionStatus.label(m.status),
                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
            ),
        ]),
        const SizedBox(height: 6),
        Text(m.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
        if (m.address.isNotEmpty || m.zone.isNotEmpty)
          Text([m.address, m.zone].where((s) => s.isNotEmpty).join(' · '),
              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
        if (extra.isNotEmpty)
          Text(extra, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
        if (m.notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Précisions : ${m.notes}',
                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
          ),
        const SizedBox(height: 8),
        // Rémunération TOUJOURS visible avant d'accepter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            const Icon(Icons.payments_rounded, size: 16, color: AppTheme.success),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Rémunération : ${formatFcfa(m.agentPay)}'
                '${m.transport > 0 ? ' + ${formatFcfa(m.transport)} transport' : ''}',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
        // Coordonnées du contact : seulement une fois la mission acceptée
        if (scope == AgentScope.mine && m.contactName.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.person_outline_rounded, size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text('Contact : ${m.contactName}', style: GoogleFonts.poppins(fontSize: 12))),
            if (m.contactPhone.isNotEmpty)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Appeler',
                icon: const Icon(Icons.call_rounded, color: AppTheme.success, size: 20),
                onPressed: () => _call(m.contactPhone),
              ),
          ]),
        ],
        const SizedBox(height: 10),
        if (busy)
          const LinearProgressIndicator(minHeight: 3)
        else if (scope == AgentScope.available)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _accept(m),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Accepter la mission'),
            ),
          )
        else if (m.isActiveForAgent)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openReport(m),
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: Text(m.status == MissionStatus.rejetee ? 'Corriger le rapport' : 'Remplir le rapport'),
            ),
          )
        else
          Text(
            m.status == MissionStatus.rapportSoumis
                ? 'Rapport envoyé : validation en cours.'
                : m.status == MissionStatus.validee
                    ? (m.payoutStatus == 'paye' ? 'Terminée · rémunération payée.' : 'Terminée · rémunération à venir.')
                    : MissionStatus.label(m.status),
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
          ),
      ]),
    );
  }
}

// ─── Rapport de mission (preuves, constat) ───────────────────────────────────
class _ReportSheet extends StatefulWidget {
  final MissionModel mission;
  const _ReportSheet({required this.mission});
  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  late final List<MapEntry<String, String>> _items = _checklistFor(widget.mission.type);
  late final Map<String, bool> _checked = {for (final e in _items) e.key: false};
  final List<String> _photos = [];
  final _note = TextEditingController();
  bool _sending = false;
  String? _error;

  static const _maxPhotos = 5;

  static List<MapEntry<String, String>> _checklistFor(String type) {
    switch (type) {
      case MissionType.entretien:
        return const [
          MapEntry('done', 'La prestation demandée a été réalisée entièrement'),
          MapEntry('clean', 'Le logement a été laissé propre et rangé'),
        ];
      case MissionType.visite:
        return const [
          MapEntry('done', 'La visite a été réalisée avec le client'),
          MapEntry('matches', "Le bien correspond à l'annonce"),
        ];
      default:
        return const [
          MapEntry('exists', "Le bien existe réellement à l'adresse indiquée"),
          MapEntry('photosMatch', 'Les photos correspondent au bien visité'),
          MapEntry('ownerIdentified', 'Le propriétaire (ou son mandataire) a été rencontré et identifié'),
        ];
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _canSend => _checked.values.every((v) => v) && _photos.isNotEmpty && !_sending;

  Future<void> _addPhotos({required bool camera}) async {
    final room = _maxPhotos - _photos.length;
    if (room <= 0) return;
    if (camera) {
      final p = await WebFilePicker.pickImage(capture: true);
      if (p != null) setState(() => _photos.add(p));
    } else {
      final list = await WebFilePicker.pickMultipleImages(maxCount: room);
      if (list.isNotEmpty) setState(() => _photos.addAll(list.take(room)));
    }
  }

  Future<String?> _upload(String src, int i) async {
    try {
      final bytes = await WebFilePicker.readBytes(src);
      if (bytes == null) return null;
      final ext = WebFilePicker.imageSubtype(src);
      final r = await PropertyService.instance
          .uploadImageBytes(bytes, 'preuve_$i.${ext == 'jpeg' ? 'jpg' : ext}');
      return r.url;
    } catch (_) {
      return null;
    }
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final urls = await Future.wait([for (var i = 0; i < _photos.length; i++) _upload(_photos[i], i)]);
    if (!mounted) return;
    final evidence = urls.whereType<String>().toList();
    if (evidence.length != _photos.length) {
      setState(() {
        _sending = false;
        _error = "Une photo n'a pas pu être envoyée. Réessayez.";
      });
      return;
    }
    final err = await MissionService.instance.submitReport(
      widget.mission.id,
      checklist: _checked,
      evidence: evidence,
      note: _note.text,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _sending = false;
        _error = err;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.mission;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Rapport de mission', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(m.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
            if (m.status == MissionStatus.rejetee && m.reportNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Motif du refus : ${m.reportNote}',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.error)),
            ],
            const SizedBox(height: 8),
            for (final e in _items)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _checked[e.key],
                onChanged: (v) => setState(() => _checked[e.key] = v ?? false),
                title: Text(e.value, style: GoogleFonts.poppins(fontSize: 13)),
              ),
            const SizedBox(height: 8),
            Text('Preuves (photos) : ${_photos.length}/$_maxPhotos',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (var i = 0; i < _photos.length; i++)
                InputChip(
                  avatar: const Icon(Icons.photo_rounded, size: 16),
                  label: Text('Photo ${i + 1}'),
                  onDeleted: _sending ? null : () => setState(() => _photos.removeAt(i)),
                ),
              ActionChip(
                avatar: const Icon(Icons.photo_camera_rounded, size: 16),
                label: const Text('Prendre'),
                onPressed: _sending ? null : () => _addPhotos(camera: true),
              ),
              ActionChip(
                avatar: const Icon(Icons.photo_library_rounded, size: 16),
                label: const Text('Galerie'),
                onPressed: _sending ? null : () => _addPhotos(camera: false),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Constat / remarques', alignLabelWithHint: true),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.error)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canSend ? _send : null,
                child: _sending
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Envoyer le rapport'),
              ),
            ),
            const SizedBox(height: 6),
            Text('Cochez tout et ajoutez au moins une photo pour envoyer.',
                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint)),
          ]),
        ),
      ),
    );
  }
}

// ─── Mes gains ───────────────────────────────────────────────────────────────
class _EarningsTab extends StatefulWidget {
  const _EarningsTab();
  @override
  State<_EarningsTab> createState() => _EarningsTabState();
}

class _EarningsTabState extends State<_EarningsTab> {
  AgentEarnings? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await MissionService.instance.getEarnings();
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _stat(String label, double v, Color c) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(formatFcfa(v), style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, color: c)),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) return const Center(child: CircularProgressIndicator());
    if (_error != null && _data == null) {
      return EmptyState(icon: Icons.cloud_off_rounded, title: _error!, buttonLabel: 'Réessayer', onButton: _load);
    }
    final d = _data!;
    return RefreshIndicator(
      onRefresh: _load,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              _stat('En validation', d.pending, AppTheme.warning),
              const SizedBox(width: 8),
              _stat('À recevoir', d.due, AppTheme.primary),
              const SizedBox(width: 8),
              _stat('Déjà payé', d.paid, AppTheme.success),
            ]),
            const SizedBox(height: 16),
            Text('Historique', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (d.items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Center(
                  child: Text('Aucune rémunération pour le moment.',
                      style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
                ),
              ),
            for (final it in d.items)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text((it['title'] ?? 'Mission').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(
                        {'en_attente': 'En validation', 'du': 'À recevoir', 'paye': 'Payé'}[it['status']] ??
                            (it['status'] ?? '').toString(),
                        style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ]),
                  ),
                  Text(formatFcfa(((it['amount'] ?? 0) as num).toDouble()),
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}

// ─── Disponibilité (zones et horaires) ───────────────────────────────────────
class _AvailabilityTab extends StatefulWidget {
  const _AvailabilityTab();
  @override
  State<_AvailabilityTab> createState() => _AvailabilityTabState();
}

class _AvailabilityTabState extends State<_AvailabilityTab> {
  bool _available = true;
  final _zones = TextEditingController();
  final _hours = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    MissionService.instance.getAvailability().then((a) {
      if (!mounted) return;
      setState(() {
        _available = a.available;
        _zones.text = a.zones;
        _hours.text = a.hours;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _zones.dispose();
    _hours.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final err = await MissionService.instance.saveAvailability(
        AgentAvailability(available: _available, zones: _zones.text.trim(), hours: _hours.text.trim()));
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? 'Disponibilité enregistrée.'),
      backgroundColor: err == null ? null : AppTheme.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _available,
            onChanged: (v) => setState(() => _available = v),
            title: Text('Disponible pour de nouvelles missions',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text('Désactivez pendant vos absences : aucune mission ne vous sera proposée.',
                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _zones,
            decoration: const InputDecoration(
              labelText: 'Zones couvertes',
              hintText: 'Ex : Lomé centre, Agoè, Tokoin',
              prefixIcon: Icon(Icons.map_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hours,
            decoration: const InputDecoration(
              labelText: 'Horaires',
              hintText: 'Ex : Lundi–samedi, 8h–18h',
              prefixIcon: Icon(Icons.schedule_rounded),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18, width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Enregistrer'),
          ),
        ]),
      ),
    );
  }
}
