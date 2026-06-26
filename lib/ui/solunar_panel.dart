import 'package:flutter/material.dart';

import '../models/solunar_models.dart';

/// Panel bawah yang menampilkan fase bulan, daftar periode Major/Minor,
/// skor berwarna, dan penanda "SEKARANG" saat ikan sedang aktif.
class SolunarPanel extends StatelessWidget {
  final SolunarDay? day;
  final String spotName;
  final DateTime now;
  final bool loading;

  const SolunarPanel({
    super.key,
    required this.day,
    required this.spotName,
    required this.now,
    this.loading = false,
  });

  static Color ratingColor(SolunarRating r) {
    switch (r) {
      case SolunarRating.high:
        return const Color(0xFF2E9E4F); // hijau
      case SolunarRating.medium:
        return const Color(0xFFE8890C); // oranye
      case SolunarRating.low:
        return const Color(0xFFD23F31); // merah
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.34,
      minChildSize: 0.12,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, -2)),
            ],
          ),
          child: loading
              ? const Center(
                  heightFactor: 4,
                  child: CircularProgressIndicator(),
                )
              : day == null
                  ? _empty(context, scrollController)
                  : _content(context, scrollController, day!),
        );
      },
    );
  }

  Widget _empty(BuildContext context, ScrollController sc) {
    return ListView(
      controller: sc,
      children: [
        _grabber(),
        const SizedBox(height: 24),
        const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Ambil lokasi GPS atau long-press di peta\nuntuk menghitung waktu makan ikan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  Widget _content(BuildContext context, ScrollController sc, SolunarDay d) {
    final active = d.activePeriod(now);

    return ListView(
      controller: sc,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _grabber(),
        _header(context, d),
        const SizedBox(height: 12),
        if (active != null) _activeBanner(active),
        if (active == null) _nextBanner(d),
        const SizedBox(height: 16),
        _sunMoonRow(d),
        const SizedBox(height: 16),
        Text('Periode Major', style: _sectionStyle(context)),
        const SizedBox(height: 6),
        ...d.periods
            .where((p) => p.type == SolunarType.major)
            .map((p) => _periodTile(context, p)),
        const SizedBox(height: 14),
        Text('Periode Minor', style: _sectionStyle(context)),
        const SizedBox(height: 6),
        ...d.periods
            .where((p) => p.type == SolunarType.minor)
            .map((p) => _periodTile(context, p)),
      ],
    );
  }

  Widget _grabber() => Center(
        child: Container(
          width: 42,
          height: 5,
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      );

  Widget _header(BuildContext context, SolunarDay d) {
    final rating = SolunarRatingX.fromScore(d.dayScore * 1.3);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(d.moonPhaseEmoji, style: const TextStyle(fontSize: 38)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                spotName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${d.moonPhaseName} • iluminasi ${(d.moonIllumination * 100).round()}%',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
        _scorePill('Skor Hari', d.dayScore, rating),
      ],
    );
  }

  Widget _scorePill(String label, double score01, SolunarRating rating) {
    final color = ratingColor(rating);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color),
          ),
          child: Text(
            '${(score01 * 100).round()}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _activeBanner(SolunarPeriod p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2E9E4F),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.phishing, color: Colors.white, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('IKAN SEDANG AKTIF — SEKARANG!',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                Text(
                  'Periode ${p.type.label} • ${p.trigger} • s/d ${_fmt(p.end)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nextBanner(SolunarDay d) {
    final upcoming = d.periods.where((p) => p.start.isAfter(now)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    if (upcoming.isEmpty) {
      return _infoBanner('Tidak ada periode tersisa hari ini.');
    }
    final next = upcoming.first;
    final diff = next.start.difference(now);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    final eta = h > 0 ? '$h jam $m mnt lagi' : '$m menit lagi';
    return _infoBanner(
      'Periode berikutnya: ${next.type.label} (${next.trigger}) '
      'pukul ${_fmt(next.start)} — $eta',
    );
  }

  Widget _infoBanner(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 20, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _sunMoonRow(SolunarDay d) {
    Widget item(IconData icon, String label, DateTime? t) => Expanded(
          child: Column(
            children: [
              Icon(icon, size: 20, color: Colors.amber.shade800),
              const SizedBox(height: 2),
              Text(t == null ? '—' : _fmt(t),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        );
    return Row(
      children: [
        item(Icons.wb_sunny, 'Sunrise', d.sunrise),
        item(Icons.wb_twilight, 'Sunset', d.sunset),
        item(Icons.nights_stay, 'Moonrise', d.moonrise),
        item(Icons.bedtime, 'Moonset', d.moonset),
      ],
    );
  }

  Widget _periodTile(BuildContext context, SolunarPeriod p) {
    final rating = SolunarRatingX.fromScore(p.score);
    final color = ratingColor(rating);
    final isActive = p.isActiveAt(now);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? color : Colors.grey.shade300,
          width: isActive ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${_fmt(p.start)} – ${_fmt(p.end)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(width: 8),
                    if (isActive)
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('SEKARANG',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${p.trigger} • puncak ${_fmt(p.peak)}'
                  '${p.sunOverlap ? ' • +bonus matahari' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(
            p.score.toStringAsFixed(2),
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ],
      ),
    );
  }

  TextStyle _sectionStyle(BuildContext context) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade700,
        letterSpacing: 0.4,
      );

  /// Format jam:menit memakai zona waktu lokal perangkat.
  static String _fmt(DateTime t) {
    final l = t.toLocal();
    final hh = l.hour.toString().padLeft(2, '0');
    final mm = l.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
