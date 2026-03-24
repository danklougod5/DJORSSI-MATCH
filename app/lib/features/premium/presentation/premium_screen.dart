import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/moyapay_service.dart';

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
  String? _phoneNumber;
  String? _email;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      _email = user.email;

      final response = await _supabase
          .from('profiles')
          .select('is_premium, full_name, phone_number, premium_until')
          .eq('id', user.id)
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
          _phoneNumber = response['phone_number'];
        });
      }
    } catch (e) {
      debugPrint('Error checking premium: $e');
    }
  }

  Future<void> _activatePremium() async {
    if (_phoneNumber == null || _phoneNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez renseigner votre numéro de téléphone dans votre profil.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // MoyaPay Webhook URL (Supabase Edge Function)
      const notifyUrl = 'https://tbhxbfunyhbrctzfpkwf.supabase.co/functions/v1/moyapay-webhook';

      final response = await MoyaPayService.initiateWavePayment(
        amount: 2000,
        phoneNumber: _phoneNumber!,
        email: _email ?? '',
        firstName: _userName?.split(' ').first ?? 'Client',
        lastName: _userName?.split(' ').length == 1 ? 'Djorssi' : _userName?.split(' ').sublist(1).join(' ') ?? 'Djorssi',
        notifyUrl: notifyUrl,
      );

      if (response != null && response.paymentUrl != null && response.payToken != null) {
        // Record payment attempt BEFORE redirect
        await _supabase.from('payments').insert({
          'user_id': userId,
          'pay_token': response.payToken,
          'amount': 2000,
          'status': 'PENDING',
        });

        final uri = Uri.parse(response.paymentUrl!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Redirection vers Wave... Revenez ici après le paiement.'),
                duration: Duration(seconds: 10),
              ),
            );
          }
        } else {
          throw Exception('Impossible d\'ouvrir le lien de paiement');
        }
      } else {
        throw Exception('Erreur lors de l\'initialisation du paiement: ${response?.message ?? "Inconnu"}');
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error activating premium: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // _showSuccessAnimation can be called once the status is SUCCESS

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
      child: Column(
        children: [
          ElevatedButton(
            onPressed: _isPremium || _isLoading ? null : _activatePremium,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isPremium ? const Color(0xFF22C55E) : Colors.white,
              foregroundColor: const Color(0xFF0F172A),
              minimumSize: const Size(double.infinity, 64),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
              elevation: 0,
            ),
            child: Text(
              _isPremium ? 'DÉSONRMAIS PREMIUM ✓' : (_isLoading ? 'TRAITEMENT...' : 'ACTIVER MAINTENANT'),
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: _isPremium ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          if (!_isPremium && !_isLoading) ...[
            SizedBox(height: 16.h),
            TextButton(
              onPressed: _checkPremiumStatus,
              child: Text(
                'VÉRIFIER MON STATUT',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
