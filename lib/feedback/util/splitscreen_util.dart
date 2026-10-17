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

  static late double w = needHorizontalView ? 0.5.w : 1.w;
  static late double h = 1.h;
  static late double r = 1.r;
  static late double sw = needHorizontalView ? 0.5.sw : 1.sw;
  static late double sh = 1.sh;
  static late double toolbarWidth = Platform.isWindows
      ? needHorizontalView
          ? 25
          : 50
      : 0;
}
