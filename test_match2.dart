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

        // Match mot entier ou mot de plus de 3 caractères
        final titleWithSpaces = ' \$jobTitle ';
        if (titleWithSpaces.contains(' \$kw ') || (kw.length > 3 && jobTitle.contains(kw))) {
          keywordHitsInTitle++;
          hasSignificantMatch = true;
        }
      }

      if (keywordHitsInTitle > 0) {
        currentSkillScore += 200 + (keywordHitsInTitle * 50);
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
        // Si on a un match description et un mot-clé title, ça renforce
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
  final file = File('jobs_dump.json');
  final data = json.decode(file.readAsStringSync());
  final List<Map<String, dynamic>> allJobs = List<Map<String, dynamic>>.from(data);
  
  allJobs.sort((a, b) {
    final scoreA = _calculateMatchScore(a, ['Informatique']);
    final scoreB = _calculateMatchScore(b, ['Informatique']);
    return scoreB.compareTo(scoreA); // Les meilleurs scores en premier
  });
  
  for(var job in allJobs.take(10)) {
    print("Score: \${_calculateMatchScore(job, ['Informatique'])}, Title: \${job['job_title']}, Tags: \${job['tags']}");
  }
}
