import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Token
  Future<void> setToken(String? token) async {
    if (token == null) {
      await _prefs?.remove('token');
    } else {
      await _prefs?.setString('token', token);
    }
  }

  String? getToken() {
    return _prefs?.getString('token');
  }

  // UserInfo
  Future<void> setUserInfo(User? user) async {
    if (user == null) {
      await _prefs?.remove('userInfo');
    } else {
      await _prefs?.setString('userInfo', jsonEncode(user.toJson()));
    }
  }

  User? getUserInfo() {
    final jsonStr = _prefs?.getString('userInfo');
    if (jsonStr != null) {
      try {
        return User.fromJson(jsonDecode(jsonStr));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // Last Selected Store
  Future<void> setLastSelectedStore(String? store) async {
    if (store == null) {
      await _prefs?.remove('lastSelectedStore');
    } else {
      await _prefs?.setString('lastSelectedStore', store);
    }
  }

  String? getLastSelectedStore() {
    return _prefs?.getString('lastSelectedStore');
  }

  // Last Selected Competitor
  Future<void> setLastSelectedCompetitor(String? competitor) async {
    if (competitor == null) {
      await _prefs?.remove('lastSelectedCompetitor');
    } else {
      await _prefs?.setString('lastSelectedCompetitor', competitor);
    }
  }

  String? getLastSelectedCompetitor() {
    return _prefs?.getString('lastSelectedCompetitor');
  }

  // Selected Task
  Future<void> setSelectedTask(dynamic task) async {
    if (task == null) {
      await _prefs?.remove('selectedTask');
    } else {
      await _prefs?.setString('selectedTask', jsonEncode(task));
    }
  }

  dynamic getSelectedTask() {
    final jsonStr = _prefs?.getString('selectedTask');
    if (jsonStr != null) {
      try {
        return jsonDecode(jsonStr);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // Clear all login data
  Future<void> clearLoginData() async {
    await _prefs?.remove('token');
    await _prefs?.remove('userInfo');
  }

  // Clear all data
  Future<void> clearAll() async {
    await _prefs?.clear();
  }
}
