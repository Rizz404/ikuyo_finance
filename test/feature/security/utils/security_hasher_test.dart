import 'package:flutter_test/flutter_test.dart';
import 'package:ikuyo_finance/features/security/utils/security_hasher.dart';

void main() {
  group('SecurityHasher.hash', () {
    test('produces the same hash for the same input', () {
      final first = SecurityHasher.hash('123456');
      final second = SecurityHasher.hash('123456');
      expect(first, equals(second));
    });

    test('produces different hashes for different inputs', () {
      final a = SecurityHasher.hash('123456');
      final b = SecurityHasher.hash('654321');
      expect(a, isNot(equals(b)));
    });

    test('is case sensitive', () {
      final lower = SecurityHasher.hash('password');
      final upper = SecurityHasher.hash('PASSWORD');
      expect(lower, isNot(equals(upper)));
    });

    test('returns a 64-character lowercase hex string (SHA-256 digest)', () {
      final digest = SecurityHasher.hash('some-input');
      expect(digest.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(digest), isTrue);
    });

    test('hashes an empty string without throwing', () {
      expect(() => SecurityHasher.hash(''), returnsNormally);
      expect(SecurityHasher.hash(''), equals(SecurityHasher.hash('')));
    });

    test('known SHA-256 vector for "abc"', () {
      // * Standard NIST test vector for SHA-256.
      expect(
        SecurityHasher.hash('abc'),
        equals(
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
        ),
      );
    });
  });

  group('SecurityHasher.verify', () {
    test('returns true when the input matches the hash', () {
      final hash = SecurityHasher.hash('mySecret');
      expect(SecurityHasher.verify('mySecret', hash), isTrue);
    });

    test('returns false when the input does not match the hash', () {
      final hash = SecurityHasher.hash('mySecret');
      expect(SecurityHasher.verify('wrongSecret', hash), isFalse);
    });

    test('returns false for a subtly different input (case difference)', () {
      final hash = SecurityHasher.hash('MySecret');
      expect(SecurityHasher.verify('mysecret', hash), isFalse);
    });

    test('returns false when compared against an arbitrary non-matching hash string', () {
      expect(SecurityHasher.verify('anything', 'not-a-real-hash'), isFalse);
    });

    test('round-trips correctly for numeric PIN-like input', () {
      final hash = SecurityHasher.hash('654321');
      expect(SecurityHasher.verify('654321', hash), isTrue);
      expect(SecurityHasher.verify('123456', hash), isFalse);
    });
  });
}
