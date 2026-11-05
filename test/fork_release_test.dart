import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:we_pei_yang_flutter/commons/update/fork_update_service.dart';

const apkDigest =
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
const releaseTag = 'v4.6.4-pad.2';
const apkName = 'WePeiYang-For-Pad-$releaseTag-release.apk';

Map<String, dynamic> releaseFixture() => {
      'tag_name': releaseTag,
      'draft': false,
      'prerelease': false,
      'published_at': '2026-11-04T12:00:00Z',
      'body': '改进平板布局',
      'assets': [
        <String, dynamic>{
          'name': apkName,
          'state': 'uploaded',
          'size': 3,
          'digest': 'sha256:$apkDigest',
          'browser_download_url':
              'https://github.com/huaaaajjj/WePeiYang-Flutter/releases/download/$releaseTag/$apkName',
        },
      ],
    };

void main() {
  test('stable fork release uses tagged build number and never hotfixes', () {
    final version = ForkUpdateService.parseRelease(
        releaseFixture(), 'name: app\nversion: 4.6.4+198\n');
    expect(version.versionCode, 198);
    expect(version.version, releaseTag);
    expect(version.isFork, isTrue);
    expect(version.canHotFix, isFalse);
    expect(version.isForced, isFalse);
    expect(version.apkDigest, apkDigest);
    expect(version.apkBytes, 3);
    expect(version.apkUrl, contains('/releases/download/$releaseTag/'));
    expect(version.apkName, '198-for-pad.apk');
  });

  test('untrusted, ambiguous or incomplete release metadata is rejected', () {
    final mutations = <void Function(Map<String, dynamic>)>[
      (r) => r['draft'] = true,
      (r) => r['prerelease'] = true,
      (r) => r['tag_name'] = '../../main',
      (r) => r['tag_name'] = 'v4.6.4',
      (r) => r['assets'] = [],
      (r) => r['assets'].add(r['assets'].first),
      (r) => r['assets'][0]['name'] = 'app-profile.apk',
      (r) => r['assets'][0]['state'] = 'open',
      (r) => r['assets'][0]['digest'] = null,
      (r) => r['assets'][0]['digest'] = 'sha256:bad',
      (r) => r['assets'][0]['size'] = -1,
      (r) =>
          r['assets'][0]['browser_download_url'] = 'https://example.com/a.apk',
      (r) => r['published_at'] = 'invalid',
    ];
    for (var i = 0; i < mutations.length; i++) {
      final release = releaseFixture();
      mutations[i](release);
      expect(
          () => ForkUpdateService.parseRelease(release, 'version: 4.6.4+198'),
          throwsFormatException,
          reason: 'mutation $i');
    }
    for (final source in [
      'version: 4.6.5+198',
      'version: 4.6.4',
      'version: 4.6.4+0',
      'version: 4.6.4+2147483648',
      'version: 4.6.4+198\nversion: 4.6.4+999',
    ]) {
      expect(() => ForkUpdateService.parseRelease(releaseFixture(), source),
          throwsFormatException,
          reason: source);
    }
  });

  test('cached and downloaded APKs require both byte length and SHA-256',
      () async {
    final directory = await Directory.systemTemp.createTemp('fork-integrity-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/update.apk');
    final version =
        ForkUpdateService.parseRelease(releaseFixture(), 'version: 4.6.4+198');
    expect(await version.verifyApk(file), isFalse);
    await file.writeAsString('abc');
    expect(await version.verifyApk(file), isTrue);
    await file.writeAsString('abd');
    expect(await version.verifyApk(file), isFalse);
    await file.writeAsString('abcd');
    expect(await version.verifyApk(file), isFalse);
  });

  test('optional live release snapshot matches its source version', () async {
    const folder = String.fromEnvironment('FORK_RELEASE_FIXTURE');
    if (folder.isEmpty) return;
    final release =
        jsonDecode(File('$folder/release/release.json').readAsStringSync());
    final version = ForkUpdateService.parseRelease(
        release, File('$folder/source/pubspec.yaml').readAsStringSync());
    expect(version.versionCode, greaterThan(0));
    expect(version.isFork, isTrue);
    const apk = String.fromEnvironment('FORK_RELEASE_APK');
    if (apk.isNotEmpty) expect(await version.verifyApk(File(apk)), isTrue);
  });
}
