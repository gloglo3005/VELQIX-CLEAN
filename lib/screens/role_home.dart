// lib/screens/role_home.dart
// Écran d'accueil selon le rôle de l'utilisateur connecté.

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'admin_dashboard_screen.dart';
import 'agent_workspace_screen.dart';
import 'main_shell.dart';

Widget roleHome() {
  final user = AuthService.instance.currentUserOrEmpty;
  switch (user.role) {
    case 'admin':
      return const AdminDashboardScreen();
    case 'demarcheur':
    case 'agent_entretien':
      return const AgentWorkspaceScreen();
    default:
      return MainShell(username: AuthService.instance.loggedUsername);
  }
}
