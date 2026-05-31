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
// Post model
// ─────────────────────────────────────────────────────────────
class Post {
  final int id;
  final String placeId;
  final String userId;
  final String username;
  final String content;
  final String? imageUrl;
  final String? authorProfileImageUrl;
  final DateTime createdAt;

  const Post({
    required this.id,
    required this.placeId,
    required this.userId,
    required this.username,
    required this.content,
    this.imageUrl,
    this.authorProfileImageUrl,
    required this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> j) {
    return Post(
      id: j['id'] as int,
      placeId: j['place_id'].toString(),
      userId: j['user_id'].toString(),
      username: j['username']?.toString() ?? 'Anonymous',
      content: j['content'].toString(),
      imageUrl: j['image_url']?.toString(),
      authorProfileImageUrl: j['author_profile_image_url']?.toString(),
      createdAt: DateTime.parse(j['created_at'].toString()),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PostReport model (admin panel)
// ─────────────────────────────────────────────────────────────
class PostReport {
  final int postId;
  final String content;
  final String author;
  final String? imageUrl;
  final String placeId;
  final int reportCount;
  final DateTime firstReportedAt;

  const PostReport({
    required this.postId,
    required this.content,
    required this.author,
    this.imageUrl,
    required this.placeId,
    required this.reportCount,
    required this.firstReportedAt,
  });

  factory PostReport.fromJson(Map<String, dynamic> j) {
    return PostReport(
      postId: j['post_id'] as int,
      content: j['content'].toString(),
      author: j['author']?.toString() ?? 'Anonymous',
      imageUrl: j['image_url']?.toString(),
      placeId: j['place_id'].toString(),
      reportCount: int.parse(j['report_count'].toString()),
      firstReportedAt: DateTime.parse(j['first_reported_at'].toString()),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PlaceReport model (admin panel)
// ─────────────────────────────────────────────────────────────
class PlaceReport {
  final String placeId;
  final String name;
  final String category;
  final double latitude;
  final double longitude;
  final int reportCount;
  final DateTime? firstReportedAt;
  final String? reasons;

  const PlaceReport({
    required this.placeId,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.reportCount,
    this.firstReportedAt,
    this.reasons,
  });

  factory PlaceReport.fromJson(Map<String, dynamic> j) => PlaceReport(
        placeId: j['place_id'].toString(),
        name: j['name']?.toString() ?? '',
        category: j['category']?.toString() ?? '',
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        reportCount: int.tryParse(j['report_count'].toString()) ?? 0,
        firstReportedAt: j['first_reported_at'] != null
            ? DateTime.tryParse(j['first_reported_at'].toString())
            : null,
        reasons: j['reasons']?.toString(),
      );
}

// ─────────────────────────────────────────────────────────────
// Comment model
// ─────────────────────────────────────────────────────────────
class Comment {
  final int id;
  final int postId;
  final String userId;
  final String username;
  final String content;
  final String? authorProfileImageUrl;
  final DateTime createdAt;

  const Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.username,
    required this.content,
    this.authorProfileImageUrl,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> j) {
    return Comment(
      id: j['id'] as int,
      postId: j['post_id'] as int,
      userId: j['user_id'].toString(),
      username: j['username']?.toString() ?? 'Anonymous',
      content: j['content'].toString(),
      authorProfileImageUrl: j['author_profile_image_url']?.toString(),
      createdAt: DateTime.parse(j['created_at'].toString()),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Friend / user search model
// ─────────────────────────────────────────────────────────────
class FriendUser {
  final String userId;
  final String? displayName;
  final String? email;
  final String? profileImageUrl;
  final String friendshipStatus; // 'friend' | 'sent' | 'incoming' | 'none'

  const FriendUser({
    required this.userId,
    this.displayName,
    this.email,
    this.profileImageUrl,
    this.friendshipStatus = 'none',
  });

  String get label =>
      displayName?.isNotEmpty == true ? displayName! : (email ?? userId);

  factory FriendUser.fromJson(Map<String, dynamic> j) => FriendUser(
        userId: j['user_id'].toString(),
        displayName: j['display_name']?.toString(),
        email: j['email']?.toString(),
        profileImageUrl: j['profile_image_url']?.toString(),
        friendshipStatus: j['friendship_status']?.toString() ?? 'none',
      );
}

// ─────────────────────────────────────────────────────────────
// Navigate Together models
// ─────────────────────────────────────────────────────────────
class NavInvite {
  final String sessionId;
  final String creatorId;
  final String creatorName;
  final String? creatorImage;
  final double? destinationLat;
  final double? destinationLng;
  final String? destinationName;

  const NavInvite({
    required this.sessionId,
    required this.creatorId,
    required this.creatorName,
    this.creatorImage,
    this.destinationLat,
    this.destinationLng,
    this.destinationName,
  });

  bool get hasDestination => destinationLat != null && destinationLng != null;

  factory NavInvite.fromJson(Map<String, dynamic> j) => NavInvite(
        sessionId: j['session_id'].toString(),
        creatorId: j['creator_id'].toString(),
        creatorName: j['creator_name']?.toString() ?? 'Someone',
        creatorImage: j['creator_image']?.toString(),
        destinationLat: j['destination_lat'] == null
            ? null
            : (j['destination_lat'] as num).toDouble(),
        destinationLng: j['destination_lng'] == null
            ? null
            : (j['destination_lng'] as num).toDouble(),
        destinationName: j['destination_name']?.toString(),
      );
}

class PartnerLocation {
  final double lat;
  final double lng;
  final double? remainingKm;
  final DateTime updatedAt;

  const PartnerLocation({
    required this.lat,
    required this.lng,
    this.remainingKm,
    required this.updatedAt,
  });

  factory PartnerLocation.fromJson(Map<String, dynamic> j) => PartnerLocation(
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        remainingKm: j['remaining_km'] == null
            ? null
            : (j['remaining_km'] as num).toDouble(),
        updatedAt: DateTime.parse(j['updated_at'].toString()),
      );
}

// ─────────────────────────────────────────────────────────────
// UserStats model
// ─────────────────────────────────────────────────────────────
class UserStats {
  final double totalKm;
  final int totalNavigations;
  final int postsCount;
  final Map<String, int> visitsByCategory;
  final int totalVisits;

  const UserStats({
    required this.totalKm,
    required this.totalNavigations,
    required this.postsCount,
    required this.visitsByCategory,
    required this.totalVisits,
  });

  factory UserStats.fromJson(Map<String, dynamic> j) {
    final raw = (j['visits_by_category'] as Map<String, dynamic>? ?? {});
    final visits = raw.map((k, v) => MapEntry(k, (v as num).toInt()));
    return UserStats(
      totalKm:           (j['total_km']          as num?)?.toDouble() ?? 0,
      totalNavigations:  (j['total_navigations']  as num?)?.toInt()    ?? 0,
      postsCount:        (j['posts_count']        as num?)?.toInt()    ?? 0,
      visitsByCategory:  visits,
      totalVisits:       (j['total_visits']       as num?)?.toInt()    ?? 0,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// LeaderboardEntry model
// ─────────────────────────────────────────────────────────────
class LeaderboardEntry {
  final String userId;
  final String displayName;
  final String? profileImageUrl;
  final int totalXp;
  final int rank;

  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    this.profileImageUrl,
    required this.totalXp,
    required this.rank,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
        userId:         j['user_id'].toString(),
        displayName:    j['display_name']?.toString() ?? 'Anonymous',
        profileImageUrl: j['profile_image_url']?.toString(),
        totalXp:        (j['total_xp'] as num?)?.toInt() ?? 0,
        rank:           (j['rank'] as num?)?.toInt() ?? 0,
      );
}

// ─────────────────────────────────────────────────────────────
// VersionInfo model
// ─────────────────────────────────────────────────────────────
class VersionInfo {
  final String version;
  final String downloadUrl;
  final String? releaseNotes;

  const VersionInfo({
    required this.version,
    required this.downloadUrl,
    this.releaseNotes,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> j) => VersionInfo(
        version:      j['version'].toString(),
        downloadUrl:  j['download_url'].toString(),
        releaseNotes: j['release_notes']?.toString(),
      );
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

  /// Hits the health endpoint — call on app startup to wake a sleeping server.
  Future<void> warmUp() async {
    try {
      await http.get(Uri.parse(baseUrl)).timeout(const Duration(seconds: 30));
    } catch (_) {}
  }

  /// Checks GitHub Releases for the latest published APK version.
  Future<VersionInfo?> fetchVersionInfo() async {
    try {
      final res = await http
          .get(
            Uri.parse(
                'https://api.github.com/repos/YDap/PathFinder_PapTamas/releases/latest'),
            headers: {'Accept': 'application/vnd.github.v3+json'},
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return null;
      final body = json.decode(res.body) as Map<String, dynamic>;
      final tag =
          (body['tag_name'] as String? ?? '').replaceFirst(RegExp(r'^v'), '');
      if (tag.isEmpty) return null;

      final assets = (body['assets'] as List? ?? []);
      Map<String, dynamic>? apkAsset;
      for (final a in assets) {
        if ((a['name'] as String? ?? '').endsWith('.apk')) {
          apkAsset = a as Map<String, dynamic>;
          break;
        }
      }

      return VersionInfo(
        version: tag,
        downloadUrl: apkAsset != null
            ? apkAsset['browser_download_url'].toString()
            : 'https://github.com/YDap/PathFinder_PapTamas/releases/latest',
      );
    } catch (_) {
      return null;
    }
  }

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
          .timeout(const Duration(seconds: 30));

      return _parsePlaceList(res);
    } on TimeoutException {
      throw Exception('Request timed out. Check your internet connection and try again.');
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
          .timeout(const Duration(seconds: 30));
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
          .timeout(const Duration(seconds: 30));
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
          .timeout(const Duration(seconds: 30));
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
          .timeout(const Duration(seconds: 45));
      if (res.statusCode != 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        throw Exception(body['error'] ?? 'AI query failed');
      }
      return AiQueryResult.fromJson(
          json.decode(res.body) as Map<String, dynamic>);
    } on TimeoutException {
      throw Exception('AI query timed out. Please try again.');
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  /// GET /posts/:postId/comments
  Future<List<Comment>> fetchComments(int postId) async {
    final uri = Uri.parse('$baseUrl/posts/$postId/comments');
    try {
      final res = await http
          .get(uri, headers: _jsonHeaders)
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }
      final List decoded = json.decode(res.body) as List;
      return decoded
          .map((e) => Comment.fromJson(e as Map<String, dynamic>))
          .toList();
    } on TimeoutException {
      throw Exception('Timeout fetching comments');
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  /// POST /posts/:postId/comments  (requires auth)
  Future<Comment> createComment(int postId, String content) async {
    final uri = Uri.parse('$baseUrl/posts/$postId/comments');
    try {
      final headers = await _authHeaders();
      final res = await http
          .post(uri,
              headers: headers, body: json.encode({'content': content}))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 201) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        throw Exception(body['error'] ?? 'Failed to post comment');
      }
      return Comment.fromJson(json.decode(res.body) as Map<String, dynamic>);
    } on TimeoutException {
      throw Exception('Timeout posting comment');
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  /// GET /users/profile-image — returns { profile_image_url, is_admin }
  Future<({String? imageUrl, bool isAdmin})> fetchCurrentUser() async {
    final uri = Uri.parse('$baseUrl/users/profile-image');
    try {
      final headers = await _authHeaders();
      final res = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return (imageUrl: null, isAdmin: false);
      final body = json.decode(res.body) as Map<String, dynamic>;
      final rel = body['profile_image_url']?.toString();
      return (
        imageUrl: rel != null ? '$baseUrl$rel' : null,
        isAdmin: body['is_admin'] == true,
      );
    } catch (_) {
      return (imageUrl: null, isAdmin: false);
    }
  }

  /// POST /posts/:postId/report  (requires auth)
  Future<void> reportPost(int postId) async {
    final uri = Uri.parse('$baseUrl/posts/$postId/report');
    try {
      final headers = await _authHeaders();
      await http.post(uri, headers: headers).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw Exception('Timeout reporting post');
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  /// GET /admin/reports  (requires admin)
  Future<List<PostReport>> fetchReports() async {
    final uri = Uri.parse('$baseUrl/admin/reports');
    try {
      final headers = await _authHeaders();
      final res = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final List decoded = json.decode(res.body) as List;
      return decoded
          .map((e) => PostReport.fromJson(e as Map<String, dynamic>))
          .toList();
    } on TimeoutException {
      throw Exception('Timeout fetching reports');
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  /// DELETE /admin/posts/:postId  (requires admin)
  Future<void> adminDeletePost(int postId) async {
    final uri = Uri.parse('$baseUrl/admin/posts/$postId');
    final headers = await _authHeaders();
    await http.delete(uri, headers: headers).timeout(const Duration(seconds: 30));
  }

  /// DELETE /admin/comments/:commentId  (requires admin)
  Future<void> adminDeleteComment(int commentId) async {
    final uri = Uri.parse('$baseUrl/admin/comments/$commentId');
    final headers = await _authHeaders();
    await http.delete(uri, headers: headers).timeout(const Duration(seconds: 30));
  }

  /// DELETE /admin/reports/:postId — dismiss reports without deleting post
  Future<void> dismissReports(int postId) async {
    final uri = Uri.parse('$baseUrl/admin/reports/$postId');
    final headers = await _authHeaders();
    await http.delete(uri, headers: headers).timeout(const Duration(seconds: 30));
  }

  /// GET /places/ratings/my  (requires auth)
  Future<List<Place>> fetchMyRatings() async {
    final uri = Uri.parse('$baseUrl/places/ratings/my');
    try {
      final headers = await _authHeaders();
      final res = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));
      return _parsePlaceList(res);
    } on TimeoutException {
      throw Exception('Timeout fetching ratings');
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  /// GET /posts?place_id=X
  Future<List<Post>> fetchPosts(String placeId) async {
    final uri = Uri.parse('$baseUrl/posts')
        .replace(queryParameters: {'place_id': placeId});
    try {
      final res = await http
          .get(uri, headers: _jsonHeaders)
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }
      final List decoded = json.decode(res.body) as List;
      return decoded
          .map((e) => Post.fromJson(e as Map<String, dynamic>))
          .toList();
    } on TimeoutException {
      throw Exception('Timeout fetching posts');
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  /// POST /posts  (multipart, requires auth)
  Future<Post> createPost({
    required String placeId,
    required String content,
    File? image,
  }) async {
    final uri = Uri.parse('$baseUrl/posts');
    try {
      final token = await _getToken();
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['place_id'] = placeId
        ..fields['content'] = content;

      if (image != null) {
        request.files.add(await http.MultipartFile.fromPath('image', image.path));
      }

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode != 201) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        throw Exception(body['error'] ?? 'Failed to create post');
      }
      return Post.fromJson(json.decode(res.body) as Map<String, dynamic>);
    } on TimeoutException {
      throw Exception('Timeout creating post');
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  // ── Friends ───────────────────────────────────────────────

  Future<List<FriendUser>> getFriends() async {
    final token = await _getToken();
    final res = await http.get(Uri.parse('$baseUrl/friends'),
        headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'});
    if (res.statusCode != 200) throw Exception('Failed to load friends');
    return (json.decode(res.body) as List)
        .map((j) => FriendUser.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<FriendUser>> getFriendRequests() async {
    final token = await _getToken();
    final res = await http.get(Uri.parse('$baseUrl/friends/requests'),
        headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'});
    if (res.statusCode != 200) throw Exception('Failed to load requests');
    return (json.decode(res.body) as List)
        .map((j) => FriendUser.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<FriendUser>> searchUsers(String q) async {
    final token = await _getToken();
    final uri = Uri.parse('$baseUrl/friends/search').replace(queryParameters: {'q': q});
    final res = await http.get(uri,
        headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'});
    if (res.statusCode != 200) return [];
    return (json.decode(res.body) as List)
        .map((j) => FriendUser.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> sendFriendRequest(String targetUserId) async {
    final token = await _getToken();
    final res = await http.post(Uri.parse('$baseUrl/friends/request'),
        headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
        body: json.encode({'targetUserId': targetUserId}));
    if (res.statusCode != 200) {
      final body = json.decode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Failed to send request');
    }
  }

  Future<void> acceptFriendRequest(String requesterId) async {
    final token = await _getToken();
    final res = await http.post(Uri.parse('$baseUrl/friends/accept/$requesterId'),
        headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'});
    if (res.statusCode != 200) throw Exception('Failed to accept request');
  }

  Future<void> removeFriend(String otherUserId) async {
    final token = await _getToken();
    final res = await http.delete(Uri.parse('$baseUrl/friends/$otherUserId'),
        headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'});
    if (res.statusCode != 200) throw Exception('Failed to remove friend');
  }

  // ── Navigate Together ────────────────────────────────────

  /// POST /places/suggest  (multipart, requires auth) — returns new place ID
  Future<String> submitPlace({
    required String name,
    required String category,
    required double lat,
    required double lng,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('$baseUrl/places/suggest');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['name'] = name
      ..fields['category'] = category
      ..fields['lat'] = lat.toString()
      ..fields['lng'] = lng.toString();
    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) {
      final body = json.decode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Failed to submit place');
    }
    final body = json.decode(res.body) as Map<String, dynamic>;
    return body['id'].toString();
  }

  /// POST /places/:id/report  (requires auth)
  Future<void> reportPlace(String placeId, {required String reason}) async {
    final uri = Uri.parse('$baseUrl/places/$placeId/report');
    try {
      final headers = await _authHeaders();
      await http
          .post(uri, headers: headers, body: json.encode({'reason': reason}))
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw Exception('Timeout reporting place');
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  /// GET /admin/place-reports  (requires admin)
  Future<List<PlaceReport>> fetchPlaceReports() async {
    final uri = Uri.parse('$baseUrl/admin/place-reports');
    try {
      final headers = await _authHeaders();
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final List decoded = json.decode(res.body) as List;
      return decoded.map((e) => PlaceReport.fromJson(e as Map<String, dynamic>)).toList();
    } on TimeoutException {
      throw Exception('Timeout fetching place reports');
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  /// DELETE /admin/places/:placeId  (requires admin)
  Future<void> adminDeletePlace(String placeId) async {
    final uri = Uri.parse('$baseUrl/admin/places/$placeId');
    final headers = await _authHeaders();
    await http.delete(uri, headers: headers).timeout(const Duration(seconds: 30));
  }

  /// DELETE /admin/place-reports/:placeId  (requires admin)
  Future<void> adminDismissPlaceReports(String placeId) async {
    final uri = Uri.parse('$baseUrl/admin/place-reports/$placeId');
    final headers = await _authHeaders();
    await http.delete(uri, headers: headers).timeout(const Duration(seconds: 30));
  }

  Future<String> inviteToNavigate(
    String partnerUserId, {
    double? destinationLat,
    double? destinationLng,
    String? destinationName,
  }) async {
    final token = await _getToken();
    final body = <String, dynamic>{'partnerUserId': partnerUserId};
    if (destinationLat != null) body['destinationLat'] = destinationLat;
    if (destinationLng != null) body['destinationLng'] = destinationLng;
    if (destinationName != null) body['destinationName'] = destinationName;
    final res = await http.post(Uri.parse('$baseUrl/navigate/invite'),
        headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
        body: json.encode(body));
    if (res.statusCode != 200) {
      final errBody = json.decode(res.body) as Map<String, dynamic>;
      throw Exception(errBody['error'] ?? 'Failed to send invite (${res.statusCode})');
    }
    return (json.decode(res.body) as Map<String, dynamic>)['session_id'].toString();
  }

  Future<NavInvite?> getPendingNavInvite() async {
    final token = await _getToken();
    final res = await http.get(Uri.parse('$baseUrl/navigate/pending'),
        headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'});
    if (res.statusCode != 200) return null;
    final body = json.decode(res.body);
    if (body == null) return null;
    return NavInvite.fromJson(body as Map<String, dynamic>);
  }

  Future<void> acceptNavSession(String sessionId) async {
    final token = await _getToken();
    await http.post(Uri.parse('$baseUrl/navigate/accept/$sessionId'),
        headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'});
  }

  Future<void> declineNavSession(String sessionId) async {
    final token = await _getToken();
    await http.post(Uri.parse('$baseUrl/navigate/decline/$sessionId'),
        headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'});
  }

  Future<void> updateNavLocation(String sessionId, double lat, double lng,
      {double? remainingKm}) async {
    final token = await _getToken();
    final body = <String, dynamic>{'sessionId': sessionId, 'lat': lat, 'lng': lng};
    if (remainingKm != null) body['remainingKm'] = remainingKm;
    await http.put(Uri.parse('$baseUrl/navigate/location'),
        headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
        body: json.encode(body));
  }

  /// Returns { status, partnerLocation, destination }
  Future<({
    String status,
    PartnerLocation? partnerLocation,
    ({double lat, double lng, String? name})? destination,
  })> getPartnerNavLocation(String sessionId) async {
    final token = await _getToken();
    final res = await http.get(
        Uri.parse('$baseUrl/navigate/partner-location/$sessionId'),
        headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'});
    if (res.statusCode != 200) {
      return (status: 'ended', partnerLocation: null, destination: null);
    }
    final body = json.decode(res.body) as Map<String, dynamic>;
    final status = body['status']?.toString() ?? 'ended';
    final locJson = body['partner_location'];
    final loc = locJson != null
        ? PartnerLocation.fromJson(locJson as Map<String, dynamic>)
        : null;
    final destJson = body['destination'] as Map<String, dynamic>?;
    final dest = destJson != null
        ? (
            lat: (destJson['lat'] as num).toDouble(),
            lng: (destJson['lng'] as num).toDouble(),
            name: destJson['name']?.toString(),
          )
        : null;
    return (status: status, partnerLocation: loc, destination: dest);
  }

  Future<void> endNavSession(String sessionId) async {
    final token = await _getToken();
    await http.delete(Uri.parse('$baseUrl/navigate/session/$sessionId'),
        headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'});
  }

  // ── Leaderboard ──────────────────────────────────────────────

  Future<List<LeaderboardEntry>> fetchLeaderboard() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/leaderboard'), headers: _jsonHeaders)
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final List decoded = json.decode(res.body) as List;
      return decoded.map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>)).toList();
    } on TimeoutException {
      throw Exception('Leaderboard request timed out');
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  // ── Stats & Achievements ─────────────────────────────────────

  Future<void> recordVisit({
    required String placeId,
    required String placeName,
    required String category,
  }) async {
    final headers = await _authHeaders();
    await http
        .post(Uri.parse('$baseUrl/stats/visit'),
            headers: headers,
            body: json.encode({'placeId': placeId, 'placeName': placeName, 'category': category}))
        .timeout(const Duration(seconds: 30));
  }

  Future<void> addKm(double km) async {
    if (km <= 0) return;
    final headers = await _authHeaders();
    await http
        .post(Uri.parse('$baseUrl/stats/km'),
            headers: headers,
            body: json.encode({'km': km}))
        .timeout(const Duration(seconds: 30));
  }

  Future<UserStats> fetchMyStats() async {
    final headers = await _authHeaders();
    final res = await http
        .get(Uri.parse('$baseUrl/stats/me'), headers: headers)
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) throw Exception('Failed to fetch stats');
    return UserStats.fromJson(json.decode(res.body) as Map<String, dynamic>);
  }
}
