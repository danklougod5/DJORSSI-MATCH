import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/error_translator.dart';
import 'widgets/support_contact_sheet.dart';

class RecruiterAuthScreen extends StatefulWidget {
  const RecruiterAuthScreen({super.key});

  @override
  State<RecruiterAuthScreen> createState() => _RecruiterAuthScreenState();
}

class _RecruiterAuthScreenState extends State<RecruiterAuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _companyController = TextEditingController();
  final _sizeController = TextEditingController();
  String? _selectedSector;
  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;

  static const List<String> _sectors = [
    'Informatique',
    'Commerce & Management',
    'Finance & Comptabilité',
    'BTP & Industrie',
    'Logistique & Transport',
    'Santé & Social',
    'Éducation & Formation',
    'Hôtellerie & Restauration',
    'Sécurité & Gardiennage',
    'Juridique & Droit',
    'Polyvalent / Tout Secteur',
  ];

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
        const SnackBar(content: Text('Veuillez entrer le nom & prénoms du responsable')),
      );
      return;
    }

    final companyName = _companyController.text.trim();
    if (_isSignUp && companyName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer le nom de votre entreprise')),
      );
      return;
    }

    final companyIndustry = _selectedSector ?? '';
    if (_isSignUp && companyIndustry.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner votre secteur d\'activité')),
      );
      return;
    }

    final companySize = _sizeController.text.trim();

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
        // Recruiter Registration
        final response = await Supabase.instance.client.auth
            .signUp(
              email: email,
              password: password,
              data: {'full_name': fullName},
            )
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () => throw Exception(
                'Délai d\'attente dépassé pour l\'inscription. Vérifiez votre connexion.',
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
            // Already validated (confirm emails disabled in local dev)
            await Supabase.instance.client
                .from('profiles')
                .upsert({
                  'id': response.user!.id,
                  'full_name': fullName,
                  'is_recruiter': true,
                  'company_name': companyName,
                  'company_industry': companyIndustry,
                  'company_size': companySize,
                })
                .timeout(
                  const Duration(seconds: 10),
                  onTimeout: () => throw Exception(
                    'Délai d\'attente dépassé pour la création du profil.',
                  ),
                );
            if (mounted) {
              context.go('/recruiter-swipes');
            }
          } else {
            // Await Email/OTP Confirmation
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Un code a été envoyé. Vérifiez vos e-mails ou spams.'),
                ),
              );
              context.push(
                '/otp',
                extra: {
                  'email': email,
                  'fullName': fullName,
                  'isRecruiter': true,
                  'companyName': companyName,
                  'companyIndustry': companyIndustry,
                  'companySize': companySize,
                },
              );
            }
          }
        }
      } else {
        // Recruiter Login
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
              .select('full_name, is_recruiter, is_blocked')
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
                    'Votre compte entreprise a été suspendu par l\'administration.',
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

          bool isRecruiter = profile != null && profile['is_recruiter'] == true;
          if (profile == null) {
            // Si le profil n'existe pas encore en base, on le crée en tant que recruteur
            await Supabase.instance.client
                .from('profiles')
                .upsert({
                  'id': response.user!.id,
                  'is_recruiter': true,
                  'full_name': response.user!.userMetadata?['full_name'] ?? 'Recruteur',
                });
          } else if (!isRecruiter) {
            // Si le compte existe mais n'était pas recruteur, on l'active en tant que recruteur
            await Supabase.instance.client
                .from('profiles')
                .update({'is_recruiter': true})
                .eq('id', response.user!.id);
          }

          context.go('/recruiter-swipes');
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
                    'Entrez l\'adresse e-mail de votre compte entreprise. Nous vous enverrons un lien sécurisé pour créer votre nouveau mot de passe.',
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
                                  backgroundColor: Theme.of(context).colorScheme.error,
                                ),
                              );
                            }
                          } finally {
                            setModalState(() => isSending = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
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
              backgroundColor: const Color(0xFF1E3A8A),
            ),
            child: const Text('Se connecter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _companyController.dispose();
    _sizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Recruiter-specific deep blue brand color
    const Color brandBlue = Color(0xFF1E3A8A);

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

                  // Recruiter/Enterprise Logo Icon Placeholder
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
                        child: const Icon(
                          Icons.business_center_rounded,
                          color: brandBlue,
                          size: 44,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 20.h),

                  Text(
                    'Espace Recruteur',
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
                        ? 'Créez votre compte Recruteur pour dénicher des talents'
                        : 'Connectez-vous pour commencer à recruter',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: const Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),

                  SizedBox(height: 28.h),

                  // Login/Signup form container
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
                          // Nom de l'entreprise *
                          TextField(
                            controller: _companyController,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: "Nom de l'entreprise *",
                              labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                              prefixIcon: const Icon(
                                Icons.business_outlined,
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
                                borderSide: const BorderSide(
                                  color: brandBlue,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 16.h),

                          // Nom & Prénoms du responsable *
                          TextField(
                            controller: _fullNameController,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Nom & Prénoms du responsable *',
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
                                borderSide: const BorderSide(
                                  color: brandBlue,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 16.h),

                          // Secteur d'activité *
                          DropdownButtonFormField<String>(
                            value: _selectedSector,
                            items: _sectors.map((sector) {
                              return DropdownMenuItem<String>(
                                value: sector,
                                child: Text(
                                  sector,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedSector = val;
                              });
                            },
                            decoration: InputDecoration(
                              labelText: "Secteur d'activité *",
                              labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                              prefixIcon: const Icon(
                                Icons.work_outline,
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
                                borderSide: const BorderSide(
                                  color: brandBlue,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 16.h),

                          // Taille de l'entreprise (optionnel)
                          TextField(
                            controller: _sizeController,
                            textInputAction: TextInputAction.next,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Taille de l'entreprise (optionnel)",
                              labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                              prefixIcon: const Icon(
                                Icons.people_outline,
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
                                borderSide: const BorderSide(
                                  color: brandBlue,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 16.h),
                        ],

                        // Adresse e-mail *
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Adresse e-mail *',
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
                              borderSide: const BorderSide(
                                  color: brandBlue,
                                  width: 2,
                                ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16.h),

                        // Mot de passe *
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _handleAuth(),
                          decoration: InputDecoration(
                            labelText: 'Mot de passe *',
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
                              borderSide: const BorderSide(
                                color: brandBlue,
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
                              child: const Text(
                                'Mot de passe oublié ?',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: brandBlue,
                                ),
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: 24.h),

                        // Submit Button
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleAuth,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandBlue,
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
                                  _isSignUp
                                      ? 'Créer mon compte'
                                      : 'Se connecter',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // Toggle between Signup and Login
                  TextButton(
                    onPressed: () {
                      setState(() => _isSignUp = !_isSignUp);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                    ),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        text: _isSignUp
                            ? 'Vous avez déjà un compte ? '
                            : 'Nouveau recruteur ? ',
                        style: TextStyle(
                          color: const Color(0xFF64748B),
                          fontSize: 13.sp,
                        ),
                        children: [
                          TextSpan(
                            text: _isSignUp ? 'Se connecter' : 'Créer un compte',
                            style: TextStyle(
                              color: brandBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 16.h),
                  const Divider(color: Color(0xFFE2E8F0), thickness: 1),
                  SizedBox(height: 12.h),

                  // Redirect to Candidate Area
                  TextButton.icon(
                    onPressed: () {
                      context.go('/auth');
                    },
                    icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFFF97316), size: 16),
                    label: Text(
                      'Vous êtes candidat ? Espace candidat',
                      style: TextStyle(
                        color: const Color(0xFFF97316),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
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
}
