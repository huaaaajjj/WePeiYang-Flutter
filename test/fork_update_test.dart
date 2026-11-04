import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:we_pei_yang_flutter/commons/update/update_manager.dart';

class _ForkUpdateManager extends UpdateManager {
  @override
  void setGetVersion() => throw StateError('Fork entered the upstream updater');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final launches = <MethodCall>[];
  const launcher = MethodChannel('plugins.flutter.io/url_launcher');

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'For Pad',
      packageName: 'com.twt.service.pad',
      version: '4.6.4',
      buildNumber: '198',
      buildSignature: '',
    );
    launches.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcher, (call) async {
      launches.add(call);
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcher, null);
  });

  test('fork auto check skips upstream updates without opening a browser',
      () async {
    final manager = _ForkUpdateManager();
    addTearDown(manager.dispose);
    await manager.checkUpdate();
    expect(manager.status, UpdateStatus.idle);
    expect(launches, isEmpty);
  });

  test('original and development packages retain their updater', () async {
    for (final name in ['com.twt.service', 'com.twt.service.develop']) {
      PackageInfo.setMockInitialValues(
        appName: 'Original',
        packageName: name,
        version: '4.6.4',
        buildNumber: '198',
        buildSignature: '',
      );
      final manager = _ForkUpdateManager();
      addTearDown(manager.dispose);
      await expectLater(manager.checkUpdate(), throwsStateError);
    }
    expect(launches, isEmpty);
  });

  test('fork manual check opens its own release page', () async {
    final manager = _ForkUpdateManager();
    addTearDown(manager.dispose);
    await manager.checkUpdate(auto: false);
    expect(manager.status, UpdateStatus.idle);
    expect(launches, hasLength(1));
    expect(launches.single.arguments['url'],
        'https://github.com/huaaaajjj/WePeiYang-Flutter/releases/latest');
  });
}
