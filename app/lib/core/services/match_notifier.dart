import 'package:flutter/foundation.dart';

/// Un simple notifieur global pour signaler à l'écran MatchesScreen 
/// qu'un nouveau match vient d'être enregistré en base de données, 
/// pour l'obliger à se rafraîchir en temps réel.
class MatchNotifier {
  static final ValueNotifier<int> stream = ValueNotifier(0);
  
  static void notifyNewMatch() {
    stream.value++;
  }
}
