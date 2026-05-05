/// Utilitaire de normalisation et regroupement des tags par famille.
///
/// Résout les problèmes de :
/// - Casse ("informatique" vs "Informatique" → même tag)
/// - Famille ("développeur web" ∈ famille "informatique")
/// - Tags génériques ("emploi", "recrutement") qui ne doivent pas bloquer le matching
class TagNormalizer {
  TagNormalizer._();

  // ─── Acronymes connus (doivent rester en majuscules) ─────────────────
  static const Set<String> _acronyms = {
    'btp',
    'hse',
    'rh',
    'qhse',
    'seo',
    'sem',
    'ia',
    'it',
    'hr',
    'pmp',
    'noc',
    'iso',
    'epi',
    'b2b',
    'b2c',
    'crm',
    'ong',
    'onu',
    'pam',
  };

  // ─── Tags génériques (ne représentent PAS un secteur d'activité) ────
  static const Set<String> genericTags = {
    'urgent',
    'nouveau',
    'premium',
    'fodese',
    'bilingue',
    'anglais',
    'français',
    'allemand',
  };

  // ─── Types d'emploi (contrats) ──────────────────────────────────────
  static const Set<String> jobTypes = {
    'cdi',
    'cdd',
    'stage',
    'freelance',
    'intérim',
    'alternance',
    'temps plein',
    'temps partiel',
    'consultant',
  };

  /// Vérifie si un tag est un type d'emploi (contrat).
  static bool isJobType(String tag) {
    return jobTypes.contains(normalizeKey(tag));
  }

  /// Normalise un tag pour l'affichage (Title Case intelligent).
  ///
  /// - "informatique" → "Informatique"
  /// - "btp" → "BTP"
  /// - "marketing digital" → "Marketing Digital"
  /// - "développeur web" → "Développeur Web"
  static String normalizeDisplay(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return trimmed;
    final lower = trimmed.toLowerCase();

    // Acronyme complet → tout en majuscules
    if (_acronyms.contains(lower)) return trimmed.toUpperCase();

    // Title Case mot par mot (gestion des acronymes intégrés)
    return lower.split(' ').map((word) {
      if (word.isEmpty) return word;
      if (_acronyms.contains(word)) return word.toUpperCase();
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  /// Clé de normalisation pour la déduplication (lowercase + trim).
  static String normalizeKey(String tag) => tag.toLowerCase().trim();

  /// Déduplique une liste de tags bruts en fusionnant les doublons
  /// insensibles à la casse. Retourne une liste de tags normalisés.
  ///
  /// Ex: ["informatique", "Informatique", "INFORMATIQUE"] → ["Informatique"]
  static List<String> deduplicateTags(Iterable<String> rawTags) {
    final Map<String, String> seen = {}; // key → display form
    for (final tag in rawTags) {
      final key = normalizeKey(tag);
      if (key.isEmpty) continue;
      // Garder la version normalisée (pas la première vue)
      if (!seen.containsKey(key)) {
        seen[key] = normalizeDisplay(tag);
      }
    }
    return seen.values.toList();
  }

  /// Vérifie si un tag est générique (non-sectoriel).
  static bool isGeneric(String tag) {
    return genericTags.contains(normalizeKey(tag));
  }

  // ─── Familles de tags (mapping bidirectionnel) ──────────────────────
  //
  // Chaque clé = nom de famille (en lowercase)
  // Chaque valeur = liste de mots-clés qui appartiennent à cette famille
  //
  // Utilisé pour :
  //    la famille correspondante et on utilise TOUS les mots-clés de cette famille.
  static const Map<String, List<String>> tagFamilies = {
    'informatique': [
      'informatique',
      'développeur',
      'developer',
      'développeur web',
      'développeur mobile',
      'développeur fullstack',
      'software',
      'web',
      'mobile',
      'fullstack',
      'frontend',
      'backend',
      'devops',
      'programmeur',
      'data',
      'cloud',
      'système',
      'sysadmin',
      'it',
      'tech',
      'cybersécurité',
      'base de données',
      'api',
      'intelligence artificielle',
      'ia',
      'machine learning',
      'ida',
      'design',
      'graphiste',
      'graphique',
      'ux',
      'ui',
      'créatif',
      'directeur artistique',
      'maquette',
      'photoshop',
      'figma',
      'illustration',
      'motion',
      'webdesign',
      'infographie',
      'brand identity',
      'communication visuelle',
      'infographie',
      'graphisme',
      'photoshop',
      'illustrator',
      'canva',
      'webmaster',
      'digital',
      'numérique',
    ],
    'commerce & management': [
      'commerce',
      'commercial',
      'vente',
      'distribution',
      'magasin',
      'boutique',
      'caissier',
      'merchandising',
      'achat',
      'négoce',
      'grossiste',
      'prospection',
      'technico-commercial',
      'marketing',
      'marketing digital',
      'community manager',
      'community management',
      'communication',
      'seo',
      'sem',
      'publicité',
      'brand',
      'marque',
      'social media',
      'content',
      'stratégie',
      'campagne',
      'emailing',
      'crm',
      'acquisition',
      'growth',
      'réseaux sociaux',
      'création de contenu',
      'vente',
      'commercial',
      'vendeur',
      'business',
      'négociation',
      'terrain',
      'retail',
      'b2b',
      'b2c',
      'account',
      'sales',
      'chiffre d\'affaires',
      'objectif',
      'télévente',
      'télévendeur',
      'closing',
      'administratif',
      'administration',
      'secrétaire',
      'assistant',
      'bureau',
      'accueil',
      'office',
      'coordination',
      'gestion',
      'archivage',
      'courrier',
      'standard',
      'assistanat',
      'secrétariat',
      'rh',
      'ressources humaines',
      'recrutement',
      'paie',
      'formation',
      'talent',
      'gpec',
      'droit du travail',
      'personnel',
      'human resources',
      'hr',
      'onboarding',
      'gestion du personnel',
      'événementiel',
      'événement',
      'event',
      'organisation',
      'logistique événementielle',
      'conférence',
      'salon',
      'spectacle',
      'production',
      'coordination',
      'relations publiques',
      'rp',
      'presse',
      'média',
      'rédaction',
    ],
    'finance & comptabilité': [
      'finance',
      'comptable',
      'comptabilité',
      'audit',
      'trésorerie',
      'banque',
      'investissement',
      'budget',
      'contrôle de gestion',
      'fiscalité',
      'analyste financier',
      'risque',
      'crédit',
      'syscohada',
      'ohada',
      'assistanat comptable',
      'fiscal',
      'assurance',
      'assurance vie',
      'assurance santé',
      'sinistre',
      'souscription',
      'courtier',
      'microfinance',
      'fintech',
      'agent bancaire',
      'audit interne',
      'audit externe',
      'contrôle interne',
      'conformité',
      'compliance',
      'inspection',
      'vérification',
      'microcrédit',
      'épargne',
      'recouvrement',
      'chef d\'agence',
      'agent de crédit',
      'portefeuille',
    ],
    'btp & industrie': [
      'btp',
      'bâtiment',
      'construction',
      'chantier',
      'génie civil',
      'architecte',
      'conducteur de travaux',
      'maçon',
      'électricien',
      'plombier',
      'topographe',
      'urbanisme',
      'ouvrage',
      'hydraulique',
      'infrastructures',
      'ingénieur',
      'engineering',
      'technique',
      'industriel',
      'mécanique',
      'électrique',
      'civil',
      'production',
      'maintenance',
      'qualité',
      'process',
      'automatisme',
      'bureau d\'études',
      'mines',
      'minier',
      'extraction',
      'géologie',
      'forage',
      'pétrole',
      'gaz',
      'exploration',
      'métallurgie',
      'hse',
      'hygiène',
      'sécurité',
      'environnement',
      'qhse',
      'prévention',
      'risques professionnels',
      'audit sécurité',
      'normes',
      'iso',
      'epi',
      'immobilier',
      'foncier',
      'promotion immobilière',
      'gestion locative',
      'aménagement',
    ],
    'logistique & transport': [
      'logistique',
      'supply chain',
      'transport',
      'approvisionnement',
      'entrepôt',
      'stock',
      'manutention',
      'livraison',
      'import',
      'export',
      'douane',
      'transit',
      'fleet',
      'chauffeur',
      'conducteur',
      'routier',
      'maritime',
      'aérien',
      'véhicule',
      'coursier',
      'dispatch',
      'achats',
      'procurement',
      'fournisseur',
      'sourcing',
      'appel d\'offres',
    ],
    'santé & social': [
      'santé',
      'médecin',
      'infirmier',
      'pharmacie',
      'hôpital',
      'clinique',
      'médical',
      'soins',
      'laboratoire',
      'biologie',
      'sage-femme',
      'dentiste',
      'paramédical',
      'aide soignant',
      'humanitaire',
      'ong',
      'développement',
      'aide humanitaire',
      'coopération',
      'unicef',
      'pam',
      'solidarité',
      'agro-alimentaire',
      'agroalimentaire',
      'agriculture',
      'production alimentaire',
      'conditionnement',
      'haccp',
    ],
    'éducation & formation': [
      'éducation',
      'enseignant',
      'professeur',
      'formateur',
      'formation',
      'école',
      'université',
      'pédagogie',
      'cours',
      'académique',
      'tuteur',
      'éducateur',
    ],
    'hôtellerie & restauration': [
      'hôtellerie',
      'restauration',
      'hôtel',
      'restaurant',
      'cuisine',
      'chef',
      'serveur',
      'réception',
      'tourisme',
      'hébergement',
      'bar',
      'traiteur',
      'catering',
    ],
    'sécurité & gardiennage': [
      'sécurité',
      'surveillance',
      'gardiennage',
      'agent de sécurité',
      'vigile',
    ],
    'juridique & droit': [
      'juridique',
      'droit',
      'avocat',
      'juriste',
      'contentieux',
      'contrat',
      'conformité',
      'compliance',
      'réglementation',
      'notaire',
      'huissier',
      'légal',
    ],
    'polyvalent / tout secteur': [
      'emploi',
      'offre',
      'offre d\'emploi',
      'recrutement',
      'job',
      'travail',
      'poste',
      'candidature',
      'opportunité',
      'recherche',
      'à pourvoir',
      'embauche',
      'hiring',
      'polyvalent',
      'divers',
      'tout secteur',
      'standard',
      'terrain',
      'agent',
      'assistant',
    ],
  };

  // Cache du reverse lookup (initialisé une seule fois)
  static Map<String, Set<String>>? _reverseCache;

  /// Construit le reverse lookup : mot-clé → set de familles auxquelles il appartient.
  static Map<String, Set<String>> get _reverseLookup {
    if (_reverseCache != null) return _reverseCache!;

    final Map<String, Set<String>> reverse = {};
    for (final entry in tagFamilies.entries) {
      final familyName = entry.key;
      // Le nom de la famille est aussi un mot-clé de lui-même
      reverse.putIfAbsent(familyName, () => <String>{}).add(familyName);
      for (final keyword in entry.value) {
        final kwLower = keyword.toLowerCase().trim();
        reverse.putIfAbsent(kwLower, () => <String>{}).add(familyName);
      }
    }
    _reverseCache = reverse;
    return reverse;
  }

  /// Retourne les familles auxquelles un tag appartient.
  ///
  /// Ex: "développeur web" → {"informatique"}
  ///     "informatique"   → {"informatique"}
  ///     "commercial"     → {"vente", "commerce"}
  static Set<String> findFamilies(String tag) {
    final tagLower = normalizeKey(tag);
    final families = <String>{};

    // 1. Match exact dans le reverse lookup
    if (_reverseLookup.containsKey(tagLower)) {
      families.addAll(_reverseLookup[tagLower]!);
    }

    // 2. Match partiel : le tag contient un mot-clé ou vice-versa (mots longs uniquement)
    if (families.isEmpty && tagLower.length > 4) {
      for (final entry in _reverseLookup.entries) {
        if (entry.key.length > 4) {
          if (tagLower.contains(entry.key) || entry.key.contains(tagLower)) {
            families.addAll(entry.value);
          }
        }
      }
    }

    return families;
  }

  /// Retourne TOUS les mots-clés étendus pour un skill utilisateur,
  /// y compris ceux de toutes les familles auxquelles il appartient.
  ///
  /// Ex: "développeur web" → tous les mots-clés de la famille "informatique"
  ///     "informatique"   → tous les mots-clés de la famille "informatique"
  static Set<String> getExpandedKeywords(String userSkill) {
    final skillLower = normalizeKey(userSkill);
    final expanded = <String>{skillLower};

    // Chercher les familles
    final families = findFamilies(skillLower);

    // Ajouter tous les mots-clés de chaque famille trouvée
    for (final family in families) {
      expanded.add(family); // Le nom de la famille lui-même
      final keywords = tagFamilies[family];
      if (keywords != null) {
        expanded.addAll(keywords.map((k) => k.toLowerCase().trim()));
      }
    }

    // Aussi vérifier les mots-clés directs (backward compat)
    if (tagFamilies.containsKey(skillLower)) {
      expanded.addAll(
        tagFamilies[skillLower]!.map((k) => k.toLowerCase().trim()),
      );
    }

    return expanded;
  }

  /// Vérifie si deux tags appartiennent à la même famille.
  ///
  /// Ex: sameFamily("développeur web", "informatique") → true
  ///     sameFamily("BTP", "génie civil") → true
  static bool sameFamily(String tag1, String tag2) {
    final families1 = findFamilies(tag1);
    final families2 = findFamilies(tag2);
    return families1.intersection(families2).isNotEmpty;
  }

  /// Normalise les compteurs de secteur en fusionnant les doublons de casse.
  ///
  /// "informatique": 5 + "Informatique": 3 → "Informatique": 8
  static Map<String, int> normalizeSectorCounts(Map<String, int> rawCounts) {
    final Map<String, int> mergedCounts = {};
    final Map<String, String> keyToDisplay = {};

    for (final entry in rawCounts.entries) {
      final key = normalizeKey(entry.key);
      if (key.isEmpty) continue;
      mergedCounts[key] = (mergedCounts[key] ?? 0) + entry.value;
      // Garder la version normalisée pour l'affichage
      keyToDisplay[key] = normalizeDisplay(entry.key);
    }

    // Reconstruire avec les clés d'affichage
    final Map<String, int> result = {};
    for (final entry in mergedCounts.entries) {
      result[keyToDisplay[entry.key]!] = entry.value;
    }
    return result;
  }
}
