import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:djossimatch/features/swipe/presentation/djossi_swipe_card.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 1. Récupérer les infos du profil (is_premium et skills)
      final profileResponse = await _supabase
          .from('profiles')
          .select('skills, is_premium, full_name, cv_url')
          .eq('id', userId)
          .maybeSingle();

      if (profileResponse != null) {
        _isPremium = profileResponse['is_premium'] ?? false;
        _cvUrl = profileResponse['cv_url'];
        _fullName = profileResponse['full_name'];
      }

      if (profileResponse != null && profileResponse['skills'] != null) {
        _userSkills = List<String>.from(profileResponse['skills']);
      }

      // 2. Récupérer les IDs des jobs déjà postulés
      final appliedResponse = await _supabase
          .from('applications')
          .select('job_id')
          .eq('user_id', userId);
      
      final appliedJobIds = (appliedResponse as List).map((a) => a['job_id'].toString()).toSet();

      // 2.5 Compter swipes du jour (GAUCHE + DROITE)
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final countResp = await _supabase
          .from('swipes_log')
          .select('id')
          .eq('user_id', userId)
          .gte('created_at', '${today}T00:00:00Z');
      
      _swipeCount = countResp != null ? (countResp as List).length : 0;

      // 3. Récupérer toutes les offres non postulées
      final jobsResponse = await _supabase
          .from('jobs')
          .select()
          .order('created_at', ascending: false);

      final allJobs = List<Map<String, dynamic>>.from(jobsResponse)
          .where((job) => !appliedJobIds.contains(job['id'].toString()))
          .toList();

      // 4. Trier par matching
      if (_userSkills.isNotEmpty) {
        allJobs.sort((a, b) {
          final scoreA = _calculateMatchScore(a);
          final scoreB = _calculateMatchScore(b);
          return scoreB.compareTo(scoreA);
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

    double score = 0;
    final jobTags = List<String>.from(job['tags'] ?? []).map((t) => t.toLowerCase()).toList();
    final jobSpecialty = (job['specialty'] as String?)?.toLowerCase() ?? '';
    final jobTitle = (job['job_title'] as String?)?.toLowerCase() ?? '';
    final jobDescription = (job['description'] as String?)?.toLowerCase() ?? '';

    for (final skill in _userSkills) {
      final keywords = _getExpandedKeywords(skill);
      int skillHits = 0;

      for (final keyword in keywords) {
        if (jobTitle.contains(keyword)) {
          score += 35;
          skillHits++;
        }
        if (jobSpecialty.contains(keyword)) {
          score += 30;
          skillHits++;
        }
        if (jobTags.any((t) => t.contains(keyword))) {
          score += 25;
          skillHits++;
        }
        if (jobDescription.contains(keyword) && skillHits < 4) {
          score += 8;
          skillHits++;
        }
      }
    }

    return (score / _userSkills.length).clamp(0, 100).toInt();
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

      // 1. Enregistrer l'action dans le log global (pour la limite)
      await _supabase.from('swipes_log').insert({
        'user_id': userId,
        'direction': direction,
      });

      // 2. Mettre à jour le compteur local immédiatement
      setState(() {
        _swipeCount++;
      });

      // 3. Traitement spécifique si c'est un swipe DROITE (postulation)
      if (direction == 'right') {
        // Enregistrer la postulation
        await _supabase.from('applications').insert({
          'user_id': userId,
          'job_id': job['id'],
          'status': 'pending',
        });

        // 4. Appel de la fonction Edge pour envoyer l'email avec le CV
        if (_cvUrl != null && _cvUrl!.isNotEmpty) {
          try {
            await _supabase.functions.invoke(
              'apply-to-job',
              body: {
                'jobTitle': job['job_title'],
                'jobCompany': job['company_name'],
                'cvUrl': _cvUrl,
                'userName': _fullName,
                // On pourrait ajouter le message premium ici si c'était implémenté dans l'UI
                'message': null, 
              },
            );
          } catch (funcErr) {
            debugPrint('Erreur appel Edge Function: $funcErr');
          }
        }

        // WhatsApp redirect si nécessaire
        final whatsapp = job['whatsapp_number'];
        if (whatsapp != null && whatsapp.toString().isNotEmpty) {
          _showWhatsAppRedirect(job['job_title'] ?? 'ce poste', whatsapp.toString());
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_cvUrl != null 
                ? 'Profil & CV envoyés pour ${job['job_title']} ! 🚀'
                : 'Profil envoyé (pensez à ajouter votre CV dans le profil) ! 🚀'),
              backgroundColor: _cvUrl != null ? Colors.green : Colors.orange,
              duration: const Duration(milliseconds: 2000),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur lors du swipe: $e');
    }
  }

  void _showPremiumLimitDialog() {
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
        content: const Text(
          'Vous avez utilisé vos 10 swipes gratuits pour aujourd\'hui. Revenez demain ou passez au illimité maintenant !',
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            child: const Text('Passer Premium', style: TextStyle(color: Colors.white)),
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
            const Icon(Icons.message, color: Color(0xFF25D366)),
            SizedBox(width: 10.w),
            const Text('Postuler via WhatsApp'),
          ],
        ),
        content: Text(
          'Ce poste accepte les candidatures via WhatsApp. Voulez-vous envoyer votre profil maintenant ?',
          style: TextStyle(fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final message = Uri.encodeComponent(
                "Bonjour, je suis intéressé par le poste de $jobTitle vu sur Djossi Match. Voici mon profil."
              );
              final url = Uri.parse("https://wa.me/$finalPhone?text=$message");
              
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Impossible de lancer WhatsApp')),
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
                          numberOfCardsDisplayed: 3,
                          backCardOffset: const Offset(0, 40),
                          padding: EdgeInsets.zero,
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

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(Icons.close, Colors.red, () {
          if (!_isPremium && _swipeCount >= 10) {
            _showPremiumLimitDialog();
            return;
          }
          _controller.swipe(CardSwiperDirection.left);
        }),
        _buildActionButton(Icons.replay, Colors.orange, () => _controller.undo(), isMini: true),
        _buildActionButton(Icons.favorite, Colors.green, () {
          if (!_isPremium && _swipeCount >= 10) {
            _showPremiumLimitDialog();
            return;
          }
          _controller.swipe(CardSwiperDirection.right);
        }),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onPressed, {bool isMini = false}) {
    final size = isMini ? 55.r : 70.r;
    final iconSize = isMini ? 24.r : 32.r;
    return Container(
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
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: iconSize),
        onPressed: onPressed,
      ),
    );
  }
}
