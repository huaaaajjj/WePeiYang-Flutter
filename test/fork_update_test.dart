import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:we_pei_yang_flutter/commons/channel/download/download_manager.dart';
import 'package:we_pei_yang_flutter/commons/channel/install/install.dart';
import 'package:we_pei_yang_flutter/commons/environment/config.dart';
import 'package:we_pei_yang_flutter/commons/preferences/common_prefs.dart';
import 'package:we_pei_yang_flutter/commons/themes/wpy_theme.dart';
import 'package:we_pei_yang_flutter/commons/update/dialog/update_dialog.dart';
import 'package:we_pei_yang_flutter/commons/update/dialog/update_failure_dialog.dart';
import 'package:we_pei_yang_flutter/commons/update/dialog/update_install_dialog.dart';
import 'package:we_pei_yang_flutter/commons/update/dialog/update_message_dialog.dart';
import 'package:we_pei_yang_flutter/commons/update/fork_update_service.dart';
import 'package:we_pei_yang_flutter/commons/update/update_manager.dart';
import 'package:we_pei_yang_flutter/commons/util/storage_util.dart';
import 'package:we_pei_yang_flutter/commons/util/text_util.dart';
import 'package:we_pei_yang_flutter/commons/util/toast_provider.dart';

import 'fork_release_test.dart' show releaseFixture, releaseTag;

class _ReleaseAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int statusCode = 200;
  final release = releaseFixture();
  Completer<void>? hold;
  final started = Completer<void>();

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    if (!started.isCompleted) started.complete();
    await hold?.future;
    final api = options.uri.host == 'api.github.com';
    return ResponseBody.fromString(
        api ? jsonEncode(release) : 'version: 4.6.4+198\n', statusCode,
        headers: {
          'content-type': [api ? 'application/json' : 'text/plain']
        });
  }

  @override
  void close({bool force = false}) {}
}

class _OriginalManager extends UpdateManager {
  bool enteredUpdater = false;
  @override
  void setGetVersion() {
    enteredUpdater = true;
    throw StateError('Stop before the original network request');
  }
}

void mockPackage(String build, {String name = 'com.twt.service.pad'}) {
  PackageInfo.setMockInitialValues(
      appName: 'For Pad',
      packageName: name,
      version: '4.6.4',
      buildNumber: build,
      buildSignature: '');
}

// SmartDialog dismissal uses timers: finish its zero-duration timer in the
// real-I/O zone before returning to the widget test's fake clock.
Future<T?> runIo<T>(WidgetTester tester, Future<T> Function() action) {
  return tester.runAsync(() async {
    final value = await action();
    await Future<void>.delayed(Duration.zero);
    return value;
  });
}

Future<void> pumpUpdater(WidgetTester tester, UpdateManager manager) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChangeNotifierProvider<UpdateManager>.value(
    value: manager,
    child: WpyTheme(
        themeData: globalTheme.value,
        child: MaterialApp(
          navigatorObservers: [FlutterSmartDialog.observer],
          builder: FlutterSmartDialog.init(builder: (context, child) {
            final size = MediaQuery.sizeOf(context);
            ScreenUtil.configure(
                data: MediaQuery.of(context),
                designSize: size.shortestSide >= 600
                    ? Size(max(size.width / 1.2308, 390),
                        max(size.height / 1.2308, 844))
                    : const Size(390, 844),
                minTextAdapt: true,
                splitScreenMode: false);
            TextUtil.init(context);
            return child!;
          }),
          home: Builder(builder: (context) {
            ToastProvider.init(context);
            return const Scaffold(body: Text('Update test'));
          }),
        )),
  ));
  await tester.pumpAndSettle();
  addTearDown(() async {
    UpdateDialog.message.cancelAll();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    manager.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _ReleaseAdapter adapter;
  late Directory temp;
  final downloads = <MethodCall>[];
  final installs = <MethodCall>[];
  final launches = <MethodCall>[];
  const downloadChannel = MethodChannel('com.twt.service/download');
  const installChannel = MethodChannel('com.twt.service/install');
  const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');

  setUp(() async {
    SmartDialog.config.custom = SmartConfigCustom(useAnimation: false);
    SharedPreferences.setMockInitialValues({});
    EnvConfig.init();
    await CommonPreferences.init();
    WpyTheme.init();
    temp = await Directory.systemTemp.createTemp('fork-update-');
    StorageUtil.downloadDir = temp;
    StorageUtil.filesDir = temp;
    await Directory('${temp.path}/apk').create();
    DownloadManager.getInstance().listeners.clear();
    mockPackage('197');
    adapter = _ReleaseAdapter();
    forkUpdateDio.httpClientAdapter = adapter;
    downloads.clear();
    installs.clear();
    launches.clear();
    InstallManager.canGoToMarket = true;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(downloadChannel, (call) async {
      downloads.add(call);
      return null;
    });
    messenger.setMockMethodCallHandler(installChannel, (call) async {
      installs.add(call);
      return null;
    });
    messenger.setMockMethodCallHandler(launcherChannel, (call) async {
      launches.add(call);
      return true;
    });
  });

  tearDown(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [downloadChannel, installChannel, launcherChannel]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    await temp.delete(recursive: true);
  });

  testWidgets('startup prompts once, fits long notes and supports skipping',
      (tester) async {
    final manager = UpdateManager();
    adapter.release['body'] = List.filled(100, '平板适配更新说明').join('\n');
    await pumpUpdater(tester, manager);
    await runIo(tester, () => manager.checkUpdate());
    await tester.pumpAndSettle();
    expect(find.byType(UpdateMessageDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(adapter.requests.map((r) => r.uri.host),
        ['api.github.com', 'raw.githubusercontent.com']);
    expect(
        adapter.requests.every((r) => !r.headers.containsKey('Authorization')),
        isTrue);
    expect(downloads, isEmpty);
    expect(installs, isEmpty);
    await tester.tap(find.text('跳过此版本'));
    await tester.pumpAndSettle();
    expect(CommonPreferences.ignoreUpdateVersion.value, releaseTag);
    await runIo(tester, () => manager.checkUpdate());
    await tester.pumpAndSettle();
    expect(find.byType(UpdateMessageDialog), findsNothing);
    await runIo(tester, () => manager.checkUpdate(auto: false));
    await tester.pumpAndSettle();
    expect(find.byType(UpdateMessageDialog), findsOneWidget);
  });

  testWidgets('same or older builds stay silent and daily opt-out skips API',
      (tester) async {
    final manager = UpdateManager();
    await pumpUpdater(tester, manager);
    for (final code in ['198', '199']) {
      mockPackage(code);
      await runIo(tester, () => manager.checkUpdate());
      await tester.pumpAndSettle();
      expect(manager.status, UpdateStatus.idle);
      expect(find.byType(UpdateMessageDialog), findsNothing);
    }
    adapter.requests.clear();
    CommonPreferences.lastCheckUpdateTime.value = DateTime.now().toString();
    await runIo(tester, () => manager.checkUpdate());
    expect(adapter.requests, isEmpty);
  });

  testWidgets('confirmed download verifies bytes then opens the installer',
      (tester) async {
    final manager = UpdateManager();
    await pumpUpdater(tester, manager);
    await runIo(tester, () => manager.checkUpdate());
    await tester.pumpAndSettle();
    await tester.tap(find.text('立刻更新'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(downloads, hasLength(1));
    final listener = DownloadManager.getInstance().listeners.values.single;
    final task = listener.tasks.values.single;
    expect(task.url, contains('/releases/download/$releaseTag/'));
    await runIo(tester, () async {
      await File(task.path).writeAsString('abc');
      await (listener.success as dynamic)(task);
    });
    await tester.pumpAndSettle();
    expect(find.byType(UpdateInstallDialog), findsOneWidget);
    expect(installs, isEmpty);
    await runIo(tester, manager.installUpdate);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(installs.single.method, 'install');
    expect(installs.single.arguments['path'], task.path);
    expect(installs.single.arguments['versionCode'], 198);
    expect(manager.status, UpdateStatus.idle);
  });

  testWidgets(
      'corrupt cache is removed; tampering after download blocks install',
      (tester) async {
    final manager = UpdateManager();
    final cache = File('${temp.path}/apk/198-for-pad.apk');
    cache.writeAsStringSync('abd');
    await pumpUpdater(tester, manager);
    await runIo(tester, () => manager.checkUpdate());
    await tester.pumpAndSettle();
    expect(await runIo(tester, cache.exists), isFalse);
    expect(find.byType(UpdateMessageDialog), findsOneWidget);
    manager.setIdle();
    await tester.pumpAndSettle();
    await runIo(tester, () => cache.writeAsString('abc'));
    await runIo(tester, () => manager.checkUpdate());
    await tester.pumpAndSettle();
    expect(find.byType(UpdateInstallDialog), findsOneWidget);
    await runIo(tester, () => cache.writeAsString('abd'));
    await runIo(tester, manager.installUpdate);
    await tester.pumpAndSettle();
    expect(installs, isEmpty);
    expect(find.byType(UpdateFailureDialog), findsOneWidget);
    expect(find.text('前往应用市场'), findsNothing);
    await tester.tap(find.text('前往网页下载'));
    await tester.pump();
    expect(launches.single.arguments['url'], ForkUpdateService.releasesUrl);
    expect(await runIo(tester, cache.exists), isFalse);
  });

  testWidgets('download corruption fails safely and allows a clean retry',
      (tester) async {
    final manager = UpdateManager();
    await pumpUpdater(tester, manager);
    await runIo(tester, () => manager.checkUpdate());
    await tester.pumpAndSettle();
    manager.setDownload();
    await tester.pump();
    final listener = DownloadManager.getInstance().listeners.values.single;
    final task = listener.tasks.values.single;
    await runIo(tester, () async {
      await File(task.path).writeAsString('abd');
      await (listener.success as dynamic)(task);
    });
    await tester.pumpAndSettle();
    expect(manager.status, UpdateStatus.error);
    expect(find.byType(UpdateFailureDialog), findsOneWidget);
    expect(installs, isEmpty);
    expect(await runIo(tester, () => File(task.path).exists()), isFalse);
    await tester.tap(find.text('重试'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(downloads, hasLength(2));
    expect(manager.status, UpdateStatus.download);
  });

  testWidgets(
      'API failures recover silently for auto checks and report manual failure',
      (tester) async {
    final manager = UpdateManager();
    await pumpUpdater(tester, manager);
    for (final code in [403, 404, 429]) {
      adapter.statusCode = code;
      await runIo(tester, () => manager.checkUpdate());
      await tester.pumpAndSettle();
      expect(manager.status, UpdateStatus.idle);
      expect(find.byType(UpdateMessageDialog), findsNothing);
    }
    await runIo(tester, () => manager.checkUpdate(auto: false));
    await tester.pump();
    expect(find.text('检查更新失败'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  test('concurrent startup checks share one pending request', () async {
    mockPackage('198');
    final manager = UpdateManager();
    addTearDown(manager.dispose);
    adapter.hold = Completer<void>();
    final first = manager.checkUpdate();
    final second = manager.checkUpdate();
    await adapter.started.future;
    expect(manager.status, UpdateStatus.getVersion);
    adapter.hold!.complete();
    await Future.wait([first, second]);
    expect(adapter.requests, hasLength(2));
    expect(manager.status, UpdateStatus.idle);
  });

  testWidgets('original package still enters its own updater, not GitHub',
      (tester) async {
    final manager = _OriginalManager();
    await pumpUpdater(tester, manager);
    mockPackage('198', name: 'com.twt.service.develop');
    await runIo(tester, () => manager.checkUpdate());
    await tester.pumpAndSettle();
    expect(manager.enteredUpdater, isTrue);
    expect(manager.isFork, isFalse);
    expect(adapter.requests, isEmpty);
  });
}
