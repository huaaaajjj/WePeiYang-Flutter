import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:we_pei_yang_flutter/commons/environment/config.dart';
import 'package:we_pei_yang_flutter/commons/preferences/common_prefs.dart';
import 'package:we_pei_yang_flutter/commons/themes/wpy_theme.dart';
import 'package:we_pei_yang_flutter/commons/util/text_util.dart';
import 'package:we_pei_yang_flutter/gpa/model/gpa_model.dart';
import 'package:we_pei_yang_flutter/gpa/model/gpa_notifier.dart';
import 'package:we_pei_yang_flutter/gpa/view/gpa_curve_detail.dart';
import 'package:we_pei_yang_flutter/gpa/view/gpa_page.dart';

GPANotifier _grades() => GPANotifier()
  ..total = Total(90, 3.8, 60)
  ..gpaStats = [
    GPAStat(
        '1H26',
        90,
        3.8,
        60,
        List.generate(
            20,
            (i) => GPACourse(
                  '2026-2027 1',
                  '课程${(i + 1).toString().padLeft(2, '0')}',
                  '必修',
                  99.0 - i,
                  '',
                  3,
                  3.8,
                ))),
    GPAStat(
        '2H26',
        92,
        4.2,
        9,
        List.generate(
            3,
            (i) => GPACourse(
                  '2026-2027 2',
                  '下学期${i + 1}',
                  '必修',
                  92.0 + i,
                  '',
                  3,
                  4.2,
                ))),
  ];

Future<void> _pumpGpa(
    WidgetTester tester, GPANotifier grades, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: grades,
    child: WpyTheme(
      themeData: globalTheme.value,
      child: MaterialApp(
        builder: (context, child) {
          ScreenUtil.configure(
            data: MediaQuery.of(context),
            designSize: size.shortestSide >= 600
                ? Size(max(size.width / 1.2308, 390),
                    max(size.height / 1.2308, 844))
                : const Size(390, 844),
            minTextAdapt: true,
            splitScreenMode: false,
          );
          TextUtil.init(context);
          if (const String.fromEnvironment('GPA_TEST_SCREENSHOT').isNotEmpty) {
            TextUtil.base = TextUtil.base
                .copyWith(fontFamilyFallback: const ['NotoSansSC']);
          }
          return child!;
        },
        home: RepaintBoundary(
          key: const ValueKey('gpa-test-render'),
          child: GPAPage(),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    EnvConfig.init();
    await CommonPreferences.init();
    CommonPreferences.firstClassesDialog.value = false;
    CommonPreferences.isBindTju.value = true;
    CommonPreferences.lakeNickname.value = 'TEST DATA';
    WpyTheme.init();
    if (const String.fromEnvironment('GPA_TEST_SCREENSHOT').isNotEmpty) {
      // Widget tests have no device font fallback; keep demo Chinese legible.
      final chineseFont = ByteData.sublistView(
          await File('assets/fonts/zh/NotoSansSC-Medium.otf').readAsBytes());
      await (FontLoader('NotoSansSC')..addFont(Future.value(chineseFont)))
          .load();
      for (final (family, asset) in [
        ('Swis', 'assets/fonts/en/Swis721-Blk-BT-Black-2.ttf'),
        ('ProductSans', 'assets/fonts/en/ProductSans-Regular.ttf'),
        ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      ]) {
        await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
      }
    }
  });

  testWidgets('tablet GPA uses independent chart and course columns',
      (tester) async {
    addTearDown(tester.view.reset);
    final grades = _grades();
    addTearDown(grades.dispose);
    await _pumpGpa(tester, grades, const Size(1280, 800));
    expect(tester.takeException(), isNull);

    final radar = tester.getRect(find.byType(RadarChartWidget));
    final curve = tester.getRect(find.byType(GPACurve));
    final courses = tester.getRect(find.byType(CourseListWidget));
    expect(courses.left, greaterThanOrEqualTo(radar.right));
    expect(curve.right, lessThanOrEqualTo(courses.left));
    expect(courses.top, closeTo(radar.top, 1));

    const screenshotPath = String.fromEnvironment('GPA_TEST_SCREENSHOT');
    if (screenshotPath.isNotEmpty) {
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('gpa-test-render')));
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(screenshotPath).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    final chartScroll = find
        .ancestor(
          of: find.byType(RadarChartWidget),
          matching: find.byType(Scrollable),
        )
        .first;
    final courseScroll = find
        .ancestor(
          of: find.byType(CourseListWidget),
          matching: find.byType(Scrollable),
        )
        .first;
    final chartPosition = tester.state<ScrollableState>(chartScroll).position;
    final coursePosition = tester.state<ScrollableState>(courseScroll).position;
    final chartOffset = chartPosition.pixels;
    await tester.drag(courseScroll, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(coursePosition.pixels, greaterThan(0));
    expect(chartPosition.pixels, closeTo(chartOffset, 0.01));

    coursePosition.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('ORDERED', findRichText: true));
    await tester.pumpAndSettle();
    expect(grades.sortType, 'score');
    expect(tester.getTopLeft(find.text('课程01')).dy,
        lessThan(tester.getTopLeft(find.text('课程20')).dy));

    final canvas = find
        .descendant(
          of: find.byType(GPACurve),
          matching: find.byType(CustomPaint),
        )
        .first;
    final canvasRect = tester.getRect(canvas);
    await tester
        .tapAt(canvasRect.topLeft + Offset(canvasRect.width * 2 / 3, 40));
    await tester.pumpAndSettle();
    expect(grades.index, 1);
    expect(find.text('下学期3'), findsOneWidget);
    expect(find.text('课程01'), findsNothing);
    expect(tester.takeException(), isNull);

    final sampleCourses = grades.courses;
    grades.gpaStats = List.generate(
        6,
        (i) => GPAStat(
              '第${i + 1}学期',
              80.0 + i,
              3.0 + i * 0.2,
              9,
              sampleCourses,
            ));
    grades.index = 0;
    await tester.pumpAndSettle();
    final curveScroll = find
        .ancestor(
          of: find.byType(GPACurve),
          matching: find.byType(Scrollable),
        )
        .first;
    final curvePosition = tester.state<ScrollableState>(curveScroll).position;
    expect(curvePosition.maxScrollExtent, greaterThan(0));
    final curveViewport = tester.getRect(curveScroll);
    final curveContent = tester.getRect(find.byType(GPACurve));
    expect(
        curveViewport.bottom - curveContent.bottom, greaterThanOrEqualTo(64));
    final horizontalView = tester.widget<SingleChildScrollView>(find
        .ancestor(
          of: find.byType(GPACurve),
          matching: find.byType(SingleChildScrollView),
        )
        .first);
    expect(horizontalView.clipBehavior, Clip.hardEdge);
    await tester.drag(curveScroll, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(curvePosition.pixels, greaterThan(0));
    await tester.tap(find.text('Weighted'));
    await tester.pumpAndSettle();
    expect(grades.typeName, '加权');
    expect(tester.takeException(), isNull);
  });

  testWidgets('GPA returns to vertical layout and keeps selection when resized',
      (tester) async {
    addTearDown(tester.view.reset);
    final grades = _grades()..index = 1;
    addTearDown(grades.dispose);
    await _pumpGpa(tester, grades, const Size(1280, 800));
    await tester.tap(find.byType(RadarChartWidget));
    for (final size in [
      const Size(800, 1280),
      const Size(390, 844),
      const Size(1280, 800),
      const Size(800, 600),
      const Size(640, 600),
    ]) {
      await _pumpGpa(tester, grades, size);
      expect(tester.takeException(), isNull, reason: '$size');
      final courseRect = tester.getRect(find.byType(CourseListWidget));
      if (size.shortestSide >= 600 && size.width > size.height) {
        expect(
            courseRect.left,
            greaterThanOrEqualTo(
                tester.getRect(find.byType(RadarChartWidget)).right));
      } else {
        expect(courseRect.top,
            greaterThanOrEqualTo(tester.getRect(find.byType(GPACurve)).bottom));
      }
      expect(grades.index, 1);
      expect(find.text('下学期3'), findsOneWidget);
    }
  });
}
