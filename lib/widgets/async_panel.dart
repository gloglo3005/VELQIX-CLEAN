// lib/widgets/async_panel.dart
// Chargement asynchrone avec état d'erreur / réessai, et grille de statistiques.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'widgets.dart' show EmptyState;

class AsyncPanel<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;
  const AsyncPanel({super.key, required this.load, required this.builder});
  @override
  State<AsyncPanel<T>> createState() => _AsyncPanelState<T>();
}

class _AsyncPanelState<T> extends State<AsyncPanel<T>> {
  T? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final d = await widget.load();
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

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) return const Center(child: CircularProgressIndicator());
    if (_error != null && _data == null) {
      return EmptyState(icon: Icons.cloud_off_rounded, title: _error!, buttonLabel: 'Réessayer', onButton: _reload);
    }
    return widget.builder(context, _data as T, _reload);
  }
}

/// Cartes de statistiques : n'affiche que les clés présentes dans [data].
Widget statGrid(Map<String, dynamic> data, List<MapEntry<String, String>> labels) {
  return Wrap(spacing: 10, runSpacing: 10, children: [
    for (final e in labels)
      if (data.containsKey(e.key))
        Container(
          width: 150,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${data[e.key]}',
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primary)),
            const SizedBox(height: 2),
            Text(e.value, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
          ]),
        ),
  ]);
}
