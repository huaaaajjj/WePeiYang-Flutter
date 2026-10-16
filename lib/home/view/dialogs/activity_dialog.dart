// @dart=2.12

import 'dart:math' as math;

import 'package:card_swiper/card_swiper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:we_pei_yang_flutter/auth/model/banner_pic.dart';
import 'package:we_pei_yang_flutter/commons/preferences/common_prefs.dart';
import 'package:we_pei_yang_flutter/commons/themes/template/wpy_theme_data.dart';
import 'package:we_pei_yang_flutter/commons/themes/wpy_theme.dart';
import 'package:we_pei_yang_flutter/commons/token/lake_token_manager.dart';
import 'package:we_pei_yang_flutter/commons/util/toast_provider.dart';
import 'package:we_pei_yang_flutter/commons/widgets/w_button.dart';
import 'package:we_pei_yang_flutter/commons/widgets/wpy_pic.dart';
import 'package:we_pei_yang_flutter/feedback/feedback_router.dart';
import 'package:we_pei_yang_flutter/home/view/web_views/festival_page.dart';

/// 活动弹窗
class ActivityDialog extends Dialog {
  final List<BannerPic> banners;

  ActivityDialog({required this.banners});

  @override
  Widget build(BuildContext context) {
    final data = banners;
    if (data.isEmpty) return SizedBox.shrink();

    // 平板大屏修复：海报同时受宽高两轴限制（旧 1.08.sw 在 800dp 高的横屏上
    // 高约 1382dp，超出屏幕且下方关闭条高度会算出负值）
    final posterH = math.min(1.08.sw, 0.62.sh);
    final posterW = posterH * 0.75;

    return Column(
      children: [
        Spacer(),
        if (data.length == 1)
          SizedBox(
            width: posterW,
            height: posterH,
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(20)),
              child: WButton(
                onPressed: () async {
                  if (data[0].url.startsWith('browser:')) {
                    if (await canLaunchUrlString(
                        data[0].url.replaceAll('browser:', ''))) {
                      launchUrlString(
                          data[0]
                              .url
                              .replaceAll('browser:', '')
                              .replaceAll(
                                  '<token>', '${CommonPreferences.token.value}')
                              .replaceAll('<laketoken>',
                                  '${await LakeTokenManager().refreshToken()}'),
                          mode: LaunchMode.externalApplication);
                    } else {
                      ToastProvider.error('好像无法打开活动呢，请联系天外天工作室');
                    }
                  } else if (data[0].url.isEmpty) {
                  } else {
                    Navigator.pushNamed(context, FeedbackRouter.haitang,
                        arguments: FestivalArgs(data[0].url, '活动'));
                  }
                },
                child: WpyPic(
                  data[0].picUrl,
                  fit: BoxFit.cover,
                  withHolder: true,
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: posterH,
            child: Swiper(
              loop: true,
              autoplay: true,
              autoplayDelay: 4000,
              itemCount: data.length,
              pagination: SwiperPagination(
                  margin: EdgeInsets.zero,
                  builder: DotSwiperPaginationBuilder(
                    activeColor: WpyTheme.of(context)
                        .get(WpyColorKey.primaryActionColor),
                    space: 5,
                  ),
                  alignment: Alignment.bottomCenter),
              itemBuilder: (BuildContext context, int index) {
                // if (data.length == 0) return SizedBox();
                return ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  child: WButton(
                    onPressed: () async {
                      if (data[index].url.startsWith('browser:')) {
                        if (await canLaunchUrlString(
                            data[index].url.replaceAll('browser:', ''))) {
                          launchUrlString(
                              data[index].url.replaceAll('browser:', ''));
                        } else {
                          ToastProvider.error('好像无法打开活动呢，请联系天外天工作室');
                        }
                      } else
                        Navigator.pushNamed(context, FeedbackRouter.haitang,
                            arguments: FestivalArgs(data[index].url, '活动'));
                    },
                    child: WpyPic(
                      data[index].picUrl,
                      fit: BoxFit.cover,
                      withHolder: false,
                    ),
                  ),
                );
              },
            ),
          ),
        WButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: SizedBox(
              width: 1.sw,
              height: math.max(0.55.sh - 0.54.sw, 0.12.sh),
              child: Align(
                alignment: Alignment.topCenter,
                child: Image.asset(
                  'assets/images/lake_butt_icons/x.png',
                  width: 50.w,
                  height: 100.w,
                  color: WpyTheme.of(context).get(WpyColorKey.reverseTextColor),
                ),
              ),
            ))
      ],
    );
  }
}
