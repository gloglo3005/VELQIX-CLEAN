import { Request, Response } from "express";
import prisma from "../prisma";
import { AdminEvents } from "../services/adminNotificationService";
import { translateAndSavePropertyAsync } from "../services/translationService";
import { shouldCountView } from "../utils/viewDedupe";

// ─── HELPER : sélection standard des champs proprietaire ─────────────────────
const proprietaireSelect = {
  id: true, nom: true, prenom: true, email: true,
  telephone: true, avatarUrl: true, isVerified: true,
  isPremium: true, rating: true, totalAvis: true,
  createdAt: true, role: true,
};

// ─── CREATE ───────────────────────────────────────────────────────────────────
export const createProperty = async (req: Request, res: Response) => {
  try {
    const {
      titre, description, prix, imageUrl, images,
      type, listingType, categorie,
      adresse, ville, pays, prixParJour,
      surface, nombrePieces, annee, caracteristiques,
    } = req.body;

    const proprietaireId = (req as any).userId;

    // Accepte imageUrl (string) OU images (array) — compatibilité Flutter
    const imageArray: string[] = Array.isArray(images)
      ? images
      : imageUrl
      ? [imageUrl]
      : [];

    const property = await prisma.property.create({
      data: {
        titre,
        description,
        prix: Number(prix),
        images: imageArray,
        type: type ?? "immobilier",
        listingType: listingType ?? "vente",
        categorie: categorie ?? "appartement",
        adresse: adresse ?? null,
        ville: ville ?? null,
        pays: pays ?? "TG",
        prixParJour: prixParJour ?? null,
        surface: surface ? Number(surface) : null,
        nombrePieces: nombrePieces ? Number(nombrePieces) : null,
        annee: annee ? Number(annee) : null,
        caracteristiques: caracteristiques ?? [],
        proprietaireId,
        status: "en_attente",
      },
      include: { proprietaire: { select: proprietaireSelect } },
    });

    // 🔔 Notifier l'admin en temps réel + email — TOUJOURS avant res.json()
    // (jamais après, sous peine de ERR_HTTP_HEADERS_SENT si ça échoue une
    // fois la réponse déjà partie). On isole cet appel dans son propre
    // try/catch : une notification qui échoue ne doit pas faire croire à
    // l'utilisateur que la création de son annonce a échoué alors qu'elle
    // a bien été enregistrée en base.
    try {
      await AdminEvents.newProperty(
        property.titre,
        `${property.proprietaire.prenom} ${property.proprietaire.nom}`,
        property.id
      );
    } catch (notifyError) {
      console.error("createProperty (notification admin) :", notifyError);
    }

    res.status(201).json({ success: true, data: property, message: "Bien créé avec succès" });

    // 🌍 Traduction automatique (EN, ES, PT, DE, IT, AR, ZH, JA, KO, RU) —
    // volontairement APRÈS la réponse et SANS await : l'appel à Gemini peut
    // prendre plusieurs secondes, et ne doit jamais retarder la création
    // perçue par l'utilisateur. Contrairement à AdminEvents.newProperty
    // ci-dessus, cette fonction ne touche jamais `res` (elle se contente de
    // mettre à jour la ligne en base une fois prête), donc aucun risque de
    // ERR_HTTP_HEADERS_SENT même en fire-and-forget après la réponse.
    void translateAndSavePropertyAsync(
      property.id,
      property.titre,
      property.description,
      property.caracteristiques
    );
  } catch (error) {
    console.error("createProperty:", error);
    res.status(500).json({ success: false, message: "Erreur serveur" });
  }
};

// ─── GET ALL (avec filtres) ───────────────────────────────────────────────────
export const getProperties = async (req: Request, res: Response) => {
  try {
    const { type, listingType, categorie, ville, pays, prixMin, prixMax, status } = req.query;

    const where: any = {};

    // Le public ne doit voir que les biens approuvés (sécurité : pas d'injection de status via query)
    where.status = "approuve";

    if (type)        where.type = type;
    if (listingType) where.listingType = listingType;
    if (categorie)   where.categorie = categorie;
    if (ville)       where.ville = { contains: String(ville), mode: "insensitive" };
    if (pays)        where.pays = pays;
    if (prixMin || prixMax) {
      where.prix = {};
      if (prixMin) where.prix.gte = Number(prixMin);
      if (prixMax) where.prix.lte = Number(prixMax);
    }

    const properties = await prisma.property.findMany({
      where,
      include: { proprietaire: { select: proprietaireSelect } },
      orderBy: { createdAt: "desc" },
    });

    res.json({ success: true, data: properties });
  } catch (error) {
    console.error("getProperties:", error);
    res.status(500).json({ success: false, message: "Erreur serveur" });
  }
};

// ─── GET FEATURED ─────────────────────────────────────────────────────────────
export const getFeaturedProperties = async (req: Request, res: Response) => {
  try {
    const properties = await prisma.property.findMany({
      where: { isFeatured: true, status: "approuve" },
      include: { proprietaire: { select: proprietaireSelect } },
      orderBy: { createdAt: "desc" },
    });
    res.json({ success: true, data: properties });
  } catch (error) {
    res.status(500).json({ success: false, message: "Erreur serveur" });
  }
};

// ─── GET MES ANNONCES ─────────────────────────────────────────────────────────
export const getMyProperties = async (req: Request, res: Response) => {
  try {
    const userId = String((req as any).userId);
    const properties = await prisma.property.findMany({
      where: { proprietaireId: userId },
      include: { proprietaire: { select: proprietaireSelect } },
      orderBy: { createdAt: "desc" },
    });
    res.json({ success: true, data: properties });
  } catch (error) {
    res.status(500).json({ success: false, message: "Erreur serveur" });
  }
};

// ─── GET ONE ──────────────────────────────────────────────────────────────────
export const getProperty = async (req: Request, res: Response) => {
  try {
    const property = await prisma.property.findUnique({
      where: { id: String(req.params.id) },
      include: { proprietaire: { select: proprietaireSelect } },
    });

    if (!property) {
      return res.status(404).json({ success: false, message: "Bien introuvable" });
    }

    res.json({ success: true, data: property });
  } catch (error) {
    res.status(500).json({ success: false, message: "Erreur serveur" });
  }
};

// ─── UPDATE ───────────────────────────────────────────────────────────────────
export const updateProperty = async (req: Request, res: Response) => {
  try {
    const userId = String((req as any).userId);
    const userRole = (req as any).userRole;
    const id = String(req.params.id);

    const existing = await prisma.property.findUnique({ where: { id } });
    if (!existing) {
      return res.status(404).json({ success: false, message: "Bien introuvable" });
    }

    // Seul le propriétaire ou un admin peut modifier
    if (existing.proprietaireId !== userId && userRole !== "admin") {
      return res.status(403).json({ success: false, message: "Non autorisé" });
    }

    // Champs modifiables — on exclut les champs sensibles non éditables par l'user
    const {
      titre, description, prix, imageUrl, images,
      type, listingType, categorie, adresse, ville, pays,
      prixParJour, surface, nombrePieces, annee, caracteristiques, isAvailable,
    } = req.body;

    const updateData: any = {};
    if (titre !== undefined)           updateData.titre = titre;
    if (description !== undefined)     updateData.description = description;
    if (prix !== undefined)            updateData.prix = Number(prix);
    if (type !== undefined)            updateData.type = type;
    if (listingType !== undefined)     updateData.listingType = listingType;
    if (categorie !== undefined)       updateData.categorie = categorie;
    if (adresse !== undefined)         updateData.adresse = adresse;
    if (ville !== undefined)           updateData.ville = ville;
    if (pays !== undefined)            updateData.pays = pays;
    if (prixParJour !== undefined)     updateData.prixParJour = prixParJour;
    if (surface !== undefined)         updateData.surface = surface ? Number(surface) : null;
    if (nombrePieces !== undefined)    updateData.nombrePieces = nombrePieces ? Number(nombrePieces) : null;
    if (annee !== undefined)           updateData.annee = annee ? Number(annee) : null;
    if (caracteristiques !== undefined) updateData.caracteristiques = caracteristiques;
    if (isAvailable !== undefined)     updateData.isAvailable = isAvailable;

    // Images
    if (Array.isArray(images))         updateData.images = images;
    else if (imageUrl)                 updateData.images = [imageUrl];

    const property = await prisma.property.update({
      where: { id },
      data: updateData,
      include: { proprietaire: { select: proprietaireSelect } },
    });

    res.json({ success: true, data: property, message: "Bien mis à jour" });

    // 🌍 Si le titre, la description ou les caractéristiques ont changé, les
    // traductions existantes sont maintenant obsolètes — on les régénère en
    // fire-and-forget (même principe que dans createProperty, voir la note
    // là-bas : jamais d'await ici, jamais de risque sur `res`).
    if (titre !== undefined || description !== undefined || caracteristiques !== undefined) {
      void translateAndSavePropertyAsync(
        property.id,
        property.titre,
        property.description,
        property.caracteristiques
      );
    }
  } catch (error) {
    console.error("updateProperty:", error);
    res.status(500).json({ success: false, message: "Erreur serveur" });
  }
};

// ─── DELETE ───────────────────────────────────────────────────────────────────
export const deleteProperty = async (req: Request, res: Response) => {
  try {
    const userId = String((req as any).userId);
    const userRole = (req as any).userRole;
    const id = String(req.params.id);

    const existing = await prisma.property.findUnique({ where: { id } });
    if (!existing) {
      return res.status(404).json({ success: false, message: "Bien introuvable" });
    }

    if (existing.proprietaireId !== userId && userRole !== "admin") {
      return res.status(403).json({ success: false, message: "Non autorisé" });
    }

    // On ne supprime jamais silencieusement l'historique financier : si des
    // transactions existent déjà sur ce bien, on bloque avec un message clair
    // plutôt que de laisser Prisma remonter une erreur de contrainte (500 opaque).
    const transactionCount = await prisma.transaction.count({ where: { propertyId: id } });
    if (transactionCount > 0) {
      return res.status(409).json({
        success: false,
        message: "Impossible de supprimer cette annonce : elle a des transactions associées. Mettez-la en pause à la place.",
      });
    }

    await prisma.property.delete({ where: { id } });
    res.json({ success: true, message: "Bien supprimé" });
  } catch (error: any) {
    // Filet de sécurité si une contrainte de clé étrangère bloque quand même
    // la suppression (ex: nouvelle relation ajoutée plus tard sans Cascade).
    if (error?.code === "P2003") {
      return res.status(409).json({
        success: false,
        message: "Impossible de supprimer cette annonce car des données y sont encore rattachées.",
      });
    }
    console.error("deleteProperty:", error);
    res.status(500).json({ success: false, message: "Erreur serveur" });
  }
};

// ─── INCRÉMENTER VUES ─────────────────────────────────────────────────────────
// Route publique (pas d'authMiddleware) — un visiteur non connecté doit
// pouvoir compter comme une vue. shouldCountView() empêche une même IP de
// gonfler artificiellement le compteur en boucle (voir utils/viewDedupe.ts).
export const incrementViews = async (req: Request, res: Response) => {
  try {
    const propertyId = String(req.params.id);
    const ip = req.ip ?? "unknown";

    if (!shouldCountView(ip, propertyId)) {
      // Pas une erreur : on répond simplement que la vue n'a pas été
      // recomptée, sans faire échouer la requête côté client.
      return res.json({ success: true, counted: false });
    }

    await prisma.property.update({
      where: { id: propertyId },
      data: { vues: { increment: 1 } },
    });
    res.json({ success: true, counted: true });
  } catch (error: any) {
    if (error?.code === "P2025") {
      return res.status(404).json({ success: false, message: "Bien introuvable" });
    }
    res.status(500).json({ success: false, message: "Erreur serveur" });
  }
};

// ─── FAVORIS ──────────────────────────────────────────────────────────────────
export const addFavorite = async (req: Request, res: Response) => {
  try {
    const userId = String((req as any).userId);
    const propertyId = String(req.params.id);

    await prisma.favorite.upsert({
      where: { userId_propertyId: { userId, propertyId } },
      update: {},
      create: { userId, propertyId },
    });

    res.json({ success: true, message: "Ajouté aux favoris" });
  } catch (error) {
    res.status(500).json({ success: false, message: "Erreur serveur" });
  }
};

export const removeFavorite = async (req: Request, res: Response) => {
  try {
    const userId = String((req as any).userId);
    const propertyId = String(req.params.id);

    await prisma.favorite.deleteMany({ where: { userId, propertyId } });
    res.json({ success: true, message: "Retiré des favoris" });
  } catch (error) {
    res.status(500).json({ success: false, message: "Erreur serveur" });
  }
};

export const getFavorites = async (req: Request, res: Response) => {
  try {
    const userId = String((req as any).userId);

    const favorites = await prisma.favorite.findMany({
      where: { userId },
      include: {
        property: {
          include: { proprietaire: { select: proprietaireSelect } },
        },
      },
      orderBy: { createdAt: "desc" },
    });

    const properties = favorites.map((f) => f.property);
    res.json({ success: true, data: properties });
  } catch (error) {
    res.status(500).json({ success: false, message: "Erreur serveur" });
  }
};