import 'package:dio/dio.dart';
import 'package:we_pei_yang_flutter/commons/util/log/log.dart';

import 'version_data.dart';

// Public GitHub requests must not carry campus credentials or a bundled token.
final forkUpdateDio = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 8),
  receiveTimeout: const Duration(seconds: 12),
  headers: {
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
  },
));

class ForkUpdateService {
  static const repository = 'huaaaajjj/WePeiYang-Flutter';
  static const releasesUrl = 'https://github.com/$repository/releases/latest';
  static const apiUrl =
      'https://api.github.com/repos/$repository/releases/latest';
  static final _tagPattern = RegExp(r'^v(\d+\.\d+\.\d+)-pad\.\d+$');

  static String _releaseTag(Map release) {
    final tag = release['tag_name'];
    if (release['draft'] != false ||
        release['prerelease'] != false ||
        tag is! String ||
        !_tagPattern.hasMatch(tag)) {
      throw const FormatException('Not a stable For Pad release');
    }
    return tag;
  }

  static Future<AndroidVersion?> get latestAndroidVersion async {
    try {
      final response = await forkUpdateDio.get<Map<String, dynamic>>(apiUrl);
      final release = response.data!;
      final tag = _releaseTag(release);
      // ponytail: tagged pubspec is the build-number source; no second update
      // manifest to maintain. Publishers must build the tagged version as-is.
      final source = await forkUpdateDio.get<String>(
        'https://raw.githubusercontent.com/$repository/$tag/pubspec.yaml',
        options: Options(responseType: ResponseType.plain),
      );
      return parseRelease(release, source.data!);
    } catch (error, stack) {
      Log.e(error, stack, 'fork-update');
      return null;
    }
  }

  static AndroidVersion parseRelease(Map release, String pubspec) {
    final tag = _releaseTag(release);
    final versions =
        RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$', multiLine: true)
            .allMatches(pubspec)
            .toList();
    final code =
        versions.length == 1 ? int.tryParse(versions.single[2]!) : null;
    if (code == null ||
        code <= 0 ||
        code > 2100000000 ||
        versions.single[1] != _tagPattern.firstMatch(tag)![1]) {
      throw const FormatException('Invalid tagged application version');
    }

    final name = 'WePeiYang-For-Pad-$tag-release.apk';
    final assets = release['assets'];
    final matches = assets is List
        ? assets
            .whereType<Map>()
            .where((asset) => asset['name'] == name)
            .toList()
        : <Map>[];
    if (matches.length != 1) {
      throw const FormatException('Expected exactly one For Pad Release APK');
    }
    final asset = matches.single;
    final url = 'https://github.com/$repository/releases/download/$tag/$name';
    final digest = asset['digest'];
    final size = asset['size'];
    final date = release['published_at'];
    final body = release['body'];
    if (asset['state'] != 'uploaded' ||
        asset['browser_download_url'] != url ||
        size is! int ||
        size <= 0 ||
        digest is! String ||
        !RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(digest) ||
        date is! String ||
        DateTime.tryParse(date) == null ||
        (body != null && body is! String)) {
      throw const FormatException(
          'Invalid APK URL, checksum, size or release details');
    }
    return AndroidVersion.fork(
      versionCode: code,
      version: tag,
      content: body as String? ?? '新的平板适配版本已发布。',
      time: date,
      apkUrl: url,
      digest: digest.substring(7).toLowerCase(),
      bytes: size,
    );
  }
}
