import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:djossimatch/core/services/version_service.dart';
import 'package:djossimatch/core/services/genius_pay_service.dart';
import 'package:djossimatch/core/services/cv_quota_service.dart';

/// Modèle local pour les packs de crédits
class CreditPackItem {
  final String id;
  final String name;
  final int credits;
  final int priceCfa;
  final String badge;
  final bool isRecommended;

  CreditPackItem({
    required this.id,
    required this.name,
    required this.credits,
    required this.priceCfa,
    this.badge = '',
    this.isRecommended = false,
  });

  factory CreditPackItem.fromJson(Map<String, dynamic> json) {
    return CreditPackItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Pack de Crédits',
      credits: (json['credits'] ?? 1) as int,
      priceCfa: (json['price_cfa'] ?? 500) as int,
      badge: json['badge']?.toString() ?? '',
      isRecommended: json['is_recommended'] == true,
    );
  }
}

class CvPaywallSheet extends StatefulWidget {
  final PaymentReason reason;

  const CvPaywallSheet({
    super.key,
    required this.reason,
  });

  /// Show the paywall bottom sheet. Returns true if payment was successful.
  static Future<bool> show(BuildContext context, PaymentReason reason) async {
    // Pendant la période d'essai CV : modifications gratuites
    if (VersionService.isCvTrialRunning && reason == PaymentReason.modification) {
      return true;
    }
    // Pendant la période d'essai IA : adaptations gratuites (contrôlé par le Toggle Admin)
    if (VersionService.isAiAdaptTrialRunning && reason == PaymentReason.aiAdaptation) {
      return true;
    }

    // Pour les autres motifs, si showPremium est inactif, bypasser
    if (!VersionService.showPremium && reason != PaymentReason.aiAdaptation) {
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

  // Packs de crédits pour l'adaptation IA
  List<CreditPackItem> _creditPacks = [];
  CreditPackItem? _selectedPack;
  bool _isLoadingPacks = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    if (widget.reason == PaymentReason.aiAdaptation) {
      _fetchCreditPacks();
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _verificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchCreditPacks() async {
    setState(() => _isLoadingPacks = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('credit_packs')
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true);

      if ((response as List).isNotEmpty) {
        final loaded = (response as List)
            .map((row) => CreditPackItem.fromJson(row as Map<String, dynamic>))
            .toList();

        setState(() {
          _creditPacks = loaded;
          _selectedPack = loaded.firstWhere(
            (p) => p.isRecommended,
            orElse: () => loaded.first,
          );
        });
      } else {
        _useDefaultPacks();
      }
    } catch (e) {
      debugPrint('Error fetching credit packs: $e');
      _useDefaultPacks();
    } finally {
      if (mounted) setState(() => _isLoadingPacks = false);
    }
  }

  void _useDefaultPacks() {
    final defaults = [
      CreditPackItem(
        id: 'pack_testeur',
        name: 'Pack Testeur',
        credits: 3,
        priceCfa: 500,
        badge: 'Pour postuler sur un coup de cœur',
        isRecommended: false,
      ),
      CreditPackItem(
        id: 'pack_booster',
        name: 'Pack Booster',
        credits: 10,
        priceCfa: 1500,
        badge: 'Meilleure valeur',
        isRecommended: true,
      ),
      CreditPackItem(
        id: 'pack_commando',
        name: 'Pack Commando',
        credits: 25,
        priceCfa: 3000,
        badge: 'Pour candidats très actifs',
        isRecommended: false,
      ),
    ];
    setState(() {
      _creditPacks = defaults;
      _selectedPack = defaults[1]; // Booster par défaut
    });
  }

  String get _title {
    switch (widget.reason) {
      case PaymentReason.extraCv:
        return 'CV supplémentaire';
      case PaymentReason.modification:
        return 'Modification de CV';
      case PaymentReason.aiAdaptation:
        return 'Packs de Crédits Adaptation IA';
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
        return 'La modification de vos CV existants nécessite un paiement unique de ${VersionService.extraCvPriceCfa} F CFA par modification.';
      case PaymentReason.aiAdaptation:
        return 'Rechargez des crédits pour adapter votre CV à chaque offre d\'emploi avec l\'IA.';
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
      case PaymentReason.aiAdaptation:
        return Icons.auto_awesome_rounded;
      default:
        return Icons.lock_outline_rounded;
    }
  }

  int get _amountToPay {
    if (widget.reason == PaymentReason.aiAdaptation && _selectedPack != null) {
      return _selectedPack!.priceCfa;
    }
    return VersionService.extraCvPriceCfa;
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
          : widget.reason == PaymentReason.aiAdaptation
              ? "Achat ${_selectedPack?.name ?? 'Pack Crédits Adaptation IA'}"
              : "Modification de CV existant";

      final Map<String, dynamic> metadata = {
        "type": widget.reason == PaymentReason.extraCv
            ? "extra_cv"
            : widget.reason == PaymentReason.aiAdaptation
                ? "ai_adaptation_pack"
                : "modification",
        "pack_id": _selectedPack?.id,
        "credits": _selectedPack?.credits,
      };

      final initResult = await GeniusPayService.initiatePayment(
        amount: _amountToPay.toDouble(),
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
      if (_verificationAttempts > 20) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isVerifying = false;
            _error =
                "La validation prend du temps. Cliquez sur 'Vérifier le paiement' manuellement.";
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

        // Si c'est un achat de pack de crédits IA, ajouter les crédits au profil
        if (widget.reason == PaymentReason.aiAdaptation && _selectedPack != null) {
          try {
            final user = supabase.auth.currentUser;
            if (user != null) {
              final profile = await supabase
                  .from('profiles')
                  .select('ai_adapt_extra_purchased')
                  .eq('id', user.id)
                  .maybeSingle();

              final currentExtra = (profile?['ai_adapt_extra_purchased'] ?? 0) as int;
              final newExtra = currentExtra + _selectedPack!.credits;

              await supabase
                  .from('profiles')
                  .update({'ai_adapt_extra_purchased': newExtra})
                  .eq('id', user.id);

              debugPrint(
                'CvPaywallSheet: ${_selectedPack!.credits} crédits ajoutés avec succès (Total: $newExtra)',
              );
            }
          } catch (creditErr) {
            debugPrint('CvPaywallSheet: Erreur ajout crédits: $creditErr');
          }
        }

        if (!mounted) return;

        Navigator.pop(context, true);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.reason == PaymentReason.aiAdaptation
                  ? '${_selectedPack?.credits ?? ''} crédits d\'adaptation IA ajoutés avec succès !'
                  : 'Paiement confirmé ! Vous pouvez continuer.',
            ),
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
        if (!automatic && mounted) {
          setState(() {
            _isVerifying = false;
            _error =
                'Paiement en attente. Veuillez finaliser la transaction sur le site et réessayer.';
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
    final isAiAdaptation = widget.reason == PaymentReason.aiAdaptation;

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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              children: [
                // Top Icon
                Container(
                  width: 64,
                  height: 64,
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
                  child: Icon(_icon, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 14),

                // Title
                Text(
                  _title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),

                // Description
                Text(
                  _description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),

                // AI Adaptation: Render the 3 Credit Packs selector
                if (isAiAdaptation) ...[
                  if (_isLoadingPacks)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(color: Color(0xFFF97316)),
                    )
                  else
                    Column(
                      children: _creditPacks.map((pack) {
                        final isSelected = _selectedPack?.id == pack.id;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedPack = pack),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFFFF7ED)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFF97316)
                                    : const Color(0xFFE2E8F0),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Radio<String>(
                                  value: pack.id,
                                  groupValue: _selectedPack?.id,
                                  activeColor: const Color(0xFFF97316),
                                  onChanged: (_) {
                                    setState(() => _selectedPack = pack);
                                  },
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          Text(
                                            pack.name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: isSelected
                                                  ? const Color(0xFF9A3412)
                                                  : const Color(0xFF0F172A),
                                            ),
                                          ),
                                          if (pack.badge.isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: pack.isRecommended
                                                    ? const Color(0xFFF97316)
                                                    : const Color(0xFFE2E8F0),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                pack.badge,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: pack.isRecommended
                                                      ? Colors.white
                                                      : const Color(0xFF475569),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${pack.credits} adaptations IA',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${pack.priceCfa} F CFA',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFF97316),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ] else ...[
                  // Single Item Price Card (Extra CV / Modification)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 20,
                    ),
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
                        Text(
                          VersionService.extraCvPriceCfa.toString(),
                          style: const TextStyle(
                            fontSize: 36,
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
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFF97316),
                              ),
                            ),
                            Text(
                              'Paiement unique',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
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
                ],

                if (_error != null) ...[
                  const SizedBox(height: 12),
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

                const SizedBox(height: 18),

                // Payment button
                if (_isVerifying)
                  _buildVerifyingButton()
                else
                  SizedBox(
                    width: double.infinity,
                    height: 52,
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
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.payment_rounded, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  isAiAdaptation
                                      ? 'Acheter le ${_selectedPack?.name ?? 'Pack'} (${_amountToPay} F CFA)'
                                      : 'Payer ${VersionService.extraCvPriceCfa} F CFA',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                const SizedBox(height: 8),

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
          height: 52,
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
