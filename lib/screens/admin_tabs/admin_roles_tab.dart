// lib/screens/admin_tabs/admin_roles_tab.dart
// Matrice rôles × permissions (comme les groupes / permissions de Django).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';
import 'admin_common.dart';

class AdminRolesTab extends StatefulWidget {
  const AdminRolesTab({super.key});
  @override
  State<AdminRolesTab> createState() => _AdminRolesTabState();
}

class _AdminRolesTabState extends State<AdminRolesTab> {
  Map<String, Set<String>> _matrix = {};
  final Set<String> _dirty = {};
  bool _loading = true;
  bool _fromServer = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final m = await AdminService.instance.getRoleMatrix();
    if (!mounted) return;
    setState(() {
      _matrix = {for (final e in m.permissions.entries) e.key: {...e.value}};
      _fromServer = m.fromServer;
      _dirty.clear();
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    String? error;
    for (final role in _dirty.toList()) {
      error = await AdminService.instance.saveRolePermissions(role, _matrix[role] ?? {});
      if (error != null) break;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      adminSnack(context, error, error: true);
      return;
    }
    adminSnack(context, 'Permissions enregistrées.');
    setState(() => _dirty.clear());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Rôles et permissions',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text("Définissez ce que chaque rôle a le droit de faire. Le rôle Administrateur a toujours tous les droits.",
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
        if (!_fromServer)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Text(
                "Valeurs par défaut affichées : la route GET /admin/roles n'est pas encore disponible côté API, "
                "l'enregistrement ne fonctionnera qu'une fois le backend prêt.",
                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textPrimary)),
          ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 22,
              dataRowMinHeight: 54,
              dataRowMaxHeight: 60,
              columns: [
                DataColumn(label: Text('Permission', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                for (final r in AdminService.roles)
                  DataColumn(
                      label: Text(AdminService.roleLabel(r),
                          style: GoogleFonts.poppins(
                              fontSize: 12, fontWeight: FontWeight.w700, color: adminRoleColor(r)))),
              ],
              rows: [
                for (final perm in AdminService.permissions)
                  DataRow(cells: [
                    DataCell(Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(perm.label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
                        Text(perm.group, style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textHint)),
                      ],
                    )),
                    for (final r in AdminService.roles)
                      DataCell(Switch(
                        value: r == 'admin' || (_matrix[r]?.contains(perm.key) ?? false),
                        onChanged: r == 'admin'
                            ? null
                            : (v) => setState(() {
                                  final set = _matrix.putIfAbsent(r, () => {});
                                  v ? set.add(perm.key) : set.remove(perm.key);
                                  _dirty.add(r);
                                }),
                      )),
                  ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _dirty.isEmpty || _saving ? null : _load,
              child: const Text('Annuler les changements'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _dirty.isEmpty || _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Enregistrer (${_dirty.length})'),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Text("Les permissions doivent aussi être vérifiées par l'API : ce tableau ne fait que les configurer.",
            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint)),
      ],
    );
  }
}
