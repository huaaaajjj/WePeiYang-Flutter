import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:we_pei_yang_flutter/feedback/util/splitscreen_util.dart';

void main() {
  test('split dimensions follow resizing and half-width mode', () {
    for (final (size, split) in [
      (const Size(800, 600), false),
      (const Size(1280, 800), false),
      (const Size(800, 1280), false),
      (const Size(390, 844), false),
      (const Size(844, 390), true),
      (const Size(390, 844), false),
    ]) {
      ScreenUtil.configure(
        data: MediaQueryData(size: size),
        designSize: size.shortestSide >= 600
            ? Size(
                max(size.width / 1.2308, 390), max(size.height / 1.2308, 844))
            : const Size(390, 844),
        minTextAdapt: true,
        splitScreenMode: false,
      );
      SplitUtil.needHorizontalView = split;
      expect(SplitUtil.w, closeTo(split ? 0.5.w : 1.w, 1e-9));
      expect(SplitUtil.h, closeTo(1.h, 1e-9));
      expect(SplitUtil.r, closeTo(1.r, 1e-9));
      expect(SplitUtil.sw, closeTo(split ? 0.5.sw : 1.sw, 1e-9));
      expect(SplitUtil.sh, closeTo(1.sh, 1e-9));
      expect(SplitUtil.toolbarWidth,
          Platform.isWindows ? (split ? 25.0 : 50.0) : 0.0);
    }
  });

  testWidgets('tablet layout follows orientation and the 600dp shortest side',
      (tester) async {
    for (final (name, size, expected) in [
      ('phone portrait', const Size(390, 844), false),
      ('phone landscape', const Size(844, 390), false),
      ('tablet portrait', const Size(800, 1280), false),
      ('tablet landscape', const Size(1280, 800), true),
      ('below 600dp', const Size(1000, 599), false),
      ('at 600dp landscape', const Size(1000, 600), true),
      ('at 600dp portrait', const Size(600, 1000), false),
      ('above 600dp', const Size(1000, 601), true),
    ]) {
      late bool actual;
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(size: size),
        child: Builder(builder: (context) {
          actual = SplitUtil.useTabletLayout(context);
          return const SizedBox.shrink();
        }),
      ));
      expect(actual, expected, reason: name);
    }
  });
}
