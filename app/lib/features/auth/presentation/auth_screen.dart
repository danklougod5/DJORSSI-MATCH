import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/error_translator.dart';
import 'widgets/support_contact_sheet.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;

  String _translateAuthError(Object error) {
    return ErrorTranslator.translate(error);
  }

  Future<void> _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs')),
      );
      return;
    }

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adresse email invalide.')),
      );
      return;
    }

    final fullName = _fullNameController.text.trim();
    if (_isSignUp && fullName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer votre nom complet')),
      );
      return;
    }

    if (_isSignUp) {
      if (password.length < 8) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le mot de passe doit contenir au moins 8 caractères.')),
        );
        return;
      }
      if (!password.contains(RegExp(r'[A-Z]'))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le mot de passe doit contenir au moins une majuscule.')),
        );
        return;
      }
      if (!password.contains(RegExp(r'[0-9]'))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le mot de passe doit contenir au moins un chiffre.')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        // Candidate Signup
        final response = await Supabase.instance.client.auth
            .signUp(
              email: email,
              password: password,
              data: {'full_name': fullName},
            )
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () => throw Exception(
                'Délai d\'attente dépassé pour l\'inscription.',
              ),
            );

        if (response.user != null) {
          final identities = response.user!.identities ?? [];
          if (identities.isEmpty) {
            setState(() => _isLoading = false);
            _showUserExistsDialog(email);
            return;
          }

          if (response.session != null) {
            await Supabase.instance.client
                .from('profiles')
                .upsert({
                  'id': response.user!.id,
                  'full_name': fullName,
                })
                .timeout(
                  const Duration(seconds: 10),
                  onTimeout: () => throw Exception(
                    'Délai d\'attente dépassé pour la création du profil.',
                  ),
                );
            if (mounted) {
              context.go('/complete-profile');
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Un code a été envoyé. Vérifiez vos spams.'),
                ),
              );
              context.push(
                '/otp',
                extra: {
                  'email': email,
                  'fullName': fullName,
                  'isRecruiter': false,
                },
              );
            }
          }
        }
      } else {
        // Candidate / User Login
        final response = await Supabase.instance.client.auth
            .signInWithPassword(email: email, password: password)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () => throw Exception(
                'Délai d\'attente dépassé pour la connexion.',
              ),
            );

        if (mounted && response.user != null) {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('full_name, skills, is_recruiter, is_blocked')
              .eq('id', response.user!.id)
              .maybeSingle()
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () => throw Exception(
                  'Délai de vérification du profil dépassé.',
                ),
              );

          if (profile != null && profile['is_blocked'] == true) {
            await Supabase.instance.client.auth.signOut();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Votre compte a été suspendu par l\'administration.',
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 8),
                  action: SnackBarAction(
                    label: 'Contacter',
                    textColor: Colors.white,
                    onPressed: () {
                      if (mounted) {
                        _showSupportContactModal(context);
                      }
                    },
                  ),
                ),
              );
              _showSupportContactModal(context);
            }
            return;
          }

          final isRecruiter = profile != null && profile['is_recruiter'] == true;
          final isProfileComplete =
              profile != null &&
              profile['full_name'] != null &&
              (profile['skills'] as List?)?.isNotEmpty == true;

          if (isRecruiter) {
            context.go('/recruiter-swipes');
          } else if (isProfileComplete) {
            context.go('/');
          } else {
            context.go('/complete-profile');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_translateAuthError(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSupportContactModal(BuildContext context) {
    SupportContactSheet.show(context, email: _emailController.text.trim());
  }

  void _showUserExistsDialog(String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Compte existant'),
        content: Text(
          'Un compte avec l\'adresse $email existe déjà. Souhaitez-vous vous connecter ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isSignUp = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
            ),
            child: const Text('Se connecter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final emailController = TextEditingController(text: _emailController.text.trim());
    bool isSending = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
              title: Text(
                'Réinitialisation du mot de passe',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Entrez l\'adresse e-mail de votre compte. Nous vous enverrons un lien sécurisé pour créer votre nouveau mot de passe.',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Adresse E-mail',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: isSending
                      ? null
                      : () async {
                          final email = emailController.text.trim();
                          if (email.isEmpty || !email.contains('@')) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Veuillez entrer une adresse e-mail valide.'),
                              ),
                            );
                            return;
                          }

                          setModalState(() => isSending = true);
                          try {
                            await Supabase.instance.client.auth.resetPasswordForEmail(
                              email,
                              redirectTo: 'com.djossimatch://reset-password',
                            );

                            if (context.mounted) {
                              Navigator.pop(dialogContext);
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20.r),
                                  ),
                                  title: const Text('E-mail envoyé 📧'),
                                  content: Text(
                                    'Un e-mail de réinitialisation a été envoyé à $email.\n\nVeuillez ouvrir cet e-mail et cliquer sur le lien pour définir votre nouveau mot de passe.',
                                    style: TextStyle(fontSize: 13.sp),
                                  ),
                                  actions: [
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(_translateAuthError(e)),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            setModalState(() => isSending = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: isSending
                      ? SizedBox(
                          width: 20.r,
                          height: 20.r,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Envoyer le lien'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 16.h),

                  // App Logo
                  Center(
                    child: Container(
                      height: 90.w,
                      width: 90.w,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(12.r),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 20.h),

                  Text(
                    'Djorssi-Match',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),

                  SizedBox(height: 6.h),

                  Text(
                    _isSignUp
                        ? 'Créez votre compte en quelques secondes'
                        : 'Trouvez votre prochaine opportunité\nen toute simplicité.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: const Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),

                  SizedBox(height: 28.h),

                  Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24.r),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (_isSignUp) ...[
                          TextField(
                            controller: _fullNameController,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Nom et Prénom',
                              labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                color: Color(0xFF94A3B8),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.r),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16.r),
                                borderSide: BorderSide(
                                  color: Theme.of(context).primaryColor,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 16.h),
                        ],
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Adresse e-mail',
                            labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(
                              Icons.email_outlined,
                              color: Color(0xFF94A3B8),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16.r),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16.r),
                              borderSide: BorderSide(
                                color: Theme.of(context).primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16.h),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _handleAuth(),
                          decoration: InputDecoration(
                            labelText: 'Mot de passe',
                            labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(
                              Icons.lock_outlined,
                              color: Color(0xFF94A3B8),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0xFF94A3B8),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16.r),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16.r),
                              borderSide: BorderSide(
                                color: Theme.of(context).primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        if (!_isSignUp) ...[
                          SizedBox(height: 10.h),
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () => _showForgotPasswordDialog(context),
                              child: Text(
                                'Mot de passe oublié ?',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: 24.h),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleAuth,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            minimumSize: Size(double.infinity, 54.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  _isSignUp ? "S'inscrire" : 'Se connecter',
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // Switch Mode
                  TextButton(
                    onPressed: () {
                      setState(() => _isSignUp = !_isSignUp);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                    ),
                    child: RichText(
                      text: TextSpan(
                        text: _isSignUp
                            ? 'Vous avez déjà un compte ? '
                            : 'Nouveau sur Djorssi-Match ? ',
                        style: TextStyle(
                          color: const Color(0xFF64748B),
                          fontSize: 14.sp,
                        ),
                        children: [
                          TextSpan(
                            text: _isSignUp ? 'Connectez-vous' : 'S\'inscrire',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 16.h),
                  const Divider(color: Color(0xFFE2E8F0), thickness: 1),
                  SizedBox(height: 12.h),

                  // Vous êtes recruteur ? Card
                  GestureDetector(
                    onTap: () => _showRecruiterOptions(context),
                    child: Container(
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10.r),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF97316).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.business_center,
                              color: Color(0xFFF97316),
                            ),
                          ),
                          SizedBox(width: 14.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Vous êtes recruteur ?',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Publiez vos offres et trouvez des talents gratuitement.',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showRecruiterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 36.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40.w,
                  height: 5.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  'Espace Recruteur',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Que souhaitez-vous faire aujourd\'hui ?',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: const Color(0xFF64748B),
                  ),
                ),
                SizedBox(height: 28.h),
                _buildRecruiterSheetOption(
                  icon: Icons.post_add_rounded,
                  title: 'Publier des offres d\'emploi',
                  description: 'Postez vos offres gratuitement et recevez des candidatures.',
                  color: const Color(0xFFF97316),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/recruiter-post');
                  },
                ),
                SizedBox(height: 16.h),
                _buildRecruiterSheetOption(
                  icon: Icons.people_alt_rounded,
                  title: 'Dénicher des talents',
                  description: 'Connectez-vous à votre espace recruteur pour voir les talents.',
                  color: const Color(0xFF1E3A8A),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/recruiter-auth');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecruiterSheetOption({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
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
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: const Color(0xFF94A3B8), size: 20.r),
          ],
        ),
      ),
    );
  }
}
