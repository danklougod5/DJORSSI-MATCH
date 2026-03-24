import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

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

  String _translateAuthError(String message) {
    final msg = message.toLowerCase();
    
    // Auth specific errors
    if (msg.contains('invalid login credentials')) return 'Email ou mot de passe incorrect.';
    if (msg.contains('user already registered') || 
        msg.contains('already registered') || 
        msg.contains('email already exists') ||
        msg.contains('compte existe déjà')) {
      return 'Cet utilisateur est déjà inscrit.';
    }
    if (msg.contains('password should be at least 6 characters')) {
      return 'Le mot de passe doit contenir au moins 6 caractères.';
    }
    if (msg.contains('rate limit')) return 'Trop de tentatives, veuillez réessayer plus tard.';
    if (msg.contains('email not confirmed')) return 'Veuillez confirmer votre adresse email.';
    if (msg.contains('invalid email')) return 'Adresse email invalide.';
    if (msg.contains('invalid or expired')) return 'Lien ou code invalide/expiré.';
    if (msg.contains('signup is disabled')) return 'Les inscriptions sont temporairement désactivées.';
    if (msg.contains('email provider is disabled')) return 'Le service d\'envoi d\'emails est désactivé.';
    if (msg.contains('email sending failed')) return 'L\'envoi de l\'email a échoué. Veuillez contacter le support.';
    if (msg.contains('network error') || msg.contains('failed host lookup')) {
      return 'Erreur réseau. Vérifiez votre connexion internet.';
    }
    
    // Log the raw error for better debugging in console
    debugPrint('Unexpected Auth Error: $message');
    
    // If we don't know the error, we return a more informative message than a generic one
    return 'Erreur d\'authentification : $message';
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

    final fullName = _fullNameController.text.trim();
    if (_isSignUp && fullName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer votre nom complet')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      if (_isSignUp) {
        // Inscription
        final response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': fullName},
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception('Délai d\'attente dépassé pour l\'inscription. Vérifiez votre connexion internet.'),
        );

        if (response.user != null) {
          // Détection d'un compte déjà existant (identities vide)
          // Cela arrive souvent quand la protection contre l'énumération est activée
          final identities = response.user!.identities ?? [];
          if (identities.isEmpty) {
            setState(() => _isLoading = false);
            _showUserExistsDialog(email);
            return;
          }

          if (response.session != null) {
            // Déjà vérifié (ex: désactivation de la confirmation d'email en dev)
            await Supabase.instance.client.from('profiles').upsert({
              'id': response.user!.id,
              'full_name': fullName,
            }).timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw Exception('Délai d\'attente dépassé pour la création du profil.'),
            );
            if (mounted) {
              context.go('/complete-profile');
            }
          } else {
            // Attente de confirmation email
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Un code de confirmation a été envoyé à votre email.')),
              );
              context.push('/otp', extra: {'email': email, 'fullName': fullName});
            }
          }
        }
      } else {
        // Connexion classique
        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception('Délai d\'attente dépassé pour la connexion. Vérifiez votre internet.'),
        );
        
        if (mounted && response.user != null) {
          // Vérifier si le profil est déjà complété
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('full_name, skills')
              .eq('id', response.user!.id)
              .maybeSingle()
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () => throw Exception('Délai de vérification du profil dépassé.'),
              );
          
          final isProfileComplete = profile != null && 
                                   profile['full_name'] != null && 
                                   (profile['skills'] as List?)?.isNotEmpty == true;

          if (isProfileComplete) {
            context.go('/');
          } else {
            context.go('/complete-profile');
          }
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        final lowerMsg = e.message.toLowerCase();
        
        if (lowerMsg.contains('email not confirmed')) {
          context.push('/otp', extra: {'email': email});
          return;
        }

        // Détection utilisateur existant lors de l'inscription
        // Correction : Supabase renvoie les erreurs en anglais (GoTrue)
        if (_isSignUp && (lowerMsg.contains('user already registered') || 
                          lowerMsg.contains('already registered') ||
                          lowerMsg.contains('email already exists') ||
                          lowerMsg.contains('compte existe déjà'))) {
          _showUserExistsDialog(email);
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_translateAuthError(e.message)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 4),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showUserExistsDialog(String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Compte existant'),
        content: Text('Un compte avec l\'adresse $email existe déjà. Souhaitez-vous vous connecter ?'),
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
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Se connecter'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer votre adresse e-mail.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'com.djossimatch://login-callback',
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Délai d\'attente dépassé pour la réinitialisation de mot de passe.'),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Un lien de réinitialisation a été envoyé.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 40.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 40.h),
              
              // App Logo
              Center(
                child: Container(
                  height: 120.w,
                  width: 120.w,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
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
              
              SizedBox(height: 32.h),
              
              Text(
                'Djossi Match',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              
              SizedBox(height: 8.h),
              
              Text(
                _isSignUp 
                  ? 'Créez votre compte en quelques secondes'
                  : 'Trouvez votre prochaine opportunité\nen toute simplicité.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15.sp,
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              
              SizedBox(height: 48.h),

              Container(
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.05),
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
                          labelStyle: TextStyle(color: const Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF94A3B8)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.r),
                            borderSide: BorderSide(color: const Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.r),
                            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
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
                        labelStyle: TextStyle(color: const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF94A3B8)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide: BorderSide(color: const Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleAuth(),
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        labelStyle: TextStyle(color: const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF94A3B8)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide: BorderSide(color: const Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                        ),
                      ),
                    ),
                    if (!_isSignUp)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading ? null : _resetPassword,
                          child: Text(
                            'Mot de passe oublié ?',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    else
                      SizedBox(height: 32.h),

                    // Auth button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleAuth,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                        child: _isLoading 
                          ? SizedBox(
                              height: 20.h, 
                              width: 20.h, 
                              child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            )
                          : Text(
                              _isSignUp ? 'S\'inscrire' : 'Se connecter',
                              style: TextStyle(
                                fontSize: 16.sp, 
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

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
                      : 'Nouveau sur Djossi Match ? ',
                    style: TextStyle(color: const Color(0xFF64748B), fontSize: 14.sp),
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
            ],
          ),
        ),
      ),
    );
  }
}
