import 'package:flutter/widgets.dart';
import 'package:we_pei_yang_flutter/feedback/network/post.dart';
import 'package:we_pei_yang_flutter/feedback/view/search_result_page.dart';

/// 平板左右分栏作用域：左栏列表点击帖子时，若上层存在该作用域，则把帖子
/// 选中到右栏内嵌展示；搜索结果页等"搜索入口"也经此把页面开进左栏。
/// 手机端不会挂载该作用域，行为完全不变。
class PostSplitScope extends InheritedNotifier<ValueNotifier<Post?>> {
  const PostSplitScope(
      {Key? key,
      required ValueNotifier<Post?> notifier,
      required Widget child,
      this.onOpenResults})
      : super(key: key, notifier: notifier, child: child);

  /// 宿主提供的"把搜索结果页开进左栏"回调；为空表示不接受内嵌（照常压路由）。
  final bool Function(SearchResultPageArgs args)? onOpenResults;

  static PostSplitScope? maybeOf(BuildContext context) => context
      .getElementForInheritedWidgetOfExactType<PostSplitScope>()
      ?.widget as PostSplitScope?;

  void select(Post post) => notifier!.value = post;

  void clear() => notifier!.value = null;

  /// 有内嵌宿主时把搜索结果页开进左栏并返回 true；否则返回 false。
  bool openResults(SearchResultPageArgs args) {
    final onOpen = onOpenResults;
    if (onOpen == null) return false;
    return onOpen(args);
  }
}
