import 'dart:convert';

import 'package:http/http.dart' as http;

/// The dev/update server. Hosts the latest web build plus a `version.json`
/// manifest describing what is available.
const String kUpdateServerUrl = 'http://localhost:39154/';

/// Version info advertised by the update server's `version.json`.
class UpdateInfo {
  const UpdateInfo({
    required this.appName,
    required this.version,
    required this.buildNumber,
    required this.packageName,
  });

  final String appName;
  final String version;
  final String buildNumber;
  final String packageName;

  /// Semantic version comparison (e.g. 1.2.10 > 1.2.9).
  /// Returns >0 if [a] is newer, <0 if older, 0 when equal.
  static int _compareParts(List<int> a, List<int> b) {
    final len = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < len; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  static List<int> _parts(String version) => [
        for (final part in version.trim().split('.'))
          int.tryParse(part.trim()) ?? 0,
      ];

  /// True when this advertised version is newer than [localVersion] (with an
  /// optional [localBuildNumber] tiebreaker).
  bool isNewerThan(String localVersion, {String? localBuildNumber}) {
    final cmp = _compareParts(_parts(version), _parts(localVersion));
    if (cmp != 0) return cmp > 0;
    final localBuild = int.tryParse(localBuildNumber ?? '') ?? 0;
    final remoteBuild = int.tryParse(buildNumber) ?? 0;
    return remoteBuild > localBuild;
  }

  factory UpdateInfo.fromJson(Map<String, dynamic> json) => UpdateInfo(
        appName: json['app_name'] as String? ?? '',
        version: json['version'] as String? ?? '0.0.0',
        buildNumber: json['build_number'] as String? ?? '0',
        packageName: json['package_name'] as String? ?? '',
      );
}

/// Fetches the current advertised version from the update server.
/// Returns null on any failure (offline, CORS, malformed payload) so the
/// caller can stay silent.
Future<UpdateInfo?> fetchLatestUpdate() async {
  try {
    final uri = Uri.parse('$kUpdateServerUrl/version.json');
    final res = await http.get(uri).timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return null;
    return UpdateInfo.fromJson(decoded);
  } catch (_) {
    return null;
  }
}
