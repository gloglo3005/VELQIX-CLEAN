
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart' show localeNotifier;
import '../services/app_translations.dart';
import '../services/chat_service.dart'
    show conversationsNotifier, incomingCallNotifier;
import '../services/notification_service.dart'
    show
        unreadNotifCountNotifier,
        NotificationService,
        latestNotificationNotifier;
import '../theme/app_theme.dart';
import '../widgets/ai_assistant_widget.dart';

import 'add_listing_screen.dart';
import 'explore_screen.dart';
import 'home_screen.dart';
import 'incoming_call_screen.dart';
import 'messages_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

class MainShell extends StatefulWidget {
  final String username;

  const MainShell({
    super.key,
    this.username = 'Utilisateur',
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  VoidCallback? _notificationListener;

  @override
  void initState() {
    super.initState();

    _screens = [
      HomeScreen(
        username: widget.username,
      ),
      const ExploreScreen(),
      const MessagesScreen(),
      const ProfileScreen(),
    ];

    // Charge les notifications déjà présentes côté backend.
    NotificationService.instance.loadNotifications();

    // Écoute les nouvelles notifications en temps réel.
    _notificationListener = () {
      final notif = latestNotificationNotifier.value;

      if (!mounted || notif == null) {
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context)
            .hideCurrentSnackBar();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${notif.titre}: ${notif.corps}',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(
              seconds: 4,
            ),
          ),
        );

        // Consommer la notification après affichage.
        latestNotificationNotifier.value = null;
      });
    };

    latestNotificationNotifier.addListener(
      _notificationListener!,
    );
  }

  @override
  void dispose() {
    if (_notificationListener != null) {
      latestNotificationNotifier.removeListener(
        _notificationListener!,
      );
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: localeNotifier,
      builder: (_, __, ___) {
        return ValueListenableBuilder(
          valueListenable: conversationsNotifier,
          builder: (_, conversations, __) {
            // Total des messages non lus.
            final totalUnread = conversations.fold<int>(
              0,
              (sum, conversation) =>
                  sum + conversation.unreadCount,
            );

            return Scaffold(
              body: Stack(
                children: [
                  IndexedStack(
                    index: _currentIndex,
                    children: _screens,
                  ),

                  const AiAssistantWidget(),

                  // ─────────────────────────────────────────────
                  // APPEL ENTRANT
                  // ─────────────────────────────────────────────
                  ValueListenableBuilder<
                      Map<String, dynamic>?>(
                    valueListenable:
                        incomingCallNotifier,
                    builder: (
                      _,
                      incomingCall,
                      __,
                    ) {
                      if (incomingCall != null) {
                        WidgetsBinding.instance
                            .addPostFrameCallback(
                          (_) {
                            if (!mounted) {
                              return;
                            }

                            // Consomme immédiatement
                            // l'événement.
                            incomingCallNotifier.value =
                                null;

                            Navigator.of(
                              context,
                              rootNavigator: true,
                            ).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    IncomingCallScreen(
                                  callData: incomingCall,
                                ),
                              ),
                            );
                          },
                        );
                      }

                      return const SizedBox.shrink();
                    },
                  ),

                  // ─────────────────────────────────────────────
                  // CLOCHETTE NOTIFICATIONS
                  // ─────────────────────────────────────────────
                  Positioned(
                    top:
                        MediaQuery.of(context).padding.top +
                            8,
                    right: 16,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const NotificationsScreen(),
                          ),
                        );
                      },
                      child:
                          ValueListenableBuilder<int>(
                        valueListenable:
                            unreadNotifCountNotifier,
                        builder: (
                          _,
                          count,
                          __,
                        ) {
                          return Stack(
                            clipBehavior:
                                Clip.none,
                            children: [
                              Container(
                                padding:
                                    const EdgeInsets.all(
                                  10,
                                ),
                                decoration:
                                    BoxDecoration(
                                  color:
                                      AppTheme.surface,
                                  shape:
                                      BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withOpacity(
                                        0.08,
                                      ),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons
                                      .notifications_outlined,
                                  size: 20,
                                  color: AppTheme
                                      .textPrimary,
                                ),
                              ),

                              if (count > 0)
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: Container(
                                    constraints:
                                        const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      horizontal: 3,
                                    ),
                                    decoration:
                                        const BoxDecoration(
                                      color:
                                          AppTheme.error,
                                      shape:
                                          BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        count > 99
                                            ? '99+'
                                            : '$count',
                                        style:
                                            GoogleFonts
                                                .poppins(
                                          fontSize: 9,
                                          color:
                                              Colors.white,
                                          fontWeight:
                                              FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),

              // ─────────────────────────────────────────────
              // BOUTON AJOUT
              // ─────────────────────────────────────────────
              floatingActionButton:
                  FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const AddListingScreen(),
                    ),
                  );
                },
                backgroundColor: AppTheme.accent,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 28,
                  color: Colors.white,
                ),
              ),

              floatingActionButtonLocation:
                  FloatingActionButtonLocation
                      .centerDocked,

              // ─────────────────────────────────────────────
              // NAVIGATION
              // ─────────────────────────────────────────────
              bottomNavigationBar: BottomAppBar(
                color: AppTheme.surface,
                elevation: 8,
                shadowColor: Colors.black12,
                shape:
                    const CircularNotchedRectangle(),
                notchMargin: 8,
                child: SizedBox(
                  height: 62,
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceAround,
                    children: [
                      _NavItem(
                        icon:
                            Icons.home_rounded,
                        label: tr('nav_home'),
                        index: 0,
                        current: _currentIndex,
                        onTap: () {
                          setState(
                            () => _currentIndex = 0,
                          );
                        },
                      ),

                      _NavItem(
                        icon:
                            Icons.search_rounded,
                        label:
                            tr('nav_explore'),
                        index: 1,
                        current: _currentIndex,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const SearchScreen(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(width: 56),

                      _NavItem(
                        icon: Icons
                            .chat_bubble_outline_rounded,
                        label:
                            tr('nav_messages'),
                        index: 2,
                        current: _currentIndex,
                        onTap: () {
                          setState(
                            () => _currentIndex = 2,
                          );
                        },
                        badge: totalUnread > 0
                            ? totalUnread
                            : null,
                      ),

                      _NavItem(
                        icon: Icons
                            .person_outline_rounded,
                        label:
                            tr('nav_profile'),
                        index: 3,
                        current: _currentIndex,
                        onTap: () {
                          setState(
                            () => _currentIndex = 3,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == current;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration:
                      const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary
                            .withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.textHint,
                  ),
                ),

                if (badge != null && badge! > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      constraints:
                          const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 3,
                      ),
                      decoration:
                          const BoxDecoration(
                        color: AppTheme.error,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          badge! > 99
                              ? '99+'
                              : '$badge',
                          style:
                              GoogleFonts.poppins(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 2),

            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: isSelected
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: isSelected
                    ? AppTheme.primary
                    : AppTheme.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

