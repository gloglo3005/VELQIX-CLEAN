/// Système de traduction simple pour VelQix.
/// Ajouter une entrée par langue pour chaque texte visible dans l'UI.
library;

import '../main.dart' show localeNotifier;

// ─── Dictionnaire de traductions ─────────────────────────────────────────────
const _translations = <String, Map<String, String>>{

  // ── Navigation ──────────────────────────────────────────────────────────────
  'nav_home':     {'fr': 'Accueil',   'en': 'Home',    'es': 'Inicio',   'pt': 'Início',  'de': 'Start',    'ar': 'الرئيسية'},
  'nav_explore':  {'fr': 'Explorer',  'en': 'Explore', 'es': 'Explorar', 'pt': 'Explorar','de': 'Entdecken','ar': 'استكشاف'},
  'nav_messages': {'fr': 'Messages',  'en': 'Messages','es': 'Mensajes', 'pt': 'Mensagens','de': 'Nachrichten','ar': 'الرسائل'},
  'nav_profile':  {'fr': 'Profil',    'en': 'Profile', 'es': 'Perfil',   'pt': 'Perfil',  'de': 'Profil',   'ar': 'الملف'},

  // ── Home ────────────────────────────────────────────────────────────────────
  'home_search_hint':   {'fr': 'Tapez une ville, type, nom…', 'en': 'Search city, type, name…', 'es': 'Busca ciudad, tipo, nombre…', 'pt': 'Cidade, tipo, nome…', 'de': 'Stadt, Typ, Name…', 'ar': 'ابحث عن مدينة أو نوع…'},
  'home_featured':      {'fr': '⭐ Annonces vedettes', 'en': '⭐ Featured listings', 'es': '⭐ Anuncios destacados', 'pt': '⭐ Anúncios em destaque', 'de': '⭐ Empfohlene Anzeigen', 'ar': '⭐ إعلانات مميزة'},
  'home_see_all':       {'fr': 'Voir tout', 'en': 'See all', 'es': 'Ver todo', 'pt': 'Ver tudo', 'de': 'Alle sehen', 'ar': 'عرض الكل'},
  'home_all_listings':  {'fr': 'Toutes les annonces', 'en': 'All listings', 'es': 'Todos los anuncios', 'pt': 'Todos os anúncios', 'de': 'Alle Anzeigen', 'ar': 'كل الإعلانات'},
  'home_categories':    {'fr': 'Catégories', 'en': 'Categories', 'es': 'Categorías', 'pt': 'Categorias', 'de': 'Kategorien', 'ar': 'الفئات'},
  'home_annonces':      {'fr': 'Annonces', 'en': 'Listings', 'es': 'Anuncios', 'pt': 'Anúncios', 'de': 'Anzeigen', 'ar': 'إعلانات'},
  'home_mobilier':      {'fr': 'Mobilier', 'en': 'Furniture', 'es': 'Muebles', 'pt': 'Mobiliário', 'de': 'Möbel', 'ar': 'أثاث'},
  'home_immobilier':    {'fr': 'Immobilier', 'en': 'Real Estate', 'es': 'Inmobiliaria', 'pt': 'Imóveis', 'de': 'Immobilien', 'ar': 'عقارات'},

  // ── Listing types ───────────────────────────────────────────────────────────
  'type_location':  {'fr': 'Location',      'en': 'Rental',    'es': 'Alquiler',  'pt': 'Aluguel',   'de': 'Miete',   'ar': 'إيجار'},
  'type_vente':     {'fr': 'Vente',         'en': 'Sale',      'es': 'Venta',     'pt': 'Venda',     'de': 'Kauf',    'ar': 'بيع'},
  'type_vedette':   {'fr': '★ Vedette',     'en': '★ Featured','es': '★ Destacado','pt': '★ Destaque','de': '★ Highlight','ar': '★ مميز'},

  // ── Profile ─────────────────────────────────────────────────────────────────
  'profile_title':      {'fr': 'Mon Profil',      'en': 'My Profile',    'es': 'Mi Perfil',      'pt': 'Meu Perfil',    'de': 'Mein Profil',   'ar': 'ملفي'},
  'profile_account':    {'fr': 'Mon compte',      'en': 'My account',    'es': 'Mi cuenta',      'pt': 'Minha conta',   'de': 'Mein Konto',    'ar': 'حسابي'},
  'profile_payment':    {'fr': 'Paiement',        'en': 'Payment',       'es': 'Pago',           'pt': 'Pagamento',     'de': 'Zahlung',       'ar': 'الدفع'},
  'profile_support':    {'fr': 'Support & Légal', 'en': 'Support & Legal','es': 'Soporte & Legal','pt': 'Suporte & Legal','de': 'Support & Recht','ar': 'الدعم والقانون'},
  'profile_settings':   {'fr': 'Paramètres',      'en': 'Settings',      'es': 'Ajustes',        'pt': 'Configurações', 'de': 'Einstellungen', 'ar': 'الإعدادات'},
  'profile_logout':     {'fr': 'Déconnexion',     'en': 'Logout',        'es': 'Cerrar sesión',  'pt': 'Sair',          'de': 'Abmelden',      'ar': 'تسجيل خروج'},
  'profile_edit':       {'fr': 'Modifier le profil','en': 'Edit profile', 'es': 'Editar perfil',  'pt': 'Editar perfil', 'de': 'Profil bearbeiten','ar': 'تعديل الملف'},
  'profile_kyc':        {'fr': 'Vérification d\'identité (KYC)', 'en': 'Identity verification (KYC)', 'es': 'Verificación de identidad (KYC)', 'pt': 'Verificação de identidade (KYC)', 'de': 'Identitätsprüfung (KYC)', 'ar': 'التحقق من الهوية'},
  'profile_listings':   {'fr': 'Mes annonces',    'en': 'My listings',   'es': 'Mis anuncios',   'pt': 'Meus anúncios', 'de': 'Meine Anzeigen','ar': 'إعلاناتي'},
  'profile_favorites':  {'fr': 'Mes favoris',     'en': 'My favorites',  'es': 'Mis favoritos',  'pt': 'Meus favoritos','de': 'Favoriten',     'ar': 'المفضلة'},
  'profile_notifs':     {'fr': 'Notifications',   'en': 'Notifications', 'es': 'Notificaciones', 'pt': 'Notificações',  'de': 'Benachrichtigungen','ar': 'الإشعارات'},
  'profile_premium':    {'fr': 'Passer Premium',  'en': 'Go Premium',    'es': 'Hazte Premium',  'pt': 'Seja Premium',  'de': 'Premium werden','ar': 'اشترك بريميوم'},
  'profile_transactions':{'fr': 'Mes transactions','en': 'My transactions','es': 'Mis transacciones','pt': 'Minhas transações','de': 'Transaktionen','ar': 'معاملاتي'},
  'profile_help':       {'fr': 'Aide & Support',  'en': 'Help & Support', 'es': 'Ayuda y soporte','pt': 'Ajuda e suporte','de': 'Hilfe & Support','ar': 'المساعدة والدعم'},
  'profile_terms':      {'fr': 'Conditions d\'utilisation','en': 'Terms of use','es': 'Términos de uso','pt': 'Termos de uso','de': 'Nutzungsbedingungen','ar': 'شروط الاستخدام'},
  'profile_theme_light':{'fr': 'Thème : Clair ☀️', 'en': 'Theme: Light ☀️','es': 'Tema: Claro ☀️','pt': 'Tema: Claro ☀️','de': 'Design: Hell ☀️','ar': 'المظهر: فاتح ☀️'},
  'profile_theme_dark': {'fr': 'Thème : Sombre 🌙','en': 'Theme: Dark 🌙', 'es': 'Tema: Oscuro 🌙','pt': 'Tema: Escuro 🌙','de': 'Design: Dunkel 🌙','ar': 'المظهر: داكن 🌙'},
  'profile_admin':      {'fr': 'Administration',  'en': 'Administration', 'es': 'Administración', 'pt': 'Administração',  'de': 'Verwaltung',    'ar': 'الإدارة'},

  // ── Settings: langue & devise ────────────────────────────────────────────────
  'settings_language':  {'fr': 'Langue',       'en': 'Language',   'es': 'Idioma',     'pt': 'Idioma',      'de': 'Sprache',    'ar': 'اللغة'},
  'settings_currency':  {'fr': 'Devise',       'en': 'Currency',   'es': 'Moneda',     'pt': 'Moeda',       'de': 'Währung',    'ar': 'العملة'},

  // ── Owner public profile ─────────────────────────────────────────────────────
  'owner_profile_title':  {'fr': 'Profil du propriétaire', 'en': 'Owner profile',    'es': 'Perfil del propietario', 'pt': 'Perfil do proprietário', 'de': 'Eigentümerprofil', 'ar': 'ملف المالك'},
  'owner_followers':      {'fr': 'Abonnés',   'en': 'Followers',  'es': 'Seguidores',  'pt': 'Seguidores',  'de': 'Follower',   'ar': 'متابعون'},
  'owner_following':      {'fr': 'Suivi(e)s', 'en': 'Following',  'es': 'Siguiendo',   'pt': 'Seguindo',    'de': 'Abonniert',  'ar': 'يتابع'},
  'owner_listings':       {'fr': 'Annonces',  'en': 'Listings',   'es': 'Anuncios',    'pt': 'Anúncios',    'de': 'Anzeigen',   'ar': 'إعلانات'},
  'owner_views':          {'fr': 'Vues',      'en': 'Views',      'es': 'Vistas',      'pt': 'Visualizações','de': 'Aufrufe',   'ar': 'مشاهدات'},
  'owner_role_label':     {'fr': 'PROPRIÉTAIRE', 'en': 'OWNER',   'es': 'PROPIETARIO', 'pt': 'PROPRIETÁRIO', 'de': 'EIGENTÜMER', 'ar': 'مالك'},
  'owner_reviews':        {'fr': 'Avis',      'en': 'Reviews',    'es': 'Reseñas',     'pt': 'Avaliações',  'de': 'Bewertungen','ar': 'تقييمات'},
  'owner_follow_btn':     {'fr': 'Suivre',    'en': 'Follow',     'es': 'Seguir',      'pt': 'Seguir',      'de': 'Folgen',     'ar': 'تابع'},
  'owner_following_btn':  {'fr': 'Abonné(e)', 'en': 'Following',  'es': 'Siguiendo',   'pt': 'Seguindo',    'de': 'Abonniert',  'ar': 'تتابعه'},
  'owner_listings_section':{'fr': 'Annonces du propriétaire', 'en': 'Owner listings', 'es': 'Anuncios del propietario', 'pt': 'Anúncios do proprietário', 'de': 'Anzeigen des Eigentümers', 'ar': 'إعلانات المالك'},
  'owner_no_listings':    {'fr': 'Aucune annonce publiée', 'en': 'No listings yet', 'es': 'Sin anuncios', 'pt': 'Sem anúncios', 'de': 'Keine Anzeigen', 'ar': 'لا إعلانات'},

  // ── Auth ────────────────────────────────────────────────────────────────────
  'auth_login':         {'fr': 'Connexion',    'en': 'Login',      'es': 'Iniciar sesión','pt': 'Entrar',    'de': 'Anmelden',  'ar': 'تسجيل دخول'},
  'auth_register':      {'fr': 'Inscription',  'en': 'Sign up',    'es': 'Registrarse',  'pt': 'Cadastrar', 'de': 'Registrieren','ar': 'إنشاء حساب'},
  'auth_username':      {'fr': 'Nom d\'utilisateur','en': 'Username','es': 'Usuario',     'pt': 'Usuário',   'de': 'Benutzername','ar': 'اسم المستخدم'},
  'auth_password':      {'fr': 'Mot de passe', 'en': 'Password',   'es': 'Contraseña',   'pt': 'Senha',     'de': 'Passwort',  'ar': 'كلمة المرور'},
  'auth_email':         {'fr': 'Email',        'en': 'Email',      'es': 'Correo',       'pt': 'E-mail',    'de': 'E-Mail',    'ar': 'البريد الإلكتروني'},
  'auth_phone':         {'fr': 'Téléphone',    'en': 'Phone',      'es': 'Teléfono',     'pt': 'Telefone',  'de': 'Telefon',   'ar': 'الهاتف'},
  'auth_country':       {'fr': 'Pays',         'en': 'Country',    'es': 'País',         'pt': 'País',      'de': 'Land',      'ar': 'البلد'},

  // ── Common ──────────────────────────────────────────────────────────────────
  'common_save':        {'fr': 'Enregistrer',  'en': 'Save',       'es': 'Guardar',      'pt': 'Salvar',    'de': 'Speichern', 'ar': 'حفظ'},
  'common_cancel':      {'fr': 'Annuler',      'en': 'Cancel',     'es': 'Cancelar',     'pt': 'Cancelar',  'de': 'Abbrechen', 'ar': 'إلغاء'},
  'common_confirm':     {'fr': 'Confirmer',    'en': 'Confirm',    'es': 'Confirmar',    'pt': 'Confirmar', 'de': 'Bestätigen','ar': 'تأكيد'},
  'common_search':      {'fr': 'Rechercher',   'en': 'Search',     'es': 'Buscar',       'pt': 'Buscar',    'de': 'Suchen',    'ar': 'بحث'},
  'common_publish':     {'fr': 'Publier',      'en': 'Publish',    'es': 'Publicar',     'pt': 'Publicar',  'de': 'Veröffentlichen','ar': 'نشر'},
  'common_premium':     {'fr': 'Premium',      'en': 'Premium',    'es': 'Premium',      'pt': 'Premium',   'de': 'Premium',   'ar': 'بريميوم'},
  'common_new':         {'fr': 'Nouveau',      'en': 'New',        'es': 'Nuevo',        'pt': 'Novo',      'de': 'Neu',       'ar': 'جديد'},
  'common_properties':  {'fr': 'biens',        'en': 'properties', 'es': 'bienes',       'pt': 'imóveis',   'de': 'Objekte',   'ar': 'عقارات'},

  // ── Explore ──────────────────────────────────────────────────────────────
  'explore_title':        {'fr': 'Explorer',              'en': 'Explore',            'es': 'Explorar',           'pt': 'Explorar',           'de': 'Entdecken',          'ar': 'استكشاف'},
  'explore_search_hint':  {'fr': 'Chercher par nom, ville, catégorie...', 'en': 'Search by name, city, category...', 'es': 'Buscar por nombre, ciudad, categoría...', 'pt': 'Buscar por nome, cidade, categoria...', 'de': 'Nach Name, Stadt, Kategorie suchen...', 'ar': 'ابحث بالاسم أو المدينة أو الفئة...'},
  'explore_sort_recent':  {'fr': 'Récent',                'en': 'Recent',             'es': 'Reciente',           'pt': 'Recente',            'de': 'Neueste',            'ar': 'الأحدث'},
  'explore_sort_price_asc': {'fr': 'Prix ↑',             'en': 'Price ↑',            'es': 'Precio ↑',           'pt': 'Preço ↑',            'de': 'Preis ↑',            'ar': 'السعر ↑'},
  'explore_sort_price_desc': {'fr': 'Prix ↓',            'en': 'Price ↓',            'es': 'Precio ↓',           'pt': 'Preço ↓',            'de': 'Preis ↓',            'ar': 'السعر ↓'},
  'explore_sort_rating':  {'fr': '⭐ Note',               'en': '⭐ Rating',           'es': '⭐ Nota',             'pt': '⭐ Nota',             'de': '⭐ Bewertung',        'ar': '⭐ التقييم'},
  'explore_tab_all':      {'fr': 'Tous',                  'en': 'All',                'es': 'Todos',              'pt': 'Todos',              'de': 'Alle',               'ar': 'الكل'},
  'explore_tab_immo':     {'fr': 'Immobilier',            'en': 'Real Estate',        'es': 'Inmobiliaria',       'pt': 'Imóveis',            'de': 'Immobilien',         'ar': 'عقارات'},
  'explore_tab_mobilier': {'fr': 'Mobilier',              'en': 'Furniture',          'es': 'Muebles',            'pt': 'Mobiliário',         'de': 'Möbel',              'ar': 'أثاث'},
  'explore_no_result':    {'fr': 'Aucun résultat',        'en': 'No results',         'es': 'Sin resultados',     'pt': 'Nenhum resultado',   'de': 'Keine Ergebnisse',   'ar': 'لا نتائج'},
  'explore_no_result_sub': {'fr': 'Essayez d\'autres mots-clés ou filtres.', 'en': 'Try other keywords or filters.', 'es': 'Prueba otras palabras clave o filtros.', 'pt': 'Tente outras palavras-chave ou filtros.', 'de': 'Versuche andere Suchbegriffe oder Filter.', 'ar': 'جرب كلمات مفتاحية أو مرشحات أخرى.'},
  'explore_results':      {'fr': 'résultat',              'en': 'result',             'es': 'resultado',          'pt': 'resultado',          'de': 'Ergebnis',           'ar': 'نتيجة'},
  'explore_results_pl':   {'fr': 'résultats',             'en': 'results',            'es': 'resultados',         'pt': 'resultados',         'de': 'Ergebnisse',         'ar': 'نتائج'},
  'explore_filter_country': {'fr': 'Filtrer par pays',   'en': 'Filter by country',  'es': 'Filtrar por país',   'pt': 'Filtrar por país',   'de': 'Nach Land filtern',  'ar': 'تصفية حسب البلد'},
  'explore_all_countries': {'fr': 'Tout voir',            'en': 'See all',            'es': 'Ver todo',           'pt': 'Ver tudo',           'de': 'Alle sehen',         'ar': 'عرض الكل'},
  'explore_search_country': {'fr': 'Rechercher un pays...', 'en': 'Search a country...', 'es': 'Buscar un país...', 'pt': 'Buscar um país...', 'de': 'Land suchen...', 'ar': 'ابحث عن بلد...'},
  'explore_filters':      {'fr': 'Filtres',               'en': 'Filters',            'es': 'Filtros',            'pt': 'Filtros',            'de': 'Filter',             'ar': 'المرشحات'},
  'explore_price_range':  {'fr': 'Fourchette de prix',   'en': 'Price range',        'es': 'Rango de precios',   'pt': 'Faixa de preço',    'de': 'Preisspanne',        'ar': 'نطاق السعر'},
  'explore_available_only': {'fr': 'Disponibles uniquement', 'en': 'Available only', 'es': 'Solo disponibles',   'pt': 'Apenas disponíveis', 'de': 'Nur verfügbare',     'ar': 'المتاحة فقط'},
  'explore_all_countries_label': {'fr': 'Tous les pays', 'en': 'All countries',      'es': 'Todos los países',   'pt': 'Todos os países',    'de': 'Alle Länder',        'ar': 'جميع الدول'},
  'explore_apply_filters': {'fr': 'Appliquer les filtres', 'en': 'Apply filters',    'es': 'Aplicar filtros',    'pt': 'Aplicar filtros',    'de': 'Filter anwenden',    'ar': 'تطبيق المرشحات'},
  'explore_country':      {'fr': 'Pays',                  'en': 'Country',            'es': 'País',               'pt': 'País',               'de': 'Land',               'ar': 'البلد'},

  // ── Add Listing ──────────────────────────────────────────────────────────
  'add_title':            {'fr': 'Publier une annonce',   'en': 'Post a listing',     'es': 'Publicar anuncio',   'pt': 'Publicar anúncio',   'de': 'Anzeige aufgeben',   'ar': 'نشر إعلان'},
  'add_next':             {'fr': 'Suivant',               'en': 'Next',               'es': 'Siguiente',          'pt': 'Próximo',            'de': 'Weiter',             'ar': 'التالي'},
  'add_prev':             {'fr': 'Précédent',             'en': 'Previous',           'es': 'Anterior',           'pt': 'Anterior',           'de': 'Zurück',             'ar': 'السابق'},
  'add_publish':          {'fr': 'Publier',               'en': 'Publish',            'es': 'Publicar',           'pt': 'Publicar',           'de': 'Veröffentlichen',    'ar': 'نشر'},
  'add_step_type':        {'fr': 'Type',                  'en': 'Type',               'es': 'Tipo',               'pt': 'Tipo',               'de': 'Typ',                'ar': 'النوع'},
  'add_step_details':     {'fr': 'Détails',               'en': 'Details',            'es': 'Detalles',           'pt': 'Detalhes',           'de': 'Details',            'ar': 'التفاصيل'},
  'add_step_price':       {'fr': 'Prix & Lieu',           'en': 'Price & Location',   'es': 'Precio & Lugar',     'pt': 'Preço & Local',      'de': 'Preis & Ort',        'ar': 'السعر والموقع'},
  'add_type_immo':        {'fr': 'Immobilier',            'en': 'Real Estate',        'es': 'Inmobiliaria',       'pt': 'Imóveis',            'de': 'Immobilien',         'ar': 'عقارات'},
  'add_type_mobilier':    {'fr': 'Mobilier',              'en': 'Furniture & Vehicles','es': 'Muebles y vehículos','pt': 'Móveis e veículos',  'de': 'Möbel & Fahrzeuge', 'ar': 'أثاث ومركبات'},
  'add_property_type':    {'fr': 'Type de bien',          'en': 'Property type',      'es': 'Tipo de bien',       'pt': 'Tipo de imóvel',     'de': 'Objekttyp',          'ar': 'نوع العقار'},
  'add_category':         {'fr': 'Catégorie',             'en': 'Category',           'es': 'Categoría',          'pt': 'Categoria',          'de': 'Kategorie',          'ar': 'الفئة'},
  'add_listing_type':     {'fr': 'Type d\'annonce',      'en': 'Listing type',       'es': 'Tipo de anuncio',    'pt': 'Tipo de anúncio',    'de': 'Anzeigentyp',        'ar': 'نوع الإعلان'},
  'add_cat_maison':       {'fr': 'Maison',                'en': 'House',              'es': 'Casa',               'pt': 'Casa',               'de': 'Haus',               'ar': 'منزل'},
  'add_cat_appartement':  {'fr': 'Appartement',           'en': 'Apartment',          'es': 'Apartamento',        'pt': 'Apartamento',        'de': 'Wohnung',            'ar': 'شقة'},
  'add_cat_terrain':      {'fr': 'Terrain',               'en': 'Land',               'es': 'Terreno',            'pt': 'Terreno',            'de': 'Grundstück',         'ar': 'أرض'},
  'add_cat_bureau':       {'fr': 'Bureau',                'en': 'Office',             'es': 'Oficina',            'pt': 'Escritório',         'de': 'Büro',               'ar': 'مكتب'},
  'add_cat_entrepot':     {'fr': 'Entrepôt',              'en': 'Warehouse',          'es': 'Almacén',            'pt': 'Armazém',            'de': 'Lager',              'ar': 'مستودع'},
  'add_cat_autre':        {'fr': 'Autre',                 'en': 'Other',              'es': 'Otro',               'pt': 'Outro',              'de': 'Sonstige',           'ar': 'أخرى'},
  'add_lt_location':      {'fr': 'Location',              'en': 'Rental',             'es': 'Alquiler',           'pt': 'Aluguel',            'de': 'Miete',              'ar': 'إيجار'},
  'add_lt_location_sub':  {'fr': 'Louer votre bien',      'en': 'Rent your property', 'es': 'Alquilar tu bien',   'pt': 'Alugar seu imóvel',  'de': 'Ihr Objekt vermieten','ar': 'تأجير عقارك'},
  'add_lt_vente':         {'fr': 'Vente',                 'en': 'Sale',               'es': 'Venta',              'pt': 'Venda',              'de': 'Verkauf',            'ar': 'بيع'},
  'add_lt_vente_sub':     {'fr': 'Vendre votre bien',     'en': 'Sell your property', 'es': 'Vender tu bien',     'pt': 'Vender seu imóvel',  'de': 'Ihr Objekt verkaufen','ar': 'بيع عقارك'},
  'add_lt_les_deux':      {'fr': 'Vente & Location',      'en': 'Sale & Rental',      'es': 'Venta y Alquiler',   'pt': 'Venda e Aluguel',    'de': 'Kauf & Miete',       'ar': 'بيع وإيجار'},
  'add_lt_les_deux_sub':  {'fr': 'Les deux options',      'en': 'Both options',       'es': 'Ambas opciones',     'pt': 'Ambas as opções',    'de': 'Beide Optionen',     'ar': 'كلا الخيارين'},
  'add_info_title':       {'fr': 'Informations du bien',  'en': 'Property information','es': 'Información del bien','pt': 'Informações do imóvel','de': 'Objektinformationen','ar': 'معلومات العقار'},
  'add_field_titre':      {'fr': 'Titre de l\'annonce *', 'en': 'Listing title *',   'es': 'Título del anuncio *','pt': 'Título do anúncio *', 'de': 'Anzeigentitel *',   'ar': 'عنوان الإعلان *'},
  'add_field_desc':       {'fr': 'Description *',         'en': 'Description *',      'es': 'Descripción *',      'pt': 'Descrição *',        'de': 'Beschreibung *',     'ar': 'الوصف *'},
  'add_photos':           {'fr': 'Photos',                'en': 'Photos',             'es': 'Fotos',              'pt': 'Fotos',              'de': 'Fotos',              'ar': 'الصور'},
  'add_photos_required':  {'fr': 'Obligatoire',           'en': 'Required',           'es': 'Obligatorio',        'pt': 'Obrigatório',        'de': 'Erforderlich',       'ar': 'مطلوب'},
  'add_photos_hint':      {'fr': 'Ajoutez au moins 1 photo (max 2)', 'en': 'Add at least 1 photo (max 2)', 'es': 'Agrega al menos 1 foto (máx 2)', 'pt': 'Adicione pelo menos 1 foto (máx 2)', 'de': 'Mindestens 1 Foto hinzufügen (max. 2)', 'ar': 'أضف صورة واحدة على الأقل (بحد أقصى 2)'},
  'add_photos_gallery':   {'fr': 'Galerie',               'en': 'Gallery',            'es': 'Galería',            'pt': 'Galeria',            'de': 'Galerie',            'ar': 'المعرض'},
  'add_photos_camera':    {'fr': 'Caméra',                'en': 'Camera',             'es': 'Cámara',             'pt': 'Câmera',             'de': 'Kamera',             'ar': 'الكاميرا'},
  'add_photos_max':       {'fr': 'Maximum 2 photos atteint', 'en': 'Maximum 2 photos reached', 'es': 'Máximo de 2 fotos alcanzado', 'pt': 'Máximo de 2 fotos atingido', 'de': 'Maximum von 2 Fotos erreicht', 'ar': 'تم الوصول إلى الحد الأقصى 2 صور'},
  'add_field_prix':       {'fr': 'Prix',                  'en': 'Price',              'es': 'Precio',             'pt': 'Preço',              'de': 'Preis',              'ar': 'السعر'},
  'add_field_prix_label': {'fr': 'Prix (FCFA) *',         'en': 'Price (FCFA) *',     'es': 'Precio (FCFA) *',    'pt': 'Preço (FCFA) *',     'de': 'Preis (FCFA) *',     'ar': 'السعر (فرنك أفريقي) *'},
  'add_location_title':   {'fr': 'Localisation',          'en': 'Location',           'es': 'Ubicación',          'pt': 'Localização',        'de': 'Standort',           'ar': 'الموقع'},
  'add_field_ville':      {'fr': 'Ville *',               'en': 'City *',             'es': 'Ciudad *',           'pt': 'Cidade *',           'de': 'Stadt *',            'ar': 'المدينة *'},
  'add_field_rue':        {'fr': 'Rue / Quartier *',      'en': 'Street / District *','es': 'Calle / Barrio *',   'pt': 'Rua / Bairro *',    'de': 'Straße / Viertel *', 'ar': 'الشارع / الحي *'},

  // ── Widgets / Cards ──────────────────────────────────────────────────────
  'card_featured':        {'fr': 'Vedette',               'en': 'Featured',           'es': 'Destacado',          'pt': 'Destaque',           'de': 'Highlight',          'ar': 'مميز'},
  'card_per_day':         {'fr': '/jour',                 'en': '/day',               'es': '/día',               'pt': '/dia',               'de': '/Tag',               'ar': '/يوم'},

  // ── Property Detail ──────────────────────────────────────────────────────
  'detail_description':   {'fr': 'Description',           'en': 'Description',        'es': 'Descripción',        'pt': 'Descrição',          'de': 'Beschreibung',       'ar': 'الوصف'},
  'detail_features':      {'fr': 'Caractéristiques',      'en': 'Features',           'es': 'Características',    'pt': 'Características',    'de': 'Merkmale',           'ar': 'المميزات'},
  'detail_see_more':      {'fr': 'Voir plus',             'en': 'See more',           'es': 'Ver más',            'pt': 'Ver mais',           'de': 'Mehr sehen',         'ar': 'عرض المزيد'},
  'detail_see_less':      {'fr': 'Voir moins',            'en': 'See less',           'es': 'Ver menos',          'pt': 'Ver menos',          'de': 'Weniger sehen',      'ar': 'عرض أقل'},
  'detail_contact':       {'fr': 'Contacter',             'en': 'Contact',            'es': 'Contactar',          'pt': 'Contatar',           'de': 'Kontakt',            'ar': 'تواصل'},
  'detail_share':         {'fr': 'Partager via',          'en': 'Share via',          'es': 'Compartir por',      'pt': 'Compartilhar via',   'de': 'Teilen über',        'ar': 'مشاركة عبر'},

  // ── Home screen ───────────────────────────────────────────────────────────
  'home_no_results':      {'fr': 'Aucun bien trouvé',    'en': 'No listings found',  'es': 'No se encontraron bienes', 'pt': 'Nenhum imóvel encontrado', 'de': 'Keine Objekte gefunden', 'ar': 'لا توجد عقارات'},
  'home_no_cat':          {'fr': 'Aucun bien dans cette catégorie', 'en': 'No listings in this category', 'es': 'Sin bienes en esta categoría', 'pt': 'Nenhum imóvel nesta categoria', 'de': 'Keine Objekte in dieser Kategorie', 'ar': 'لا عقارات في هذه الفئة'},
  'home_country_filter':  {'fr': 'Filtrer par pays',     'en': 'Filter by country',  'es': 'Filtrar por país',   'pt': 'Filtrar por país',   'de': 'Nach Land filtern',  'ar': 'تصفية حسب البلد'},
  'home_search_country':  {'fr': 'Rechercher un pays...','en': 'Search a country...','es': 'Buscar un país...', 'pt': 'Buscar um país...','de': 'Land suchen...','ar': 'ابحث عن بلد...'},

  // ── Messages ──────────────────────────────────────────────────────────────
  'msg_title':            {'fr': 'Messages',              'en': 'Messages',           'es': 'Mensajes',           'pt': 'Mensagens',          'de': 'Nachrichten',        'ar': 'الرسائل'},
  'msg_call':             {'fr': 'Appeler',               'en': 'Call',               'es': 'Llamar',             'pt': 'Ligar',              'de': 'Anrufen',            'ar': 'اتصال'},
  'msg_cancel':           {'fr': 'Annuler',               'en': 'Cancel',             'es': 'Cancelar',           'pt': 'Cancelar',           'de': 'Abbrechen',          'ar': 'إلغاء'},
  'msg_online':           {'fr': 'En ligne',              'en': 'Online',             'es': 'En línea',           'pt': 'Online',             'de': 'Online',             'ar': 'متصل'},
  'msg_hint':             {'fr': 'Écrire un message…',   'en': 'Write a message…',   'es': 'Escribe un mensaje…','pt': 'Escrever mensagem…', 'de': 'Nachricht schreiben…','ar': 'اكتب رسالة…'},
  'msg_clear':            {'fr': 'Vider la conversation', 'en': 'Clear conversation', 'es': 'Borrar conversación','pt': 'Limpar conversa',    'de': 'Gespräch leeren',    'ar': 'مسح المحادثة'},
  'msg_block':            {'fr': 'Bloquer cet utilisateur','en': 'Block this user',  'es': 'Bloquear usuario',   'pt': 'Bloquear usuário',   'de': 'Benutzer sperren',   'ar': 'حظر المستخدم'},
  'msg_blocked':          {'fr': 'Utilisateur bloqué',   'en': 'User blocked',       'es': 'Usuario bloqueado',  'pt': 'Usuário bloqueado',  'de': 'Benutzer gesperrt',  'ar': 'تم حظر المستخدم'},
  'msg_report':           {'fr': 'Signaler',              'en': 'Report',             'es': 'Reportar',           'pt': 'Reportar',           'de': 'Melden',             'ar': 'الإبلاغ'},
  'msg_reported':         {'fr': 'Signalement envoyé',   'en': 'Report sent',        'es': 'Reporte enviado',    'pt': 'Relatório enviado',  'de': 'Meldung gesendet',   'ar': 'تم الإبلاغ'},

  // ── Favorites ─────────────────────────────────────────────────────────────
  'fav_title':            {'fr': 'Mes favoris',           'en': 'My favorites',       'es': 'Mis favoritos',      'pt': 'Meus favoritos',     'de': 'Meine Favoriten',    'ar': 'المفضلة'},
  'fav_removed':          {'fr': 'Retiré des favoris',   'en': 'Removed from favorites','es': 'Eliminado de favoritos','pt': 'Removido dos favoritos','de': 'Aus Favoriten entfernt','ar': 'تمت الإزالة من المفضلة'},
  'fav_undo':             {'fr': 'Annuler',               'en': 'Undo',               'es': 'Deshacer',           'pt': 'Desfazer',           'de': 'Rückgängig',         'ar': 'تراجع'},

  // ── My Listings ───────────────────────────────────────────────────────────
  'mylist_no_pending':    {'fr': 'Aucune annonce en attente', 'en': 'No pending listings', 'es': 'Sin anuncios pendientes', 'pt': 'Nenhum anúncio pendente', 'de': 'Keine ausstehenden Anzeigen', 'ar': 'لا إعلانات معلقة'},
  'mylist_pending_sub':   {'fr': 'Vos annonces soumises apparaîtront ici', 'en': 'Your submitted listings will appear here', 'es': 'Tus anuncios enviados aparecerán aquí', 'pt': 'Seus anúncios enviados aparecerão aqui', 'de': 'Ihre eingereichten Anzeigen erscheinen hier', 'ar': 'ستظهر إعلاناتك المقدمة هنا'},
  'mylist_delete':        {'fr': 'Supprimer l\'annonce', 'en': 'Delete listing',     'es': 'Eliminar anuncio',   'pt': 'Excluir anúncio',    'de': 'Anzeige löschen',    'ar': 'حذف الإعلان'},
  'mylist_deleted':       {'fr': 'Annonce supprimée',     'en': 'Listing deleted',    'es': 'Anuncio eliminado',  'pt': 'Anúncio excluído',   'de': 'Anzeige gelöscht',   'ar': 'تم حذف الإعلان'},
  'mylist_cancel':        {'fr': 'Annuler',               'en': 'Cancel',             'es': 'Cancelar',           'pt': 'Cancelar',           'de': 'Abbrechen',          'ar': 'إلغاء'},
  'mylist_confirm_del':   {'fr': 'Supprimer',             'en': 'Delete',             'es': 'Eliminar',           'pt': 'Excluir',            'de': 'Löschen',            'ar': 'حذف'},
  'mylist_edit':          {'fr': 'Modifier',              'en': 'Edit',               'es': 'Editar',             'pt': 'Editar',             'de': 'Bearbeiten',         'ar': 'تعديل'},
  'mylist_delete_short':  {'fr': 'Suppr.',                'en': 'Del.',               'es': 'Elim.',              'pt': 'Excl.',              'de': 'Lösch.',             'ar': 'حذف'},
  'mylist_submitted':     {'fr': 'Bien envoyé à l\'admin pour validation !', 'en': 'Listing sent to admin for validation!', 'es': '¡Bien enviado al admin para validación!', 'pt': 'Imóvel enviado ao admin para validação!', 'de': 'Objekt zur Validierung an Admin gesendet!', 'ar': 'تم إرسال العقار للمشرف للمراجعة!'},

  // ── Premium ───────────────────────────────────────────────────────────────
  'prem_title':           {'fr': 'VelQix Premium',     'en': 'VelQix Premium',   'es': 'VelQix Premium',   'pt': 'VelQix Premium',   'de': 'VelQix Premium',   'ar': 'VelQix Premium'},
  'prem_subtitle':        {'fr': 'Boostez vos ventes et locations', 'en': 'Boost your sales and rentals', 'es': 'Impulsa tus ventas y alquileres', 'pt': 'Impulsione suas vendas e aluguéis', 'de': 'Steigern Sie Ihre Verkäufe und Vermietungen', 'ar': 'عزز مبيعاتك وإيجاراتك'},
  'prem_choose_plan':     {'fr': 'Choisissez votre plan','en': 'Choose your plan',   'es': 'Elige tu plan',      'pt': 'Escolha seu plano',  'de': 'Wählen Sie Ihren Plan','ar': 'اختر خطتك'},
  'prem_whats_included':  {'fr': 'Ce qui est inclus',   'en': 'What\'s included',   'es': 'Qué incluye',        'pt': 'O que está incluído','de': 'Was ist enthalten',  'ar': 'ما هو مضمن'},
  'prem_free_vs':         {'fr': 'Gratuit vs Premium',  'en': 'Free vs Premium',    'es': 'Gratis vs Premium',  'pt': 'Grátis vs Premium',  'de': 'Kostenlos vs. Premium','ar': 'مجاني مقابل Premium'},
  'prem_free':            {'fr': 'Free',                 'en': 'Free',               'es': 'Gratis',             'pt': 'Grátis',             'de': 'Kostenlos',          'ar': 'مجاني'},
  'prem_forever':         {'fr': 'Pour toujours',        'en': 'Forever',            'es': 'Para siempre',       'pt': 'Para sempre',        'de': 'Für immer',          'ar': 'إلى الأبد'},
  'prem_mensuel':         {'fr': 'Mensuel',              'en': 'Monthly',            'es': 'Mensual',            'pt': 'Mensal',             'de': 'Monatlich',          'ar': 'شهري'},
  'prem_semestriel':      {'fr': 'Semestriel',           'en': 'Semi-annual',        'es': 'Semestral',          'pt': 'Semestral',          'de': 'Halbjährlich',       'ar': 'نصف سنوي'},
  'prem_annuel':          {'fr': 'Annuel',               'en': 'Annual',             'es': 'Anual',              'pt': 'Anual',              'de': 'Jährlich',           'ar': 'سنوي'},
  'prem_per_month':       {'fr': '/mois',                'en': '/month',             'es': '/mes',               'pt': '/mês',               'de': '/Monat',             'ar': '/شهر'},
  'prem_per_6months':     {'fr': '/6 mois',              'en': '/6 months',          'es': '/6 meses',           'pt': '/6 meses',           'de': '/6 Monate',          'ar': '/6 أشهر'},
  'prem_per_year':        {'fr': '/an',                  'en': '/year',              'es': '/año',               'pt': '/ano',               'de': '/Jahr',              'ar': '/سنة'},
  'prem_saved_15':        {'fr': '15% économisé',        'en': '15% saved',          'es': '15% ahorrado',       'pt': '15% economizado',    'de': '15% gespart',        'ar': 'وفر 15%'},
  'prem_saved_35':        {'fr': '35% économisé',        'en': '35% saved',          'es': '35% ahorrado',       'pt': '35% economizado',    'de': '35% gespart',        'ar': 'وفر 35%'},
  'prem_payment_title':   {'fr': 'Paiement Premium',     'en': 'Premium Payment',    'es': 'Pago Premium',       'pt': 'Pagamento Premium',  'de': 'Premium-Zahlung',    'ar': 'دفع Premium'},
  'prem_verify_id':       {'fr': 'Vérifiez votre identité', 'en': 'Verify your identity', 'es': 'Verifica tu identidad', 'pt': 'Verifique sua identidade', 'de': 'Identität prüfen', 'ar': 'تحقق من هويتك'},
  'prem_active':          {'fr': 'Votre badge Premium est maintenant actif sur votre profil.', 'en': 'Your Premium badge is now active on your profile.', 'es': 'Tu insignia Premium ya está activa en tu perfil.', 'pt': 'Seu badge Premium está ativo no seu perfil.', 'de': 'Ihr Premium-Badge ist jetzt in Ihrem Profil aktiv.', 'ar': 'شارة Premium نشطة الآن على ملفك الشخصي.'},
  'prem_vendor':          {'fr': 'Vendeur Premium',      'en': 'Premium Vendor',     'es': 'Vendedor Premium',   'pt': 'Vendedor Premium',   'de': 'Premium-Verkäufer',  'ar': 'بائع مميز'},

  // ── Payment ───────────────────────────────────────────────────────────────
  'pay_dates':            {'fr': 'Dates de location',    'en': 'Rental dates',       'es': 'Fechas de alquiler', 'pt': 'Datas de aluguel',   'de': 'Mietdaten',          'ar': 'تواريخ الإيجار'},
  'pay_method':           {'fr': 'Mode de paiement',     'en': 'Payment method',     'es': 'Método de pago',     'pt': 'Método de pagamento','de': 'Zahlungsmethode',    'ar': 'طريقة الدفع'},
  'pay_operator':         {'fr': 'Opérateur',            'en': 'Operator',           'es': 'Operador',           'pt': 'Operadora',          'de': 'Anbieter',           'ar': 'المشغل'},
  'pay_phone':            {'fr': 'Numéro de téléphone',  'en': 'Phone number',       'es': 'Número de teléfono', 'pt': 'Número de telefone', 'de': 'Telefonnummer',      'ar': 'رقم الهاتف'},
  'pay_total':            {'fr': 'Total',                 'en': 'Total',              'es': 'Total',              'pt': 'Total',              'de': 'Gesamt',             'ar': 'المجموع'},
  'pay_confirm_sms':      {'fr': 'Vous recevrez une confirmation par SMS et email sous peu.', 'en': 'You will receive an SMS and email confirmation shortly.', 'es': 'Recibirás una confirmación por SMS y email pronto.', 'pt': 'Você receberá uma confirmação por SMS e e-mail em breve.', 'de': 'Sie erhalten in Kürze eine SMS- und E-Mail-Bestätigung.', 'ar': 'ستتلقى تأكيداً عبر الرسائل والبريد الإلكتروني قريباً.'},
  'pay_back_home':        {'fr': 'Retour à l\'accueil', 'en': 'Back to home',       'es': 'Volver al inicio',   'pt': 'Voltar ao início',   'de': 'Zurück zur Startseite','ar': 'العودة للرئيسية'},
  'pay_paypal_info':      {'fr': 'Vous serez redirigé vers PayPal pour finaliser le paiement de manière sécurisée.', 'en': 'You will be redirected to PayPal to complete the payment securely.', 'es': 'Serás redirigido a PayPal para completar el pago de forma segura.', 'pt': 'Você será redirecionado ao PayPal para concluir o pagamento com segurança.', 'de': 'Sie werden zu PayPal weitergeleitet, um die Zahlung sicher abzuschließen.', 'ar': 'ستتم إعادة توجيهك إلى PayPal لإتمام الدفع بأمان.'},

  // ── KYC ───────────────────────────────────────────────────────────────────
  'kyc_doc_type':         {'fr': 'Type de document',     'en': 'Document type',      'es': 'Tipo de documento',  'pt': 'Tipo de documento',  'de': 'Dokumenttyp',        'ar': 'نوع الوثيقة'},
  'kyc_photos':           {'fr': 'Photos du document',   'en': 'Document photos',    'es': 'Fotos del documento','pt': 'Fotos do documento', 'de': 'Dokumentfotos',      'ar': 'صور الوثيقة'},
  'kyc_recto':            {'fr': 'Recto',                'en': 'Front',              'es': 'Anverso',            'pt': 'Frente',             'de': 'Vorderseite',        'ar': 'الوجه الأمامي'},
  'kyc_verso':            {'fr': 'Verso',                'en': 'Back',               'es': 'Reverso',            'pt': 'Verso',              'de': 'Rückseite',          'ar': 'الوجه الخلفي'},
  'kyc_selfie':           {'fr': 'Selfie avec document', 'en': 'Selfie with document','es': 'Selfie con documento','pt': 'Selfie com documento','de': 'Selfie mit Dokument','ar': 'صورة مع الوثيقة'},
  'kyc_recap':            {'fr': 'Récapitulatif',        'en': 'Summary',            'es': 'Resumen',            'pt': 'Resumo',             'de': 'Zusammenfassung',    'ar': 'ملخص'},
  'kyc_done':             {'fr': 'Dossier soumis !',     'en': 'File submitted!',    'es': '¡Expediente enviado!','pt': 'Dossiê enviado!',    'de': 'Akte eingereicht!',  'ar': 'تم تقديم الملف!'},
  'kyc_understood':       {'fr': 'Compris',              'en': 'Got it',             'es': 'Entendido',          'pt': 'Entendido',          'de': 'Verstanden',         'ar': 'مفهوم'},
  'kyc_gallery':          {'fr': 'Galerie',              'en': 'Gallery',            'es': 'Galería',            'pt': 'Galeria',            'de': 'Galerie',            'ar': 'المعرض'},
  'kyc_camera':           {'fr': 'Caméra',               'en': 'Camera',             'es': 'Cámara',             'pt': 'Câmera',             'de': 'Kamera',             'ar': 'الكاميرا'},
  'kyc_change':           {'fr': 'Changer',              'en': 'Change',             'es': 'Cambiar',            'pt': 'Alterar',            'de': 'Ändern',             'ar': 'تغيير'},

  // ── Notifications ─────────────────────────────────────────────────────────
  'notif_title':          {'fr': 'Notifications',        'en': 'Notifications',      'es': 'Notificaciones',     'pt': 'Notificações',       'de': 'Benachrichtigungen', 'ar': 'الإشعارات'},
  'notif_unread':         {'fr': 'non lue',              'en': 'unread',             'es': 'no leída',           'pt': 'não lida',           'de': 'ungelesen',          'ar': 'غير مقروءة'},
  'notif_unread_pl':      {'fr': 'non lues',             'en': 'unread',             'es': 'no leídas',          'pt': 'não lidas',          'de': 'ungelesen',          'ar': 'غير مقروءة'},
  'notif_read_all':       {'fr': 'Tout lire',            'en': 'Read all',           'es': 'Leer todo',          'pt': 'Ler tudo',           'de': 'Alle lesen',         'ar': 'قراءة الكل'},

  // ── Support ───────────────────────────────────────────────────────────────
  'support_title':        {'fr': 'Aide & Support',       'en': 'Help & Support',     'es': 'Ayuda & Soporte',    'pt': 'Ajuda & Suporte',    'de': 'Hilfe & Support',    'ar': 'المساعدة والدعم'},
  'support_need_help':    {'fr': 'Besoin d\'aide ?',    'en': 'Need help?',         'es': '¿Necesitas ayuda?',  'pt': 'Precisa de ajuda?',  'de': 'Brauchen Sie Hilfe?','ar': 'تحتاج مساعدة؟'},
  'support_24h':          {'fr': 'Notre équipe répond en moins de 24h', 'en': 'Our team replies within 24h', 'es': 'Nuestro equipo responde en menos de 24h', 'pt': 'Nossa equipe responde em menos de 24h', 'de': 'Unser Team antwortet innerhalb von 24h', 'ar': 'فريقنا يرد في أقل من 24 ساعة'},
  'support_contact':      {'fr': 'Nous contacter',       'en': 'Contact us',         'es': 'Contáctanos',        'pt': 'Contate-nos',        'de': 'Kontaktieren Sie uns','ar': 'تواصل معنا'},
  'support_faq':          {'fr': 'Questions fréquentes', 'en': 'Frequently asked questions','es': 'Preguntas frecuentes','pt': 'Perguntas frequentes','de': 'Häufige Fragen','ar': 'الأسئلة الشائعة'},
  'support_copied':       {'fr': 'copié dans le presse-papier', 'en': 'copied to clipboard', 'es': 'copiado al portapapeles', 'pt': 'copiado para a área de transferência', 'de': 'in Zwischenablage kopiert', 'ar': 'تم النسخ إلى الحافظة'},

  // ── Transactions ──────────────────────────────────────────────────────────
  'trans_revenue':        {'fr': 'Revenus totaux',       'en': 'Total revenue',      'es': 'Ingresos totales',   'pt': 'Receita total',      'de': 'Gesamteinnahmen',    'ar': 'إجمالي الإيرادات'},

  // ── Profile ───────────────────────────────────────────────────────────────
  'prof_premium_badge':   {'fr': 'Compte Premium',       'en': 'Premium Account',    'es': 'Cuenta Premium',     'pt': 'Conta Premium',      'de': 'Premium-Konto',      'ar': 'حساب مميز'},
  'prof_country_updated': {'fr': 'Pays mis à jour',      'en': 'Country updated',    'es': 'País actualizado',   'pt': 'País atualizado',    'de': 'Land aktualisiert',  'ar': 'تم تحديث البلد'},
  'prof_editable':        {'fr': 'Modifiable',           'en': 'Editable',           'es': 'Editable',           'pt': 'Editável',           'de': 'Bearbeitbar',        'ar': 'قابل للتعديل'},
  'prof_save':            {'fr': 'Enregistrer',          'en': 'Save',               'es': 'Guardar',            'pt': 'Salvar',             'de': 'Speichern',          'ar': 'حفظ'},
  'prof_change_pwd':      {'fr': 'Changer le mot de passe', 'en': 'Change password', 'es': 'Cambiar contraseña', 'pt': 'Alterar senha',      'de': 'Passwort ändern',    'ar': 'تغيير كلمة المرور'},
  'prof_search_country':  {'fr': 'Rechercher un pays...','en': 'Search a country...','es': 'Buscar un país...', 'pt': 'Buscar um país...','de': 'Land suchen...','ar': 'ابحث عن بلد...'},
  'prof_annonces':        {'fr': 'Annonces',             'en': 'Listings',           'es': 'Anuncios',           'pt': 'Anúncios',           'de': 'Anzeigen',           'ar': 'إعلانات'},
  'prof_note':            {'fr': 'Note',                 'en': 'Rating',             'es': 'Nota',               'pt': 'Nota',               'de': 'Bewertung',          'ar': 'التقييم'},
  'prof_avis':            {'fr': 'Avis',                 'en': 'Reviews',            'es': 'Reseñas',            'pt': 'Avaliações',         'de': 'Bewertungen',        'ar': 'تقييمات'},
  'prof_upgrade_kyc':     {'fr': 'Passez Premium pour accéder à la vérification d\'identité', 'en': 'Go Premium to access identity verification', 'es': 'Hazte Premium para acceder a la verificación de identidad', 'pt': 'Torne-se Premium para acessar a verificação de identidade', 'de': 'Premium werden, um die Identitätsprüfung zu nutzen', 'ar': 'اشترك بـ Premium للوصول إلى التحقق من الهوية'},

  // ── Auth ──────────────────────────────────────────────────────────────────
  'auth_google':          {'fr': 'Continuer avec Google','en': 'Continue with Google','es': 'Continuar con Google','pt': 'Continuar com Google','de': 'Mit Google fortfahren','ar': 'المتابعة مع Google'},
  'auth_facebook':        {'fr': 'Continuer avec Facebook','en': 'Continue with Facebook','es': 'Continuar con Facebook','pt': 'Continuar com Facebook','de': 'Mit Facebook fortfahren','ar': 'المتابعة مع Facebook'},
  'auth_accept':          {'fr': 'Accepter',             'en': 'Accept',             'es': 'Aceptar',            'pt': 'Aceitar',            'de': 'Akzeptieren',        'ar': 'قبول'},
  'auth_accept_terms':    {'fr': 'Veuillez accepter les conditions d\'utilisation.', 'en': 'Please accept the terms of use.', 'es': 'Por favor acepta los términos de uso.', 'pt': 'Por favor, aceite os termos de uso.', 'de': 'Bitte akzeptieren Sie die Nutzungsbedingungen.', 'ar': 'يرجى قبول شروط الاستخدام.'},
  'auth_welcome':         {'fr': 'Compte créé avec succès ! Bienvenue 🎉', 'en': 'Account created successfully! Welcome 🎉', 'es': '¡Cuenta creada exitosamente! Bienvenido 🎉', 'pt': 'Conta criada com sucesso! Bem-vindo 🎉', 'de': 'Konto erfolgreich erstellt! Willkommen 🎉', 'ar': 'تم إنشاء الحساب بنجاح! مرحباً 🎉'},
  'auth_field_nom':       {'fr': 'Nom *',                'en': 'Last name *',        'es': 'Apellido *',         'pt': 'Sobrenome *',        'de': 'Nachname *',         'ar': 'اللقب *'},
  'auth_field_prenom':    {'fr': 'Prénom *',             'en': 'First name *',       'es': 'Nombre *',           'pt': 'Nome *',             'de': 'Vorname *',          'ar': 'الاسم الأول *'},
  'auth_field_username':  {'fr': 'Nom d\'utilisateur *','en': 'Username *',         'es': 'Nombre de usuario *','pt': 'Nome de usuário *',  'de': 'Benutzername *',     'ar': 'اسم المستخدم *'},
  'auth_field_email':     {'fr': 'Email *',              'en': 'Email *',            'es': 'Correo electrónico *','pt': 'E-mail *',           'de': 'E-Mail *',           'ar': 'البريد الإلكتروني *'},
  'auth_field_phone':     {'fr': 'Téléphone *',          'en': 'Phone *',            'es': 'Teléfono *',         'pt': 'Telefone *',         'de': 'Telefon *',          'ar': 'الهاتف *'},
  'auth_field_address':   {'fr': 'Adresse',              'en': 'Address',            'es': 'Dirección',          'pt': 'Endereço',           'de': 'Adresse',            'ar': 'العنوان'},
  'auth_search_country':  {'fr': 'Rechercher un pays...','en': 'Search a country...','es': 'Buscar un país...', 'pt': 'Buscar um país...','de': 'Land suchen...','ar': 'ابحث عن بلد...'},
  'auth_pwd_label':       {'fr': 'Mot de passe *',       'en': 'Password *',         'es': 'Contraseña *',       'pt': 'Senha *',            'de': 'Passwort *',         'ar': 'كلمة المرور *'},

  // ── Property Detail ───────────────────────────────────────────────────────
  'detail_reserve':       {'fr': 'Réserver',             'en': 'Book',               'es': 'Reservar',           'pt': 'Reservar',           'de': 'Buchen',             'ar': 'حجز'},
  'detail_contact_owner': {'fr': 'Contacter le propriétaire', 'en': 'Contact owner',  'es': 'Contactar propietario', 'pt': 'Contatar proprietário', 'de': 'Eigentümer kontaktieren', 'ar': 'الاتصال بالمالك'},
  'common_retry':         {'fr': 'Réessayer',            'en': 'Retry',              'es': 'Reintentar',         'pt': 'Tentar novamente',   'de': 'Erneut versuchen',   'ar': 'إعادة المحاولة'},
  'detail_buy':           {'fr': 'Acheter',              'en': 'Buy',                'es': 'Comprar',            'pt': 'Comprar',            'de': 'Kaufen',             'ar': 'شراء'},
  'detail_submit_admin':  {'fr': 'Soumettre à la validation', 'en': 'Submit for validation', 'es': 'Enviar para validación', 'pt': 'Enviar para validação', 'de': 'Zur Validierung einreichen', 'ar': 'إرسال للمراجعة'},
  'detail_submit_desc':   {'fr': 'Envoyez ce bien à l\'administrateur pour qu\'il soit validé et visible par tous les utilisateurs.', 'en': 'Send this property to the administrator to be validated and visible to all users.', 'es': 'Envía este bien al administrador para que sea validado y visible para todos los usuarios.', 'pt': 'Envie este imóvel ao administrador para ser validado e visível para todos os usuários.', 'de': 'Senden Sie dieses Objekt an den Administrator zur Validierung und Sichtbarkeit für alle Nutzer.', 'ar': 'أرسل هذا العقار للمشرف ليتم التحقق منه وجعله مرئياً لجميع المستخدمين.'},
  'detail_send_admin':    {'fr': 'Envoyer à l\'admin',  'en': 'Send to admin',      'es': 'Enviar al admin',    'pt': 'Enviar ao admin',    'de': 'An Admin senden',    'ar': 'إرسال للمشرف'},
  'detail_submitted':     {'fr': 'Bien soumis à l\'admin pour validation !', 'en': 'Property submitted to admin for validation!', 'es': '¡Bien enviado al admin para validación!', 'pt': 'Imóvel enviado ao admin para validação!', 'de': 'Objekt zur Validierung an Admin eingereicht!', 'ar': 'تم إرسال العقار للمشرف للمراجعة!'},
  'detail_owner':         {'fr': 'Propriétaire',        'en': 'Owner',              'es': 'Propietario',        'pt': 'Proprietário',       'de': 'Eigentümer',         'ar': 'المالك'},
  'detail_views':         {'fr': 'vues',                 'en': 'views',              'es': 'vistas',             'pt': 'visualizações',      'de': 'Aufrufe',            'ar': 'مشاهدات'},
  'detail_reviews':       {'fr': 'avis',                 'en': 'reviews',            'es': 'reseñas',            'pt': 'avaliações',         'de': 'Bewertungen',        'ar': 'تقييمات'},
  'detail_reviews_title': {'fr': 'Avis',                 'en': 'Reviews',            'es': 'Reseñas',            'pt': 'Avaliações',         'de': 'Bewertungen',        'ar': 'التقييمات'},
  'detail_copy':          {'fr': 'Copier',               'en': 'Copy',               'es': 'Copiar',             'pt': 'Copiar',             'de': 'Kopieren',           'ar': 'نسخ'},
  'detail_copied':        {'fr': 'Lien copié avec succès !', 'en': 'Link copied successfully!', 'es': '¡Enlace copiado con éxito!', 'pt': 'Link copiado com sucesso!', 'de': 'Link erfolgreich kopiert!', 'ar': 'تم نسخ الرابط بنجاح!'},
  'detail_wa_copied':     {'fr': 'Texte copié — collez dans WhatsApp', 'en': 'Text copied — paste in WhatsApp', 'es': 'Texto copiado — pega en WhatsApp', 'pt': 'Texto copiado — cole no WhatsApp', 'de': 'Text kopiert — in WhatsApp einfügen', 'ar': 'تم نسخ النص — الصقه في واتساب'},
  'detail_email_copied':  {'fr': 'Texte copié — collez dans votre email', 'en': 'Text copied — paste in your email', 'es': 'Texto copiado — pega en tu correo', 'pt': 'Texto copiado — cole no seu e-mail', 'de': 'Text kopiert — in E-Mail einfügen', 'ar': 'تم نسخ النص — الصقه في بريدك'},
  'detail_add_listing_hint': {'fr': 'Utilisez la galerie ou prenez une photo directement', 'en': 'Use the gallery or take a photo directly', 'es': 'Usa la galería o toma una foto directamente', 'pt': 'Use a galeria ou tire uma foto diretamente', 'de': 'Galerie verwenden oder Foto direkt aufnehmen', 'ar': 'استخدم المعرض أو التقط صورة مباشرة'},

  // ── Widgets shared ────────────────────────────────────────────────────────
  'widget_copied':        {'fr': 'Copié dans le presse-papier', 'en': 'Copied to clipboard', 'es': 'Copiado al portapapeles', 'pt': 'Copiado para a área de transferência', 'de': 'In Zwischenablage kopiert', 'ar': 'تم النسخ إلى الحافظة'},

  // ── Catégories home ──────────────────────────────────────────────────────
  'cat_all':          {'fr': 'Tous',          'en': 'All',           'es': 'Todos',         'pt': 'Todos',         'de': 'Alle',          'ar': 'الكل'},
  'cat_maisons':      {'fr': 'Maisons',       'en': 'Houses',        'es': 'Casas',         'pt': 'Casas',         'de': 'Häuser',        'ar': 'منازل'},
  'cat_voitures':     {'fr': 'Voitures',      'en': 'Cars',          'es': 'Coches',        'pt': 'Carros',        'de': 'Autos',         'ar': 'سيارات'},
  'cat_appartements': {'fr': 'Appartements',  'en': 'Apartments',    'es': 'Apartamentos',  'pt': 'Apartamentos',  'de': 'Wohnungen',     'ar': 'شقق'},
  'cat_equipements':  {'fr': 'Équipements',   'en': 'Equipment',     'es': 'Equipos',       'pt': 'Equipamentos',  'de': 'Ausstattung',   'ar': 'معدات'},
  'cat_terrains':     {'fr': 'Terrains',      'en': 'Land',          'es': 'Terrenos',      'pt': 'Terrenos',      'de': 'Grundstücke',   'ar': 'أراضي'},
  'cat_bureaux':      {'fr': 'Bureaux',       'en': 'Offices',       'es': 'Oficinas',      'pt': 'Escritórios',   'de': 'Büros',         'ar': 'مكاتب'},
  'cat_motos':        {'fr': 'Motos',         'en': 'Motorcycles',   'es': 'Motos',         'pt': 'Motos',         'de': 'Motorräder',    'ar': 'دراجات'},
  'cat_autre':        {'fr': 'Autre',         'en': 'Other',         'es': 'Otro',          'pt': 'Outro',         'de': 'Sonstige',      'ar': 'أخرى'},
  'home_listings':    {'fr': 'biens',         'en': 'listings',      'es': 'bienes',        'pt': 'imóveis',       'de': 'Objekte',       'ar': 'عقارات'},

  // ── Premium features ─────────────────────────────────────────────────────
  'feat_badge':           {'fr': 'Badge Vendeur Premium',      'en': 'Premium Vendor Badge',      'es': 'Insignia Vendedor Premium',   'pt': 'Distintivo Vendedor Premium',  'de': 'Premium-Verkäufer-Abzeichen', 'ar': 'شارة البائع المميز'},
  'feat_badge_sub':       {'fr': 'Obtenez le badge doré sur votre profil', 'en': 'Get the golden badge on your profile', 'es': 'Obtén la insignia dorada en tu perfil', 'pt': 'Obtenha o distintivo dourado no seu perfil', 'de': 'Erhalten Sie das goldene Abzeichen in Ihrem Profil', 'ar': 'احصل على الشارة الذهبية في ملفك الشخصي'},
  'feat_vedette':         {'fr': 'Annonces en vedette',        'en': 'Featured listings',         'es': 'Anuncios destacados',         'pt': 'Anúncios em destaque',         'de': 'Hervorgehobene Anzeigen',     'ar': 'إعلانات مميزة'},
  'feat_vedette_sub':     {'fr': 'Vos biens apparaissent en premier', 'en': 'Your listings appear first', 'es': 'Tus bienes aparecen primero', 'pt': 'Seus imóveis aparecem primeiro', 'de': 'Ihre Objekte erscheinen zuerst', 'ar': 'تظهر عقاراتك أولاً'},
  'feat_photos':          {'fr': '30 photos par annonce',      'en': '30 photos per listing',     'es': '30 fotos por anuncio',        'pt': '30 fotos por anúncio',         'de': '30 Fotos pro Anzeige',        'ar': '30 صورة لكل إعلان'},
  'feat_photos_sub':      {'fr': 'vs 2 photos pour les comptes gratuits', 'en': 'vs 2 photos for free accounts', 'es': 'vs 2 fotos para cuentas gratuitas', 'pt': 'vs 2 fotos para contas gratuitas', 'de': 'vs. 2 Fotos für kostenlose Konten', 'ar': 'مقابل 2 صور للحسابات المجانية'},
  'feat_stats':           {'fr': 'Statistiques avancées',      'en': 'Advanced statistics',       'es': 'Estadísticas avanzadas',      'pt': 'Estatísticas avançadas',       'de': 'Erweiterte Statistiken',      'ar': 'إحصائيات متقدمة'},
  'feat_stats_sub':       {'fr': 'Vues, clics, taux de conversion', 'en': 'Views, clicks, conversion rate', 'es': 'Vistas, clics, tasa de conversión', 'pt': 'Visualizações, cliques, taxa de conversão', 'de': 'Aufrufe, Klicks, Konversionsrate', 'ar': 'المشاهدات والنقرات ومعدل التحويل'},
  'feat_support':         {'fr': 'Support prioritaire',        'en': 'Priority support',          'es': 'Soporte prioritario',         'pt': 'Suporte prioritário',          'de': 'Prioritäts-Support',          'ar': 'دعم ذو أولوية'},
  'feat_support_sub':     {'fr': 'Réponse garantie en moins de 2h', 'en': 'Response guaranteed within 2h', 'es': 'Respuesta garantizada en menos de 2h', 'pt': 'Resposta garantida em menos de 2h', 'de': 'Antwort garantiert innerhalb von 2h', 'ar': 'رد مضمون في أقل من ساعتين'},
  'feat_kyc':             {'fr': 'Vérification express KYC',  'en': 'Express KYC verification',  'es': 'Verificación KYC express',    'pt': 'Verificação KYC express',      'de': 'Express-KYC-Verifizierung',   'ar': 'التحقق السريع KYC'},
  'feat_kyc_sub':         {'fr': 'Validation en moins de 2h (vs 48h)', 'en': 'Validation in under 2h (vs 48h)', 'es': 'Validación en menos de 2h (vs 48h)', 'pt': 'Validação em menos de 2h (vs 48h)', 'de': 'Validierung unter 2h (vs. 48h)', 'ar': 'التحقق في أقل من ساعتين (مقابل 48 ساعة)'},
  'feat_assurance':       {'fr': 'Assurance transactions',      'en': 'Transaction insurance',     'es': 'Seguro de transacciones',     'pt': 'Seguro de transações',         'de': 'Transaktionsversicherung',    'ar': 'تأمين المعاملات'},
  'feat_assurance_sub':   {'fr': 'Protection contre les litiges', 'en': 'Protection against disputes', 'es': 'Protección contra disputas', 'pt': 'Proteção contra disputas',    'de': 'Schutz vor Streitigkeiten',   'ar': 'الحماية من النزاعات'},
  'feat_alertes':         {'fr': 'Alertes instantanées',        'en': 'Instant alerts',            'es': 'Alertas instantáneas',        'pt': 'Alertas instantâneos',         'de': 'Sofortige Benachrichtigungen','ar': 'تنبيهات فورية'},
  'feat_alertes_sub':     {'fr': "Notifié dès qu'un client s'intéresse", 'en': 'Notified as soon as a client shows interest', 'es': 'Notificado cuando un cliente se interesa', 'pt': 'Notificado quando um cliente se interessa', 'de': 'Benachrichtigt sobald ein Kunde Interesse zeigt', 'ar': 'إشعار فور اهتمام عميل'},

  // ── Premium plans ─────────────────────────────────────────────────────────
  'prem_start_with':       {'fr': 'Commencer avec',   'en': 'Start with',     'es': 'Empezar con',   'pt': 'Começar com',   'de': 'Starten mit',   'ar': 'ابدأ مع'},
  'prem_no_commitment':    {'fr': 'Annulation possible à tout moment · Sans engagement', 'en': 'Cancel anytime · No commitment', 'es': 'Cancelación posible en cualquier momento · Sin compromiso', 'pt': 'Cancelamento a qualquer momento · Sem compromisso', 'de': 'Jederzeit kündbar · Keine Verpflichtung', 'ar': 'إلغاء في أي وقت · بدون التزام'},
  'prem_saved_25':         {'fr': '25% économisé 🔥', 'en': '25% saved 🔥',   'es': '25% ahorrado 🔥','pt': '25% economizado 🔥','de': '25% gespart 🔥', 'ar': 'وفر 25% 🔥'},

  // ── Comparison table ──────────────────────────────────────────────────────
  'prem_table_feature':    {'fr': 'Fonctionnalité',   'en': 'Feature',          'es': 'Funcionalidad',   'pt': 'Funcionalidade',  'de': 'Funktion',        'ar': 'الميزة'},
  'prem_table_free':       {'fr': 'Gratuit',          'en': 'Free',             'es': 'Gratis',          'pt': 'Grátis',          'de': 'Kostenlos',       'ar': 'مجاني'},
  'prem_table_listings':   {'fr': "Nombre d'annonces",'en': 'Listings',         'es': 'Anuncios',        'pt': 'Anúncios',        'de': 'Inserate',        'ar': 'الإعلانات'},
  'prem_table_photos':     {'fr': 'Photos par annonce','en': 'Photos per listing','es': 'Fotos por anuncio','pt': 'Fotos por anúncio','de': 'Fotos pro Inserat','ar': 'صور لكل إعلان'},
  'prem_table_featured':   {'fr': 'Annonces vedettes','en': 'Featured listings', 'es': 'Anuncios destacados','pt': 'Anúncios em destaque','de': 'Featured-Inserate','ar': 'إعلانات مميزة'},
  'prem_table_badge':      {'fr': 'Badge Premium',    'en': 'Premium Badge',    'es': 'Insignia Premium', 'pt': 'Distintivo Premium','de': 'Premium-Abzeichen','ar': 'شارة Premium'},
  'prem_table_stats':      {'fr': 'Statistiques',     'en': 'Statistics',       'es': 'Estadísticas',    'pt': 'Estatísticas',    'de': 'Statistiken',     'ar': 'إحصائيات'},
  'prem_table_basic':      {'fr': 'Basiques',         'en': 'Basic',            'es': 'Básicas',         'pt': 'Básicas',         'de': 'Grundlegend',     'ar': 'أساسية'},
  'prem_table_advanced':   {'fr': 'Avancées',         'en': 'Advanced',         'es': 'Avanzadas',       'pt': 'Avançadas',       'de': 'Erweitert',       'ar': 'متقدمة'},
  'prem_table_support':    {'fr': 'Support',          'en': 'Support',          'es': 'Soporte',         'pt': 'Suporte',         'de': 'Support',         'ar': 'الدعم'},
  'prem_table_standard':   {'fr': 'Standard (48h)',   'en': 'Standard (48h)',   'es': 'Estándar (48h)',  'pt': 'Padrão (48h)',    'de': 'Standard (48h)',  'ar': 'قياسي (48h)'},
  'prem_table_priority':   {'fr': 'Prioritaire (2h)', 'en': 'Priority (2h)',    'es': 'Prioritario (2h)','pt': 'Prioritário (2h)','de': 'Priorität (2h)',  'ar': 'أولوية (2h)'},
  'prem_table_kyc':        {'fr': 'Vérification KYC', 'en': 'KYC Verification', 'es': 'Verificación KYC','pt': 'Verificação KYC', 'de': 'KYC-Verifizierung','ar': 'التحقق KYC'},
  'prem_table_express':    {'fr': 'Express 2h',       'en': 'Express 2h',       'es': 'Exprés 2h',       'pt': 'Expresso 2h',     'de': 'Express 2h',      'ar': 'سريع 2h'},
  'prem_table_commission': {'fr': 'Commission',       'en': 'Commission',       'es': 'Comisión',        'pt': 'Comissão',        'de': 'Provision',       'ar': 'العمولة'},
  'prem_table_unlimited':  {'fr': 'Illimité',         'en': 'Unlimited',        'es': 'Ilimitado',       'pt': 'Ilimitado',       'de': 'Unbegrenzt',      'ar': 'غير محدود'},
  'comp_badge':            {'fr': 'Badge Premium',    'en': 'Premium Badge',    'es': 'Insignia Premium','pt': 'Distintivo Premium','de': 'Premium-Abzeichen','ar': 'شارة Premium'},
  'comp_stats':            {'fr': 'Statistiques',     'en': 'Statistics',       'es': 'Estadísticas',    'pt': 'Estatísticas',    'de': 'Statistiken',     'ar': 'إحصائيات'},
  'comp_basic':            {'fr': 'Basiques',         'en': 'Basic',            'es': 'Básicas',         'pt': 'Básicas',         'de': 'Grundlegend',     'ar': 'أساسية'},
  'comp_advanced':         {'fr': 'Avancées',         'en': 'Advanced',         'es': 'Avanzadas',       'pt': 'Avançadas',       'de': 'Erweitert',       'ar': 'متقدمة'},

  // ── Profile tabs/fields ───────────────────────────────────────────────────
  'prof_tab_info':     {'fr': 'Informations',     'en': 'Information',    'es': 'Información',   'pt': 'Informações',   'de': 'Informationen', 'ar': 'المعلومات'},
  'prof_tab_pwd':      {'fr': 'Mot de passe',     'en': 'Password',       'es': 'Contraseña',    'pt': 'Senha',         'de': 'Passwort',      'ar': 'كلمة المرور'},
  'prof_non_editable': {'fr': 'Non modifiables',  'en': 'Non-editable',   'es': 'No editables',  'pt': 'Não editáveis', 'de': 'Nicht bearbeitbar','ar': 'غير قابل للتعديل'},

  // ── Payment extra ─────────────────────────────────────────────────────────
  'pay_mobile_money':  {'fr': 'Mobile Money',     'en': 'Mobile Money',   'es': 'Mobile Money',  'pt': 'Mobile Money',  'de': 'Mobile Money',  'ar': 'موبايل موني'},
  'pay_card':          {'fr': 'Carte bancaire',   'en': 'Bank card',      'es': 'Tarjeta bancaria','pt': 'Cartão bancário','de': 'Bankkarte',   'ar': 'بطاقة بنكية'},
  'pay_card_sub':      {'fr': 'Visa, Mastercard', 'en': 'Visa, Mastercard','es': 'Visa, Mastercard','pt': 'Visa, Mastercard','de': 'Visa, Mastercard','ar': 'فيزا، ماستركارد'},
  'pay_intl':          {'fr': 'Paiement international','en': 'International payment','es': 'Pago internacional','pt': 'Pagamento internacional','de': 'Internationale Zahlung','ar': 'دفع دولي'},
  'pay_card_num':      {'fr': 'Numéro de carte',  'en': 'Card number',    'es': 'Número de tarjeta','pt': 'Número do cartão','de': 'Kartennummer','ar': 'رقم البطاقة'},
  'pay_expiry':        {'fr': 'Expiration',        'en': 'Expiry',         'es': 'Vencimiento',   'pt': 'Vencimento',    'de': 'Ablaufdatum',   'ar': 'تاريخ الانتهاء'},
  'pay_reservation':   {'fr': 'Réservation',       'en': 'Booking',        'es': 'Reserva',       'pt': 'Reserva',       'de': 'Buchung',       'ar': 'حجز'},
  'pay_achat':         {'fr': 'Achat',             'en': 'Purchase',       'es': 'Compra',        'pt': 'Compra',        'de': 'Kauf',          'ar': 'شراء'},
  'pay_confirm_resa':  {'fr': 'Confirmer la réservation','en': 'Confirm booking','es': 'Confirmar reserva','pt': 'Confirmar reserva','de': 'Buchung bestätigen','ar': 'تأكيد الحجز'},
  'pay_now':           {'fr': 'Payer maintenant',  'en': 'Pay now',        'es': 'Pagar ahora',   'pt': 'Pagar agora',   'de': 'Jetzt zahlen',  'ar': 'ادفع الآن'},
  'pay_resa_confirmed':{'fr': 'Réservation confirmée !','en': 'Booking confirmed!','es': '¡Reserva confirmada!','pt': 'Reserva confirmada!','de': 'Buchung bestätigt!','ar': 'تم تأكيد الحجز!'},
  'pay_success':       {'fr': 'Paiement réussi !', 'en': 'Payment successful!','es': '¡Pago exitoso!','pt': 'Pagamento realizado!','de': 'Zahlung erfolgreich!','ar': 'تم الدفع بنجاح!'},

  // ── Add listing hints ─────────────────────────────────────────────────────
  'add_hint_titre':    {'fr': 'Ex: Villa moderne avec piscine', 'en': 'Ex: Modern villa with pool', 'es': 'Ej: Villa moderna con piscina', 'pt': 'Ex: Villa moderna com piscina', 'de': 'Bsp: Moderne Villa mit Pool', 'ar': 'مثال: فيلا عصرية مع مسبح'},
  'add_hint_desc':     {'fr': 'Décrivez votre bien en détail...', 'en': 'Describe your property in detail...', 'es': 'Describe tu bien en detalle...', 'pt': 'Descreva seu imóvel em detalhes...', 'de': 'Beschreiben Sie Ihr Objekt im Detail...', 'ar': 'صف عقارك بالتفصيل...'},

  // ── Comparison table (toutes les lignes) ─────────────────────────────────
  'comp_listings':    {'fr': 'Nombre d\'annonces',   'en': 'Number of listings',  'es': 'Número de anuncios',   'pt': 'Número de anúncios',   'de': 'Anzahl Anzeigen',      'ar': 'عدد الإعلانات'},
  'comp_photos':      {'fr': 'Photos par annonce',    'en': 'Photos per listing',  'es': 'Fotos por anuncio',    'pt': 'Fotos por anúncio',    'de': 'Fotos pro Anzeige',    'ar': 'صور لكل إعلان'},
  'comp_featured':    {'fr': 'Annonces vedettes',     'en': 'Featured listings',   'es': 'Anuncios destacados',  'pt': 'Anúncios em destaque', 'de': 'Hervorgehobene Anzeigen','ar': 'إعلانات مميزة'},
  'comp_support_lbl': {'fr': 'Support',               'en': 'Support',             'es': 'Soporte',              'pt': 'Suporte',               'de': 'Support',              'ar': 'الدعم'},
  'comp_standard':    {'fr': 'Standard (48h)',        'en': 'Standard (48h)',      'es': 'Estándar (48h)',       'pt': 'Padrão (48h)',          'de': 'Standard (48h)',       'ar': 'قياسي (48 ساعة)'},
  'comp_priority':    {'fr': 'Prioritaire (2h)',      'en': 'Priority (2h)',       'es': 'Prioritario (2h)',     'pt': 'Prioritário (2h)',      'de': 'Priorität (2h)',       'ar': 'أولوية (ساعتان)'},
  'comp_kyc':         {'fr': 'Vérification KYC',     'en': 'KYC Verification',   'es': 'Verificación KYC',     'pt': 'Verificação KYC',       'de': 'KYC-Verifizierung',    'ar': 'التحقق KYC'},
  'comp_kyc_express': {'fr': 'Express 2h',           'en': 'Express 2h',         'es': 'Express 2h',           'pt': 'Express 2h',            'de': 'Express 2h',           'ar': 'سريع 2 ساعة'},
  'comp_commission':  {'fr': 'Commission',           'en': 'Commission',         'es': 'Comisión',             'pt': 'Comissão',              'de': 'Provision',            'ar': 'العمولة'},
  'comp_unlimited':   {'fr': 'Illimité',             'en': 'Unlimited',          'es': 'Ilimitado',            'pt': 'Ilimitado',             'de': 'Unbegrenzt',           'ar': 'غير محدود'},

  // ── Add listing - catégories supplémentaires ────────────────────────────
  'add_cat_voiture':    {'fr': 'Voiture',          'en': 'Car',            'es': 'Coche',          'pt': 'Carro',          'de': 'Auto',           'ar': 'سيارة'},
  'add_cat_moto':       {'fr': 'Moto',             'en': 'Motorcycle',     'es': 'Moto',           'pt': 'Moto',           'de': 'Motorrad',       'ar': 'دراجة نارية'},
  'add_cat_camion':     {'fr': 'Camion',           'en': 'Truck',          'es': 'Camión',         'pt': 'Caminhão',       'de': 'LKW',            'ar': 'شاحنة'},
  'add_cat_equipement': {'fr': 'Équipement',       'en': 'Equipment',      'es': 'Equipo',         'pt': 'Equipamento',    'de': 'Ausstattung',    'ar': 'معدات'},

  // ── My listings ──────────────────────────────────────────────────────────
  'mylist_title':           {'fr': 'Mes annonces',              'en': 'My listings',            'es': 'Mis anuncios',           'pt': 'Meus anúncios',          'de': 'Meine Anzeigen',         'ar': 'إعلاناتي'},
  'mylist_tab_active':      {'fr': 'Actives',                   'en': 'Active',                 'es': 'Activos',                'pt': 'Ativos',                  'de': 'Aktiv',                  'ar': 'نشطة'},
  'mylist_tab_all':         {'fr': 'Toutes',                    'en': 'All',                    'es': 'Todos',                  'pt': 'Todos',                   'de': 'Alle',                   'ar': 'الكل'},
  'mylist_tab_pending':     {'fr': 'En attente',                'en': 'Pending',                'es': 'Pendiente',              'pt': 'Pendente',                'de': 'Ausstehend',             'ar': 'معلقة'},
  'mylist_no_listing':      {'fr': 'Aucune annonce',            'en': 'No listings',            'es': 'Sin anuncios',           'pt': 'Sem anúncios',            'de': 'Keine Anzeigen',         'ar': 'لا إعلانات'},
  'mylist_no_listing_sub':  {'fr': 'Publiez votre premier bien et commencez à louer ou vendre.', 'en': 'Post your first listing and start renting or selling.', 'es': 'Publica tu primer bien y empieza a alquilar o vender.', 'pt': 'Publique seu primeiro imóvel e comece a alugar ou vender.', 'de': 'Veröffentlichen Sie Ihr erstes Objekt und beginnen Sie zu vermieten oder zu verkaufen.', 'ar': 'انشر إعلانك الأول وابدأ الإيجار أو البيع.'},
  'mylist_add_btn':         {'fr': '+ Publier une annonce',     'en': '+ Post a listing',       'es': '+ Publicar anuncio',     'pt': '+ Publicar anúncio',      'de': '+ Anzeige aufgeben',     'ar': '+ نشر إعلان'},
  'mylist_status_pending':  {'fr': 'En attente de validation',  'en': 'Pending validation',     'es': 'Pendiente de validación','pt': 'Aguardando validação',    'de': 'Auf Validierung wartend','ar': 'في انتظار المراجعة'},
  'mylist_status_not_submitted': {'fr': 'Non soumis à l\'admin','en': 'Not submitted to admin','es': 'No enviado al admin',    'pt': 'Não enviado ao admin',    'de': 'Nicht an Admin gesendet','ar': 'لم يُرسل للمشرف'},

  // ── Favorites ────────────────────────────────────────────────────────────
  'fav_no_fav':         {'fr': 'Aucun favori',             'en': 'No favorites',           'es': 'Sin favoritos',          'pt': 'Sem favoritos',          'de': 'Keine Favoriten',        'ar': 'لا مفضلة'},
  'fav_no_fav_sub':     {'fr': 'Ajoutez des biens à vos favoris pour les retrouver facilement.', 'en': 'Add properties to your favorites to find them easily.', 'es': 'Agrega bienes a tus favoritos para encontrarlos fácilmente.', 'pt': 'Adicione imóveis aos seus favoritos para encontrá-los facilmente.', 'de': 'Fügen Sie Objekte zu Ihren Favoriten hinzu, um sie leicht wiederzufinden.', 'ar': 'أضف عقارات إلى مفضلتك للعثور عليها بسهولة.'},

  // ── Notifications ────────────────────────────────────────────────────────
  'notif_time_mins':    {'fr': 'Il y a',            'en': 'ago',            'es': 'Hace',           'pt': 'Há',             'de': 'Vor',            'ar': 'منذ'},
  'notif_time_hours':   {'fr': 'Il y a',            'en': 'ago',            'es': 'Hace',           'pt': 'Há',             'de': 'Vor',            'ar': 'منذ'},
  'notif_time_days':    {'fr': 'Il y a',            'en': 'ago',            'es': 'Hace',           'pt': 'Há',             'de': 'Vor',            'ar': 'منذ'},

  // ── Transactions ─────────────────────────────────────────────────────────
  'trans_title':            {'fr': 'Mes transactions',          'en': 'My transactions',        'es': 'Mis transacciones',      'pt': 'Minhas transações',       'de': 'Meine Transaktionen',    'ar': 'معاملاتي'},
  'trans_tab_all':          {'fr': 'Toutes',                    'en': 'All',                    'es': 'Todas',                  'pt': 'Todas',                   'de': 'Alle',                   'ar': 'الكل'},
  'trans_tab_loc':          {'fr': 'Locations',                 'en': 'Rentals',                'es': 'Alquileres',             'pt': 'Aluguéis',                'de': 'Vermietungen',           'ar': 'إيجارات'},
  'trans_tab_buy':          {'fr': 'Achats',                    'en': 'Purchases',              'es': 'Compras',                'pt': 'Compras',                  'de': 'Käufe',                  'ar': 'مشتريات'},
  'trans_confirmed':        {'fr': 'transactions confirmées',   'en': 'confirmed transactions', 'es': 'transacciones confirmadas','pt': 'transações confirmadas', 'de': 'bestätigte Transaktionen','ar': 'معاملات مؤكدة'},
  'trans_start':            {'fr': 'Début',                     'en': 'Start',                  'es': 'Inicio',                 'pt': 'Início',                  'de': 'Beginn',                 'ar': 'بداية'},
  'trans_end':              {'fr': 'Fin',                       'en': 'End',                    'es': 'Fin',                    'pt': 'Fim',                     'de': 'Ende',                   'ar': 'نهاية'},
  'trans_status_confirmed': {'fr': 'Confirmé',                  'en': 'Confirmed',              'es': 'Confirmado',             'pt': 'Confirmado',              'de': 'Bestätigt',              'ar': 'مؤكد'},
  'trans_status_done':      {'fr': 'Terminé',                   'en': 'Completed',              'es': 'Terminado',              'pt': 'Concluído',               'de': 'Abgeschlossen',          'ar': 'منتهي'},
  'trans_status_pending':   {'fr': 'En attente',                'en': 'Pending',                'es': 'Pendiente',              'pt': 'Pendente',                'de': 'Ausstehend',             'ar': 'قيد الانتظار'},

  // ── Support FAQs ─────────────────────────────────────────────────────────
  'support_phone_label':  {'fr': 'Téléphone',      'en': 'Phone',          'es': 'Teléfono',       'pt': 'Telefone',       'de': 'Telefon',        'ar': 'هاتف'},
  'faq1_q': {'fr': 'Comment publier une annonce ?', 'en': 'How to post a listing?', 'es': '¿Cómo publicar un anuncio?', 'pt': 'Como publicar um anúncio?', 'de': 'Wie gibt man eine Anzeige auf?', 'ar': 'كيف أنشر إعلاناً؟'},
  'faq1_a': {'fr': 'Appuyez sur le bouton "+" en bas de l\'écran, remplissez les informations de votre bien (titre, prix, photos, description) puis publiez.', 'en': 'Tap the "+" button at the bottom of the screen, fill in your property information (title, price, photos, description) then publish.', 'es': 'Pulsa el botón "+" en la parte inferior, rellena la información de tu bien (título, precio, fotos, descripción) y publica.', 'pt': 'Toque no botão "+" na parte inferior, preencha as informações do seu imóvel (título, preço, fotos, descrição) e publique.', 'de': 'Tippen Sie auf die Schaltfläche "+" unten, füllen Sie die Informationen zu Ihrem Objekt aus und veröffentlichen Sie.', 'ar': 'اضغط على زر "+" في الأسفل، أدخل معلومات عقارك (العنوان، السعر، الصور، الوصف) ثم انشر.'},
  'faq2_q': {'fr': 'Comment passer en compte Premium ?', 'en': 'How to upgrade to Premium?', 'es': '¿Cómo pasar a cuenta Premium?', 'pt': 'Como fazer upgrade para Premium?', 'de': 'Wie werde ich Premium-Mitglied?', 'ar': 'كيف أترقى إلى Premium؟'},
  'faq2_a': {'fr': 'Allez dans votre profil → "Passer Premium". Choisissez un plan et effectuez le paiement via Mobile Money, carte bancaire ou PayPal.', 'en': 'Go to your profile → "Go Premium". Choose a plan and pay via Mobile Money, bank card or PayPal.', 'es': 'Ve a tu perfil → "Hazte Premium". Elige un plan y paga mediante Mobile Money, tarjeta bancaria o PayPal.', 'pt': 'Vá ao seu perfil → "Torne-se Premium". Escolha um plano e pague via Mobile Money, cartão bancário ou PayPal.', 'de': 'Gehen Sie zu Ihrem Profil → "Premium werden". Wählen Sie einen Plan und zahlen Sie per Mobile Money, Bankkarte oder PayPal.', 'ar': 'اذهب إلى ملفك الشخصي → "الترقية إلى Premium". اختر خطة وادفع عبر Mobile Money أو بطاقة بنكية أو PayPal.'},
  'faq3_q': {'fr': 'Comment vérifier mon identité (KYC) ?', 'en': 'How to verify my identity (KYC)?', 'es': '¿Cómo verificar mi identidad (KYC)?', 'pt': 'Como verificar minha identidade (KYC)?', 'de': 'Wie verifiziere ich meine Identität (KYC)?', 'ar': 'كيف أتحقق من هويتي (KYC)؟'},
  'faq3_a': {'fr': 'Dans votre profil, appuyez sur "Vérification d\'identité". Suivez les étapes pour soumettre votre pièce d\'identité.', 'en': 'In your profile, tap "Identity Verification". Follow the steps to submit your ID document.', 'es': 'En tu perfil, pulsa "Verificación de identidad". Sigue los pasos para enviar tu documento de identidad.', 'pt': 'No seu perfil, toque em "Verificação de identidade". Siga os passos para enviar seu documento de identidade.', 'de': 'Tippen Sie in Ihrem Profil auf "Identitätsprüfung". Folgen Sie den Schritten zur Einreichung Ihres Ausweises.', 'ar': 'في ملفك الشخصي، اضغط على "التحقق من الهوية". اتبع الخطوات لتقديم وثيقة هويتك.'},
  'faq4_q': {'fr': 'Comment contacter un propriétaire ?', 'en': 'How to contact an owner?', 'es': '¿Cómo contactar a un propietario?', 'pt': 'Como contatar um proprietário?', 'de': 'Wie kontaktiere ich einen Vermieter?', 'ar': 'كيف أتصل بمالك العقار؟'},
  'faq4_a': {'fr': 'Sur la page d\'un bien, appuyez sur "Contacter" pour envoyer un message ou appeler directement le propriétaire.', 'en': 'On a property page, tap "Contact" to send a message or call the owner directly.', 'es': 'En la página de un bien, pulsa "Contactar" para enviar un mensaje o llamar directamente al propietario.', 'pt': 'Na página de um imóvel, toque em "Contatar" para enviar uma mensagem ou ligar diretamente ao proprietário.', 'de': 'Tippen Sie auf der Objektseite auf "Kontakt", um eine Nachricht zu senden oder den Eigentümer direkt anzurufen.', 'ar': 'في صفحة العقار، اضغط على "تواصل" لإرسال رسالة أو الاتصال بالمالك مباشرة.'},
  'faq5_q': {'fr': 'Comment supprimer mon compte ?', 'en': 'How to delete my account?', 'es': '¿Cómo eliminar mi cuenta?', 'pt': 'Como excluir minha conta?', 'de': 'Wie lösche ich mein Konto?', 'ar': 'كيف أحذف حسابي؟'},
  'faq5_a': {'fr': 'Pour supprimer votre compte, contactez notre support par email à support@innorent.tg avec l\'objet "Suppression de compte".', 'en': 'To delete your account, contact our support by email at support@innorent.tg with the subject "Account deletion".', 'es': 'Para eliminar tu cuenta, contacta nuestro soporte por email a support@innorent.tg con el asunto "Eliminación de cuenta".', 'pt': 'Para excluir sua conta, entre em contato com nosso suporte por e-mail em support@innorent.tg com o assunto "Exclusão de conta".', 'de': 'Um Ihr Konto zu löschen, kontaktieren Sie unseren Support per E-Mail unter support@innorent.tg mit dem Betreff "Kontolöschung".', 'ar': 'لحذف حسابك، تواصل مع الدعم عبر البريد الإلكتروني support@innorent.tg بعنوان "حذف الحساب".'},

  // ── Banières home ─────────────────────────────────────────────────────────
  'banner1_title':    {'fr': 'Louez & Vendez en toute simplicité',        'en': 'Rent & Sell with ease',                   'es': 'Alquila y Vende fácilmente',           'pt': 'Alugue e Venda com simplicidade',      'de': 'Mieten & Verkaufen leicht gemacht',    'ar': 'أجّر وبع بكل سهولة'},
  'banner1_sub':      {'fr': 'Des milliers de biens disponibles partout au Togo.', 'en': 'Thousands of listings available across Togo.', 'es': 'Miles de bienes disponibles en Togo.', 'pt': 'Milhares de imóveis disponíveis no Togo.', 'de': 'Tausende Angebote in ganz Togo.', 'ar': 'آلاف العقارات المتاحة في طوغو.'},
  'banner2_title':    {'fr': 'Voitures, motos & équipements',             'en': 'Cars, bikes & equipment',                 'es': 'Coches, motos y equipos',              'pt': 'Carros, motos e equipamentos',         'de': 'Autos, Motorräder & Ausstattung',      'ar': 'سيارات، دراجات ومعدات'},
  'banner2_sub':      {'fr': 'Trouvez le véhicule qui vous convient, près de chez vous.', 'en': 'Find the vehicle that suits you, near you.', 'es': 'Encuentra el vehículo ideal cerca de ti.', 'pt': 'Encontre o veículo ideal perto de você.', 'de': 'Finden Sie das passende Fahrzeug in Ihrer Nähe.', 'ar': 'اعثر على المركبة المناسبة بالقرب منك.'},
  'banner3_title':    {'fr': 'Transactions sécurisées & vérifiées',       'en': 'Secure & verified transactions',          'es': 'Transacciones seguras y verificadas',  'pt': 'Transações seguras e verificadas',     'de': 'Sichere & verifizierte Transaktionen', 'ar': 'معاملات آمنة وموثقة'},
  'banner3_sub':      {'fr': 'Tous nos propriétaires passent par une vérification KYC.', 'en': 'All our owners go through a KYC verification.', 'es': 'Todos los propietarios pasan por verificación KYC.', 'pt': 'Todos os proprietários passam por verificação KYC.', 'de': 'Alle Vermieter durchlaufen eine KYC-Prüfung.', 'ar': 'جميع الملاك يخضعون لتحقق KYC.'},
  'banner4_title':    {'fr': 'Passez en Premium',                         'en': 'Go Premium',                             'es': 'Hazte Premium',                        'pt': 'Torne-se Premium',                     'de': 'Jetzt Premium werden',                 'ar': 'اشترك بالباقة المميزة'},
  'banner4_sub':      {'fr': 'Boostez vos annonces et accédez à des fonctionnalités exclusives.', 'en': 'Boost your listings and unlock exclusive features.', 'es': 'Impulsa tus anuncios y accede a funciones exclusivas.', 'pt': 'Impulsione seus anúncios e acesse recursos exclusivos.', 'de': 'Steigern Sie Ihre Anzeigen mit exklusiven Funktionen.', 'ar': 'عزز إعلاناتك واستمتع بميزات حصرية.'},
  'banner5_title':    {'fr': 'Publiez votre annonce',                     'en': 'Post your listing',                      'es': 'Publica tu anuncio',                   'pt': 'Publique seu anúncio',                 'de': 'Ihre Anzeige aufgeben',                'ar': 'انشر إعلانك'},
  'banner5_sub':      {'fr': 'En quelques étapes, touchez des milliers d\'acheteurs.', 'en': 'In a few steps, reach thousands of buyers.', 'es': 'En pocos pasos, llega a miles de compradores.', 'pt': 'Em poucos passos, alcance milhares de compradores.', 'de': 'In wenigen Schritten Tausende Käufer erreichen.', 'ar': 'في خطوات بسيطة، تواصل مع آلاف المشترين.'},

  // ── IA Assistant (InnoAssist) ──────────────────────────────────────────────
  'ai_hello_reply':       {'fr': '👋 Bonjour ! Je suis **VelqIA**, l\'assistant de VelQix.\n\nJe peux vous aider à :\n• 🔍 Trouver un bien (maison, voiture, terrain…)\n• 📖 Comprendre la plateforme\n• 💡 Répondre à vos questions\n\nQue puis-je faire pour vous ?',
                           'en': '👋 Hello! I am **VelqIA**, VelQix\'s assistant.\n\nI can help you:\n• 🔍 Find a property (house, car, land…)\n• 📖 Understand the platform\n• 💡 Answer your questions\n\nWhat can I do for you?',
                           'es': '👋 ¡Hola! Soy **VelqIA**, el asistente de VelQix.\n\nPuedo ayudarte a:\n• 🔍 Encontrar un bien (casa, coche, terreno…)\n• 📖 Entender la plataforma\n• 💡 Responder tus preguntas\n\n¿En qué puedo ayudarte?',
                           'pt': '👋 Olá! Sou **VelqIA**, o assistente da VelQix.\n\nPosso ajudá-lo a:\n• 🔍 Encontrar um imóvel (casa, carro, terreno…)\n• 📖 Entender a plataforma\n• 💡 Responder às suas perguntas\n\nO que posso fazer por você?',
                           'de': '👋 Hallo! Ich bin **VelqIA**, der Assistent von VelQix.\n\nIch kann Ihnen helfen:\n• 🔍 Eine Immobilie finden (Haus, Auto, Grundstück…)\n• 📖 Die Plattform verstehen\n• 💡 Ihre Fragen beantworten\n\nWas kann ich für Sie tun?',
                           'ar': '👋 مرحباً! أنا **VelqIA**، مساعد VelQix.\n\nيمكنني مساعدتك في:\n• 🔍 إيجاد عقار (منزل، سيارة، أرض…)\n• 📖 فهم المنصة\n• 💡 الإجابة على أسئلتك\n\nكيف يمكنني مساعدتك؟'},
  'ai_not_understood':    {'fr': '🤔 Je n\'ai pas bien compris votre demande.\n\nEssayez par exemple :\n• *Maison à Lomé*\n• *Voiture à louer*\n• *Comment publier une annonce ?*\n• *Comment passer à Premium ?*',
                           'en': '🤔 I didn\'t quite understand your request.\n\nTry for example:\n• *House in Accra*\n• *Car for rent*\n• *How to post a listing?*\n• *How to go Premium?*',
                           'es': '🤔 No entendí bien tu solicitud.\n\nPrueba por ejemplo:\n• *Casa en Abiyán*\n• *Coche en alquiler*\n• *¿Cómo publicar un anuncio?*\n• *¿Cómo pasarme a Premium?*',
                           'pt': '🤔 Não entendi bem sua solicitação.\n\nTente por exemplo:\n• *Casa em Cotonou*\n• *Carro para alugar*\n• *Como publicar um anúncio?*\n• *Como ir para o Premium?*',
                           'de': '🤔 Ich habe Ihre Anfrage nicht ganz verstanden.\n\nVersuchen Sie zum Beispiel:\n• *Haus in Accra*\n• *Auto zu mieten*\n• *Wie schalte ich eine Anzeige?*\n• *Wie werde ich Premium?*',
                           'ar': '🤔 لم أفهم طلبك جيداً.\n\nجرّب مثلاً:\n• *منزل في أكرا*\n• *سيارة للإيجار*\n• *كيف أنشر إعلاناً؟*\n• *كيف أنتقل إلى Premium؟*'},
  'ai_mic_unavailable':   {'fr': '⚠️ Microphone non disponible. Vérifiez les permissions dans les paramètres de votre téléphone.',
                           'en': '⚠️ Microphone unavailable. Please check permissions in your phone settings.',
                           'es': '⚠️ Micrófono no disponible. Verifica los permisos en la configuración de tu teléfono.',
                           'pt': '⚠️ Microfone indisponível. Verifique as permissões nas configurações do seu telefone.',
                           'de': '⚠️ Mikrofon nicht verfügbar. Überprüfen Sie die Berechtigungen in den Telefoneinstellungen.',
                           'ar': '⚠️ الميكروفون غير متاح. تحقق من الأذونات في إعدادات هاتفك.'},
};

// ─── Accesseur global ─────────────────────────────────────────────────────────
/// Retourne la traduction d'une clé selon la locale active.
/// Usage: `tr('nav_home')` → "Home" si locale = en
String tr(String key) {
  final lang = localeNotifier.value.languageCode;
  final entry = _translations[key];
  if (entry == null) return key; // clé inconnue → retourne la clé brute
  return entry[lang] ?? entry['fr'] ?? key; // fallback français
}