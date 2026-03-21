import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final _supabase = Supabase.instance.client;
  bool _isPremium = false;
  bool _isLoading = false;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('profiles')
          .select('is_premium, full_name')
          .eq('id', userId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          final isPremium = response['is_premium'] ?? false;
          final premiumUntilRaw = response['premium_until'];
          if (isPremium && premiumUntilRaw != null) {
            final premiumUntil = DateTime.parse(premiumUntilRaw);
            _isPremium = premiumUntil.isAfter(DateTime.now());
          } else {
            _isPremium = isPremium;
          }
          _userName = response['full_name'];
        });
      }
    } catch (e) {
      debugPrint('Error checking premium: $e');
    }
  }

  Future<void> _activatePremium() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Simulate payment process or just update DB for MVP
      // Activate for 30 days
      final expiryDate = DateTime.now().add(const Duration(days: 30));
      await _supabase.from('profiles').update({
        'is_premium': true,
        'premium_until': expiryDate.toIso8601String(),
      }).eq('id', userId);

      await Future.delayed(const Duration(seconds: 2)); // Logic simulation

      if (mounted) {
        setState(() {
          _isPremium = true;
          _isLoading = false;
        });
        
        _showSuccessAnimation();
      }
    } catch (e) {
      debugPrint('Error activating premium: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessAnimation() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.8),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.elasticOut),
          child: Center(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 24.w),
              padding: EdgeInsets.all(32.r),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(20.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.workspace_premium_rounded, color: const Color(0xFFF59E0B), size: 100.r),
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      _userName != null && _userName!.trim().isNotEmpty 
                          ? 'FÉLICITATIONS\n${_userName!.toUpperCase()} !'
                          : 'FÉLICITATIONS !',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'Vous êtes désormais membre PREMIUM.\nPréparez-vous à matcher avec les meilleures offres !',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 32.h),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.pop(context); // Go back to profile
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: const Color(0xFF0F172A),
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        elevation: 0,
                      ),
                      child: Text(
                        'EXPLORER MES AVANTAGES',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                _buildAppBar(),
                const SizedBox(height: 20),
                _buildHeroSection(),
                const SizedBox(height: 40),
                _buildFeatureCard(
                  icon: Icons.all_inclusive_rounded,
                  title: 'SWIPES ILLIMITÉS',
                  description: 'Ne soyez plus jamais bloqué. Swiper autant de Djossis que vous voulez par jour.',
                  color: const Color(0xFFF97316),
                ),
                const SizedBox(height: 16),
                _buildFeatureCard(
                  icon: Icons.history_rounded,
                  title: 'HISTORIQUE DÉVERROUILLÉ',
                  description: 'Ne soyez plus limité à vos 3 derniers matches. Consultez l\'intégralité de vos candidatures.',
                  color: const Color(0xFFF59E0B),
                ),
                const SizedBox(height: 16),
                _buildFeatureCard(
                  icon: Icons.verified_rounded,
                  title: 'BADGE "CANDIDAT CERTIFIÉ"',
                  description: 'Un signal de confiance unique pour rassurer les employeurs sur votre sérieux.',
                  color: const Color(0xFFF97316),
                ),
                const SizedBox(height: 16),
                _buildFeatureCard(
                  icon: Icons.undo_rounded,
                  title: 'RETOUR EN ARRIÈRE',
                  description: 'Vous avez swipé trop vite ? Annulez votre dernier geste instantanément.',
                  color: const Color(0xFFFB923C),
                ),
                const SizedBox(height: 16),
                _buildFeatureCard(
                  icon: Icons.notifications_active_rounded,
                  title: 'ALERTES EMPLOIS PAR EMAIL',
                  description: 'Soyez le premier informé ! Recevez un email dès qu\'un job correspondant est publié.',
                  color: const Color(0xFFF97316),
                ),
                const SizedBox(height: 40),
                _buildPriceCard(),
                const SizedBox(height: 40),
                _buildBottomAction(),
                const SizedBox(height: 40),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator(color: Color(0xFFF97316))),
            ),
        ],
      ),
    );
  }

  Widget _buildBlurCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
          Text(
            'DJOSSI PREMIUM',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16.sp,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 48), // Spacer
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: const Color(0xFFF97316).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.stars_rounded, color: const Color(0xFFF97316), size: 64.r),
        ),
        SizedBox(height: 24.h),
        Text(
          'Passez à la vitesse supérieure',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          'Multipliez par 10 vos chances de trouver\nle job de vos rêves à Abidjan.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15.sp,
            color: Colors.white70,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(icon, color: color, size: 24.r),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 13.sp,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32.r),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF97316), Color(0xFFEA580C)],
        ),
        borderRadius: BorderRadius.circular(32.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF97316).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'FORFAIT ILLIMITÉ',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w900,
              fontSize: 12.sp,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '2.000',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                'CFA / MOIS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            'Abonnement de 30 jours renouvelable.\nMoins cher qu\'un ticket de bus par jour.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13.sp,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: EdgeInsets.all(24.r),
      child: ElevatedButton(
        onPressed: _isPremium || _isLoading ? null : _activatePremium,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isPremium ? const Color(0xFF22C55E) : Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          minimumSize: const Size(double.infinity, 64),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          elevation: 0,
        ),
        child: Text(
          _isPremium ? 'DÉSONRMAIS PREMIUM ✓' : 'ACTIVER MAINTENANT',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color: _isPremium ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }
}
