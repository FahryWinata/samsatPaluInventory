import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'supabase_service.dart';

class UpdateInfo {
  final String version;
  final String url;
  final String notes;

  UpdateInfo({required this.version, required this.url, required this.notes});

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] as String,
      url: json['url'] as String,
      notes: json['notes'] as String,
    );
  }
}

class UpdateService {
  // Replace with your actual Supabase Project URL or a fixed remote URL if prefered
  // For this implementation, we will fetch from the 'app-updates' bucket using a public URL.
  // We assume the file is named 'version.json' in 'app-updates' bucket.

  String get _versionFileUrl {
    final client = SupabaseService.client;
    return client.storage.from('app-updates').getPublicUrl('version.json');
  }

  Future<UpdateInfo?> checkForUpdate() async {
    try {
      // 1. Get Current Version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 2. Fetch Remote Version Info
      final response = await http.get(Uri.parse(_versionFileUrl));

      if (response.statusCode != 200) {
        debugPrint('Update check failed: ${response.statusCode}');
        return null;
      }

      final json = jsonDecode(response.body);
      final platformKey = Platform.isAndroid ? 'android' : 'windows';

      if (!json.containsKey(platformKey)) return null;

      final updateInfo = UpdateInfo.fromJson(json[platformKey]);

      // 3. Compare Versions
      // Simple string comparison (assumes semver format like 1.0.0)
      if (_isNewer(updateInfo.version, currentVersion)) {
        return updateInfo;
      }

      return null;
    } catch (e) {
      debugPrint('Error checking for update: $e');
      return null;
    }
  }

  bool _isNewer(String remote, String local) {
    List<int> r = remote.split('.').map(int.parse).toList();
    List<int> l = local.split('.').map(int.parse).toList();

    for (int i = 0; i < r.length; i++) {
      if (i >= l.length) return true; // Remote has more parts (1.0 vs 1.0.1)
      if (r[i] > l[i]) return true;
      if (r[i] < l[i]) return false;
    }
    return false; // Equal
  }

  Future<void> performUpdate(UpdateInfo info) async {
    // Open Browser/Downloader for both Android and Windows
    // This avoids build issues with r_upgrade and provides a reliable fallback
    final uri = Uri.parse(info.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
