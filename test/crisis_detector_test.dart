import 'package:flutter_test/flutter_test.dart';
import 'package:mindra/core/crisis_detector.dart';
import 'package:mindra/models/ai_reflection.dart';

void main() {
  test('flags accented and unaccented crisis phrases', () {
    for (final text in [
      'Mình muốn chết',
      'muon chet qua',
      'tu sat cho xong',
      'khong con muon song',
      'I want to end it all',
    ]) {
      expect(hasCrisisSignal(text), isTrue, reason: text);
    }
  });

  test('does not flag common phrases that look similar without accents', () {
    for (final text in [
      'Cứ từ từ rồi mọi chuyện sẽ ổn',
      'cu tu tu thoi',
      'Mai mình đi tư vấn tâm lý',
      'mai di tu van tam ly',
      'Hôm nay mình cắt tóc',
      '',
    ]) {
      expect(hasCrisisSignal(text), isFalse, reason: text);
    }
  });

  test('flags decomposed (NFD) text like the backend', () {
    // "muốn chết" với dấu là ký tự tổ hợp rời.
    const decomposed = 'muo\u0302\u0301n che\u0302\u0301t';
    expect(hasCrisisSignal(decomposed), isTrue);
  });

  test('offline fallback reflection switches to the safety flow', () {
    final reflection = AIReflection.forEmotion(
      emotionKey: 'sad',
      intensity: 4,
      thought: 'muon chet',
    );
    expect(reflection.safetyFlag, isTrue);
  });
}
