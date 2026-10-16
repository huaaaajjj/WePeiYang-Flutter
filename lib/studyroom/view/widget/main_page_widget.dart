import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:we_pei_yang_flutter/commons/themes/template/wpy_theme_data.dart';
import 'package:we_pei_yang_flutter/commons/themes/wpy_theme.dart';
import 'package:we_pei_yang_flutter/commons/util/text_util.dart';
import 'package:we_pei_yang_flutter/commons/widgets/loading.dart';
import 'package:we_pei_yang_flutter/studyroom/model/studyroom_provider.dart';
import 'package:we_pei_yang_flutter/studyroom/util/studyroom_images.dart';
import 'package:we_pei_yang_flutter/studyroom/view/widget/building_grid_view.dart';
import 'package:we_pei_yang_flutter/studyroom/view/widget/favour_room_card.dart';

class MainPageStudyRoomWidget extends StatelessWidget {
  const MainPageStudyRoomWidget({Key? key}) : super(key: key);

  Widget _favorList(BuildContext context) {
    return Consumer<FavorProvider>(builder: (_, fp, __) {
      if (!fp.loaded) return Loading();
      final favors = fp.rooms; // provider 内已按名称排序

      if (favors.isEmpty)
        return Center(
          child: Text('暂无收藏信息',
              style: TextUtil.base.PingFangSC.label(context).sp(14)),
        );

      return SizedBox(
        height: 120.h,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: favors.length,
          separatorBuilder: (_, __) => SizedBox(width: 12.w),
          itemBuilder: (_, i) => FavourRoomCard(favors[i]),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 22.w, right: 22.w, bottom: 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 16.h),
          Padding(
            padding: EdgeInsets.only(left: 8.w),
            child: Text(
              '我的收藏',
              style: TextUtil.base.PingFangSC.label(context).bold.sp(14.2),
            ),
          ),
          SizedBox(height: 12.h),
          _favorList(context),
          SizedBox(height: 4.h),
          TextButton.icon(
            onPressed: () => context.read<CampusProvider>().next(),
            style: ButtonStyle(
                padding: WidgetStateProperty.all(EdgeInsets.only(left: 8.w)),
                overlayColor: WidgetStateProperty.resolveWith((_) =>
                    WpyTheme.of(context)
                        .get(WpyColorKey.primaryLightestActionColor))),
            icon: Text(
              context.watch<CampusProvider>().name,
              style: TextUtil.base.PingFangSC.label(context).bold.sp(14),
            ),
            label: SvgPicture.asset(
              StudyroomImages.direction,
              colorFilter: ColorFilter.mode(
                  WpyTheme.of(context).get(WpyColorKey.primaryActionColor),
                  BlendMode.srcIn),
              width: 10.w,
            ),
          ),
          Expanded(
            child: BuildingGridViewWidget(),
          )
        ],
      ),
    );
  }
}
