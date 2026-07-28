import 'package:flutter/foundation.dart';

/// Un simple notifieur global pour signaler aux écrans
/// les rafraîchissements et navigations de profil.
class ProfileNotifier {
  static final ValueNotifier<int> stream = ValueNotifier(0);

  /// Notifieur pour changer d'onglet dans la navigation principale
  static final ValueNotifier<int> selectedTabNotifier = ValueNotifier<int>(0);

  /// Notifieur pour faire clignoter le toggle de visibilité recruteur
  static final ValueNotifier<bool> highlightVisibilityNotifier = ValueNotifier<bool>(false);

  static void notifyProfileUpdated() {
    stream.value++;
  }

  /// Redirige directement vers l'onglet Profil (index 4) et fait clignoter le toggle visibilité
  static void navigateToProfileWithVisibilityHighlight() {
    highlightVisibilityNotifier.value = true;
    selectedTabNotifier.value = 4;
  }
}
