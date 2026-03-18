import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileService {
  static const String _profileImageUrlKey = 'profile_image_url';

  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Pick an image from gallery or camera
  Future<File?> pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } catch (e) {
      print('Error picking image: $e');
    }
    return null;
  }

  /// Upload image to Firebase Storage and return download URL
  Future<String?> uploadProfileImage(File imageFile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      // Create a unique filename
      final fileName =
          '${user.uid}_profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = _storage.ref().child('profile_images/$fileName');

      // Upload the file
      final uploadTask = storageRef.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Wait for upload to complete
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Save URL locally for caching
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_profileImageUrlKey, downloadUrl);

      return downloadUrl;
    } catch (e) {
      print('Error uploading profile image: $e');
      return null;
    }
  }

  /// Get cached profile image URL
  Future<String?> getProfileImageUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_profileImageUrlKey);
  }

  /// Clear cached profile image URL
  Future<void> clearProfileImageUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileImageUrlKey);
  }

  /// Delete profile image from Firebase Storage
  Future<void> deleteProfileImage() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get current image URL to extract the path
      final currentUrl = await getProfileImageUrl();
      if (currentUrl != null) {
        // Extract the path from the Firebase Storage URL
        final uri = Uri.parse(currentUrl);
        final pathSegments = uri.pathSegments;
        if (pathSegments.length >= 2) {
          final imagePath =
              '${pathSegments[pathSegments.length - 2]}/${pathSegments.last}';
          await _storage.ref().child(imagePath).delete();
        }
      }

      // Clear local cache
      await clearProfileImageUrl();
    } catch (e) {
      print('Error deleting profile image: $e');
    }
  }
}
