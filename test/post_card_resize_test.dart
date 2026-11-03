import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:we_pei_yang_flutter/commons/environment/config.dart';
import 'package:we_pei_yang_flutter/commons/preferences/common_prefs.dart';
import 'package:we_pei_yang_flutter/commons/themes/wpy_theme.dart';
import 'package:we_pei_yang_flutter/commons/util/text_util.dart';
import 'package:we_pei_yang_flutter/feedback/network/post.dart';
import 'package:we_pei_yang_flutter/feedback/util/splitscreen_util.dart';
import 'package:we_pei_yang_flutter/feedback/view/components/post_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    EnvConfig.init();
    await CommonPreferences.init();
    WpyTheme.init();
  });

  testWidgets('feed and detail headers fit after resizing', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final post = Post.empty()
      ..id = 1
      ..nickname = '测试用户'
      ..level = 93
      ..title = 'Test post'
      ..createAt = DateTime(2026, 11, 3, 14);

    for (final size in [
      const Size(800, 600),
      const Size(1280, 800),
      const Size(800, 1280),
      const Size(1280, 800),
      const Size(390, 844),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(WpyTheme(
        themeData: globalTheme.value,
        child: MaterialApp(
          home: Scaffold(body: Builder(builder: (context) {
            ScreenUtil.configure(
              data: MediaQuery.of(context),
              designSize: size.shortestSide >= 600
                  ? Size(max(size.width / 1.2308, 390),
                      max(size.height / 1.2308, 844))
                  : const Size(390, 844),
              minTextAdapt: true,
              splitScreenMode: false,
            );
            SplitUtil.needHorizontalView = false;
            TextUtil.init(context);
            final cards = [
              PostCardNormal(post, key: const ValueKey('feed')),
              PostCardNormal(post, key: const ValueKey('detail'), outer: false),
            ];
            return SingleChildScrollView(
              child: size.width > size.height && size.shortestSide >= 600
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:
                          cards.map((card) => Expanded(child: card)).toList(),
                    )
                  : Column(children: cards),
            );
          })),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$size');
      expect(find.text('2026-11-03 14:00:00'), findsNWidgets(2));
    }
  });
}
