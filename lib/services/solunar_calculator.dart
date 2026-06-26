import 'dart:math' as math;

import '../models/solunar_models.dart';
import 'sun_calc.dart';

/// Menghitung periode makan ikan (solunar) secara offline berdasarkan
/// posisi Bulan & Matahari untuk satu lokasi dan satu hari.
///
/// RUMUS SKOR:
///   Skor = Bobot_Periode × Faktor_Fase + Bonus_Matahari
///     - Major (transit atas/bawah Bulan)  → bobot 1.0, durasi ±1 jam (total 2 jam)
///     - Minor (moonrise/moonset)          → bobot 0.6, durasi ±30 mnt (total 1 jam)
///     - Faktor_Fase                        → 0.5..1.0, tertinggi saat purnama/baru
///     - Bonus_Matahari                     → +0.3 bila beririsan sunrise/sunset (±1 jam)
class SolunarCalculator {
  /// Resolusi pemindaian altitude Bulan untuk mencari transit (menit).
  static const int _scanStepMinutes = 10;

  /// Setengah durasi periode Major dan Minor.
  static const Duration _majorHalf = Duration(hours: 1);
  static const Duration _minorHalf = Duration(minutes: 30);

  /// Jendela overlap dengan sunrise/sunset.
  static const Duration _sunWindow = Duration(hours: 1);

  /// Bonus skor saat periode beririsan dengan sunrise/sunset.
  static const double _sunBonus = 0.3;

  static SolunarDay calculate({
    required double latitude,
    required double longitude,
    DateTime? date,
  }) {
    final base = date ?? DateTime.now();
    final dayStart = DateTime(base.year, base.month, base.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final noon = dayStart.add(const Duration(hours: 12));

    // --- Fase bulan & faktor fase -------------------------------------------
    final illum = SunCalc.moonIllumination(noon);
    final phaseFactor = _phaseFactor(illum.phase);

    // --- Waktu matahari & bulan ---------------------------------------------
    final sun = SunCalc.sunTimes(noon, latitude, longitude);
    final moon = SunCalc.moonTimes(dayStart, latitude, longitude);

    final periods = <SolunarPeriod>[];

    // --- MAJOR: transit atas (kulminasi) & transit bawah Bulan --------------
    final transits = _findMoonTransits(dayStart, dayEnd, latitude, longitude);
    for (final t in transits) {
      periods.add(_buildPeriod(
        type: SolunarType.major,
        center: t.time,
        half: _majorHalf,
        phaseFactor: phaseFactor,
        sun: sun,
        trigger: t.isUpper ? 'Transit atas Bulan' : 'Transit bawah Bulan',
      ));
    }

    // --- MINOR: moonrise & moonset ------------------------------------------
    void addMinor(DateTime? t, String trigger) {
      if (t == null) return;
      if (t.isBefore(dayStart) || !t.isBefore(dayEnd)) return;
      periods.add(_buildPeriod(
        type: SolunarType.minor,
        center: t,
        half: _minorHalf,
        phaseFactor: phaseFactor,
        sun: sun,
        trigger: trigger,
      ));
    }

    addMinor(moon.rise, 'Moonrise');
    addMinor(moon.set, 'Moonset');

    periods.sort((a, b) => a.start.compareTo(b.start));

    return SolunarDay(
      date: dayStart,
      latitude: latitude,
      longitude: longitude,
      moonPhase: illum.phase,
      moonIllumination: illum.fraction,
      phaseFactor: phaseFactor,
      sunrise: sun.sunrise,
      sunset: sun.sunset,
      moonrise: moon.rise,
      moonset: moon.set,
      periods: periods,
    );
  }

  // ---------------------------------------------------------------------------
  // Faktor fase: tertinggi (1.0) saat bulan baru & purnama, terendah (0.5)
  // saat kuartal. phase: 0=baru, 0.5=purnama, 1≈baru lagi.
  // Pakai cos(4πφ): puncak di φ=0, 0.5, 1.0 ; lembah di φ=0.25, 0.75.
  // ---------------------------------------------------------------------------
  static double _phaseFactor(double phase) =>
      0.75 + 0.25 * math.cos(4 * math.pi * phase);

  // ---------------------------------------------------------------------------
  // Bangun satu periode beserta skornya.
  // ---------------------------------------------------------------------------
  static SolunarPeriod _buildPeriod({
    required SolunarType type,
    required DateTime center,
    required Duration half,
    required double phaseFactor,
    required SunTimes sun,
    required String trigger,
  }) {
    final start = center.subtract(half);
    final end = center.add(half);

    final overlap = _overlapsSun(start, end, sun);
    final score = type.weight * phaseFactor + (overlap ? _sunBonus : 0.0);

    return SolunarPeriod(
      type: type,
      start: start,
      peak: center,
      end: end,
      score: score,
      sunOverlap: overlap,
      trigger: trigger,
    );
  }

  /// True bila [start]..[end] beririsan dengan jendela ±1 jam sunrise/sunset.
  static bool _overlapsSun(DateTime start, DateTime end, SunTimes sun) {
    bool near(DateTime? event) {
      if (event == null) return false;
      final w0 = event.subtract(_sunWindow);
      final w1 = event.add(_sunWindow);
      // Dua rentang beririsan bila start<=w1 && end>=w0.
      return !start.isAfter(w1) && !end.isBefore(w0);
    }

    return near(sun.sunrise) || near(sun.sunset);
  }

  // ---------------------------------------------------------------------------
  // Cari transit Bulan dengan memindai altitude sepanjang hari, lalu mencari
  // maksimum lokal (transit atas) dan minimum lokal (transit bawah), kemudian
  // memperhalus ke resolusi 1 menit di sekitar titik ekstrem.
  // ---------------------------------------------------------------------------
  static List<_Transit> _findMoonTransits(
    DateTime dayStart,
    DateTime dayEnd,
    double lat,
    double lng,
  ) {
    final samples = <DateTime>[];
    final alts = <double>[];

    for (var t = dayStart;
        !t.isAfter(dayEnd);
        t = t.add(const Duration(minutes: _scanStepMinutes))) {
      samples.add(t);
      alts.add(SunCalc.moonPosition(t, lat, lng).altitude);
    }

    final result = <_Transit>[];
    for (var i = 1; i < samples.length - 1; i++) {
      final prev = alts[i - 1];
      final cur = alts[i];
      final next = alts[i + 1];

      if (cur > prev && cur >= next) {
        // Maksimum lokal → transit atas.
        result.add(_refine(samples[i], lat, lng, isUpper: true));
      } else if (cur < prev && cur <= next) {
        // Minimum lokal → transit bawah.
        result.add(_refine(samples[i], lat, lng, isUpper: false));
      }
    }
    return result;
  }

  /// Perhalus titik ekstrem ke resolusi 1 menit di jendela ±_scanStep.
  static _Transit _refine(DateTime around, double lat, double lng,
      {required bool isUpper}) {
    DateTime best = around;
    double bestAlt = SunCalc.moonPosition(around, lat, lng).altitude;

    for (var m = -_scanStepMinutes; m <= _scanStepMinutes; m++) {
      final t = around.add(Duration(minutes: m));
      final a = SunCalc.moonPosition(t, lat, lng).altitude;
      if (isUpper ? a > bestAlt : a < bestAlt) {
        bestAlt = a;
        best = t;
      }
    }
    return _Transit(time: best, isUpper: isUpper);
  }
}

class _Transit {
  final DateTime time;
  final bool isUpper;
  const _Transit({required this.time, required this.isUpper});
}
