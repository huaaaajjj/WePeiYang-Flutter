import 'package:flutter/services.dart';
import 'package:we_pei_yang_flutter/commons/util/log/log.dart';

class InstallManager {
  static const _channel = MethodChannel('com.twt.service/install');
  static bool canGoToMarket = false;

  static Future<void> install(String apkName,
      {int? expectedVersionCode}) async {
    final argument = <String, dynamic>{
      'path': apkName,
      if (expectedVersionCode != null) 'versionCode': expectedVersionCode,
    };
    await _channel.invokeMethod<void>('install', argument);
  }

  static Future<void> goToMarket() async {
    try {
      await _channel.invokeMethod<bool>("goToMarket");
    } catch (e, s) {
      Log.e(e, s, 'install');
    }
  }

  static Future<void> getCanGoToMarket() async {
    try {
      canGoToMarket =
          await _channel.invokeMethod<bool>("canGoToMarket") ?? false;
    } catch (e, s) {
      Log.e(e, s, 'install');
    }
  }
}
