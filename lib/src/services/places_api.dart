import 'dart:convert';
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

/// Simple client that queries the *view* via PostgREST filters.
/// (No RPCs — fewer permission pitfalls.)
class PlacesApi {
  final String baseUrl;
  const PlacesApi({required this.baseUrl});

  Future<List<Place>> fetchInBounds({
    required LatLng southWest,
    required LatLng northEast,
    int limit = 1000,
  }) async {
    // normalize bounds just in case
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

    // PostgREST allows repeated keys: latitude=gte.X&latitude=lte.Y ...
    final qs =
        'latitude=${Uri.encodeComponent('gte.${minLat.toStringAsFixed(6)}')}'
        '&latitude=${Uri.encodeComponent('lte.${maxLat.toStringAsFixed(6)}')}'
        '&longitude=${Uri.encodeComponent('gte.${minLon.toStringAsFixed(6)}')}'
        '&longitude=${Uri.encodeComponent('lte.${maxLon.toStringAsFixed(6)}')}'
        '&limit=$limit';

    final uri = Uri.parse('$baseUrl/v_places_basic?$qs');

    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final List decoded = json.decode(res.body) as List;
    return decoded
        .map((e) => Place.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
