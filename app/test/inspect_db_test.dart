import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  test('inspect database columns', () async {
    // Read .env
    final envLines = File('.env').readAsLinesSync();
    String? url;
    String? key;
    for (var line in envLines) {
      if (line.startsWith('SUPABASE_URL=')) {
        url = line.split('SUPABASE_URL=')[1].trim();
      }
      if (line.startsWith('SUPABASE_ANON_KEY=')) {
        key = line.split('SUPABASE_ANON_KEY=')[1].trim();
      }
    }

    expect(url, isNotNull);
    expect(key, isNotNull);

    await Supabase.initialize(
      url: url!,
      anonKey: key!,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
      ),
    );
    final client = Supabase.instance.client;

    try {
      final response = await client.from('profiles').select().limit(1).maybeSingle();
      if (response != null) {
        print('*** PROFILES COLUMNS: ${response.keys.toList()} ***');
      } else {
        print('*** PROFILES: NO DATA ***');
      }
    } catch (e) {
      print('Error profiles: $e');
    }

    try {
      final response = await client.from('user_cvs').select().limit(1).maybeSingle();
      if (response != null) {
        print('*** USER_CVS COLUMNS: ${response.keys.toList()} ***');
      } else {
        print('*** USER_CVS: NO DATA ***');
      }
    } catch (e) {
      print('Error user_cvs: $e');
    }

    exit(0);
  });
}
