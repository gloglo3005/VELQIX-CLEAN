import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/chat_service.dart';
import '../services/notification_service.dart';
import '../services/push_notification_service.dart';
import '../theme/app_theme.dart';
import 'add_listing_screen.dart';
import 'home_screen.dart';
import 'incoming_call_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

class MainShell extends StatefulWidget {
  final String username;

  const MainShell({
    super.key,
    required this.username,
  });

  @override
  State<MainShell> createState() =>
      _MainShellState();
}

class _MainShellState
    extends State<MainShell> with WidgetsBindingObserver {
  bool _openingIncomingCall = false;

  /// Onglet actuellement affiché.
  /// 0 = Accueil, 1 = Explorer, 3 = Messages, 4 = Profil
  /// (l'index 2 est le bouton "Publier", qui ouvre un écran à part).
  int _currentIndex = 0;

  /// Pages créées une seule fois : l'état de chaque onglet
  /// (défilement, recherche...) est conservé quand on change d'onglet.
  late final List<Widget> _pages;

  static const int _publishIndex = 2;

  /// Quand on revient dans l'app (après l'avoir quittée), on relance le
  /// socket : Android le coupe en arrière-plan.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ChatService.instance.reconnectIfNeeded();
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _pages = [
      HomeScreen(username: widget.username),
      const SearchScreen(),
      const SizedBox.shrink(), // emplacement du bouton "Publier"
      const MessagesScreen(),
      const ProfileScreen(),
    ];

    /// Enregistre le token push (sans effet s'il est déjà initialisé).
    unawaited(
      PushNotificationService.instance
          .initialize(),
    );

    /// Charger les notifications existantes.
    unawaited(
      NotificationService.instance
          .loadNotifications(),
    );

    /// Notification reçue en temps réel.
    latestNotificationNotifier
        .addListener(
      _handleLatestNotification,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    latestNotificationNotifier
        .removeListener(
      _handleLatestNotification,
    );

    super.dispose();
  }

  /// =============================================================
  /// NAVIGATION
  /// =============================================================

  void _onTabTap(int index) {
    if (index == _publishIndex) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              const AddListingScreen(),
        ),
      );
      return;
    }

    if (index == _currentIndex) {
      return;
    }

    setState(() => _currentIndex = index);
  }

  /// =============================================================
  /// LATEST NOTIFICATION
  /// =============================================================

  void _handleLatestNotification() {
    final notification =
        latestNotificationNotifier.value;

    if (notification == null ||
        !mounted) {
      return;
    }

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context)
            .hideCurrentSnackBar();

        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.notifications_active,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      if (notification.message
                          .isNotEmpty)
                        Text(
                          notification.message,
                          maxLines: 2,
                          overflow:
                              TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            behavior:
                SnackBarBehavior.floating,
          ),
        );

        latestNotificationNotifier
            .value = null;
      },
    );
  }

  /// =============================================================
  /// INCOMING CALL
  /// =============================================================

  void _checkIncomingCall(
    Map<String, dynamic>? call,
  ) {
    if (call == null ||
        !mounted ||
        _openingIncomingCall) {
      return;
    }

    _openingIncomingCall = true;

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) async {
        if (!mounted) {
          _openingIncomingCall =
              false;
          return;
        }

        /// Empêche une deuxième navigation.
        incomingCallNotifier.value =
            null;

        try {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) {
                return IncomingCallScreen(
                  callData: call,
                );
              },
            ),
          );
        } catch (e) {
          debugPrint(
            'Incoming call navigation error: $e',
          );
        } finally {
          _openingIncomingCall =
              false;
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<
        Map<String, dynamic>?>(
      valueListenable:
          incomingCallNotifier,
      builder: (
        context,
        incomingCall,
        child,
      ) {
        /// Si un appel arrive, on ouvre l'écran
        /// après le frame courant.
        if (incomingCall != null) {
          _checkIncomingCall(
            incomingCall,
          );
        }

        return Scaffold(
          body: _buildBody(context),
          bottomNavigationBar:
              _buildBottomBar(context),
        );
      },
    );
  }

  /// =============================================================
  /// BOTTOM BAR
  /// =============================================================

  Widget _buildBottomBar(
    BuildContext context,
  ) {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: _onTabTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor:
          Theme.of(context).colorScheme.surface,
      selectedItemColor: AppTheme.primary,
      unselectedItemColor: AppTheme.textHint,
      selectedLabelStyle:
          GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle:
          GoogleFonts.poppins(
        fontSize: 11,
      ),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_rounded),
          label: 'Accueil',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.explore_rounded),
          label: 'Explorer',
        ),
        BottomNavigationBarItem(
          icon: Icon(
            Icons.add_circle_rounded,
            size: 34,
          ),
          label: 'Publier',
        ),
        BottomNavigationBarItem(
          icon: Icon(
            Icons.chat_bubble_rounded,
          ),
          label: 'Messages',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_rounded),
          label: 'Profil',
        ),
      ],
    );
  }

  /// =============================================================
  /// BODY
  /// =============================================================

  Widget _buildBody(
    BuildContext context,
  ) {
    return Stack(
      children: [
        _buildMainContent(context),

        /// Badge de notifications.
        ValueListenableBuilder<int>(
          valueListenable:
              unreadNotifCountNotifier,
          builder: (
            context,
            unreadCount,
            child,
          ) {
            if (unreadCount <= 0) {
              return const SizedBox.shrink();
            }

            return Positioned(
              top: 12,
              right: 12,
              child: IgnorePointer(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration:
                      BoxDecoration(
                    color: Colors.red,
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: Text(
                    unreadCount > 99
                        ? '99+'
                        : unreadCount.toString(),
                    style:
                        GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// =============================================================
  /// MAIN CONTENT
  /// =============================================================

  Widget _buildMainContent(
    BuildContext context,
  ) {
    return IndexedStack(
      index: _currentIndex,
      children: _pages,
    );
  }
}