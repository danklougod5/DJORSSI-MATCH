import 'dart:convert';
import 'dart:io';
import '../app/lib/core/utils/tag_normalizer.dart';

// Emulation of swipe_screen.dart matching logic

bool _isContractType(String tag) {
  return const {'cdd', 'cdi', 'stage', 'freelance', 'intérim', 'alternance'}
      .contains(TagNormalizer.normalizeKey(tag));
}

bool _isGenericTag(String tag) {
  return TagNormalizer.isGeneric(tag);
}

List<String> _getExpandedKeywords(String userSkill) {
  return TagNormalizer.getExpandedKeywords(userSkill).toList();
}

bool _matchWord(String text, String word) {
  final textLower = text.toLowerCase();
  final wordLower = TagNormalizer.normalizeKey(word);

  if (wordLower.isEmpty) return false;

  if (wordLower.length <= 4) {
    final escaped = RegExp.escape(wordLower);
    return RegExp('\\b$escaped\\b', caseSensitive: false).hasMatch(textLower);
  }

  return textLower.contains(wordLower);
}

int _calculateMatchScore(Map<String, dynamic> job, List<String> userSkills, bool isPremium) {
  if (userSkills.isEmpty) return 50;

  double totalScore = 0;
  int matchesCount = 0;

  final jobTitle = (job['job_title'] as String?)?.toLowerCase().trim() ?? '';
  final jobSpecialty = (job['specialty'] as String?)?.toLowerCase().trim() ?? '';
  final jobDescription = (job['description'] as String?)?.toLowerCase() ?? '';
  final allJobTags = List<String>.from(
    job['tags'] ?? [],
  ).map((t) => t.toLowerCase().trim()).toList();

  for (final skill in userSkills) {
    double currentSkillScore = 0;
    final skillLower = skill.toLowerCase().trim();
    final isContractTag = _isContractType(skillLower);
    
    bool matchedThisSkill = false;

    // 1. MATCH DIRECT PAR TAG (POIDS TRÈS FORT)
    for (final jobTag in allJobTags) {
      if (TagNormalizer.normalizeKey(jobTag) == TagNormalizer.normalizeKey(skillLower)) {
        currentSkillScore += isContractTag ? 400 : 300;
        matchedThisSkill = true;
        break;
      }
      if (skillLower.length > 3 && (TagNormalizer.normalizeKey(jobTag).contains(TagNormalizer.normalizeKey(skillLower)) || TagNormalizer.normalizeKey(skillLower).contains(TagNormalizer.normalizeKey(jobTag)))) {
        currentSkillScore += 150;
        matchedThisSkill = true;
        break;
      }
    }

    // 2. MATCH PAR SPÉCIALITÉ (POIDS FORT)
    if (!matchedThisSkill && jobSpecialty.isNotEmpty) {
      if (TagNormalizer.normalizeKey(jobSpecialty) == TagNormalizer.normalizeKey(skillLower)) {
        currentSkillScore += 150;
        matchedThisSkill = true;
      } else if (skillLower.length > 3 && (TagNormalizer.normalizeKey(jobSpecialty).contains(TagNormalizer.normalizeKey(skillLower)) ||
          TagNormalizer.normalizeKey(skillLower).contains(TagNormalizer.normalizeKey(jobSpecialty)))) {
        currentSkillScore += 80;
        matchedThisSkill = true;
      }
    }

    // 3. RECHERCHE DE MOTS-CLÉS (POIDS MOYEN)
    if (!matchedThisSkill) {
      final keywords = _getExpandedKeywords(skill);
      for (final kw in keywords) {
        final kwLower = kw.toLowerCase().trim();
        if (_matchWord(jobTitle, kwLower)) {
          currentSkillScore += 100;
          matchedThisSkill = true;
          break;
        }
        if (allJobTags.any((tag) => _matchWord(tag, kwLower))) {
          currentSkillScore += 50;
          matchedThisSkill = true;
          break;
        }
      }
    }

    // 4. Bonus Description
    if (!matchedThisSkill || isContractTag) {
      if (_matchWord(jobDescription, skillLower)) {
        currentSkillScore += matchedThisSkill ? 20 : 40;
        matchedThisSkill = true;
      }
    }

    if (matchedThisSkill) {
      totalScore += currentSkillScore;
      matchesCount++;
    }
  }

  if (matchesCount == 0 && userSkills.isNotEmpty) {
    return -100;
  }

  if (matchesCount > 1) {
    totalScore += (matchesCount * 30);
  }

  if (isPremium) {
    final createdAt = job['created_at'] as String?;
    if (createdAt != null) {
      try {
        final jobDate = DateTime.parse(createdAt);
        final hoursAgo = DateTime.now().difference(jobDate).inHours;
        if (hoursAgo <= 24) {
          totalScore += 50;
        } else if (hoursAgo <= 72) {
          totalScore += 20;
        }
      } catch (_) {}
    }
  }

  return totalScore.clamp(0, 1000).toInt();
}

void main() {
  final file = File('jobs_dump.json');
  if (!file.existsSync()) {
    print("Error: jobs_dump.json does not exist. Run dump_jobs.py first.");
    return;
  }
  
  final data = json.decode(file.readAsStringSync());
  final allJobs = List<Map<String, dynamic>>.from(data);
  
  final userSkills = ['Informatique', 'CDD'];
  print("Diagnosing match score for user skills: $userSkills");
  
  final matchedJobs = <Map<String, dynamic>>[];
  final scores = <String, int>{};
  
  for (final job in allJobs) {
    final score = _calculateMatchScore(job, userSkills, false);
    if (score > 0) {
      matchedJobs.add(job);
      scores[job['id'].toString()] = score;
    }
  }
  
  matchedJobs.sort((a, b) {
    final scoreA = scores[a['id'].toString()] ?? 0;
    final scoreB = scores[b['id'].toString()] ?? 0;
    return scoreB.compareTo(scoreA);
  });
  
  print("Found ${matchedJobs.length} matched jobs out of ${allJobs.length}.");
  print("\nTop 30 matches:");
  for (int i = 0; i < matchedJobs.length && i < 30; i++) {
    final job = matchedJobs[i];
    final id = job['id'].toString();
    final score = scores[id];
    print("#${i+1} [Score: $score] Title: ${job['job_title']} | Tags: ${job['tags']}");
  }
  
  print("\nChecking specifically for 'batiment' or 'bâtiment' or 'technicien' matches:");
  int foundSpec = 0;
  for (final job in matchedJobs) {
    final title = (job['job_title'] as String? ?? '').toLowerCase();
    final description = (job['description'] as String? ?? '').toLowerCase();
    if (title.contains('batiment') || title.contains('bâtiment') || title.contains('technicien')) {
      final id = job['id'].toString();
      final score = scores[id];
      print("MATCHED SPECIAL JOB: [Score: $score] Title: ${job['job_title']} | Tags: ${job['tags']}");
      foundSpec++;
      // Let's trace why this job matched!
      _traceMatch(job, userSkills);
    }
  }
  print("Total special jobs matching: $foundSpec");
}

void _traceMatch(Map<String, dynamic> job, List<String> userSkills) {
  print("  --> TRACING MATCH FOR: ${job['job_title']}");
  final jobTitle = (job['job_title'] as String?)?.toLowerCase().trim() ?? '';
  final jobSpecialty = (job['specialty'] as String?)?.toLowerCase().trim() ?? '';
  final jobDescription = (job['description'] as String?)?.toLowerCase() ?? '';
  final allJobTags = List<String>.from(
    job['tags'] ?? [],
  ).map((t) => t.toLowerCase().trim()).toList();

  for (final skill in userSkills) {
    final skillLower = skill.toLowerCase().trim();
    print("    * Skill: $skillLower");
    
    // Tag matches
    for (final jobTag in allJobTags) {
      if (TagNormalizer.normalizeKey(jobTag) == TagNormalizer.normalizeKey(skillLower)) {
        print("      - Match 1 (exact tag): '$jobTag' == '$skillLower'");
      }
      if (skillLower.length > 3 && (TagNormalizer.normalizeKey(jobTag).contains(TagNormalizer.normalizeKey(skillLower)) || TagNormalizer.normalizeKey(skillLower).contains(TagNormalizer.normalizeKey(jobTag)))) {
        print("      - Match 1 (partial tag): '$jobTag' contains/contained-by '$skillLower'");
      }
    }
    
    // Specialty matches
    if (jobSpecialty.isNotEmpty) {
      if (TagNormalizer.normalizeKey(jobSpecialty) == TagNormalizer.normalizeKey(skillLower)) {
        print("      - Match 2 (exact specialty): '$jobSpecialty'");
      } else if (skillLower.length > 3 && (TagNormalizer.normalizeKey(jobSpecialty).contains(TagNormalizer.normalizeKey(skillLower)) ||
          TagNormalizer.normalizeKey(skillLower).contains(TagNormalizer.normalizeKey(jobSpecialty)))) {
        print("      - Match 2 (partial specialty): '$jobSpecialty'");
      }
    }
    
    // Keyword matches
    final keywords = _getExpandedKeywords(skill);
    for (final kw in keywords) {
      final kwLower = kw.toLowerCase().trim();
      if (_matchWord(jobTitle, kwLower)) {
        print("      - Match 3 (keyword in title): '$kwLower' matched in title '$jobTitle'");
      }
      if (allJobTags.any((tag) => _matchWord(tag, kwLower))) {
        print("      - Match 3 (keyword in tags): '$kwLower' matched in tags $allJobTags");
      }
    }
    
    // Description matches
    if (_matchWord(jobDescription, skillLower)) {
      print("      - Match 4 (description): '$skillLower' matched in description");
    }
  }
}
