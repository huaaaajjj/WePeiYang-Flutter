import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:we_pei_yang_flutter/studyroom/model/studyroom_models.dart';

/// 收藏卡片依赖 Room 的 JSON 序列化做本地缓存（FavorProvider._saveCache /
/// _restoreCache），这里锁定该格式，防止单边改动造成缓存解析静默失效。
void main() {
  test('Room survives a toJson/fromJson round-trip', () {
    final room = Room(123, '0305', '7', true);
    final restored = Room.fromJson(room.toJson());

    expect(restored.id, 123);
    expect(restored.name, '305'); // fromJson 会去掉前导零
    expect(restored.buildingId, '7');
    expect(restored.isFree, isTrue);
  });

  test('favor cache payload stays parseable', () {
    final room = Room(42, 'A201', '9', false);
    // 与 _saveCache 相同的结构：{id: Room JSON}
    final raw = json.encode({room.id.toString(): room.toJson()});
    final decoded = json.decode(raw) as Map<String, dynamic>;
    final restored = Room.fromJson(decoded['42'] as Map<String, dynamic>);

    expect(restored.id, room.id);
    expect(restored.name, room.name);
    expect(restored.buildingId, room.buildingId);
    expect(restored.isFree, room.isFree);
  });
}
