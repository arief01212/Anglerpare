import 'package:flutter_test/flutter_test.dart';
import 'package:fishing_solunar/models/solunar_models.dart';
import 'package:fishing_solunar/services/solunar_calculator.dart';

void main() {
  group('SolunarCalculator', () {
    test('menghasilkan periode major & minor untuk satu hari', () {
      final day = SolunarCalculator.calculate(
        latitude: -6.2088,
        longitude: 106.8456,
        date: DateTime(2026, 6, 26),
      );

      // Bulan biasanya transit atas + bawah → minimal ada periode major.
      final majors =
          day.periods.where((p) => p.type == SolunarType.major).toList();
      expect(majors, isNotEmpty);

      // Skor major harus mengikuti rumus: bobot(1.0)*faktorFase (+ bonus).
      for (final p in majors) {
        final expectedMin = 1.0 * day.phaseFactor;
        expect(p.score, greaterThanOrEqualTo(expectedMin - 1e-9));
        // Maksimum = 1.0 * 1.0 + 0.3 bonus.
        expect(p.score, lessThanOrEqualTo(1.0 * 1.0 + 0.3 + 1e-9));
      }
    });

    test('faktor fase berada dalam rentang 0.5..1.0', () {
      for (final d in [
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 10),
        DateTime(2026, 1, 20),
        DateTime(2026, 1, 29),
      ]) {
        final day = SolunarCalculator.calculate(
          latitude: 0,
          longitude: 0,
          date: d,
        );
        expect(day.phaseFactor, inInclusiveRange(0.5, 1.0));
      }
    });

    test('durasi major 2 jam dan minor 1 jam', () {
      final day = SolunarCalculator.calculate(
        latitude: 10,
        longitude: 120,
        date: DateTime(2026, 6, 26),
      );
      for (final p in day.periods) {
        if (p.type == SolunarType.major) {
          expect(p.duration, const Duration(hours: 2));
        } else {
          expect(p.duration, const Duration(hours: 1));
        }
      }
    });

    test('rating mengikuti ambang skor', () {
      expect(SolunarRatingX.fromScore(1.2), SolunarRating.high);
      expect(SolunarRatingX.fromScore(0.7), SolunarRating.medium);
      expect(SolunarRatingX.fromScore(0.4), SolunarRating.low);
    });
  });
}
