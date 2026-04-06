
class ErrorTranslator {
  /// Traduit les erreurs Supabase et générales en français
  static String translate(Object error) {
    // Si c'est déjà une chaîne en français, on la laisse
    if (error.toString().startsWith('Veuillez') || 
        error.toString().startsWith('Erreur réseau') ||
        error.toString().startsWith('Trop de tentatives')) {
      return error.toString();
    }

    final String message = error.toString().toLowerCase();
    
    // --- AUTH ERRORS ---
    if (message.contains('invalid login credentials')) {
      return 'Email ou mot de passe incorrect.';
    }
    if (message.contains('user already registered') ||
        message.contains('already registered') ||
        message.contains('email already exists') ||
        message.contains('compte existe déjà')) {
      return 'Cet utilisateur est déjà inscrit.';
    }
    if (message.contains('password should be at least 6 characters') ||
        message.contains('password should be at least 8 characters')) {
      return 'Le mot de passe doit contenir au moins 8 caractères, une majuscule et un chiffre.';
    }
    if (message.contains('rate limit') || 
        message.contains('429') || 
        message.contains('over_email_send_rate_limit')) {
      final secondsMatch = RegExp(r'after (\d+) seconds').firstMatch(error.toString());
      if (secondsMatch != null) {
        final seconds = secondsMatch.group(1);
        return 'Trop de tentatives. Veuillez patienter $seconds secondes.';
      }
      return 'Trop de tentatives, veuillez réessayer plus tard.';
    }
    if (message.contains('email not confirmed')) {
      return 'Veuillez confirmer votre adresse email.';
    }
    if (message.contains('invalid email') ||
        message.contains('invalid format') ||
        message.contains('unable to validate email address')) {
      return 'Adresse email invalide.';
    }
    if (message.contains('invalid or expired') || 
        message.contains('token has expired') ||
        message.contains('is invalid')) {
      return 'Lien ou code invalide/expiré.';
    }
    if (message.contains('signup is disabled')) {
      return 'Les inscriptions sont temporairement désactivées.';
    }
    if (message.contains('email provider is disabled')) {
      return 'Le service d\'envoi d\'emails est désactivé.';
    }
    if (message.contains('email sending failed')) {
      return 'L\'envoi de l\'email a échoué. Veuillez contacter le support.';
    }

    // --- DATABASE / POSTGREST ERRORS ---
    if (message.contains('postgrestexception')) {
      if (message.contains('unique constraint') || message.contains('already exists')) {
        return 'Cette information existe déjà dans notre base de données.';
      }
      if (message.contains('permission denied') || message.contains('insufficient_privilege')) {
        return 'Vous n\'avez pas la permission d\'effectuer cette action.';
      }
      return 'Erreur de base de données. Veuillez réessayer plus tard.';
    }

    // --- STORAGE ERRORS ---
    if (message.contains('storageexception')) {
      if (message.contains('object not found')) {
        return 'Le fichier demandé est introuvable.';
      }
      if (message.contains('bucket not found')) {
        return 'Erreur système de stockage. Veuillez contacter le support.';
      }
      if (message.contains('payload too large')) {
        return 'Le fichier est trop lourd. Limite : 5 Mo.';
      }
      return 'Erreur lors du transfert du fichier.';
    }

    // --- NETWORK / TIMEOUT ERRORS ---
    if (message.contains('network error') ||
        message.contains('failed host lookup') ||
        message.contains('socketexception') ||
        message.contains('clientexception') ||
        message.contains('authretryablefetchexception') ||
        message.contains('timeout') ||
        message.contains('délai d\'attente dépassé')) {
      return 'Erreur réseau. Veuillez vérifier votre connexion internet.';
    }

    // --- FALLBACK ---
    // Nettoie l'erreur brute si possible
    String cleanError = error.toString()
        .replaceAll('Exception: ', '')
        .replaceAll('AuthApiException: ', '')
        .replaceAll('AuthRetryableFetchException: ', '')
        .replaceAll('PostgrestException: ', '')
        .replaceAll('StorageException: ', '');
        
    if (cleanError.startsWith('(') && cleanError.endsWith(')')) {
      cleanError = cleanError.substring(1, cleanError.length - 1);
    }
    
    return 'Erreur : $cleanError';
  }
}
