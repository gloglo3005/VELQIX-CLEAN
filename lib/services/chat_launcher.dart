import 'package:flutter/material.dart';

import '../screens/messages_screen.dart';
import 'property_service.dart';

/// Ouvre la conversation avec un utilisateur à partir de son id.
/// Sert aux missions : le client écrit à l'agent assigné, l'agent écrit
/// au client, depuis la carte de la mission.
Future<void> openChatWith(BuildContext context, String userId) async {
  final nav = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final user = await PropertyService.instance.fetchUserProfile(userId, auth: true);

  if (user == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Impossible d\'ouvrir la conversation pour le moment.')),
    );
    return;
  }

  nav.push(
    MaterialPageRoute(
      builder: (_) => ChatScreen(user: user, otherUserId: userId),
    ),
  );
}