import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/cv_quota_service.dart';
import '../../../core/services/genius_pay_service.dart';
import '../../../core/services/version_service.dart';

/// A bottom sheet paywall for CV creation/modification payments.
/// Shows the reason (extra CV or modification) and allows 500 F CFA payment.
class CvPaywallSheet extends StatefulWidget {
  final PaymentReason reason;
  final VoidCallback? onPaymentSuccess;

  const CvPaywallSheet({
    Key? key,
    required this.reason,
    this.onPaymentSuccess,
  }) : super(key: key);

  /// Show the paywall bottom sheet. Returns true if payment was successful.
  /// Si la période d'essai CV est active, le paiement est bypassé automatiquement.
  static Future<bool> show(BuildContext context, PaymentReason reason) async {
    // Pendant la période d'essai : modifications gratuites, mais les quotas de
    // création (1 CV freemium / 3 CV premium) restent en vigueur.
    if (VersionService.isCvTrialRunning && reason == PaymentReason.modification) {
      return true;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CvPaywallSheet(reason: reason),
    );
    return result == true;
  }

  @override
  State<CvPaywallSheet> createState() => _CvPaywallSheetState();
}

class _CvPaywallSheetState extends State<CvPaywallSheet>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _isVerifying = false;
  String? _error;
  late AnimationController _shimmerController;

  String? _payToken;
  Timer? _verificationTimer;
  int _verificationAttempts = 0;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _verificationTimer?.cancel();
    super.dispose();
  }

  String get _title {
    switch (widget.reason) {
      case PaymentReason.extraCv:
        return 'CV supplémentaire';
      case PaymentReason.modification:
        return 'Modification de CV';
      default:
        return 'Paiement requis';
    }
  }

  String get _description {
    switch (widget.reason) {
      case PaymentReason.extraCv:
        return 'Vous avez atteint votre limite de création gratuite. '
            'Débloquez un emplacement supplémentaire pour créer un nouveau CV.';
      case PaymentReason.modification:
        return 'La modification de vos CV existants nécessite un paiement unique de 500 F CFA par modification.';
      default:
        return '';
    }
  }

  IconData get _icon {
    switch (widget.reason) {
      case PaymentReason.extraCv:
        return Icons.add_circle_outline_rounded;
      case PaymentReason.modification:
        return Icons.edit_note_rounded;
      default:
        return Icons.lock_outline_rounded;
    }
  }

  Future<void> _initiatePayment() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final profile = await supabase
          .from('profiles')
          .select('full_name, phone_number')
          .eq('id', user.id)
          .maybeSingle();

      final phone = profile?['phone_number'] ?? '';
      final name = profile?['full_name'] ?? 'Client Djorssi';

      if (phone.toString().isEmpty) {
        throw Exception(
            'Veuillez renseigner votre numéro de téléphone dans votre profil.');
      }

      final String description = widget.reason == PaymentReason.extraCv
          ? "Déblocage d'un CV supplémentaire"
          : "Modification de CV existant";
          
      final Map<String, dynamic> metadata = {
        "type": widget.reason == PaymentReason.extraCv ? "extra_cv" : "modification"
      };

      final initResult = await GeniusPayService.initiatePayment(
        amount: CvQuotaService.extraCvPrice,
        phone: phone.toString(),
        email: user.email ?? '',
        name: name.toString(),
        description: description,
        metadata: metadata,
      );

      if (!mounted) return;

      await GeniusPayService.launchCheckout(initResult.checkoutUrl);

      setState(() {
        _payToken = initResult.reference;
        _isLoading = false;
        _isVerifying = true;
      });

      // Start verifying payment status
      _startPaymentVerification();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _startPaymentVerification() {
    _verificationAttempts = 0;
    _verificationTimer?.cancel();
    _verificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _verificationAttempts++;
      if (_verificationAttempts > 20) { // Max 1 minute of polling (20 * 3s = 60s)
        timer.cancel();
        if (mounted) {
          setState(() {
            _isVerifying = false;
            _error = "La validation prend du temps. Cliquez sur 'Vérifier le paiement' manuellement.";
          });
        }
      } else {
        _verifyPayment(automatic: true);
      }
    });
  }

  Future<void> _verifyPayment({bool automatic = false}) async {
    if (_payToken == null) return;

    if (!automatic) {
      setState(() {
        _isVerifying = true;
        _error = null;
      });
    }

    try {
      final supabase = Supabase.instance.client;
      
      final response = await supabase
          .from('payments')
          .select('status')
          .eq('pay_token', _payToken!)
          .maybeSingle();

      final status = response?['status'];

      if (status == 'SUCCESS') {
        _verificationTimer?.cancel();

        if (!mounted) return;

        Navigator.pop(context, true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paiement confirmé ! Vous pouvez continuer.'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (status == 'FAILED') {
        _verificationTimer?.cancel();
        if (mounted) {
          setState(() {
            _isVerifying = false;
            _error = 'Le paiement a échoué. Veuillez réessayer.';
          });
        }
      } else {
        // Still PENDING
        if (!automatic && mounted) {
          setState(() {
            _isVerifying = false;
            _error = 'Paiement en attente. Veuillez finaliser la transaction sur le site et réessayer.';
          });
        }
      }
    } catch (e) {
      if (!automatic && mounted) {
        setState(() {
          _isVerifying = false;
          _error = 'Erreur de vérification. Réessayez.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Column(
              children: [
                // Icon with gradient background
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF97316).withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(_icon, color: Colors.white, size: 32),
                ),

                const SizedBox(height: 20),

                // Title
                Text(
                  _title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 10),

                // Description
                Text(
                  _description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 24),

                // Price card
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFF97316).withOpacity(0.08),
                        const Color(0xFFF97316).withOpacity(0.03),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFF97316).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '500',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFF97316),
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'F CFA',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFF97316),
                            ),
                          ),
                          Text(
                            'Paiement unique',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Features
                _buildFeature(
                  icon: Icons.flash_on_rounded,
                  text: widget.reason == PaymentReason.extraCv
                      ? 'Emplacement débloqué immédiatement'
                      : 'Modification illimitée pour ce CV',
                ),
                const SizedBox(height: 8),
                _buildFeature(
                  icon: Icons.verified_outlined,
                  text: 'Paiement sécurisé via Mobile Money',
                ),
                const SizedBox(height: 8),
                _buildFeature(
                  icon: Icons.star_outline_rounded,
                  text: 'Passez en Premium pour plus d\'avantages',
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            size: 18, color: Colors.red.shade400),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Payment button
                if (_isVerifying)
                  _buildVerifyingButton()
                else
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _initiatePayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            const Color(0xFFF97316).withOpacity(0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.payment_rounded, size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'Payer 500 F CFA',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                const SizedBox(height: 12),

                // Cancel button
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Annuler',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyingButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: _verifyPayment,
            icon: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFF97316),
              ),
            ),
            label: const Text('Vérifier le paiement'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFF97316),
              side: const BorderSide(color: Color(0xFFF97316)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Cliquez après avoir terminé le paiement',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildFeature({required IconData icon, required String text}) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFF97316).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFFF97316), size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }
}
