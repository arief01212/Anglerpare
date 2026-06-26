import 'dart:math' as math;

/// Port Dart ringkas dari algoritma SunCalc (oleh Vladimir Agafonkin, BSD-2).
///
/// Disertakan langsung di dalam proyek agar perhitungan posisi Matahari
/// dan Bulan berjalan 100% offline tanpa internet maupun API key, dan tidak
/// bergantung pada perubahan API paket eksternal.
///
/// Semua sudut internal memakai radian. Waktu masuk/keluar berupa [DateTime]
/// dalam zona waktu lokal perangkat (mengikuti DateTime bawaan).
class SunCalc {
  SunCalc._();

  static const double _rad = math.pi / 180.0;
  static const double _dayMs = 1000 * 60 * 60 * 24;
  static const double _j1970 = 2440588;
  static const double _j2000 = 2451545;
  // Kemiringan sumbu ekliptika bumi.
  static const double _e = _rad * 23.4397;

  // ---------------------------------------------------------------------------
  // Konversi tanggal <-> Julian
  // ---------------------------------------------------------------------------
  static double _toJulian(DateTime date) =>
      date.millisecondsSinceEpoch / _dayMs - 0.5 + _j1970;

  static DateTime _fromJulian(double j) => DateTime.fromMillisecondsSinceEpoch(
        ((j + 0.5 - _j1970) * _dayMs).round(),
      );

  static double _toDays(DateTime date) => _toJulian(date) - _j2000;

  // ---------------------------------------------------------------------------
  // Posisi umum benda langit
  // ---------------------------------------------------------------------------
  static double _rightAscension(double l, double b) =>
      math.atan2(math.sin(l) * math.cos(_e) - math.tan(b) * math.sin(_e),
          math.cos(l));

  static double _declination(double l, double b) =>
      math.asin(math.sin(b) * math.cos(_e) +
          math.cos(b) * math.sin(_e) * math.sin(l));

  static double _azimuth(double h, double phi, double dec) =>
      math.atan2(math.sin(h),
          math.cos(h) * math.sin(phi) - math.tan(dec) * math.cos(phi));

  static double _altitude(double h, double phi, double dec) =>
      math.asin(math.sin(phi) * math.sin(dec) +
          math.cos(phi) * math.cos(dec) * math.cos(h));

  static double _siderealTime(double d, double lw) =>
      _rad * (280.16 + 360.9856235 * d) - lw;

  static double _astroRefraction(double h) {
    if (h < 0) h = 0;
    return 0.0002967 / math.tan(h + 0.00312536 / (h + 0.08901179));
  }

  // ---------------------------------------------------------------------------
  // Matahari
  // ---------------------------------------------------------------------------
  static double _solarMeanAnomaly(double d) =>
      _rad * (357.5291 + 0.98560028 * d);

  static double _eclipticLongitude(double m) {
    final c = _rad *
        (1.9148 * math.sin(m) +
            0.02 * math.sin(2 * m) +
            0.0003 * math.sin(3 * m));
    const p = _rad * 102.9372; // perihelion bumi
    return m + c + p + math.pi;
  }

  static _RaDec _sunCoords(double d) {
    final m = _solarMeanAnomaly(d);
    final l = _eclipticLongitude(m);
    return _RaDec(_rightAscension(l, 0), _declination(l, 0), 0);
  }

  /// Azimuth & altitude Matahari (radian) untuk waktu & koordinat tertentu.
  static AstroPosition sunPosition(DateTime date, double lat, double lng) {
    final lw = _rad * -lng;
    final phi = _rad * lat;
    final d = _toDays(date);
    final c = _sunCoords(d);
    final h = _siderealTime(d, lw) - c.ra;
    return AstroPosition(
      azimuth: _azimuth(h, phi, c.dec),
      altitude: _altitude(h, phi, c.dec),
    );
  }

  static const double _j0 = 0.0009;

  static double _julianCycle(double d, double lw) =>
      (d - _j0 - lw / (2 * math.pi)).roundToDouble();

  static double _approxTransit(double ht, double lw, double n) =>
      _j0 + (ht + lw) / (2 * math.pi) + n;

  static double _solarTransitJ(double ds, double m, double l) =>
      _j2000 + ds + 0.0053 * math.sin(m) - 0.0069 * math.sin(2 * l);

  static double _hourAngle(double h, double phi, double d) => math.acos(
      (math.sin(h) - math.sin(phi) * math.sin(d)) /
          (math.cos(phi) * math.cos(d)));

  static double _getSetJ(double h, double lw, double phi, double dec, double n,
      double m, double l) {
    final w = _hourAngle(h, phi, dec);
    final a = _approxTransit(w, lw, n);
    return _solarTransitJ(a, m, l);
  }

  /// Waktu sunrise, sunset, dan solar noon. Nilai bisa null bila Matahari
  /// tidak terbit/terbenam pada hari itu (lintang ekstrem).
  static SunTimes sunTimes(DateTime date, double lat, double lng) {
    final lw = _rad * -lng;
    final phi = _rad * lat;
    final d = _toDays(date);

    final n = _julianCycle(d, lw);
    final ds = _approxTransit(0, lw, n);
    final m = _solarMeanAnomaly(ds);
    final l = _eclipticLongitude(m);
    final dec = _declination(l, 0);

    final jNoon = _solarTransitJ(ds, m, l);

    const h0 = -0.833 * _rad; // tepi atas piringan matahari + refraksi
    final cosH = (math.sin(h0) - math.sin(phi) * math.sin(dec)) /
        (math.cos(phi) * math.cos(dec));

    DateTime? sunrise;
    DateTime? sunset;
    if (cosH.abs() <= 1) {
      final jSet = _getSetJ(h0, lw, phi, dec, n, m, l);
      final jRise = jNoon - (jSet - jNoon);
      sunrise = _fromJulian(jRise);
      sunset = _fromJulian(jSet);
    }

    return SunTimes(
      sunrise: sunrise,
      sunset: sunset,
      solarNoon: _fromJulian(jNoon),
    );
  }

  // ---------------------------------------------------------------------------
  // Bulan
  // ---------------------------------------------------------------------------
  static _RaDec _moonCoords(double d) {
    final l = _rad * (218.316 + 13.176396 * d); // bujur ekliptika
    final m = _rad * (134.963 + 13.064993 * d); // anomali rata-rata
    final f = _rad * (93.272 + 13.229350 * d); // jarak rata-rata

    final lng = l + _rad * 6.289 * math.sin(m); // bujur
    final lat = _rad * 5.128 * math.sin(f); // lintang
    final dt = 385001 - 20905 * math.cos(m); // jarak (km)

    return _RaDec(_rightAscension(lng, lat), _declination(lng, lat), dt);
  }

  /// Posisi Bulan (azimuth, altitude terkoreksi refraksi, jarak km).
  static AstroPosition moonPosition(DateTime date, double lat, double lng) {
    final lw = _rad * -lng;
    final phi = _rad * lat;
    final d = _toDays(date);

    final c = _moonCoords(d);
    final h = _siderealTime(d, lw) - c.ra;
    var alt = _altitude(h, phi, c.dec);
    alt += _astroRefraction(alt);

    return AstroPosition(
      azimuth: _azimuth(h, phi, c.dec),
      altitude: alt,
      distance: c.dist,
    );
  }

  /// Iluminasi & fase Bulan.
  ///
  /// - [fraction] : porsi piringan yang tersinari (0..1).
  /// - [phase]    : 0 = bulan baru, 0.25 = sabit awal, 0.5 = purnama,
  ///   0.75 = sabit akhir, mendekati 1 kembali ke bulan baru.
  static MoonIllumination moonIllumination(DateTime date) {
    final d = _toDays(date);
    final s = _sunCoords(d);
    final m = _moonCoords(d);

    const sdist = 149598000.0; // jarak Matahari (km)

    final phi = math.acos(math.sin(s.dec) * math.sin(m.dec) +
        math.cos(s.dec) * math.cos(m.dec) * math.cos(s.ra - m.ra));
    final inc = math.atan2(sdist * math.sin(phi), m.dist - sdist * math.cos(phi));
    final angle = math.atan2(
        math.cos(s.dec) * math.sin(s.ra - m.ra),
        math.sin(s.dec) * math.cos(m.dec) -
            math.cos(s.dec) * math.sin(m.dec) * math.cos(s.ra - m.ra));

    return MoonIllumination(
      fraction: (1 + math.cos(inc)) / 2,
      phase: 0.5 + 0.5 * inc * (angle < 0 ? -1 : 1) / math.pi,
      angle: angle,
    );
  }

  static DateTime _hoursLater(DateTime date, double h) =>
      DateTime.fromMillisecondsSinceEpoch(
          date.millisecondsSinceEpoch + (h * 3600000).round());

  /// Waktu moonrise & moonset pada hari [date] (port getMoonTimes SunCalc).
  static MoonTimes moonTimes(DateTime date, double lat, double lng) {
    final t = DateTime(date.year, date.month, date.day);
    const hc = 0.133 * _rad;
    var h0 = moonPosition(t, lat, lng).altitude - hc;

    double? rise;
    double? set;
    double ye = 0;

    for (var i = 1; i <= 24; i += 2) {
      final h1 = moonPosition(_hoursLater(t, i.toDouble()), lat, lng).altitude - hc;
      final h2 =
          moonPosition(_hoursLater(t, (i + 1).toDouble()), lat, lng).altitude - hc;

      final a = (h0 + h2) / 2 - h1;
      final b = (h2 - h0) / 2;
      final xe = -b / (2 * a);
      ye = (a * xe + b) * xe + h1;
      final d = b * b - 4 * a * h1;
      var roots = 0;
      double x1 = 0;
      double x2 = 0;

      if (d >= 0) {
        final dx = math.sqrt(d) / (a.abs() * 2);
        x1 = xe - dx;
        x2 = xe + dx;
        if (x1.abs() <= 1) roots++;
        if (x2.abs() <= 1) roots++;
        if (x1 < -1) x1 = x2;
      }

      if (roots == 1) {
        if (h0 < 0) {
          rise = i + x1;
        } else {
          set = i + x1;
        }
      } else if (roots == 2) {
        rise = i + (ye < 0 ? x2 : x1);
        set = i + (ye < 0 ? x1 : x2);
      }

      if (rise != null && set != null) break;
      h0 = h2;
    }

    return MoonTimes(
      rise: rise != null ? _hoursLater(t, rise) : null,
      set: set != null ? _hoursLater(t, set) : null,
      alwaysUp: rise == null && set == null && ye > 0,
      alwaysDown: rise == null && set == null && ye <= 0,
    );
  }
}

/// Right ascension / declination (+ jarak untuk Bulan).
class _RaDec {
  final double ra;
  final double dec;
  final double dist;
  const _RaDec(this.ra, this.dec, this.dist);
}

/// Posisi suatu benda langit di langit (radian).
class AstroPosition {
  final double azimuth;
  final double altitude;
  final double distance;
  const AstroPosition({
    required this.azimuth,
    required this.altitude,
    this.distance = 0,
  });
}

class SunTimes {
  final DateTime? sunrise;
  final DateTime? sunset;
  final DateTime solarNoon;
  const SunTimes({this.sunrise, this.sunset, required this.solarNoon});
}

class MoonIllumination {
  final double fraction;
  final double phase;
  final double angle;
  const MoonIllumination({
    required this.fraction,
    required this.phase,
    required this.angle,
  });
}

class MoonTimes {
  final DateTime? rise;
  final DateTime? set;
  final bool alwaysUp;
  final bool alwaysDown;
  const MoonTimes({
    this.rise,
    this.set,
    this.alwaysUp = false,
    this.alwaysDown = false,
  });
}
