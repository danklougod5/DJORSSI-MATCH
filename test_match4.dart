import 'dart:convert';
import 'dart:io';

  String _normalize(String text) {
    return text.toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ô', 'o')
        .replaceAll('û', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('ç', 'c')
        .trim();
  }

  const Map<String, List<String>> _skillKeywords = {
    'informatique': ['developpeur', 'developer', 'software', 'web', 'mobile', 'fullstack', 'frontend', 'backend', 'devops', 'informatique', 'programmeur', 'data', 'cloud', 'systeme', 'reseau', 'sysadmin', 'it', 'tech', 'digital', 'cybersecurite', 'base de donnees', 'api', 'intelligence artificielle', 'ia', 'machine learning'],
    'administration': ['administratif', 'administration', 'secretaire', 'assistant', 'bureau', 'accueil', 'office', 'coordination', 'gestion', 'archivage', 'courrier', 'standard', 'assistanat', 'dirigeant', 'manager', 'directeur', 'operatrice', 'standardiste'],
    'marketing': ['marketing', 'community manager', 'communication', 'digital', 'seo', 'sem', 'publicite', 'brand', 'marque', 'social media', 'content', 'strategie', 'campagne', 'emailing', 'crm', 'acquisition', 'growth'],
    'ressources humaines': ['rh', 'ressources humaines', 'recrutement', 'paie', 'formation', 'talent', 'gpec', 'droit du travail', 'personnel', 'human resources', 'hr', 'onboarding', 'gestion du personnel'],
    'finance': ['finance', 'comptable', 'comptabilite', 'audit', 'tresorerie', 'banque', 'investissement', 'budget', 'controle de gestion', 'fiscalite', 'analyste financier', 'risque', 'credit'],
  };

  List<String> _getExpandedKeywords(String userSkill) {
    final skillKey = _normalize(userSkill);
    return _skillKeywords[skillKey] ?? [skillKey];
  }

  int _calculateMatchScore(Map<String, dynamic> job, List<String> _userSkills) {
    if (_userSkills.isEmpty) return 0;

    double maxScore = 0;
    bool hasSignificantMatch = false;
    
    // Normalisation basique
    final jobTitle = _normalize(job['job_title'] as String? ?? '');
    final jobSpecialty = _normalize(job['specialty'] as String? ?? '');
    final jobDescription = (job['description'] as String?)?.toLowerCase() ?? '';
    List<String> jobTags = [];
    if (job['tags'] != null) {
      if (job['tags'] is List) {
        jobTags = List<String>.from(job['tags']).map((t) => _normalize(t)).toList();
      }
    }

    // Calcul de la pénalité pour faux positifs
    int penalty = 0;
    final userNormalizedSkills = _userSkills.map(_normalize).toList();
    for (final entry in _skillKeywords.entries) {
      if (userNormalizedSkills.contains(_normalize(entry.key))) continue;
      for (final kw in entry.value) {
        final nkw = _normalize(kw);
        if (nkw.length > 3) {
          final titleWithSpaces = ' \$jobTitle ';
          if (titleWithSpaces.contains(' \$nkw ') || jobTitle.contains(nkw)) {
             penalty -= 800; // Forte pénalité !
             break;
          }
        }
      }
    }

    for (final skill in _userSkills) {
      double currentSkillScore = 0;
      final skillLower = _normalize(skill);
      
      // 1. MATCH DIRECT PAR TAG OU SPÉCIALITÉ (PRIORITÉ ABSOLUE)
      for (final jobTag in jobTags) {
        if (jobTag.isEmpty) continue;
        if (jobTag == skillLower || jobTag.contains(skillLower) || skillLower.contains(jobTag)) {
          currentSkillScore += 1000;
          hasSignificantMatch = true;
          break;
        }
      }

      if (jobSpecialty.isNotEmpty) {
        if (jobSpecialty == skillLower || jobSpecialty.contains(skillLower) || skillLower.contains(jobSpecialty)) {
          currentSkillScore += 800;
          hasSignificantMatch = true;
        }
      }

      // 2. RECHERCHE DE MOTS-CLÉS DANS LE TITRE (POIDS FORT)
      final keywords = _getExpandedKeywords(skill);
      int keywordHitsInTitle = 0;

      for (final keyword in keywords) {
        final kw = _normalize(keyword);
        if (kw.isEmpty) continue;

        final titleWithSpaces = ' \$jobTitle ';
        if (titleWithSpaces.contains(' \$kw ') || (kw.length > 3 && jobTitle.contains(kw))) {
          keywordHitsInTitle++;
          hasSignificantMatch = true;
        }
      }

      if (keywordHitsInTitle > 0) {
        currentSkillScore += 200 + (keywordHitsInTitle * 50);
      } else {
        currentSkillScore += penalty;
      }

      // 3. RECHERCHE DANS LA DESCRIPTION (POIDS LÉGER)
      int descHits = 0;
      for (final keyword in keywords) {
        final kw = _normalize(keyword);
        if (kw.length > 3 && jobDescription.contains(kw)) {
          descHits++;
        }
      }
      if (descHits > 0) {
        currentSkillScore += (descHits * 10);
        if (keywordHitsInTitle > 0) hasSignificantMatch = true;
      }

      if (currentSkillScore > maxScore) {
        maxScore = currentSkillScore;
      }
    }

    if (!hasSignificantMatch) {
      return -100;
    }

    return maxScore.toInt();
  }

void main() {
  final badJob = {
    'job_title': 'STAGIAIRE EN MARKETING',
    'specialty': null,
    'tags': ['Stage', 'Marketing', 'Commerce', 'RH', 'Informatique', 'Communication visuelle'],
    'description': "Un hôtel recrute"
  };
  
  final goodJob = {
    'job_title': 'DEVELOPPEUR CRM',
    'specialty': null,
    'tags': ['Informatique', 'CRM', 'Administration de bases de données'],
    'description': ''
  };

  print("Score Bad: \${_calculateMatchScore(badJob, ['Informatique'])}");
  print("Score IT: \${_calculateMatchScore(goodJob, ['Informatique'])}");
}
