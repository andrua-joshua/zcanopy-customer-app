import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';

class CloudinaryService {
  static const String _boxName = 'cloudinary_config';
  static const String _cloudNameKey = 'cloud_name';
  static const String _uploadPresetKey = 'upload_preset';
  static const String _baseUrl = 'https://api.cloudinary.com/v1_1';

  static Future<String> get _cloudName async {
    final box = await Hive.openBox(_boxName);
    return box.get(_cloudNameKey, defaultValue: '') as String;
  }

  static Future<String> get _uploadPreset async {
    final box = await Hive.openBox(_boxName);
    return box.get(_uploadPresetKey, defaultValue: '') as String;
  }

  static Future<void> configure({
    required String cloudName,
    required String uploadPreset,
  }) async {
    final box = await Hive.openBox(_boxName);
    await box.put(_cloudNameKey, cloudName);
    await box.put(_uploadPresetKey, uploadPreset);
  }

  static Future<Map<String, dynamic>> uploadFile({
    required File file,
    String folder = 'zcanopy/properties',
    String resourceType = 'auto',
  }) async {
    final cloudName = await _cloudName;
    final uploadPreset = await _uploadPreset;

    if (cloudName.isEmpty || uploadPreset.isEmpty) {
      throw Exception('Cloudinary is not configured. Call CloudinaryService.configure() first.');
    }

    final uri = Uri.parse('$_baseUrl/$cloudName/$resourceType/upload');
    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      await http.MultipartFile.fromPath('file', file.path),
    );
    request.fields['upload_preset'] = uploadPreset;
    request.fields['folder'] = folder;

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Cloudinary upload failed: ${response.statusCode} $responseBody');
    }

    return jsonDecode(responseBody) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> uploadMultipleFiles({
    required List<File> files,
    String folder = 'zcanopy/properties',
    String resourceType = 'auto',
  }) async {
    final List<Map<String, dynamic>> results = [];
    for (final file in files) {
      final result = await uploadFile(file: file, folder: folder, resourceType: resourceType);
      results.add(result);
    }
    return results;
  }

  static String getSecureUrl(Map<String, dynamic> uploadResult) {
    return uploadResult['secure_url']?.toString() ?? '';
  }

  static String getPublicId(Map<String, dynamic> uploadResult) {
    return uploadResult['public_id']?.toString() ?? '';
  }
}
