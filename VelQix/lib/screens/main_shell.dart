import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/app_translations.dart';
import '../main.dart' show localeNotifier;
import '../widgets/ai_assistant_widget.dart';
import 'home_screen.dart';
import 'explore_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'add_listing_screen.dart';

class MainShell extends StatefulWidget {
  final String username;
  const MainShell({super.key, this.username = 'Utilisateur'});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(username: widget.username),
      const ExploreScreen(),
      const MessagesScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: localeNotifier,
      builder: (_, __, ___) => Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _screens),
          // ── Bouton IA flottant bas-gauche ──────────────────────────────
          const AiAssistantWidget(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddListingScreen())),
        backgroundColor: AppTheme.accent,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.add_rounded, size: 28, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: AppTheme.surface,
        elevation: 8,
        shadowColor: Colors.black12,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_rounded, label: tr('nav_home'), index: 0, current: _currentIndex, onTap: () => setState(() => _currentIndex = 0)),
              _NavItem(icon: Icons.search_rounded, label: tr('nav_explore'), index: 1, current: _currentIndex, onTap: () => setState(() => _currentIndex = 1)),
              const SizedBox(width: 56),
              _NavItem(icon: Icons.chat_bubble_outline_rounded, label: tr('nav_messages'), index: 2, current: _currentIndex, onTap: () => setState(() => _currentIndex = 2), badge: 2),
              _NavItem(icon: Icons.person_outline_rounded, label: tr('nav_profile'), index: 3, current: _currentIndex, onTap: () => setState(() => _currentIndex = 3)),
            ],
          ),
        ),
      ),
    ),   // ValueListenableBuilder
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final VoidCallback onTap;
  final int? badge;

  const _NavItem({required this.icon, required this.label, required this.index, required this.current, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    final isSelected = index == current;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 22, color: isSelected ? AppTheme.primary : AppTheme.textHint),
                ),
                if (badge != null)
                  Positioned(
                    top: -2, right: -2,
                    child: Container(
                      width: 16, height: 16,
                      decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
                      child: Center(child: Text('$badge', style: GoogleFonts.poppins(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700))),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.poppins(fontSize: 10, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: isSelected ? AppTheme.primary : AppTheme.textHint)),
          ],
        ),
      ),
    );
  }
}
