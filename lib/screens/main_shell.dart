import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/chat_service.dart';
import '../services/notification_service.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
  });

  @override
  State<MainShell> createState() =>
      _MainShellState();
}

class _MainShellState
    extends State<MainShell> {
  bool _openingIncomingCall = false;

  @override
  void initState() {
    super.initState();

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
    latestNotificationNotifier
        .removeListener(
      _handleLatestNotification,
    );

    super.dispose();
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
        );
      },
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
    /*
     * IMPORTANT :
     *
     * Garde ici ton contenu/navigateur principal
     * existant si MainShell possède déjà une logique
     * d'onglets/navigation.
     *
     * Cette partie ne doit pas être remplacée par
     * une interface vide dans ton projet réel.
     */

    return const SizedBox.expand();
  }
}