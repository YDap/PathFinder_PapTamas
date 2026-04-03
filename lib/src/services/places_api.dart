import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

// ─────────────────────────────────────────────────────────────
// Place model
// ─────────────────────────────────────────────────────────────
class Place {
  final String id;
  final String name;
  final String category;
  final int? elevationM;
  final double latitude;
  final double longitude;
  final double? averageRating;
  final int ratingCount;
  final String? description;
  final dynamic images;
  final Map<String, dynamic>? tags;
  final double? distanceKm;

  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.elevationM,
    this.averageRating,
    this.ratingCount = 0,
    this.description,
    this.images,
    this.tags,
    this.distanceKm,
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
      averageRating: j['avg_rating'] == null
          ? null
          : double.tryParse(j['avg_rating'].toString()),
      ratingCount: j['rating_count'] == null
          ? 0
          : int.tryParse(j['rating_count'].toString()) ?? 0,
      description: j['description']?.toString(),
      images: j['images'],
      tags: j['tags'] != null ? Map<String, dynamic>.from(j['tags']) : null,
      distanceKm: j['distance_km'] == null
          ? null
          : double.tryParse(j['distance_km'].toString()),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AiQueryResult model
// ─────────────────────────────────────────────────────────────
class AiQueryResult {
  final String message;
  final List<Place> places;

  const AiQueryResult({required this.message, required this.places});

  factory AiQueryResult.fromJson(Map<String, dynamic> j) {
    return AiQueryResult(
      message: (j['message'] ?? '').toString(),
      places: (j['places'] as List? ?? [])
          .map((e) => Place.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PlacesApi
// ─────────────────────────────────────────────────────────────
class PlacesApi {
  final String baseUrl;
  const PlacesApi({required this.baseUrl});

  Future<String> _getToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User is not logged in');
    final token = await user.getIdToken();
    if (token == null) throw Exception('Could not retrieve auth token');
    return token;
  }

  Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
      };

  Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  List<Place> _parsePlaceList(http.Response res) {
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final List decoded = json.decode(res.body) as List;
    return decoded
        .map((e) => Place.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /places?lat=&lng=&radius=
  Future<List<Place>> fetchInBounds({
    required LatLng southWest,
    required LatLng northEast,
    int limit = 1000,
  }) async {
    final centerLat = (southWest.latitude + northEast.latitude) / 2;
    final centerLng = (southWest.longitude + northEast.longitude) / 2;
    final radius =
        ((northEast.latitude - southWest.latitude) / 2).abs().clamp(0.01, 5.0);

    final uri = Uri.parse('$baseUrl/places').replace(queryParameters: {
      'lat': centerLat.toStringAsFixed(6),
      'lng': centerLng.toStringAsFixed(6),
      'radius': radius.toStringAsFixed(6),
    });

    try {
      final res = await http
          .get(uri, headers: _jsonHeaders)
          .timeout(const Duration(seconds: 10));

      return _parsePlaceList(res);
    } on TimeoutException {
      throw Exception('Timeout reaching $baseUrl. '
          'Make sure adb reverse tcp:3000 tcp:3000 is running.');
    } on SocketException catch (e) {
      throw Exception('Network error to $baseUrl: ${e.message}');
    }
  }

  /// GET /places/search?q=
  Future<List<Place>> searchPlaces(String query) async {
    final uri = Uri.parse('$baseUrl/places/search')
        .replace(queryParameters: {'q': query});
    try {
      final res = await http
          .get(uri, headers: _jsonHeaders)
          .timeout(const Duration(seconds: 10));
      return _parsePlaceList(res);
    } on TimeoutException {
      throw Exception('Timeout searching places');
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  /// GET /places/:id
  Future<Place> fetchPlaceById(String id) async {
    final uri = Uri.parse('$baseUrl/places/$id');
    try {
      final res = await http
          .get(uri, headers: _jsonHeaders)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 404) throw Exception('Place not found');
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }
      return Place.fromJson(json.decode(res.body) as Map<String, dynamic>);
    } on TimeoutException {
      throw Exception('Timeout fetching place');
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  /// POST /places/:id/rate  (requires auth)
  Future<void> ratePlace(String placeId, int rating) async {
    final uri = Uri.parse('$baseUrl/places/$placeId/rate');
    try {
      final headers = await _authHeaders();
      final res = await http
          .post(
            uri,
            headers: headers,
            body: json.encode({'rating': rating}),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 201) {
        final body = json.decode(res.body);
        throw Exception(body['error'] ?? 'Failed to submit rating');
      }
    } on TimeoutException {
      throw Exception('Timeout submitting rating');
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  /// POST /ai/query — natural language place search
  Future<AiQueryResult> queryAI({
    required String message,
    required double lat,
    required double lng,
  }) async {
    final uri = Uri.parse('$baseUrl/ai/query');
    try {
      final res = await http
          .post(
            uri,
            headers: _jsonHeaders,
            body: json.encode({'message': message, 'lat': lat, 'lng': lng}),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        throw Exception(body['error'] ?? 'AI query failed');
      }
      return AiQueryResult.fromJson(
          json.decode(res.body) as Map<String, dynamic>);
    } on TimeoutException {
      throw Exception('AI query timed out — Gemini may be slow, try again');
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  /// GET /places/ratings/my  (requires auth)
  Future<List<Place>> fetchMyRatings() async {
    final uri = Uri.parse('$baseUrl/places/ratings/my');
    try {
      final headers = await _authHeaders();
      final res = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
      return _parsePlaceList(res);
    } on TimeoutException {
      throw Exception('Timeout fetching ratings');
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }
}
