// ═══════════════════════════════════════════════════════════════════
// AUTH SERVICE — VelQix
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import 'api_service.dart';
import 'chat_service.dart';
import 'property_service.dart';

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

final _googleSignIn = GoogleSignIn(
  clientId: '330595771551-209on5g1r101munca38unkks8kogbgql.apps.googleusercontent.com',
  scopes: ['email', 'profile'],
);

const _kAccountType   = 'auth_account_type';
const _kNomEntreprise = 'auth_nom_entreprise';
const _kTypeActivite  = 'auth_type_activite';

// Erreurs backend qui signifient que la session n'est plus valide (par
// opposition à une panne réseau ou serveur, où l'on garde la session locale).
const _kSessionErrors = {
  'SESSION_EXPIRED', 'ACCOUNT_BANNED', 'USER_NOT_FOUND', 'INVALID_TOKEN', 'MISSING_TOKEN',
};

class AuthService {
  AuthService._() {
    ApiService.instance.sessionExpiredNotifier.addListener(() {
      if (_currentUser != null) logout();
    });
  }
  static final AuthService instance = AuthService._();

  final _api = ApiService.instance;
  UserModel? _currentUser;

  bool get isLoggedIn      => _currentUser != null;
  UserModel? get currentUser => _currentUser;

  UserModel get currentUserOrEmpty => _currentUser ?? UserModel(
    id: '', nom: '', prenom: '', email: '', telephone: '',
    rating: 0, totalAvis: 0, createdAt: DateTime.now(),
    role: 'client', isPremium: false, isVerified: false,
  );

  String get loggedUsername => _currentUser?.email ?? '';

  // ─── Auto-login ──────────────────────────────────────────────────
  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_kLoggedIn) ?? false)) return false;

    _currentUser = _userFromPrefs(prefs);
    if (_currentUser == null) return false;

    final res = await _api.get('/auth/me', auth: true);
    if (res['success'] == true) {
      _currentUser = _userFromJson(res['data']);
      await _cacheUser(_currentUser!, method: prefs.getString(_kAuthMethod) ?? 'email');
      notifyUserChanged();
      // Connecter le socket maintenant que l'utilisateur est authentifié
      await _onAuthenticated();
      return true;
    }

    // Session réellement invalide → déconnexion
    if (_kSessionErrors.contains(res['error'])) {
      await logout();
      return false;
    }

    // Panne réseau / serveur (ex. démarrage à froid de Render) : on garde la
    // session en cache plutôt que de déconnecter l'utilisateur.
    if (await _api.getToken() == null) {
      await logout();
      return false;
    }
    notifyUserChanged();
    await _onAuthenticated();
    return true;
  }

  // ─── Register ────────────────────────────────────────────────────
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
      'nom': nom, 'prenom': prenom, 'email': email, 'password': password,
      if (telephone != null) 'telephone': telephone,
      if (countryCode != null) 'countryCode': countryCode,
      if (countryName != null) 'countryName': countryName,
      'accountType': accountType,
      if (nomEntreprise != null) 'nomEntreprise': nomEntreprise,
      if (typeActivite != null) 'typeActivite': typeActivite,
    });

    if (res['success'] != true) return res['message'] ?? 'Erreur lors de l\'inscription.';

    await _api.saveToken(res['data']['accessToken']);
    if (res['data']['refreshToken'] != null) {
      await _api.saveRefreshToken(res['data']['refreshToken']);
    }
    _currentUser = _userFromJson(res['data']['user']);
    await _cacheUser(_currentUser!, method: 'email');
    notifyUserChanged();
    // Connecter le socket
    await _onAuthenticated();
    return null;
  }

  // ─── Login ───────────────────────────────────────────────────────
  Future<String?> login({
    String? email,
    String? username,
    required String password,
  }) async {
    final res = await _api.post('/auth/login', {
      'email': email ?? username ?? '',
      'password': password,
    });

    if (res['success'] != true) return res['message'] ?? 'Email ou mot de passe invalide.';

    await _api.saveToken(res['data']['accessToken']);
    if (res['data']['refreshToken'] != null) {
      await _api.saveRefreshToken(res['data']['refreshToken']);
    }
    _currentUser = _userFromJson(res['data']['user']);
    await _cacheUser(_currentUser!, method: 'email');
    notifyUserChanged();
    // Connecter le socket
    await _onAuthenticated();
    return null; }
  // Instance exposée pour que l'écran de login puisse afficher le bouton
  // natif Google sur le web (GoogleSignInPlatform.instance.renderButton())
  // et s'abonner à onCurrentUserChanged.
  GoogleSignIn get googleSignIn => _googleSignIn;

  Future<String?> loginWithGoogle() async {
    if (kIsWeb) {
      // ⚠️ Sur le web, l'appel interactif _googleSignIn.signIn() n'est pas
      // fiable avec l'API Google Identity Services (GIS) utilisée depuis
      // google_sign_in ^6.x : un clic sur un bouton custom qui appelle
      // signIn() directement peut être rejeté par Google avec une page
      // "Accès bloqué : erreur d'autorisation" (authError=...), même quand
      // les origines JS sont correctement enregistrées. Le flow supporté
      // sur web est le bouton natif rendu par renderButton(), qui déclenche
      // onCurrentUserChanged — voir completeGoogleLoginFromAccount() et le
      // widget du bouton dans l'écran de login.
      try {
        final account = await _googleSignIn.signInSilently();
        if (account == null) {
          return 'Utilisez le bouton Google ci-dessous pour vous connecter.';
        }
        return _completeGoogleLogin(account);
      } catch (e) {
        return "Connexion Google impossible : $e";
      }
    }

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
      return _completeGoogleLogin(account);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('popup_closed') || msg.contains('user_cancel') ||
          msg.contains('canceled') || msg.contains('annul')) return 'Connexion Google annulée.';
      return "Connexion Google impossible : $e";
    }
  }

  // Appelée par loginWithGoogle() (mobile + silent web) ET par l'écran de
  // login sur web, une fois que onCurrentUserChanged a livré un compte via
  // le bouton natif Google.
  Future<String?> completeGoogleLoginFromAccount(GoogleSignInAccount account) =>
      _completeGoogleLogin(account);

  Future<String?> _completeGoogleLogin(GoogleSignInAccount account) async {
    final googleAuth = await account.authentication;
    final idToken    = googleAuth.idToken;

    if (idToken == null) {
      // Impossible d'obtenir un idToken Google exploitable côté serveur :
      // on ne peut pas authentifier l'utilisateur, donc on ne simule
      // surtout pas une connexion réussie (voir historique : l'ancien
      // fallback local créait un faux compte sans jamais sauvegarder de
      // token, laissant l'utilisateur "connecté" en apparence mais avec
      // tous les appels API authentifiés qui échouaient silencieusement).
      return "Connexion Google impossible : réessayez ou utilisez votre email.";
    }

    // Backend attend { idToken } — on envoie exactement ça
    final res = await _api.post('/auth/google', {'idToken': idToken});
    if (res['success'] == true) {
      await _api.saveToken(res['data']['accessToken']);
      if (res['data']['refreshToken'] != null) {
        await _api.saveRefreshToken(res['data']['refreshToken']);
      }
      _currentUser = _userFromJson(res['data']['user']);
      await _cacheUser(_currentUser!, method: 'google');
      notifyUserChanged();
      await _onAuthenticated();
      return null;
    }

    // Le backend a refusé/échoué : on remonte l'erreur, pas de session
    // fantôme sans token.
    return res['message'] ?? "Connexion Google impossible. Réessayez.";
  }

  // ─── Facebook ────────────────────────────────────────────────────
  Future<String?> loginWithFacebook() async {
    try {
      final result = await FacebookAuth.instance.login(permissions: ['email', 'public_profile']);
      if (result.status != LoginStatus.success) return 'Connexion Facebook annulée.';

      // Backend attend { accessToken } pour Facebook
      final fbToken = result.accessToken?.tokenString;
      if (fbToken == null) {
        return "Connexion Facebook impossible : réessayez ou utilisez votre email.";
      }

      final res = await _api.post('/auth/facebook', {'accessToken': fbToken});
      if (res['success'] == true) {
        await _api.saveToken(res['data']['accessToken']);
        if (res['data']['refreshToken'] != null) {
          await _api.saveRefreshToken(res['data']['refreshToken']);
        }
        _currentUser = _userFromJson(res['data']['user']);
        await _cacheUser(_currentUser!, method: 'facebook');
        notifyUserChanged();
        await _onAuthenticated();
        return null;
      }

      // Le backend a refusé/échoué : on remonte l'erreur, jamais de faux
      // compte local sans token (voir note équivalente dans loginWithGoogle).
      return res['message'] ?? "Connexion Facebook impossible. Réessayez.";
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('not supported') || msg.contains('MissingPluginException') ||
          msg.contains('PlatformException')) {
        return "Facebook Login non disponible sur le web. Utilisez l'app mobile.";
      }
      return 'Erreur Facebook Login : $e';
    }
  }

  // ─── Refresh user ────────────────────────────────────────────────
  Future<void> refreshUser() async {
    final res = await _api.get('/auth/me', auth: true);
    if (res['success'] == true) {
      _currentUser = _userFromJson(res['data']);
      notifyUserChanged();
    }
  }

  // ─── Change password ─────────────────────────────────────────────
  // Backend attend { oldPassword, newPassword }
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

  // ─── Mot de passe oublié (code envoyé par email par le backend) ───
  // Chaque méthode renvoie null en cas de succès, sinon le message d'erreur.
  Future<String?> requestPasswordReset(String email) async {
    final res = await _api.post('/auth/forgot-password', {'email': email});
    return res['success'] == true ? null : (res['message'] ?? 'Erreur lors de l\'envoi du code.');
  }

  Future<String?> verifyResetCode({required String email, required String code}) async {
    final res = await _api.post('/auth/verify-reset-code', {'email': email, 'code': code});
    return res['success'] == true ? null : (res['message'] ?? 'Code invalide ou expiré.');
  }

  Future<String?> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final res = await _api.post('/auth/reset-password', {
      'email': email, 'code': code, 'newPassword': newPassword,
    });
    return res['success'] == true ? null : (res['message'] ?? 'Erreur lors de la réinitialisation.');
  }

  // ─── Mise à jour du profil (persiste réellement côté serveur) ──────
  // ⚠️ Avant : updateUser() ci-dessous ne faisait que du cache local
  // (SharedPreferences), jamais envoyé au backend — les infos étaient
  // perdues au changement d'appareil et invisibles pour les autres
  // utilisateurs/l'admin. email n'est volontairement pas modifiable ici
  // (le backend PUT /auth/profile ne l'accepte pas).
  Future<String?> updateProfile({
    required String nom,
    required String prenom,
    String? telephone,
    String? countryCode,
    String? countryName,
    String? avatarUrl,
    String? nomEntreprise,
    String? typeActivite,
  }) async {
    final res = await _api.put('/auth/profile', {
      'nom': nom,
      'prenom': prenom,
      'telephone': telephone,
      if (countryCode != null) 'countryCode': countryCode,
      if (countryName != null) 'countryName': countryName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (nomEntreprise != null) 'nomEntreprise': nomEntreprise,
      if (typeActivite != null) 'typeActivite': typeActivite,
    }, auth: true);

    if (res['success'] != true) return res['message'] ?? 'Erreur';

    // Le serveur renvoie l'utilisateur à jour — on s'en sert comme source
    // de vérité plutôt que de reconstruire l'objet à la main.
    final data = res['data'] as Map<String, dynamic>?;
    if (data != null && _currentUser != null) {
      final updated = _copyWith(
        _currentUser!,
        nom: data['nom'] ?? nom,
        prenom: data['prenom'] ?? prenom,
        telephone: data['telephone'] ?? telephone,
        countryCode: data['countryCode'] ?? countryCode,
        countryName: data['countryName'] ?? countryName,
        avatarUrl: data['avatarUrl'] ?? avatarUrl,
        nomEntreprise: data['nomEntreprise'] ?? nomEntreprise,
        typeActivite: data['typeActivite'] ?? typeActivite,
      );
      _currentUser = updated;
      await _cacheUser(updated, method: 'email');
      notifyUserChanged();
    }
    return null;
  }

  // ─── Premium / KYC ───────────────────────────────────────────────
  Future<void> setPremium(bool value) async {
    if (_currentUser == null) return;
    _currentUser = _copyWith(_currentUser!, isPremium: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsPremium, value);
    notifyUserChanged();
  }

  Future<void> setVerified(bool value) async {
    if (_currentUser == null) return;
    _currentUser = _copyWith(_currentUser!, isVerified: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsVerified, value);
    notifyUserChanged();
  }

  // ─── Update local ────────────────────────────────────────────────
  Future<void> updateUser(UserModel updated) async {
    _currentUser = updated;
    await _cacheUser(updated, method: 'email');
    notifyUserChanged();
  }

  // ─── Logout ──────────────────────────────────────────────────────
  Future<void> logout() async {
    try { if (await _googleSignIn.isSignedIn()) await _googleSignIn.signOut(); } catch (_) {}
    ChatService.instance.disconnect();
    // Révoquer le refresh token côté serveur (sinon il reste valide 7 jours)
    final refreshToken = await _api.getRefreshToken();
    if (refreshToken != null) {
      _api.post('/auth/logout', {'refreshToken': refreshToken});
    }
    await _api.clearToken();
    _currentUser = null;
    globalFavorites.clear();
    followedOwnersNotifier.value = {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLoggedIn, false);
    notifyUserChanged();
  }

  /// Socket + synchronisation des favoris une fois la session établie.
  Future<void> _onAuthenticated() async {
    await ChatService.instance.connect(userId: _currentUser!.id);
    PropertyService.instance.getFavorites().then((favs) {
      if (favs.isEmpty && globalFavorites.isEmpty) return;
      globalFavorites
        ..clear()
        ..addAll(favs.map((p) => p.id));
      notifyUserChanged();
    }).catchError((_) {});
  }

  // ─── Cache local ─────────────────────────────────────────────────
  Future<void> _cacheUser(UserModel u, {required String method}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLoggedIn, true);
    await prefs.setString(_kUserId, u.id);
    await prefs.setString(_kNom, u.nom);
    await prefs.setString(_kPrenom, u.prenom);
    await prefs.setString(_kEmail, u.email);
    await prefs.setString(_kTelephone, u.telephone);
    if (u.avatarUrl != null) await prefs.setString(_kAvatarUrl, u.avatarUrl!);
    await prefs.setBool(_kIsPremium, u.isPremium);
    await prefs.setBool(_kIsVerified, u.isVerified);
    await prefs.setString(_kRole, u.role);
    await prefs.setString(_kCreatedAt, u.createdAt.toIso8601String());
    await prefs.setString(_kAuthMethod, method);
    if (u.countryCode != null) await prefs.setString(_kCountryCode, u.countryCode!);
    if (u.countryName != null) await prefs.setString(_kCountryName, u.countryName!);
    await prefs.setString(_kAccountType, u.accountType);
    if (u.nomEntreprise != null) {
      await prefs.setString(_kNomEntreprise, u.nomEntreprise!);
    } else {
      await prefs.remove(_kNomEntreprise);
    }
    if (u.typeActivite != null) {
      await prefs.setString(_kTypeActivite, u.typeActivite!);
    } else {
      await prefs.remove(_kTypeActivite);
    }
  }

  UserModel? _userFromPrefs(SharedPreferences prefs) {
    final id    = prefs.getString(_kUserId);
    final email = prefs.getString(_kEmail);
    if (id == null || email == null) return null;
    return UserModel(
      id: id, nom: prefs.getString(_kNom) ?? '', prenom: prefs.getString(_kPrenom) ?? '',
      email: email, telephone: prefs.getString(_kTelephone) ?? '',
      avatarUrl: prefs.getString(_kAvatarUrl),
      isVerified: prefs.getBool(_kIsVerified) ?? false,
      isPremium:  prefs.getBool(_kIsPremium)  ?? false,
      rating: 0, totalAvis: 0,
      createdAt: DateTime.tryParse(prefs.getString(_kCreatedAt) ?? '') ?? DateTime.now(),
      role: prefs.getString(_kRole) ?? 'client',
      countryCode: prefs.getString(_kCountryCode),
      countryName: prefs.getString(_kCountryName),
      accountType: prefs.getString(_kAccountType) ?? 'personal',
      nomEntreprise: prefs.getString(_kNomEntreprise),
      typeActivite: prefs.getString(_kTypeActivite),
    );
  }

  UserModel _userFromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] ?? '', nom: json['nom'] ?? '', prenom: json['prenom'] ?? '',
    email: json['email'] ?? '', telephone: json['telephone'] ?? '',
    avatarUrl: json['avatarUrl'], isVerified: json['isVerified'] ?? false,
    isPremium: json['isPremium'] ?? false,
    rating: (json['rating'] ?? 0.0).toDouble(), totalAvis: json['totalAvis'] ?? 0,
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
        : DateTime.now(),
    role: json['role'] ?? 'client',
    countryCode: json['countryCode'], countryName: json['countryName'],
    accountType: json['accountType'] ?? 'personal',
    nomEntreprise: json['nomEntreprise'], typeActivite: json['typeActivite'],
  );

  UserModel _copyWith(UserModel u, {bool? isPremium, bool? isVerified, String? nom, String? prenom, String? telephone, String? countryCode, String? countryName, String? avatarUrl, String? nomEntreprise, String? typeActivite}) => UserModel(
    id: u.id, nom: nom ?? u.nom, prenom: prenom ?? u.prenom, email: u.email, telephone: telephone ?? u.telephone,
    avatarUrl: avatarUrl ?? u.avatarUrl, isVerified: isVerified ?? u.isVerified,
    isPremium: isPremium ?? u.isPremium, rating: u.rating, totalAvis: u.totalAvis,
    createdAt: u.createdAt, role: u.role, countryCode: countryCode ?? u.countryCode, countryName: countryName ?? u.countryName,
    accountType: u.accountType, nomEntreprise: nomEntreprise ?? u.nomEntreprise, typeActivite: typeActivite ?? u.typeActivite,
  );
}