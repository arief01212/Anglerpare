import 'package:geolocator/geolocator.dart';

/// Pembungkus tipis di atas geolocator untuk mengambil lokasi GPS perangkat.
class LocationService {
  /// Mengambil posisi pengguna saat ini. Akan meminta izin bila perlu.
  ///
  /// Melempar [LocationException] dengan pesan yang ramah pengguna bila
  /// layanan lokasi mati atau izin ditolak.
  static Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException(
          'Layanan lokasi (GPS) perangkat sedang nonaktif. Aktifkan dulu.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationException('Izin lokasi ditolak.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
          'Izin lokasi ditolak permanen. Aktifkan lewat Pengaturan aplikasi.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }
}

class LocationException implements Exception {
  final String message;
  const LocationException(this.message);

  @override
  String toString() => message;
}
