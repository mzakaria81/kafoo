import 'package:kafoo_domain/egyptian_phone.dart';
import 'package:test/test.dart';

void main() {
  group('the form an Egyptian actually types', () {
    test('a local mobile number becomes E.164', () {
      expect(normalizeEgyptianMobile('01112513196'), '+201112513196');
    });

    test('spaces and dashes are how people write numbers, not errors', () {
      expect(normalizeEgyptianMobile('011 1251 3196'), '+201112513196');
      expect(normalizeEgyptianMobile('011-1251-3196'), '+201112513196');
      expect(normalizeEgyptianMobile('  01112513196  '), '+201112513196');
    });

    // An Arabic keyboard produces these, and the number is no less valid for it.
    test('Arabic-Indic digits are digits', () {
      expect(normalizeEgyptianMobile('٠١١١٢٥١٣١٩٦'), '+201112513196');
      expect(normalizeEgyptianMobile('۰۱۱۱۲۵۱۳۱۹۶'), '+201112513196');
    });

    test('an already-international number is left alone', () {
      expect(normalizeEgyptianMobile('+201112513196'), '+201112513196');
    });

    test('the two other ways of writing the country code', () {
      expect(normalizeEgyptianMobile('00201112513196'), '+201112513196');
      expect(normalizeEgyptianMobile('201112513196'), '+201112513196');
    });

    test('a number without its leading zero', () {
      expect(normalizeEgyptianMobile('1112513196'), '+201112513196');
    });

    // The demo numbers in supabase/config.toml, which is the one set of inputs
    // this must not break: they are what signs anybody into the demo build.
    test('the demo test numbers survive', () {
      expect(normalizeEgyptianMobile('01000000001'), '+201000000001');
      expect(normalizeEgyptianMobile('+201000000002'), '+201000000002');
    });
  });

  group('what is not an Egyptian mobile number', () {
    test('too short, too long', () {
      expect(normalizeEgyptianMobile('0111251319'), isNull);
      expect(normalizeEgyptianMobile('011125131964'), isNull);
    });

    test('a landline is not a mobile — it cannot receive the code', () {
      expect(normalizeEgyptianMobile('0223456789'), isNull);
    });

    test('an unknown mobile prefix', () {
      // Egyptian mobiles are 010, 011, 012 and 015 and nothing else.
      expect(normalizeEgyptianMobile('01312513196'), isNull);
      expect(normalizeEgyptianMobile('01912513196'), isNull);
    });

    test('another country is not silently treated as Egyptian', () {
      expect(normalizeEgyptianMobile('+447700900123'), isNull);
      expect(normalizeEgyptianMobile('+11234567890'), isNull);
    });

    test('empty and nonsense', () {
      expect(normalizeEgyptianMobile(''), isNull);
      expect(normalizeEgyptianMobile('   '), isNull);
      expect(normalizeEgyptianMobile('hello'), isNull);
      expect(normalizeEgyptianMobile('+20'), isNull);
    });
  });
}
