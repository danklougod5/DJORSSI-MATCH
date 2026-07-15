import 'package:flutter_test/flutter_test.dart';

List<String> _extractPhoneNumbers(String raw) {
  final List<String> numbers = [];
  final String cleaned = raw.replaceAll(RegExp(r'[\s\-\.\(\)]+'), '');
  final Iterable<Match> digitBlocks = RegExp(r'\d+').allMatches(cleaned);

  for (final block in digitBlocks) {
    final String digits = block.group(0)!;
    String remaining = digits;

    while (remaining.isNotEmpty) {
      if (remaining.startsWith('225')) {
        if (remaining.length >= 13) {
          numbers.add(remaining.substring(0, 13));
          remaining = remaining.substring(13);
        } else if (remaining.length >= 11) {
          numbers.add(remaining.substring(0, 11));
          remaining = remaining.substring(11);
        } else {
          if (remaining.length >= 8) {
            numbers.add(remaining);
          }
          remaining = '';
        }
      } else {
        if (remaining.length >= 10) {
          numbers.add(remaining.substring(0, 10));
          remaining = remaining.substring(10);
        } else if (remaining.length >= 8) {
          numbers.add(remaining);
          remaining = '';
        } else {
          remaining = '';
        }
      }
    }
  }
  return numbers;
}

void main() {
  group('Phone Number Extraction Tests', () {
    test('Extracts single 13-digit number starting with 225', () {
      expect(_extractPhoneNumbers('2250101818745'), equals(['2250101818745']));
    });

    test('Extracts single 10-digit number without prefix', () {
      expect(_extractPhoneNumbers('0101818745'), equals(['0101818745']));
    });

    test('Extracts single 11-digit old format number starting with 225', () {
      expect(_extractPhoneNumbers('22501020304'), equals(['22501020304']));
    });

    test('Extracts single 8-digit old format number without prefix', () {
      expect(_extractPhoneNumbers('07070707'), equals(['07070707']));
    });

    test('Extracts multiple numbers separated by spaces or characters', () {
      expect(_extractPhoneNumbers('0101818745 / 0707070707'), equals(['0101818745', '0707070707']));
      expect(_extractPhoneNumbers('2250101818745, 07070707'), equals(['2250101818745', '07070707']));
    });

    test('Extracts multiple glued numbers starting with 225', () {
      expect(_extractPhoneNumbers('22501018187452250707070707'), equals(['2250101818745', '2250707070707']));
    });

    test('Extracts multiple glued numbers without prefix', () {
      expect(_extractPhoneNumbers('01010101010707070707'), equals(['0101010101', '0707070707']));
    });
  });
}
