import 'package:flutter/widgets.dart';
import 'package:we_pei_yang_flutter/feedback/network/post.dart';

/// 平板左右分栏作用域：左栏列表点击帖子时，若上层存在该作用域，则把帖子
/// 选中到右栏内嵌展示；否则各入口保持原样（压栈打开全屏详情页）。
/// 手机端不会挂载该作用域，行为完全不变。
class PostSplitScope extends InheritedNotifier<ValueNotifier<Post?>> {
  const PostSplitScope(
      {Key? key, required ValueNotifier<Post?> notifier, required Widget child})
      : super(key: key, notifier: notifier, child: child);

  static PostSplitScope? maybeOf(BuildContext context) => context
      .getElementForInheritedWidgetOfExactType<PostSplitScope>()
      ?.widget as PostSplitScope?;

  void select(Post post) => notifier!.value = post;

  void clear() => notifier!.value = null;
}
