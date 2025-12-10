import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class Place {
  final String id;
  final String name;
  final String category;
  final int? elevationM;
  final double latitude;
  final double longitude;

  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.elevationM,
  });

  factory Place.fromJson(Map<String, dynamic> j) {
    return Place(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? 'Unknown').toString(),
      category: (j['category'] ?? 'unknown').toString(),
      elevationM: j['elevation_m'] == null
          ? null
          : int.tryParse(j['elevation_m'].toString()),
      latitude: (j['latitude'] as num).toDouble(),
      longitude: (j['longitude'] as num).toDouble(),
    );
  }
}

/// Queries the *view* via PostgREST with a single AND-composite filter.
/// Example: and=(latitude.gte.45,latitude.lte.46,longitude.gte.23,longitude.lte.25)&limit=1000
class PlacesApi {
  final String baseUrl;
  const PlacesApi({required this.baseUrl});

  Future<List<Place>> fetchInBounds({
    required LatLng southWest,
    required LatLng northEast,
    int limit = 1000,
  }) async {
    // Normalize bounds (in case they arrive inverted)
    final minLat = southWest.latitude < northEast.latitude
        ? southWest.latitude
        : northEast.latitude;
    final maxLat = southWest.latitude < northEast.latitude
        ? northEast.latitude
        : southWest.latitude;
    final minLon = southWest.longitude < northEast.longitude
        ? southWest.longitude
        : northEast.longitude;
    final maxLon = southWest.longitude < northEast.longitude
        ? northEast.longitude
        : southWest.longitude;

    final andValue = '(${[
      'latitude.gte.${minLat.toStringAsFixed(6)}',
      'latitude.lte.${maxLat.toStringAsFixed(6)}',
      'longitude.gte.${minLon.toStringAsFixed(6)}',
      'longitude.lte.${maxLon.toStringAsFixed(6)}',
    ].join(',')})';

    // Let Uri handle the encoding of () , .
    final uri = Uri.parse('$baseUrl/v_places_basic')
        .replace(queryParameters: {'and': andValue, 'limit': '$limit'});

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }

      final List decoded = json.decode(res.body) as List;
      return decoded
          .map((e) => Place.fromJson(e as Map<String, dynamic>))
          .toList();
    } on TimeoutException catch (e) {
      throw Exception(
          'Timeout reaching $baseUrl. If running on a real phone, use USB + "adb reverse tcp:3000 tcp:3000" '
          'OR ensure Wi-Fi allows phone→PC on port 3000. $e');
    } on SocketException catch (e) {
      throw Exception('Network error to $baseUrl: ${e.message}');
    }
  }
}
