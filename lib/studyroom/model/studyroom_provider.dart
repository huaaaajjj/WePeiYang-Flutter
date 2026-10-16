// @dart=2.12
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:we_pei_yang_flutter/commons/util/log/log.dart';
import 'package:we_pei_yang_flutter/studyroom/model/studyroom_models.dart';
import 'package:we_pei_yang_flutter/studyroom/model/studyroom_service.dart';
import 'package:we_pei_yang_flutter/studyroom/util/session_util.dart';

import '../../commons/preferences/common_prefs.dart';

List<SingleChildWidget> studyroomProviders = [
  ChangeNotifierProvider(create: (_) => CampusProvider()),
  ChangeNotifierProvider(create: (_) => TimeProvider()),
  ChangeNotifierProvider(create: (_) => FavorProvider())
];

class TimeProvider with ChangeNotifier {
  DateTime _date = DateTime.now();

  DateTime get date => _date;

  int _sessionIndex = -1;

  int get session => _sessionIndex;

  ClassPeriod? get period =>
      session == -1 ? null : SessionIndexUtil.periods[session - 1];

  set session(int value) {
    _sessionIndex = value;
    notifyListeners();
  }

  set date(DateTime value) {
    _date = value;
    notifyListeners();
  }
}

class CampusProvider with ChangeNotifier {
  List<Campus> _campusList = [];
  Map<int, bool> _buildingLoaded = {};

  Map<int, List<Building>> _buildingMaps = {};

  bool loadedCampus = false;

  void init() async {
    _campusList = await StudyroomService.getCampusList();
    loadedCampus = true;
    notifyListeners();
    _campusList.forEach((campus) async {
      final buildings = await StudyroomService.getBuildingList(campus.id);
      _buildingMaps[campus.id] = buildings;
      _buildingLoaded[campus.id] = true;
      notifyListeners();
    });
  }

  Building building(int id) {
    return buildings.firstWhere((element) => element.id == id);
  }

  List<Building> get buildings => _campusList.isEmpty ? [] : _buildingMaps[_campusList[_current].id] ?? [];

  int _current = CommonPreferences.lastChoseCampus.value;

  void next() {
    if (_campusList.isEmpty) return;
    _current = (_current + 1) % _campusList.length;
    CommonPreferences.lastChoseCampus.value = _current;
    notifyListeners();
  }

  bool get buildingLoaded => _campusList.isEmpty
      ? false
      : _buildingLoaded[_campusList[_current].id] ?? false;

  int get id => _campusList.isNotEmpty ? _campusList[_current].id : -1;

  /// 按 id 查任意校区下的楼名（收藏卡片跳转详情页需要 areaName）
  String? buildingNameOf(String buildingId) {
    final id = int.tryParse(buildingId);
    if (id == null) return null;
    for (final list in _buildingMaps.values) {
      for (final b in list) {
        if (b.id == id) return b.name;
      }
    }
    return null;
  }

  String get name =>
      _campusList.isNotEmpty ? _campusList[_current].name : "加载中";
}

/// 自习室收藏（恢复自旧版实现，适配新数据结构）
class FavorProvider with ChangeNotifier {
  /// 服务端收藏的教室 id
  final Set<int> _ids = {};

  /// 本地缓存解析出的教室对象，用于渲染收藏卡片
  final Map<int, Room> _rooms = {};

  bool loaded = false;

  List<Room> get rooms =>
      _rooms.values.toList()..sort((a, b) => a.name.compareTo(b.name));

  bool isFavor(int roomId) => _ids.contains(roomId);

  /// 先用本地缓存点亮界面，再与服务端对齐（失败时保留缓存）
  Future<void> init() async {
    _restoreCache();
    loaded = true;
    notifyListeners();
    try {
      final ids = await StudyroomService.getFavouriteIds();
      _ids
        ..clear()
        ..addAll(ids);
      _rooms.removeWhere((id, _) => !_ids.contains(id));
      _saveCache();
      notifyListeners();
    } catch (e, s) {
      Log.e(e, s, 'studyroom');
    }
  }

  /// 切换收藏；失败时状态不变并返回 false
  Future<bool> toggle(Room room) async {
    final favored = _ids.contains(room.id);
    final ok = favored
        ? await StudyroomService.deleteRoom(room.id)
        : await StudyroomService.collectRoom(room.id);
    if (!ok) return false;
    if (favored) {
      _ids.remove(room.id);
      _rooms.remove(room.id);
    } else {
      _ids.add(room.id);
      _rooms[room.id] = room;
    }
    _saveCache();
    notifyListeners();
    return true;
  }

  void _restoreCache() {
    try {
      final raw = CommonPreferences.favorRoomCache.value;
      if (raw.isEmpty) return;
      (json.decode(raw) as Map<String, dynamic>).forEach((key, value) {
        final id = int.parse(key);
        _ids.add(id);
        _rooms[id] = Room.fromJson(value as Map<String, dynamic>);
      });
    } catch (e, s) {
      Log.e(e, s, 'studyroom');
    }
  }

  void _saveCache() {
    CommonPreferences.favorRoomCache.value = json.encode({
      for (final e in _rooms.entries) e.key.toString(): e.value.toJson(),
    });
  }
}
