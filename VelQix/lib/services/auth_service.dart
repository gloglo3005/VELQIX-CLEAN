// ═══════════════════════════════════════════════════════════════════
// AUTH SERVICE — VelQix
// Connecté au backend Node.js/Express via JWT
// Google Sign-In et Facebook Login conservés
// ═══════════════════════════════════════════════════════════════════

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import 'api_service.dart';

// ── Clés SharedPreferences (profil mis en cache localement) ─────────
const _kLoggedIn    = 'auth_logged_in';
const _kUserId      = 'auth_user_id';
const _kNom         = 'auth_nom';
const _kPrenom      = 'auth_prenom';
const _kEmail       = 'auth_email';
const _kTelephone   = 'auth_telephone';
const _kAvatarUrl   = 'auth_avatar_url';
const _kIsPremium   = 'auth_is_premium';
const _kIsVerified  = 'auth_is_verified';
const _kRole        = 'auth_role';
const _kCreatedAt   = 'auth_created_at';
const _kAuthMethod  = 'auth_method';
const _kCountryCode = 'auth_country_code';
const _kCountryName = 'auth_country_name';

// ── Google Sign-In ───────────────────────────────────────────────────
final _googleSignIn = GoogleSignIn(
  clientId: '465274402627-7qtn4rava253u4qh0gbr6bv74pu9ieqm.apps.googleusercontent.com',
  scopes: ['email', 'profile'],
);

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _api = ApiService.instance;

  UserModel? _currentUser;

  bool get isLoggedIn => _currentUser != null;
  UserModel? get currentUser => _currentUser;

  // ─── Auto-login au démarrage ─────────────────────────────────────
  // Tente de restaurer la session depuis le cache local,
  // puis vérifie auprès du backend que le token est toujours valide.
  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool(_kLoggedIn) ?? false;
    if (!loggedIn) return false;

    // Restaurer depuis le cache local d'abord (affichage rapide)
    _currentUser = _userFromPrefs(prefs);
    if (_currentUser == null) return false;

    // Vérifier le token auprès du backend en arrière-plan
    final res = await _api.get('/auth/me', auth: true);
    if (res['success'] == true) {
      // Mettre à jour le profil avec les données fraîches du backend
      _currentUser = _userFromJson(res['data']);
      await _cacheUser(_currentUser!, method: prefs.getString(_kAuthMethod) ?? 'email');
      notifyUserChanged();
      return true;
    } else {
      // Token expiré ou invalide → déconnexion propre
      await logout();
      return false;
    }
  }

  // ─── Inscription email/password ──────────────────────────────────
  /// Retourne null si succès, un message d'erreur sinon.
  Future<String?> register({
    required String nom,
    required String prenom,
    required String email,
    required String password,
    String? telephone,
    String? countryCode,
    String? countryName,
    String accountType = 'personal',
    String? nomEntreprise,
    String? typeActivite,
  }) async {
    final res = await _api.post('/auth/register', {
      'nom': nom,
      'prenom': prenom,
      'email': email,
      'password': password,
      if (telephone != null) 'telephone': telephone,
      if (countryCode != null) 'countryCode': countryCode,
      if (countryName != null) 'countryName': countryName,
      'accountType': accountType,
      if (nomEntreprise != null) 'nomEntreprise': nomEntreprise,
      if (typeActivite != null) 'typeActivite': typeActivite,
    });

    if (res['success'] != true) {
      return res['message'] ?? 'Erreur lors de l\'inscription.';
    }

    await _api.saveToken(res['data']['accessToken']);
    _currentUser = _userFromJson(res['data']['user']);
    await _cacheUser(_currentUser!, method: 'email');
    notifyUserChanged();
    return null;
  }

  // ─── Connexion email/password ────────────────────────────────────
  /// Retourne null si succès, un message d'erreur sinon.
  Future<String?> login({
  String? email,
  String? username,  // ← ajouter ce paramètre
  required String password,
}) async {
  final res = await _api.post('/auth/login', {
    'email': email ?? username ?? '',
    'password': password,
  });

    if (res['success'] != true) {
      return res['message'] ?? 'Email ou mot de passe invalide.';
    }
   
    await _api.saveToken(res['data']['accessToken']);
    _currentUser = _userFromJson(res['data']['user']);
    await _cacheUser(_currentUser!, method: 'email');
    notifyUserChanged();
    return null;
  }

  // ─── Connexion Google ────────────────────────────────────────────
  Future<String?> loginWithGoogle() async {
    try {
      GoogleSignInAccount? account;
      try { account = await _googleSignIn.signInSilently(); } catch (_) {}
      if (account == null) {
        try {
          account = await _googleSignIn.signIn();
        } catch (e) {
          final msg = e.toString().toLowerCase();
          if (msg.contains('cancel') || msg.contains('annul') || msg.contains('dismiss')) {
            return 'Connexion Google annulée.';
          }
          rethrow;
        }
      }
      account ??= _googleSignIn.currentUser;
      if (account == null) return 'Connexion Google annulée.';

      final googleAuth = await account.authentication;
      final idToken = googleAuth.idToken;

      if (idToken != null) {
        // Envoyer le token Google au backend pour validation
        final res = await _api.post('/auth/google', {'token': idToken});
        if (res['success'] == true) {
          await _api.saveToken(res['data']['accessToken']);
          _currentUser = _userFromJson(res['data']['user']);
          await _cacheUser(_currentUser!, method: 'google');
          notifyUserChanged();
          return null;
        }
      }

      // Fallback : créer le user localement si le backend Google n'est pas encore implémenté
      final names = account.displayName?.split(' ') ?? ['', ''];
      final prenom = names.isNotEmpty ? names.first : '';
      final nom = names.length > 1 ? names.sublist(1).join(' ') : '';
      _currentUser = UserModel(
        id: 'google_${account.id}',
        nom: nom.isEmpty ? account.email.split('@').first : nom,
        prenom: prenom,
        email: account.email,
        telephone: '',
        avatarUrl: account.photoUrl,
        isVerified: true,
        isPremium: false,
        rating: 0, totalAvis: 0,
        createdAt: DateTime.now(),
        role: 'client',
      );
      await _cacheUser(_currentUser!, method: 'google');
      notifyUserChanged();
      return null;
    } catch (e) {
      if (_currentUser != null) return null;
      final msg = e.toString();
      if (msg.contains('popup_closed') || msg.contains('user_cancel') ||
          msg.contains('canceled') || msg.contains('annul')) {
        return 'Connexion Google annulée.';
      }
      return null;
    }
  }

  // ─── Connexion Facebook ──────────────────────────────────────────
  Future<String?> loginWithFacebook() async {
    try {
      final result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );
      if (result.status != LoginStatus.success) return 'Connexion Facebook annulée.';

      final data = await FacebookAuth.instance.getUserData(
        fields: 'name,email,picture.width(200)',
      );
      final fullName = data['name'] as String? ?? '';
      final names = fullName.split(' ');
      final prenom = names.isNotEmpty ? names.first : '';
      final nom = names.length > 1 ? names.sublist(1).join(' ') : fullName;
      final email = data['email'] as String? ?? 'facebook_user@velqix.tg';
      final avatar = (data['picture']?['data']?['url']) as String?;

      // Essayer de passer par le backend Facebook
      final fbToken = result.accessToken?.tokenString;
      if (fbToken != null) {
        final res = await _api.post('/auth/facebook', {'token': fbToken});
        if (res['success'] == true) {
          await _api.saveToken(res['data']['accessToken']);
          _currentUser = _userFromJson(res['data']['user']);
          await _cacheUser(_currentUser!, method: 'facebook');
          notifyUserChanged();
          return null;
        }
      }

      // Fallback local
      _currentUser = UserModel(
        id: 'fb_${data['id'] ?? DateTime.now().millisecondsSinceEpoch}',
        nom: nom, prenom: prenom, email: email,
        telephone: '', avatarUrl: avatar,
        isVerified: true, isPremium: false,
        rating: 0, totalAvis: 0,
        createdAt: DateTime.now(), role: 'client',
      );
      await _cacheUser(_currentUser!, method: 'facebook');
      notifyUserChanged();
      return null;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('not supported') || msg.contains('MissingPluginException') ||
          msg.contains('PlatformException')) {
        return "Facebook Login non disponible sur le web. Utilisez l'app mobile.";
      }
      return 'Erreur Facebook Login : $e';
    }
  }

  // ─── Modifier le profil ──────────────────────────────────────────
  Future<String?> updateProfile({
    required String nom,
    required String prenom,
    String? telephone,
    String? avatarUrl,
    String? countryCode,
    String? countryName,
  }) async {
    final res = await _api.put('/auth/profile', {
      'nom': nom,
      'prenom': prenom,
      if (telephone != null) 'telephone': telephone,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (countryCode != null) 'countryCode': countryCode,
      if (countryName != null) 'countryName': countryName,
    }, auth: true);

    if (res['success'] != true) {
      return res['message'] ?? 'Erreur lors de la mise à jour.';
    }

    _currentUser = _userFromJson(res['data']);
    await _cacheUser(_currentUser!, method: 'email');
    notifyUserChanged();
    return null;
  }

  // ─── Récupérer le profil frais depuis le backend ─────────────────
  Future<void> refreshUser() async {
    final res = await _api.get('/auth/me', auth: true);
    if (res['success'] == true) {
      _currentUser = _userFromJson(res['data']);
      notifyUserChanged();
    }
  }

  // ─── Premium ─────────────────────────────────────────────────────
  Future<void> setPremium(bool value) async {
    if (_currentUser == null) return;
    _currentUser = UserModel(
      id: _currentUser!.id, nom: _currentUser!.nom, prenom: _currentUser!.prenom,
      email: _currentUser!.email, telephone: _currentUser!.telephone,
      avatarUrl: _currentUser!.avatarUrl, isVerified: _currentUser!.isVerified,
      rating: _currentUser!.rating, totalAvis: _currentUser!.totalAvis,
      createdAt: _currentUser!.createdAt, role: _currentUser!.role,
      isPremium: value,
      countryCode: _currentUser!.countryCode,
      countryName: _currentUser!.countryName,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsPremium, value);
    notifyUserChanged();
  }

  // ─── KYC ────────────────────────────────────────────────────────
  Future<void> setVerified(bool value) async {
    if (_currentUser == null) return;
    _currentUser = UserModel(
      id: _currentUser!.id, nom: _currentUser!.nom, prenom: _currentUser!.prenom,
      email: _currentUser!.email, telephone: _currentUser!.telephone,
      avatarUrl: _currentUser!.avatarUrl, isVerified: value,
      rating: _currentUser!.rating, totalAvis: _currentUser!.totalAvis,
      createdAt: _currentUser!.createdAt, role: _currentUser!.role,
      isPremium: _currentUser!.isPremium,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsVerified, value);
    notifyUserChanged();
  }

  // ─── Déconnexion ────────────────────────────────────────────────
  Future<void> logout() async {
    try {
      if (await _googleSignIn.isSignedIn()) await _googleSignIn.signOut();
    } catch (_) {}

    await _api.clearToken();
    _currentUser = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLoggedIn, false);
    notifyUserChanged();
  }

  // ─── Cache local ─────────────────────────────────────────────────
  Future<void> _cacheUser(UserModel u, {required String method}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLoggedIn, true);
    await prefs.setString(_kUserId, u.id);
    await prefs.setString(_kNom, u.nom);
    await prefs.setString(_kPrenom, u.prenom);
    await prefs.setString(_kEmail, u.email);
    await prefs.setString(_kTelephone, u.telephone ?? '');
    if (u.avatarUrl != null) await prefs.setString(_kAvatarUrl, u.avatarUrl!);
    await prefs.setBool(_kIsPremium, u.isPremium);
    await prefs.setBool(_kIsVerified, u.isVerified);
    await prefs.setString(_kRole, u.role);
    await prefs.setString(_kCreatedAt, u.createdAt.toIso8601String());
    await prefs.setString(_kAuthMethod, method);
    if (u.countryCode != null) await prefs.setString(_kCountryCode, u.countryCode!);
    if (u.countryName != null) await prefs.setString(_kCountryName, u.countryName!);
  }

  UserModel? _userFromPrefs(SharedPreferences prefs) {
    final id = prefs.getString(_kUserId);
    final email = prefs.getString(_kEmail);
    if (id == null || email == null) return null;

    return UserModel(
      id: id,
      nom: prefs.getString(_kNom) ?? '',
      prenom: prefs.getString(_kPrenom) ?? '',
      email: email,
      telephone: prefs.getString(_kTelephone) ?? '',
      avatarUrl: prefs.getString(_kAvatarUrl),
      isVerified: prefs.getBool(_kIsVerified) ?? false,
      isPremium: prefs.getBool(_kIsPremium) ?? false,
      rating: 0, totalAvis: 0,
      createdAt: DateTime.tryParse(prefs.getString(_kCreatedAt) ?? '') ?? DateTime.now(),
      role: prefs.getString(_kRole) ?? 'client',
      countryCode: prefs.getString(_kCountryCode),
      countryName: prefs.getString(_kCountryName),
    );
  }

  UserModel _userFromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] ?? '',
    nom: json['nom'] ?? '',
    prenom: json['prenom'] ?? '',
    email: json['email'] ?? '',
    telephone: json['telephone'] ?? '',
    avatarUrl: json['avatarUrl'],
    isVerified: json['isVerified'] ?? false,
    isPremium: json['isPremium'] ?? false,
    rating: (json['rating'] ?? 0.0).toDouble(),
    totalAvis: json['totalAvis'] ?? 0,
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
        : DateTime.now(),
    role: json['role'] ?? 'client',
    countryCode: json['countryCode'],
    countryName: json['countryName'],
    accountType: json['accountType'] ?? 'personal',
    nomEntreprise: json['nomEntreprise'],
    typeActivite: json['typeActivite'],
  );
  // ─── Getters de compatibilité avec les screens existants ─────────

  // Alias email comme username
  String get loggedUsername => _currentUser?.email ?? '';

  // Getter non-nullable — retourne un user vide si non connecté
  // Évite de modifier tous les screens
  UserModel get currentUserOrEmpty => _currentUser ?? UserModel(
    id: '', nom: '', prenom: '', email: '',
    telephone: '', rating: 0, totalAvis: 0,
    createdAt: DateTime.now(), role: 'client',
    isPremium: false, isVerified: false,
  );

  // ─── Mise à jour locale du user (sans appel API) ──────────────────
  Future<void> updateUser(UserModel updated) async {
    _currentUser = updated;
    await _cacheUser(updated, method: 'email');
    notifyUserChanged();
  }

  // ─── Changement de mot de passe ───────────────────────────────────
  Future<String?> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final res = await _api.put('/auth/password', {
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    }, auth: true);
    if (res['success'] != true) return res['message'] ?? 'Erreur';
    return null;
  }
}