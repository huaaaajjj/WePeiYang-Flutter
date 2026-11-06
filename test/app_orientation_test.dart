import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:we_pei_yang_flutter/main.dart';

void main() {
  testWidgets('orientation uses the display, not the startup or resized view',
      (tester) async {
    final requests = <List<String>>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        requests.add(List<String>.from(call.arguments as List));
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      tester.view.reset();
      tester.view.display.reset();
    });

    for (final (name, display, viewport, expected) in [
      ('tablet startup', const Size(3200, 2000), Size.zero, <String>[]),
      ('tablet letterbox', const Size(3200, 2000), const Size(1599, 2000),
          <String>[]),
      ('tablet narrow split', const Size(3200, 2000), const Size(1000, 2000),
          <String>[]),
      ('tablet portrait', const Size(2000, 3200), const Size(2000, 3200),
          <String>[]),
      ('phone', const Size(975, 2110), const Size(975, 2110),
          ['DeviceOrientation.portraitUp']),
      ('600dp boundary', const Size(1500, 2500), const Size(1500, 2500),
          <String>[]),
      ('below boundary', const Size(1499, 2500), const Size(1499, 2500),
          ['DeviceOrientation.portraitUp']),
    ]) {
      tester.view.devicePixelRatio = 2.5;
      tester.view.display.size = display;
      tester.view.physicalSize = viewport;
      requests.clear();
      await configureAppOrientation();
      expect(requests, [expected], reason: name);
    }
  });
}
