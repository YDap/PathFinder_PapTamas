import 'dart:io';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileService {
  static const String _profileImageUrlKey = 'profile_image_url';
  final String baseUrl;

  ProfileService({this.baseUrl = 'http://127.0.0.1:3001'});

  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> _getToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  /// Pick an image from gallery or camera
  Future<File?> pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (pickedFile != null) return File(pickedFile.path);
    } catch (e) {
      print('Error picking image: $e');
    }
    return null;
  }

  /// Upload profile image to backend and return the full download URL.
  /// Throws a descriptive [Exception] on failure.
  Future<String> uploadProfileImage(File imageFile) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not logged in');

    final uri = Uri.parse('$baseUrl/users/profile-image');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode != 200) {
      String detail = '';
      try {
        final body = json.decode(res.body) as Map<String, dynamic>;
        detail = body['error']?.toString() ?? '';
      } catch (_) {}
      throw Exception(
          'Server error ${res.statusCode}${detail.isNotEmpty ? ": $detail" : ""}');
    }

    final body = json.decode(res.body) as Map<String, dynamic>;
    final relativePath = body['profile_image_url'] as String?;
    if (relativePath == null) throw Exception('Server returned no image URL');

    final downloadUrl = '$baseUrl$relativePath';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileImageUrlKey, downloadUrl);

    return downloadUrl;
  }

  /// Get profile image URL — tries cache first, then fetches from backend
  Future<String?> getProfileImageUrl() async {
    // Return cached value immediately if available
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_profileImageUrlKey);
    if (cached != null) return cached;

    // Otherwise fetch from backend
    try {
      final token = await _getToken();
      if (token == null) return null;

      final uri = Uri.parse('$baseUrl/users/profile-image');
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return null;

      final body = json.decode(res.body) as Map<String, dynamic>;
      final relativePath = body['profile_image_url'] as String?;
      if (relativePath == null) return null;

      final downloadUrl = '$baseUrl$relativePath';
      await prefs.setString(_profileImageUrlKey, downloadUrl);
      return downloadUrl;
    } catch (e) {
      print('Error fetching profile image: $e');
      return null;
    }
  }

  /// Clear cached profile image URL (call on logout)
  Future<void> clearProfileImageUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileImageUrlKey);
  }
}
