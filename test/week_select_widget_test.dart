import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:we_pei_yang_flutter/commons/environment/config.dart';
import 'package:we_pei_yang_flutter/commons/preferences/common_prefs.dart';
import 'package:we_pei_yang_flutter/commons/themes/wpy_theme.dart';
import 'package:we_pei_yang_flutter/schedule/model/course_provider.dart';
import 'package:we_pei_yang_flutter/schedule/view/week_select_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'termStart':
          DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch ~/
              1000,
    });
    EnvConfig.init();
    await CommonPreferences.init();
    WpyTheme.init();
  });

  testWidgets('vertical week list retains selection, State and scroll offset',
      (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(2560, 1600);
    addTearDown(tester.view.reset);
    final course = CourseProvider()..selectedWeek = 6;
    final display = CourseDisplayProvider();

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => course),
        ChangeNotifierProvider(create: (_) => display),
      ],
      child: WpyTheme(
        themeData: globalTheme.value,
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          useInheritedMediaQuery: true,
          minTextAdapt: true,
          builder: (_, __) => const MaterialApp(
            home: Scaffold(
              body: Row(children: [WeekSelectWidget(vertical: true)]),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byType(WeekSelectWidget),
      matching: find.byType(Scrollable),
    );
    final state = tester.state<ScrollableState>(scrollable);
    final position = state.position;
    final initialOffset = position.pixels;
    expect(course.currentWeek, 1);
    // The real initial offset follows the selected week, not the current week.
    expect(initialOffset, closeTo(5 * (38 + 50.h), 0.01));

    final weekTile = find
        .ancestor(of: find.text('WEEK 8'), matching: find.byType(Stack))
        .first;
    await tester.tap(find.descendant(
      of: weekTile,
      matching: find.byType(InkWell),
    ));
    await tester.pumpAndSettle();
    expect(course.selectedWeek, 8);
    expect(state.position, same(position));
    expect(position.pixels, closeTo(initialOffset, 0.01));

    await tester.drag(find.byType(ListView), const Offset(0, -180));
    await tester.pumpAndSettle();
    final scrolledOffset = position.pixels;
    expect(scrolledOffset, greaterThan(initialOffset));
    expect(scrolledOffset, lessThan(position.maxScrollExtent));

    for (final shrink in [true, false]) {
      display.shrink = shrink;
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(WeekSelectWidget)).width,
          shrink ? 0 : greaterThan(0));
      expect(state.mounted, isTrue);
      expect(tester.state<ScrollableState>(scrollable), same(state));
      expect(state.position, same(position));
      expect(state.position.pixels, closeTo(scrolledOffset, 0.01));
      expect(course.selectedWeek, 8);
    }
    expect(tester.widget<Text>(find.text('WEEK 8')).style!.color!.a, 1);
  });
}
