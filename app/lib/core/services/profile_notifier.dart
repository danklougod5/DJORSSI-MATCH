import 'package:flutter/foundation.dart';

/// Un simple notifieur global pour signaler aux écrans (comme SwipeScreen)
/// que le profil utilisateur (tags, CV, etc.) a été modifié,
/// pour les obliger à se rafraîchir.
class ProfileNotifier {
  static final ValueNotifier<int> stream = ValueNotifier(0);

  static void notifyProfileUpdated() {
    stream.value++;
  }
}
