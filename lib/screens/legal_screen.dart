import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

// ═══════════════════════════════════════════════════════════════════
// LEGAL SCREEN — Conditions d'utilisation & Politique de confidentialité
// ═══════════════════════════════════════════════════════════════════

enum LegalType { terms, privacy }

class LegalScreen extends StatelessWidget {
  final LegalType type;
  const LegalScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final isTerms = type == LegalType.terms;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: isTerms ? 'Conditions d\'utilisation' : 'Politique de confidentialité',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isTerms ? Icons.gavel_rounded : Icons.lock_outline_rounded,
                    color: AppTheme.primary, size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    isTerms ? 'Conditions d\'utilisation' : 'Politique de confidentialité',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700,
                        color: Theme.of(context).textTheme.bodyLarge?.color),
                  ),
                  Text(
                    'Dernière mise à jour : Mai 2025',
                    style: GoogleFonts.poppins(fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color),
                  ),
                ])),
              ]),
            ),

            const SizedBox(height: 24),

            // ── Contenu ────────────────────────────────────────────
            if (isTerms) ..._termsContent(context),
            if (!isTerms) ..._privacyContent(context),

            const SizedBox(height: 40),

            // ── Contact ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
              ),
              child: Row(children: [
                const Icon(Icons.mail_outline_rounded, color: AppTheme.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Des questions ?',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color)),
                  Text('support@velqix.tg',
                      style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.primary,
                          fontWeight: FontWeight.w500)),
                ])),
              ]),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── CONDITIONS D'UTILISATION ───────────────────────────────────────────────
  List<Widget> _termsContent(BuildContext context) => [
    _Section(context, '1. Acceptation des conditions',
        'En accédant à VelQix et en l\'utilisant, vous acceptez d\'être lié par ces conditions d\'utilisation. Si vous n\'acceptez pas ces conditions, veuillez ne pas utiliser notre plateforme.'),
    _Section(context, '2. Utilisation licite',
        'Vous vous engagez à utiliser VelQix uniquement à des fins licites. Il est interdit de publier du contenu frauduleux, trompeur, illégal ou portant atteinte aux droits de tiers.'),
    _Section(context, '3. Responsabilité des annonces',
        'Chaque utilisateur est seul responsable de l\'exactitude et de la légalité des informations publiées dans ses annonces. VelQix n\'assume aucune responsabilité pour les contenus publiés par les utilisateurs.'),
    _Section(context, '4. Transactions sécurisées',
        'VelQix facilite la mise en relation entre propriétaires et locataires/acheteurs. Nous encourageons l\'utilisation de nos outils de paiement intégrés pour sécuriser vos transactions. Toute transaction hors plateforme se fait sous votre entière responsabilité.'),
    _Section(context, '5. Compte utilisateur',
        'Vous êtes responsable de la confidentialité de vos identifiants de connexion. Vous devez nous signaler immédiatement toute utilisation non autorisée de votre compte. VelQix ne peut être tenu responsable des pertes résultant d\'un accès non autorisé à votre compte.'),
    _Section(context, '6. Propriété intellectuelle',
        'Le contenu de VelQix (logos, interface, textes, etc.) est protégé par des droits de propriété intellectuelle. Toute reproduction ou utilisation non autorisée est interdite.'),
    _Section(context, '7. Suspension et résiliation',
        'VelQix se réserve le droit de suspendre ou supprimer tout compte qui viole ces conditions, sans préavis et sans indemnité. Nous pouvons également modifier ou interrompre nos services à tout moment.'),
    _Section(context, '8. Modifications',
        'VelQix peut modifier ces conditions à tout moment. Les modifications entrent en vigueur dès leur publication. En continuant à utiliser la plateforme, vous acceptez les nouvelles conditions.'),
    _Section(context, '9. Droit applicable',
        'Ces conditions sont régies par le droit en vigueur au Togo. Tout litige sera soumis aux tribunaux compétents de Lomé.'),
  ];

  // ── POLITIQUE DE CONFIDENTIALITÉ ──────────────────────────────────────────
  List<Widget> _privacyContent(BuildContext context) => [
    _Section(context, '1. Données collectées',
        'VelQix collecte les informations suivantes :\n• Informations d\'identité : nom, prénom, email, téléphone\n• Données de localisation (si autorisées)\n• Photos et documents partagés dans vos annonces\n• Données de navigation et d\'utilisation de l\'application\n• Informations de paiement (traitées par FedaPay — nous ne stockons pas vos données bancaires)'),
    _Section(context, '2. Utilisation des données',
        'Vos données sont utilisées pour :\n• Créer et gérer votre compte\n• Afficher et gérer vos annonces\n• Faciliter la communication entre utilisateurs\n• Traiter vos paiements\n• Améliorer nos services\n• Vous envoyer des notifications pertinentes'),
    _Section(context, '3. Protection des données',
        'Vos données personnelles sont protégées par des mesures de sécurité techniques et organisationnelles. Nous ne revendons jamais vos données à des tiers à des fins commerciales.'),
    _Section(context, '4. Partage des données',
        'Vos données peuvent être partagées avec :\n• D\'autres utilisateurs (uniquement les informations nécessaires aux transactions)\n• Nos prestataires de paiement (FedaPay)\n• Les autorités compétentes si la loi l\'exige'),
    _Section(context, '5. Conservation des données',
        'Vos données sont conservées pendant la durée de votre compte et jusqu\'à 3 ans après sa suppression, conformément aux obligations légales.'),
    _Section(context, '6. Vos droits',
        'Vous disposez des droits suivants sur vos données :\n• Droit d\'accès et de rectification\n• Droit à l\'effacement (droit à l\'oubli)\n• Droit à la portabilité des données\n• Droit d\'opposition au traitement\n\nPour exercer ces droits, contactez-nous à support@velqix.tg'),
    _Section(context, '7. Cookies',
        'VelQix utilise des cookies et technologies similaires pour améliorer votre expérience. Vous pouvez les désactiver dans les paramètres de votre navigateur, mais cela peut affecter le fonctionnement de certaines fonctionnalités.'),
    _Section(context, '8. Modifications',
        'Nous pouvons mettre à jour cette politique à tout moment. Nous vous notifierons des changements significatifs par email ou via l\'application.'),
  ];
}

// ── Widget section ─────────────────────────────────────────────────────────
Widget _Section(BuildContext context, String title, String body) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700,
              color: Theme.of(context).textTheme.bodyLarge?.color)),
      const SizedBox(height: 6),
      Text(body,
          style: GoogleFonts.poppins(fontSize: 13, height: 1.7,
              color: Theme.of(context).textTheme.bodySmall?.color)),
      const SizedBox(height: 4),
      Divider(color: AppTheme.primary.withOpacity(0.1)),
    ]),
  );
}
