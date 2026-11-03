import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SplitUtil {
  static bool needHorizontalView = 1.sw > 1.sh;

  SplitUtil._();

  /// 平板横屏才启用"大屏版式"（海棠左右分栏、首页双栏等）；平板竖屏回落
  /// 手机版式。手机（shortestSide < 600）恒为 false；横竖屏切换随
  /// MediaQuery 重建自动生效。
  static bool useTabletLayout(BuildContext context) {
    final mq = MediaQuery.of(context);
    return mq.size.shortestSide >= 600 &&
        mq.orientation == Orientation.landscape;
  }

  static double get w => needHorizontalView ? 0.5.w : 1.w;
  static double get h => 1.h;
  static double get r => 1.r;
  static double get sw => needHorizontalView ? 0.5.sw : 1.sw;
  static double get sh => 1.sh;
  static double get toolbarWidth => Platform.isWindows
      ? needHorizontalView
          ? 25
          : 50
      : 0;
}
