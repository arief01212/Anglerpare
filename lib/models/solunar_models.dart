/// Jenis periode aktivitas ikan menurut teori solunar.
enum SolunarType { major, minor }

extension SolunarTypeX on SolunarType {
  String get label => this == SolunarType.major ? 'Major' : 'Minor';

  /// Bobot dasar periode pada rumus skor.
  double get weight => this == SolunarType.major ? 1.0 : 0.6;
}

/// Satu rentang waktu aktif (Major/Minor) lengkap dengan skornya.
class SolunarPeriod {
  final SolunarType type;
  final DateTime start;
  final DateTime peak;
  final DateTime end;

  /// Skor mentah = bobot × faktorFase + bonusMatahari.
  final double score;

  /// True bila periode beririsan dengan sunrise/sunset (±1 jam).
  final bool sunOverlap;

  /// Keterangan pemicu, mis. "Transit atas" / "Moonrise".
  final String trigger;

  const SolunarPeriod({
    required this.type,
    required this.start,
    required this.peak,
    required this.end,
    required this.score,
    required this.sunOverlap,
    required this.trigger,
  });

  bool isActiveAt(DateTime t) =>
      !t.isBefore(start) && !t.isAfter(end);

  Duration get duration => end.difference(start);
}

/// Kualitas skor untuk pewarnaan UI.
enum SolunarRating { high, medium, low }

extension SolunarRatingX on SolunarRating {
  static SolunarRating fromScore(double score) {
    if (score >= 0.9) return SolunarRating.high;
    if (score >= 0.6) return SolunarRating.medium;
    return SolunarRating.low;
  }

  String get label {
    switch (this) {
      case SolunarRating.high:
        return 'Tinggi';
      case SolunarRating.medium:
        return 'Sedang';
      case SolunarRating.low:
        return 'Rendah';
    }
  }
}

/// Hasil perhitungan solunar untuk satu hari di satu lokasi.
class SolunarDay {
  final DateTime date;
  final double latitude;
  final double longitude;

  /// 0 = bulan baru, 0.5 = purnama (lihat SunCalc.moonIllumination).
  final double moonPhase;
  final double moonIllumination;

  /// Faktor fase pada rumus skor (0.5..1.0), tertinggi saat purnama/baru.
  final double phaseFactor;

  final DateTime? sunrise;
  final DateTime? sunset;
  final DateTime? moonrise;
  final DateTime? moonset;

  final List<SolunarPeriod> periods;

  const SolunarDay({
    required this.date,
    required this.latitude,
    required this.longitude,
    required this.moonPhase,
    required this.moonIllumination,
    required this.phaseFactor,
    required this.sunrise,
    required this.sunset,
    required this.moonrise,
    required this.moonset,
    required this.periods,
  });

  /// Skor harian keseluruhan (0..1) berdasar rata-rata periode major.
  double get dayScore {
    final majors = periods.where((p) => p.type == SolunarType.major).toList();
    if (majors.isEmpty) return 0;
    final avg =
        majors.map((p) => p.score).reduce((a, b) => a + b) / majors.length;
    return (avg / 1.3).clamp(0.0, 1.0); // 1.3 = skor maksimum teoretis
  }

  /// Periode yang sedang aktif "SEKARANG", bila ada.
  SolunarPeriod? activePeriod(DateTime now) {
    for (final p in periods) {
      if (p.isActiveAt(now)) return p;
    }
    return null;
  }

  /// Nama fase bulan dalam Bahasa Indonesia.
  String get moonPhaseName {
    final p = moonPhase;
    if (p < 0.03 || p > 0.97) return 'Bulan Baru';
    if (p < 0.22) return 'Sabit Awal';
    if (p < 0.28) return 'Kuartal Pertama';
    if (p < 0.47) return 'Cembung Awal';
    if (p < 0.53) return 'Purnama';
    if (p < 0.72) return 'Cembung Akhir';
    if (p < 0.78) return 'Kuartal Akhir';
    return 'Sabit Akhir';
  }

  /// Emoji fase bulan untuk tampilan ringkas.
  String get moonPhaseEmoji {
    final p = moonPhase;
    if (p < 0.03 || p > 0.97) return '🌑';
    if (p < 0.22) return '🌒';
    if (p < 0.28) return '🌓';
    if (p < 0.47) return '🌔';
    if (p < 0.53) return '🌕';
    if (p < 0.72) return '🌖';
    if (p < 0.78) return '🌗';
    return '🌘';
  }
}
