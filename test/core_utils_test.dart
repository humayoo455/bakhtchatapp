import 'package:bakht/core/utils/chat_id.dart';
import 'package:bakht/core/utils/phone_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('generateChatId', () {
    test('is stable regardless of participant order', () {
      expect(generateChatId('user-b', 'user-a'), 'user-a_user-b');
      expect(generateChatId('user-a', 'user-b'), 'user-a_user-b');
    });

    test('rejects invalid participant IDs', () {
      expect(() => generateChatId('', 'user-b'), throwsArgumentError);
      expect(() => generateChatId('same', 'same'), throwsArgumentError);
    });
  });

  group('formatPakistanPhone', () {
    test('normalizes common local formats', () {
      expect(formatPakistanPhone('0300 1234567'), '+923001234567');
      expect(formatPakistanPhone('3001234567'), '+923001234567');
      expect(formatPakistanPhone('00923001234567'), '+923001234567');
    });

    test('preserves an international number', () {
      expect(formatPakistanPhone('+923001234567'), '+923001234567');
    });
  });
}
