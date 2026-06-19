// Ce fichier était un script de debug pour inspecter la structure de la DB.
// Il a été remplacé par ce test no-op car il utilisait exit(0) et
// nécessitait des plugins natifs non disponibles en test headless.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inspect_db - skipped (script de debug)', () {
    // Ce test était un script de debug DB. Ignoré en CI.
    // Pour inspecter la DB, utiliser les scripts Python dans /scratch/
  }, skip: 'Script de debug - nécessite un vrai appareil et SharedPreferences');
}
