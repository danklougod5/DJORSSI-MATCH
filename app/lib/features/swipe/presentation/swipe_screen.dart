import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:djossimatch/features/swipe/presentation/djossi_swipe_card.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class SwipeScreen extends StatefulWidget {
  const SwipeScreen({super.key});

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> {
  final _supabase = Supabase.instance.client;
  final CardSwiperController _controller = CardSwiperController();
  bool _isLoading = true;
  List<Map<String, dynamic>> _jobs = [];
  List<String> _userSkills = [];
  
  // Nouveaux états pour le Premium
  int _swipeCount = 0;
  bool _isPremium = false;
  String? _cvUrl;
  String? _fullName;
  String? _sexe;

  // File d'attente pour les envois d'email (éviter le rate-limiting)
  final List<Map<String, dynamic>> _emailQueue = [];
  bool _isProcessingQueue = false;

  StreamSubscription<List<Map<String, dynamic>>>? _profileSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealtime();
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _setupRealtime() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _profileSubscription = _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen((data) {
      if (data.isNotEmpty && mounted) {
        setState(() {
          final isPremium = data.first['is_premium'] ?? false;
          final premiumUntilRaw = data.first['premium_until'];
          if (isPremium && premiumUntilRaw != null) {
            final premiumUntil = DateTime.parse(premiumUntilRaw);
            _isPremium = premiumUntil.isAfter(DateTime.now());
          } else {
            _isPremium = isPremium;
          }
          _cvUrl = data.first['cv_url'];
          _fullName = data.first['full_name'];
          _sexe = data.first['sexe'];
        });
      }
    });
  }

  Future<void> _loadData() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 1. Récupérer les infos du profil (is_premium et skills)
      final profileResponse = await _supabase
          .from('profiles')
          .select('skills, is_premium, full_name, cv_url, sexe')
          .eq('id', userId)
          .maybeSingle();

      if (profileResponse != null) {
        final isPremium = profileResponse['is_premium'] ?? false;
        final premiumUntilRaw = profileResponse['premium_until'];
        if (isPremium && premiumUntilRaw != null) {
          final premiumUntil = DateTime.parse(premiumUntilRaw);
          _isPremium = premiumUntil.isAfter(DateTime.now());
        } else {
          _isPremium = isPremium;
        }
        _cvUrl = profileResponse['cv_url'];
        _fullName = profileResponse['full_name'];
        _sexe = profileResponse['sexe'];
      }

      if (profileResponse != null && profileResponse['skills'] != null) {
        _userSkills = List<String>.from(profileResponse['skills']);
      }

      // 2. Récupérer les IDs des jobs déjà swipés (GAUCHE ou DROITE)
      final swipedResponse = await _supabase
          .from('swipes_log')
          .select('job_id')
          .eq('user_id', userId);
      
      final swipedJobIds = (swipedResponse as List)
          .where((s) => s['job_id'] != null)
          .map((s) => s['job_id'].toString())
          .toSet();

      // 2.5 Compter swipes du jour (GAUCHE + DROITE) pour la limite
      final today = DateTime.now().toIso8601String().substring(0, 10);
      try {
        final countResp = await _supabase
            .from('swipes_log')
            .select('id')
            .eq('user_id', userId)
            .gte('created_at', '${today}T00:00:00Z');
        
        _swipeCount = countResp != null ? (countResp as List).length : 0;
      } catch (e) {
        debugPrint('Erreur lors du comptage des swipes: $e');
        _swipeCount = 0;
      }

      // 3. Récupérer toutes les offres non swipées
      final jobsResponse = await _supabase
          .from('jobs')
          .select()
          .order('created_at', ascending: false);

      final allJobs = List<Map<String, dynamic>>.from(jobsResponse)
          .where((job) => !swipedJobIds.contains(job['id'].toString()))
          .toList();

      // 4. Trier par matching pour tous les utilisateurs
      if (_userSkills.isNotEmpty) {
        allJobs.sort((a, b) {
          final scoreA = _calculateMatchScore(a);
          final scoreB = _calculateMatchScore(b);
          return scoreB.compareTo(scoreA); // Les meilleurs scores en premier
        });
      }

      if (mounted) {
        setState(() {
          _jobs = allJobs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des offres: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static const Map<String, List<String>> _skillKeywords = {
    'informatique': ['développeur', 'developer', 'software', 'web', 'mobile', 'fullstack', 'frontend', 'backend', 'devops', 'informatique', 'programmeur', 'data', 'cloud', 'système', 'réseau', 'sysadmin', 'it', 'tech', 'digital', 'cybersécurité', 'base de données', 'api', 'intelligence artificielle', 'ia', 'machine learning'],
    'marketing': ['marketing', 'community manager', 'communication', 'digital', 'seo', 'sem', 'publicité', 'brand', 'marque', 'social media', 'content', 'stratégie', 'campagne', 'emailing', 'crm', 'acquisition', 'growth'],
    'vente': ['vente', 'commercial', 'vendeur', 'business', 'négociation', 'client', 'prospection', 'terrain', 'retail', 'b2b', 'b2c', 'account', 'sales', 'chiffre d\'affaires', 'objectif'],
    'ressources humaines': ['rh', 'ressources humaines', 'recrutement', 'paie', 'formation', 'talent', 'gpec', 'droit du travail', 'personnel', 'human resources', 'hr', 'onboarding', 'gestion du personnel'],
    'finance': ['finance', 'comptable', 'comptabilité', 'audit', 'trésorerie', 'banque', 'investissement', 'budget', 'contrôle de gestion', 'fiscalité', 'analyste financier', 'risque', 'crédit'],
    'logistique': ['logistique', 'supply chain', 'transport', 'approvisionnement', 'entrepôt', 'stock', 'manutention', 'livraison', 'import', 'export', 'douane', 'transit', 'chauffeur', 'fleet'],
    'ingénierie': ['ingénieur', 'engineering', 'technique', 'industriel', 'mécanique', 'électrique', 'civil', 'production', 'maintenance', 'qualité', 'process', 'automatisme', 'projet', 'bureau d\'études'],
    'design': ['design', 'graphiste', 'graphique', 'ux', 'ui', 'créatif', 'directeur artistique', 'maquette', 'photoshop', 'figma', 'illustration', 'motion', 'webdesign', 'infographie', 'brand identity'],
    'administration': ['administratif', 'administration', 'secrétaire', 'assistant', 'bureau', 'accueil', 'office', 'coordination', 'gestion', 'archivage', 'courrier', 'standard'],
    'télécommunications': ['télécom', 'télécommunication', 'réseau', 'fibre', 'antenne', 'mobile', 'opérateur', 'infrastructure', 'noc', 'radio', '4g', '5g'],
    'btp': ['btp', 'bâtiment', 'construction', 'chantier', 'génie civil', 'architecte', 'conducteur de travaux', 'maçon', 'électricien', 'plombier', 'topographe', 'urbanisme', 'ouvrage'],
    'santé': ['santé', 'médecin', 'infirmier', 'pharmacie', 'hôpital', 'clinique', 'médical', 'soins', 'laboratoire', 'biologie', 'sage-femme', 'dentiste', 'paramédical'],
    'éducation': ['éducation', 'enseignant', 'professeur', 'formateur', 'formation', 'école', 'université', 'pédagogie', 'cours', 'académique', 'tuteur', 'éducateur'],
    'juridique': ['juridique', 'droit', 'avocat', 'juriste', 'contentieux', 'contrat', 'conformité', 'compliance', 'réglementation', 'notaire', 'huissier', 'légal'],
    'banque & assurance': ['banque', 'assurance', 'crédit', 'épargne', 'investissement', 'courtier', 'souscription', 'sinistre', 'risque', 'microfinance', 'fintech', 'agent bancaire'],
    'commerce': ['commerce', 'commercial', 'vente', 'distribution', 'magasin', 'boutique', 'caissier', 'merchandising', 'achat', 'approvisionnement', 'négoce', 'grossiste'],
    'transport': ['transport', 'chauffeur', 'conducteur', 'routier', 'maritime', 'aérien', 'logistique', 'flotte', 'véhicule', 'livraison', 'coursier', 'dispatch'],
    'hôtellerie': ['hôtellerie', 'restauration', 'hôtel', 'restaurant', 'cuisine', 'chef', 'serveur', 'réception', 'tourisme', 'hébergement', 'bar', 'traiteur', 'catering'],
  };

  List<String> _getExpandedKeywords(String userSkill) {
    final skillKey = userSkill.toLowerCase();
    return _skillKeywords[skillKey] ?? [skillKey];
  }

  int _calculateMatchScore(Map<String, dynamic> job) {
    if (_userSkills.isEmpty) return 0;

    double maxScore = 0;
    
    // Normalisation basique (minuscules)
    final jobTitle = (job['job_title'] as String?)?.toLowerCase() ?? '';
    final jobSpecialty = (job['specialty'] as String?)?.toLowerCase() ?? '';
    final jobDescription = (job['description'] as String?)?.toLowerCase() ?? '';
    final jobTags = List<String>.from(job['tags'] ?? []).map((t) => t.toLowerCase()).toList();

    for (final skill in _userSkills) {
      double currentSectorScore = 0;
      final skillLower = skill.toLowerCase();
      
      // 1. MATCH DIRECT DE SPÉCIALITÉ (GROS POIDS)
      // Si la spécialité du job est exactement le secteur de l'utilisateur
      if (jobSpecialty == skillLower || jobSpecialty.contains(skillLower)) {
        currentSectorScore += 60;
      }
      
      // 1.5 MATCH DIRECT PAR TAG RÉEL DE LA BASE (Le plus précis pour le nouveau système)
      if (jobTags.contains(skillLower)) {
        currentSectorScore += 80;
      }

      // 2. RECHERCHE DE MOTS-CLÉS SPÉCIFIQUES AU SECTEUR
      final keywords = _getExpandedKeywords(skill);
      int keywordHitsInTitle = 0;
      int keywordHitsInTags = 0;

      for (final keyword in keywords) {
        final kw = keyword.toLowerCase();
        
        // Poids fort si présent dans le titre
        if (jobTitle.contains(kw)) {
          keywordHitsInTitle++;
        }
        
        // Poids moyen si présent dans les tags
        if (jobTags.any((tag) => tag.contains(kw))) {
          keywordHitsInTags++;
        }

        // Poids léger dans la description
        if (jobDescription.contains(kw)) {
          currentSectorScore += 2;
        }
      }

      // Calcul des points par mots-clés (plafonné pour éviter l'inflation)
      currentSectorScore += (keywordHitsInTitle > 0 ? 30 : 0);
      currentSectorScore += (keywordHitsInTags > 0 ? 10 : 0);
      
      // Bonus si plusieurs mots-clés dans le titre
      if (keywordHitsInTitle > 1) currentSectorScore += 10;

      if (currentSectorScore > maxScore) {
        maxScore = currentSectorScore;
      }
    }

    // Un job qui ne correspond à aucun mot-clé d'aucun secteur choisi
    // mais qui est dans la base doit quand même avoir un micro score ou 0
    return maxScore.clamp(0, 100).toInt();
  }

  bool _onSwipe(
    int previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
  ) {
    // BLOCAGE PHYSIQUE STRICT : Si pas premium et limite de 10 atteinte
    // On bloque TOUT mouvement (Gauche ou Droite)
    if (!_isPremium && _swipeCount >= 10) {
      _showPremiumLimitDialog();
      return false; // Bloque physiquement la carte
    }

    if (direction == CardSwiperDirection.right) {
      _handleSwipe(previousIndex, 'right');
    } else if (direction == CardSwiperDirection.left) {
      _handleSwipe(previousIndex, 'left');
    }
    return true;
  }

  void _handleSwipe(int index, String direction) async {
    final job = _jobs[index];
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 1. Enregistrer l'action dans le log global (pour le filtrage et la limite)
      await _supabase.from('swipes_log').insert({
        'user_id': userId,
        'job_id': job['id'],
        'direction': direction,
      });

      // 2. Mettre à jour le compteur local immédiatement
      setState(() {
        _swipeCount++;
      });

      // 3. Traitement spécifique si c'est un swipe DROITE (postulation)
      if (direction == 'right') {
        debugPrint('*** [DIAGNOSTIC] DÉBUT SWIPE DROITE DÉTECTÉ ***');
        
        // Enregistrer la postulation
        await _supabase.from('applications').insert({
          'user_id': userId,
          'job_id': job['id'],
          'status': 'pending',
        });

        debugPrint('*** [DIAGNOSTIC] URL CV: $_cvUrl ***');

        // 4. Ajouter l'email à la file d'attente (NON BLOQUANT)
        if (_cvUrl != null && _cvUrl!.isNotEmpty) {
          _enqueueEmail(job);
          
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Candidature enregistrée pour ${job['job_title']} — email en cours d\'envoi...'),
                backgroundColor: Colors.green,
                duration: const Duration(milliseconds: 1500),
              ),
            );
          }
        } else {
          debugPrint('*** [DIAGNOSTIC] ÉCHEC: PAS DE CV DANS LE PROFIL ***');
        }

        // Priorité des redirections sur Match (Swipe Right)
        final whatsapp = job['whatsapp_number'];
        final email = job['contact_email'];
        final appLink = job['application_link'] ?? 
            (job['raw_data'] != null ? job['raw_data']['application_link'] : null);

        // Si il y a un WhatsApp, on redirige
        if (whatsapp != null && whatsapp.toString().isNotEmpty) {
          _showWhatsAppRedirect(job['job_title'] ?? 'ce poste', whatsapp.toString());
        } 
        // Sinon, si il n'y a ni email ni WhatsApp, mais un lien, on redirige vers le lien
        else if ((email == null || email.toString().isEmpty) && 
                 appLink != null && appLink.toString().isNotEmpty) {
          _showApplicationLinkRedirect(job['job_title'] ?? 'ce poste', appLink.toString());
        } else if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_cvUrl != null 
                ? 'Profil et CV envoyés pour ${job['job_title']}'
                : 'Profil envoyé (pensez à ajouter votre CV dans le profil)'),
              backgroundColor: _cvUrl != null ? Colors.green : Colors.orange,
              duration: const Duration(milliseconds: 1500),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur lors du swipe: $e');
      if (e.toString().contains('Daily free swipe limit')) {
        _controller.undo(); // Ramène la carte à l'écran
        setState(() => _swipeCount = 10); // Resynchronise le compteur local de force
        if (mounted) _showPremiumLimitDialog();
      }
    }
  }

  /// Ajoute un job à la file d'attente d'envoi d'email
  void _enqueueEmail(Map<String, dynamic> job) {
    _emailQueue.add(job);
    debugPrint('*** [QUEUE] Email ajouté à la file. Taille: ${_emailQueue.length} ***');
    
    // Lancer le traitement de la file si pas déjà en cours
    if (!_isProcessingQueue) {
      _processEmailQueue();
    }
  }

  /// Traite la file d'attente d'envoi d'email un par un avec délai
  Future<void> _processEmailQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;
    
    while (_emailQueue.isNotEmpty) {
      final job = _emailQueue.removeAt(0);
      
      try {
        final session = _supabase.auth.currentSession;
        final token = session?.accessToken;
        
        debugPrint('*** [QUEUE] Envoi email pour: ${job['job_title']} ***');

        final response = await _supabase.functions.invoke(
          'apply-to-job',
          body: {
            'jobTitle': job['job_title'],
            'jobCompany': job['company_name'],
            'jobContactEmail': job['contact_email'],
            'cvUrl': _cvUrl,
            'userName': _fullName,
            'userSexe': _sexe,
            'message': null,
            'requiresCoverLetter': job['requires_cover_letter'] ?? false,
            'coverLetterInstructions': job['cover_letter_instructions'],
            'jobDescription': job['description'],
          },
          headers: {
            'Authorization': 'Bearer ${token ?? ''}',
          },
        );
        
        debugPrint('*** [QUEUE] RÉPONSE SERVEUR: ${response.status} - ${response.data} ***');
        
        if (response.status == 200) {
          debugPrint('*** [QUEUE] ✅ Email envoyé avec succès pour: ${job['job_title']} ***');
        } else {
          debugPrint('*** [QUEUE] ❌ Erreur serveur pour: ${job['job_title']} - ${response.data} ***');
        }
      } catch (funcErr) {
        debugPrint('*** [QUEUE] ❌ ERREUR CRITIQUE pour ${job['job_title']}: $funcErr ***');
      }
      
      // Délai entre chaque envoi pour éviter le rate-limiting de Resend
      if (_emailQueue.isNotEmpty) {
        debugPrint('*** [QUEUE] Attente 2s avant le prochain envoi... ***');
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    
    _isProcessingQueue = false;
    debugPrint('*** [QUEUE] File d\'attente vidée. Tous les emails envoyés. ***');
  }

  void _showPremiumFeatureDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        title: Row(
          children: [
            const Icon(Icons.star, color: Color(0xFFF97316)),
            SizedBox(width: 10.w),
            const Text('Fonction Premium'),
          ],
        ),
        content: Text(
          'La fonctionnalité "$feature" est réservée aux membres Premium.\n\nPassez au forfait illimité pour en profiter !',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/premium');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              elevation: 0,
            ),
            child: const Text('Passer Premium', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPremiumLimitDialog() {
    // Calculer le temps restant avant minuit
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final remaining = midnight.difference(now);
    
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        title: Row(
          children: [
            const Icon(Icons.lock_clock, color: Color(0xFFF97316)),
            SizedBox(width: 10.w),
            const Text('Limite atteinte !'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vous avez utilisé vos 10 swipes gratuits pour aujourd\'hui.',
            ),
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 18, color: Color(0xFF64748B)),
                  SizedBox(width: 8.w),
                  Text(
                    'Nouveaux swipes dans $hours\h $minutes\min',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            const Text(
              'Ou passez au illimité maintenant pour ne rater aucun Djossi !',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/premium');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              elevation: 0,
            ),
            child: const Text('Passer Premium', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showWhatsAppRedirect(String jobTitle, String phoneNumber) {
    if (!mounted) return;

    // Nettoyer le numéro (enlever espaces, +, etc pour l'URL)
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    // Ajouter le code pays CIV si manquant (8 chiffres ou 10 chiffres sans indicatif)
    final finalPhone = cleanPhone.length <= 10 ? '225$cleanPhone' : cleanPhone;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Row(
          children: [
            const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366)),
            SizedBox(width: 10.w),
            const Expanded(child: Text('Postuler via WhatsApp')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prêt à postuler ?',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            Text(
              "L'application va ouvrir WhatsApp avec le numéro du recruteur. N'oubliez pas de joindre votre CV une fois sur WhatsApp !",
              style: TextStyle(fontSize: 13.sp),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              String textMessage = "Bonjour, je suis intéressé par le poste de $jobTitle vu sur Djossi Match. Veuillez trouver mon CV ci-joint.";
              
              final message = Uri.encodeComponent(textMessage);
              final whatsappAppUrl = Uri.parse("whatsapp://send?phone=$finalPhone&text=$message");
              final webUrl = Uri.parse("https://wa.me/$finalPhone?text=$message");
              
              try {
                bool launched = await launchUrl(whatsappAppUrl, mode: LaunchMode.externalApplication);
                if (!launched) {
                  launched = await launchUrl(webUrl, mode: LaunchMode.externalApplication);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Impossible d'ouvrir WhatsApp")),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            child: const Text('Envoyer mon CV', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showApplicationLinkRedirect(String jobTitle, String urlString) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Row(
          children: [
            const Icon(Icons.open_in_new_rounded, color: Color(0xFFF97316)),
            SizedBox(width: 10.w),
            const Expanded(child: Text('Postuler en ligne')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cette offre nécessite de postuler sur un site externe.',
              style: TextStyle(fontSize: 14.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              "Voulez-vous ouvrir le lien de candidature ?",
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final url = Uri.parse(urlString);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            child: const Text('Ouvrir le lien', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFF97316)));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Djossi Match',
          style: TextStyle(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 24.sp,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFFE2E8F0), // Ligne de séparation douce
            height: 1.0,
          ),
        ),
      ),
      body: _jobs.isEmpty 
          ? _buildEmptyState()
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  child: Column(
                    children: [
                      Expanded(
                        child: CardSwiper(
                          controller: _controller,
                          cardsCount: _jobs.length,
                          onSwipe: _onSwipe,
                          numberOfCardsDisplayed: _jobs.length >= 3 ? 3 : _jobs.length,
                          backCardOffset: const Offset(0, 40),
                          duration: const Duration(milliseconds: 400),
                          padding: EdgeInsets.zero,
                          scale: 0.9,
                          maxAngle: 30,
                          threshold: 40,
                          isLoop: false,
                          onEnd: () {
                            setState(() {
                              _jobs.clear();
                            });
                          },
                          cardBuilder: (context, index, horizontalThresholdPercent, verticalThresholdPercent) {
                            final job = _jobs[index];
                            final matchScore = _calculateMatchScore(job);
                            return Stack(
                              children: [
                                DjossiSwipeCard(
                                  title: job['job_title'] ?? 'Inconnu',
                                  company: job['company_name'] ?? 'Inconnu',
                                  salary: job['salary_range'] ?? 'À négocier',
                                  location: job['location'] ?? 'Abidjan',
                                  requiredLevel: job['required_level'],
                                  experience: job['experience'],
                                  contactEmail: job['contact_email'],
                                  whatsappNumber: job['whatsapp_number'],
                                  specialty: job['specialty'],
                                  contractType: job['contract_type'],
                                  description: job['description'],
                                  isVerified: job['is_ai_verified'] ?? false,
                                  tags: List<String>.from(job['tags'] ?? []),
                                  deadline: job['deadline'],
                                  applicationLink: job['application_link'] ?? 
                                      (job['raw_data'] != null ? job['raw_data']['application_link'] : null),
                                  requiresCoverLetter: job['requires_cover_letter'] ?? false,
                                  coverLetterInstructions: job['cover_letter_instructions'],
                                ),
                                if (matchScore > 0)
                                  Positioned(
                                    top: 12.h,
                                    right: 12.w,
                                    child: _buildMatchBadge(matchScore),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 24.h),
                      _buildActionButtons(),
                      SizedBox(height: 16.h),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.done_all, size: 80, color: Colors.green),
          const SizedBox(height: 16),
          const Text(
            'Plus d\'offres pour le moment !',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Text('Revenez plus tard pour de nouveaux Djossis.'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() => _isLoading = true);
              _loadData();
            },
            child: const Text('Actualiser'),
          )
        ],
      ),
    );
  }

  Widget _buildMatchBadge(int matchScore) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: matchScore >= 50 ? const Color(0xFF22C55E) : const Color(0xFFF97316),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, color: Colors.white, size: 14.r),
          SizedBox(width: 4.w),
          Text(
            'Match ${matchScore > 100 ? 100 : matchScore}%',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUndo() async {
    if (!_isPremium) {
      _showPremiumFeatureDialog('Retour en arrière');
      return;
    }

    // Dans CardSwiper, l'undo ramène la carte précédente
    _controller.undo();
    
    setState(() {
      if (_swipeCount > 0) _swipeCount--;
    });
    
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        // Optionnel: On pourrait supprimer le log en DB
      }
    } catch (e) {
      debugPrint('Erreur undo DB: $e');
    }
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(Icons.close_rounded, Colors.red, () {
          if (!_isPremium && _swipeCount >= 10) {
            _showPremiumLimitDialog();
            return;
          }
          _controller.swipe(CardSwiperDirection.left);
        }),
        _buildActionButton(
          Icons.replay_rounded, 
          _isPremium ? const Color(0xFFF59E0B) : Colors.grey, 
          _handleUndo, 
          isMini: true,
          locked: !_isPremium,
        ),
        _buildActionButton(Icons.favorite_rounded, Colors.green, () {
          if (!_isPremium && _swipeCount >= 10) {
            _showPremiumLimitDialog();
            return;
          }
          _controller.swipe(CardSwiperDirection.right);
        }),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onPressed, {bool isMini = false, bool locked = false}) {
    final size = isMini ? 55.r : 70.r;
    final iconSize = isMini ? 24.r : 32.r;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                spreadRadius: 2.r,
                blurRadius: 10.r,
                offset: Offset(0, 4.h),
              ),
            ],
            border: _isPremium && !isMini && color == Colors.green
                ? Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5), width: 2)
                : null,
          ),
          child: IconButton(
            icon: Icon(icon, color: color, size: iconSize),
            onPressed: onPressed,
          ),
        ),
        if (locked)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(4.r),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock, color: const Color(0xFFF59E0B), size: 12.r),
            ),
          ),
      ],
    );
  }
}
