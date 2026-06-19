import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:djossimatch/core/services/profile_notifier.dart';
import 'package:djossimatch/core/services/cv_quota_service.dart';
import 'package:djossimatch/core/services/version_service.dart';
import 'package:printing/printing.dart';
import '../models/cv_model.dart';
import '../services/cv_storage_service.dart';
import '../utils/cv_pdf_generator.dart';
import '../widgets/cv_paywall_sheet.dart';

class CvListScreen extends StatefulWidget {
  const CvListScreen({Key? key}) : super(key: key);

  @override
  State<CvListScreen> createState() => _CvListScreenState();
}

class _CvListScreenState extends State<CvListScreen> {
  List<CvModel> _cvs = [];
  bool _isLoading = true;
  String? _error;
  bool _isUploading = false;
  CvQuotaInfo? _quotaInfo;
  StreamSubscription<List<Map<String, dynamic>>>? _profileSubscription;

  @override
  void initState() {
    super.initState();
    _loadCvs();
    _loadQuotaInfo();
    _setupRealtime();
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtime() {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    _profileSubscription = supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen((data) {
          if (data.isNotEmpty && mounted) {
            final profile = data.first;
            final isPremiumVal = profile['is_premium'] ?? false;
            final premiumUntilRaw = profile['premium_until'];
            final extraPurchased = (profile['extra_cvs_purchased'] ?? 0) as int;
            final showPremiumOverride = profile['show_premium'];

            bool activePremium = isPremiumVal;
            if (isPremiumVal && premiumUntilRaw != null) {
              final premiumUntil = DateTime.parse(premiumUntilRaw);
              activePremium = premiumUntil.isAfter(DateTime.now());
            }

            if (showPremiumOverride == false || !VersionService.showPremium) {
              activePremium = true;
            }

            _updateQuotaWithDetails(activePremium, extraPurchased);
          }
        }, onError: (e) {
          debugPrint('CvListScreen: profiles realtime error: $e');
        });
  }

  Future<void> _updateQuotaWithDetails(bool isPremium, int extraPurchased) async {
    try {
      final info = await CvQuotaService.getQuotaInfo(
        isPremiumUser: isPremium,
        extraPurchased: extraPurchased,
      );
      if (mounted) {
        setState(() => _quotaInfo = info);
      }
    } catch (e) {
      debugPrint('Error updating quota details: $e');
    }
  }

  Future<void> _loadQuotaInfo() async {
    try {
      final info = await CvQuotaService.getQuotaInfo();
      if (mounted) setState(() => _quotaInfo = info);
    } catch (e) {
      debugPrint('Error loading quota info: $e');
    }
  }

  Future<void> _loadCvs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final cvs = await CvStorageService.loadUserCvs();
      if (!mounted) return;
      setState(() {
        _cvs = cvs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _deleteCv(CvModel cv) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce CV ?'),
        content: Text('Le CV "${cv.displayTitle}" sera supprimé définitivement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true && cv.id != null) {
      await CvStorageService.deleteCv(cv.id!);
      _loadCvs();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CV supprimé'), duration: Duration(seconds: 2)),
      );
    }
  }

  Future<void> _duplicateCv(CvModel cv) async {
    final quotaResult = await CvQuotaService.canCreateCv();
    if (!quotaResult.allowed) {
      if (!mounted) return;
      final paid = await CvPaywallSheet.show(context, PaymentReason.extraCv);
      if (!paid) return;
    }

    try {
      await CvStorageService.duplicateCv(cv);
      _loadCvs();
      _loadQuotaInfo();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CV dupliqué !'), duration: Duration(seconds: 2)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _renameCv(CvModel cv) async {
    final textController = TextEditingController(text: cv.displayTitle);
    final formKey = GlobalKey<FormState>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renommer le CV'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nom du CV',
              hintText: 'Entrez le nouveau nom...',
              isDense: true,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Le nom ne peut pas être vide';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Renommer', style: TextStyle(color: Color(0xFFF97316))),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final newTitle = textController.text.trim();
      if (newTitle == cv.displayTitle) return;

      try {
        final updated = cv.copyWith(title: newTitle);
        await CvStorageService.saveCv(updated);
        _loadCvs();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CV renommé !'), duration: Duration(seconds: 2)),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _downloadCv(CvModel cv) async {
    try {
      final pdfBytes = await CvPdfGenerator.generateCvPdf(cv);
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'CV_${cv.personalInfo.fullName.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du téléchargement : $e')),
        );
      }
    }
  }

  Future<void> _setAsProfileCv(CvModel cv) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Définir comme CV du profil ?'),
        content: const Text(
          'Ce CV généré va remplacer le CV actuel de votre profil. '
          'Les recruteurs verront ce nouveau CV lorsque vous postulerez aux offres.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFF97316)),
            child: const Text('Remplacer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Utilisateur non connecté')),
      );
      return;
    }

    setState(() => _isUploading = true);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: Color(0xFFF97316)),
            SizedBox(width: 16),
            Expanded(child: Text("Mise à jour du CV de votre profil...")),
          ],
        ),
      ),
    );

    try {
      final pdfBytes = await CvPdfGenerator.generateCvPdf(cv);
      final fileName = '${user.id}_cv.pdf';
      final filePath = 'cvs/$fileName';

      await supabase.storage
          .from('cv_files')
          .uploadBinary(
            filePath,
            pdfBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final String publicUrl = supabase.storage
          .from('cv_files')
          .getPublicUrl(filePath);

      await supabase
          .from('profiles')
          .update({'cv_url': publicUrl})
          .eq('id', user.id);

      ProfileNotifier.notifyProfileUpdated();

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Votre profil a été mis à jour avec ce CV !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise à jour : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  String _getTemplateLabel(String id) {
    switch (id) {
      case 'classic': return 'Classique';
      case 'modern': return 'Moderne';
      case 'minimalist': return 'Minimaliste';
      case 'elegant': return 'Élégant';
      case 'executive': return 'Exécutif';
      case 'left_right': return 'Gauche-Droite';
      case 'timeline': return 'Chronologique';
      case 'creative': return 'Créatif';
      default: return id;
    }
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF1E3A8A);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Mes CV'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _cvs.isEmpty
                  ? _buildEmptyView()
                  : _buildCvList(),
      floatingActionButton: (_isLoading || _cvs.isEmpty)
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _handleCreateCv(),
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: Text(
                _quotaInfo != null && _quotaInfo!.remaining > 0 && VersionService.showPremium
                    ? 'Nouveau CV (${_quotaInfo!.remaining} restant${_quotaInfo!.remaining > 1 ? "s" : ""})'
                    : 'Nouveau CV',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
    );
  }

  Future<void> _handleCreateCv() async {
    final result = await CvQuotaService.canCreateCv();
    if (result.allowed) {
      if (!mounted) return;
      await context.push('/cv_landing');
      if (mounted) {
        _loadCvs();
        _loadQuotaInfo();
      }
    } else {
      if (!mounted) return;
      final paid = await CvPaywallSheet.show(context, PaymentReason.extraCv);
      if (paid && mounted) {
        _loadQuotaInfo();
        await context.push('/cv_landing');
        if (mounted) {
          _loadCvs();
          _loadQuotaInfo();
        }
      }
    }
  }

  Future<void> _handleEditCv(CvModel cv) async {
    final result = await CvQuotaService.canModifyCv();
    if (result.allowed) {
      if (!mounted) return;
      await context.push('/cv_builder', extra: cv);
      if (mounted) _loadCvs();
    } else {
      if (!mounted) return;
      final paid = await CvPaywallSheet.show(context, PaymentReason.modification);
      if (paid && mounted) {
        await context.push('/cv_builder', extra: cv);
        if (mounted) _loadCvs();
      }
    }
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Impossible de charger vos CV',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _loadCvs,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.description_outlined, size: 36, color: Color(0xFFF97316)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Aucun CV pour le moment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Créez votre premier CV professionnel\nen quelques minutes.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.5),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => _handleCreateCv(),
              icon: const Icon(Icons.add),
              label: const Text('Créer mon premier CV'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateThumbnail(String id, Color primary, Color secondary) {
    final lineGrey = Colors.grey.shade300;
    final accent = primary;

    Widget line([double width = 40, Color? col]) => Container(
          margin: const EdgeInsets.only(bottom: 3),
          height: 3,
          width: width,
          decoration: BoxDecoration(
            color: col ?? lineGrey,
            borderRadius: BorderRadius.circular(1.5),
          ),
        );

    switch (id) {
      case 'classic':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: line(30, accent)),
            const SizedBox(height: 2),
            Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [line(15), const SizedBox(width: 2), line(15)])),
            const Divider(height: 6, thickness: 0.5),
            line(25, accent),
            Row(children: [line(12), const Spacer(), line(15, secondary)]),
            line(50),
            line(45),
            const SizedBox(height: 4),
            line(25, accent),
            Row(children: [line(15), const Spacer(), line(10, secondary)]),
            line(50),
          ],
        );
      case 'modern':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 14,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Container(width: 20, height: 3, color: Colors.white),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  line(30, secondary),
                  const SizedBox(height: 2),
                  line(50),
                  line(45),
                  const SizedBox(height: 4),
                  line(25, accent),
                  line(50),
                ],
              ),
            ),
          ],
        );
      case 'minimalist':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 4),
            line(35, accent),
            line(20, secondary),
            const SizedBox(height: 6),
            line(40),
            line(35),
            const SizedBox(height: 6),
            line(25, accent),
            line(45),
          ],
        );
      case 'left_right':
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column
            Container(
              width: 22,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), bottomLeft: Radius.circular(4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: accent.withValues(alpha: 0.3), shape: BoxShape.circle)),
                  const SizedBox(height: 4),
                  line(12, accent),
                  line(14),
                  line(14),
                  const SizedBox(height: 6),
                  line(12, accent),
                  line(14),
                ],
              ),
            ),
            const VerticalDivider(width: 2, thickness: 0.5),
            // Right column
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    line(30, accent),
                    line(50),
                    line(45),
                    const SizedBox(height: 6),
                    line(25, accent),
                    line(48),
                  ],
                ),
              ),
            ),
          ],
        );
      case 'timeline':
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  Container(width: 4, height: 4, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                  Container(width: 1, height: 12, color: accent),
                  Container(width: 4, height: 4, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                  Container(width: 1, height: 12, color: accent),
                  Container(width: 4, height: 4, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    line(20, accent),
                    line(40),
                    const SizedBox(height: 4),
                    line(25, accent),
                    line(42),
                    const SizedBox(height: 4),
                    line(15, accent),
                    line(30),
                  ],
                ),
              ),
            ),
          ],
        );
      case 'creative':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [accent, secondary]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  line(35, accent),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    color: accent.withValues(alpha: 0.1),
                    child: line(20, accent),
                  ),
                  const SizedBox(height: 2),
                  line(50),
                  line(45),
                ],
              ),
            ),
          ],
        );
      case 'elegant':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                border: Border.symmetric(horizontal: BorderSide(color: accent, width: 0.5)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Center(child: line(30, accent)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: line(25, secondary)),
                  const SizedBox(height: 4),
                  line(20, accent),
                  line(50),
                  line(45),
                ],
              ),
            ),
          ],
        );
      case 'executive':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      line(25, accent),
                      const SizedBox(height: 2),
                      line(15, secondary),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    line(12),
                    line(12),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(width: 2, height: 6, color: accent),
                const SizedBox(width: 4),
                line(20, accent),
              ],
            ),
            const Divider(height: 4, thickness: 0.5),
            Row(
              children: [
                Expanded(child: line(30)),
                const SizedBox(width: 8),
                line(12),
              ],
            ),
            line(45),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(width: 2, height: 6, color: accent),
                const SizedBox(width: 4),
                line(20, accent),
              ],
            ),
            const Divider(height: 4, thickness: 0.5),
            Row(
              children: [
                Expanded(child: line(30)),
                const SizedBox(width: 8),
                line(12),
              ],
            ),
          ],
        );
      default:
        return Container();
    }
  }

  Widget _buildQuotaBanner() {
    if (!VersionService.showPremium) return const SizedBox.shrink();
    if (_quotaInfo == null) return const SizedBox.shrink();
    final info = _quotaInfo!;
    final remaining = info.remaining;
    final isAtLimit = remaining <= 0;
    final int overLimit = isAtLimit ? (info.cvCount - info.totalAllowed) : 0;
    final int includedSlots = info.maxFreeCvs;
    final int purchasedSlots = info.extraPurchased;

    // Calculate progress ratio (0.0 to 1.0)
    final double progress = info.totalAllowed > 0 
        ? (info.cvCount / info.totalAllowed).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAtLimit ? Colors.red.shade200 : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      (info.isPremium && VersionService.showPremium) ? Icons.stars_rounded : Icons.account_circle_rounded,
                      color: (info.isPremium && VersionService.showPremium) ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        VersionService.showPremium ? 'Forfait ${info.tierLabel}' : 'Mon Compte',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isAtLimit 
                      ? Colors.red.shade50 
                      : const Color(0xFFF97316).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${info.cvCount} CV créé${info.cvCount > 1 ? "s" : ""}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isAtLimit ? Colors.red.shade600 : const Color(0xFFF97316),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(
                isAtLimit ? Colors.red.shade500 : const Color(0xFFF97316),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Colored dots legend
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _buildLegendItem(
                color: const Color(0xFFF97316),
                label: '$includedSlots inclus',
              ),
              if (purchasedSlots > 0)
                _buildLegendItem(
                  color: const Color(0xFF3B82F6),
                  label: '$purchasedSlots acheté${purchasedSlots > 1 ? "s" : ""}',
                ),
              if (overLimit > 0)
                _buildLegendItem(
                  color: Colors.red.shade500,
                  label: '$overLimit en excès',
                ),
              if (remaining > 0)
                _buildLegendItem(
                  color: Colors.grey.shade300,
                  label: '$remaining disponible${remaining > 1 ? "s" : ""}',
                  isBorder: true,
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Status + Premium
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isAtLimit
                      ? 'Limite atteinte · ${VersionService.extraCvPriceCfa} F par CV supplémentaire'
                      : '$remaining emplacement${remaining > 1 ? "s" : ""} disponible${remaining > 1 ? "s" : ""}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isAtLimit ? Colors.red.shade500 : Colors.grey.shade500,
                    fontWeight: isAtLimit ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (!info.isPremium && VersionService.showPremium)
                GestureDetector(
                  onTap: () => context.push('/premium').then((_) {
                    if (mounted) {
                      _loadQuotaInfo();
                      _loadCvs();
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_upward_rounded,
                          size: 12,
                          color: Color(0xFFF97316),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Passer Premium',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF97316),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({required Color color, required String label, bool isBorder = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: isBorder ? Colors.white : color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color, width: 1.5),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }


  Widget _buildCvList() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadCvs();
        await _loadQuotaInfo();
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildQuotaBanner()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.70,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildCvCard(_cvs[index]),
                childCount: _cvs.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCvCard(CvModel cv) {
    final primaryColor = _parseColor(cv.primaryColor);
    final secondaryColor = _parseColor(cv.secondaryColor);

    return GestureDetector(
      onTap: () => _handleEditCv(cv),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail Representation
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _buildTemplateThumbnail(cv.templateId, primaryColor, secondaryColor),
                    ),
                    // Preview overlay button at top-right
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.visibility, size: 16),
                          color: primaryColor,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          tooltip: 'Voir l\'aperçu PDF',
                          onPressed: () async {
                            final result = await context.push<CvModel>('/cv_preview', extra: cv);
                            if (result != null && mounted) {
                              await CvStorageService.saveCv(result);
                              _loadCvs();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Title and Desc with Action Menu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cv.displayTitle,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getTemplateLabel(cv.templateId),
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey.shade400, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onSelected: (action) {
                      if (_isUploading) return;
                      switch (action) {
                        case 'edit':
                          _handleEditCv(cv);
                          break;
                        case 'rename':
                          _renameCv(cv);
                          break;
                        case 'preview':
                          context.push<CvModel>('/cv_preview', extra: cv).then((result) async {
                            if (result != null && mounted) {
                              await CvStorageService.saveCv(result);
                              _loadCvs();
                            }
                          });
                          break;
                        case 'duplicate':
                          _duplicateCv(cv);
                          break;
                        case 'download':
                          _downloadCv(cv);
                          break;
                        case 'set_profile':
                          _setAsProfileCv(cv);
                          break;
                        case 'delete':
                          _deleteCv(cv);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 16, color: Color(0xFF475569)),
                            SizedBox(width: 8),
                            Text('Modifier', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.drive_file_rename_outline, size: 16, color: Color(0xFF475569)),
                            SizedBox(width: 8),
                            Text('Renommer', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'preview',
                        child: Row(
                          children: [
                            Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF475569)),
                            SizedBox(width: 8),
                            Text('Aperçu PDF', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Row(
                          children: [
                            Icon(Icons.copy_outlined, size: 16, color: Color(0xFF475569)),
                            SizedBox(width: 8),
                            Text('Dupliquer', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'download',
                        child: Row(
                          children: [
                            Icon(Icons.download_rounded, size: 16, color: Color(0xFF475569)),
                            SizedBox(width: 8),
                            Text('Télécharger PDF', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'set_profile',
                        child: Row(
                          children: [
                            Icon(Icons.cloud_upload_outlined, size: 16, color: Color(0xFF475569)),
                            SizedBox(width: 8),
                            Text('Utiliser sur le profil', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Supprimer', style: TextStyle(color: Colors.red, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Action button at the bottom
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8, top: 4),
              child: Container(
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Modifier',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
