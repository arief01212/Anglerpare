import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/fishing_spot.dart';
import '../models/solunar_models.dart';
import '../services/location_service.dart';
import '../services/solunar_calculator.dart';
import 'solunar_panel.dart';

/// Layar utama: peta OpenStreetMap + panel solunar.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  final List<FishingSpot> _spots = [];
  FishingSpot? _selected;
  SolunarDay? _solunar;

  bool _loadingLocation = false;
  bool _calculating = false;

  // Default awal: Jakarta, sebelum GPS didapat.
  static const LatLng _fallbackCenter = LatLng(-6.2088, 106.8456);

  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    // Ambil lokasi pengguna otomatis saat pertama buka.
    WidgetsBinding.instance.addPostFrameCallback((_) => _useMyLocation());
  }

  // ---------------------------------------------------------------------------
  // Aksi
  // ---------------------------------------------------------------------------

  Future<void> _useMyLocation() async {
    setState(() => _loadingLocation = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      final loc = LatLng(pos.latitude, pos.longitude);
      final spot = FishingSpot(
        id: 'gps-${DateTime.now().millisecondsSinceEpoch}',
        name: 'Lokasi Saya',
        location: loc,
      );
      setState(() {
        _spots
          ..removeWhere((s) => s.id.startsWith('gps-'))
          ..add(spot);
      });
      _mapController.move(loc, 13);
      await _selectSpot(spot);
    } catch (e) {
      _snack('$e');
      // Tetap tampilkan solunar untuk titik fallback agar app tidak kosong.
      if (_solunar == null) {
        final spot = FishingSpot(
          id: 'fallback',
          name: 'Lokasi default (Jakarta)',
          location: _fallbackCenter,
        );
        setState(() => _spots.add(spot));
        await _selectSpot(spot);
      }
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _addSpotAt(LatLng latlng) async {
    final spot = FishingSpot(
      id: 'spot-${DateTime.now().millisecondsSinceEpoch}',
      name: 'Spot ${_spots.where((s) => s.id.startsWith('spot-')).length + 1}',
      location: latlng,
    );
    setState(() => _spots.add(spot));
    await _selectSpot(spot);
  }

  /// Pilih spot lalu hitung ulang solunar untuk titik itu.
  Future<void> _selectSpot(FishingSpot spot) async {
    setState(() {
      _selected = spot;
      _calculating = true;
      _now = DateTime.now();
    });

    // Hitung di luar frame agar UI tetap responsif.
    final day = await Future(() => SolunarCalculator.calculate(
          latitude: spot.location.latitude,
          longitude: spot.location.longitude,
          date: _now,
        ));

    if (!mounted) return;
    setState(() {
      _solunar = day;
      _calculating = false;
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fishing Solunar'),
        actions: [
          IconButton(
            tooltip: 'Hitung ulang',
            icon: const Icon(Icons.refresh),
            onPressed: _selected == null ? null : () => _selectSpot(_selected!),
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildMap(),
          SolunarPanel(
            day: _solunar,
            spotName: _selected?.name ?? 'Belum ada spot',
            now: _now,
            loading: _calculating,
          ),
          if (_loadingLocation)
            const Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(child: _LoadingChip(text: 'Mengambil lokasi…')),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startTop,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(top: 56),
        child: FloatingActionButton.small(
          heroTag: 'gps',
          tooltip: 'Lokasi saya',
          onPressed: _loadingLocation ? null : _useMyLocation,
          child: const Icon(Icons.my_location),
        ),
      ),
    );
  }

  Widget _buildMap() {
    final center = _selected?.location ?? _fallbackCenter;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 12,
        onLongPress: (tapPos, latlng) => _addSpotAt(latlng),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.fishing_solunar',
          maxZoom: 19,
        ),
        MarkerLayer(markers: _spots.map(_buildMarker).toList()),
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('© OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }

  Marker _buildMarker(FishingSpot spot) {
    final isSelected = spot.id == _selected?.id;
    final isGps = spot.id.startsWith('gps-');

    Color color;
    if (isGps) {
      color = Colors.blue;
    } else if (_solunar != null && isSelected) {
      final rating = SolunarRatingX.fromScore(_solunar!.dayScore * 1.3);
      color = SolunarPanel.ratingColor(rating);
    } else {
      color = Colors.deepOrange;
    }

    return Marker(
      point: spot.location,
      width: 46,
      height: 46,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () => _selectSpot(spot),
        child: Icon(
          isGps ? Icons.my_location : Icons.location_on,
          color: color,
          size: isSelected ? 46 : 38,
          shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
        ),
      ),
    );
  }
}

class _LoadingChip extends StatelessWidget {
  final String text;
  const _LoadingChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(text),
          ],
        ),
      ),
    );
  }
}
