import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../models/diet_record.dart';
import '../models/exercise_plan.dart';

/// 本地持久化服务（SharedPreferences）
class StorageService {
  static const _keyProfile = 'user_profile';
  static const _keyDietRecords = 'diet_records';
  static const _keyPlans = 'exercise_plans';
  static const _keyPin = 'auth_pin';
  static const _keyWeightHistory = 'weight_history';
  static const _maxDietRecords = 100;

  // ─── Auth ──────────────────────────────────────────

  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyPin);
  }

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPin, pin);
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keyPin);
    return stored == pin;
  }

  // ─── Profile ───────────────────────────────────────

  Future<UserProfile> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyProfile);
    if (json == null) return UserProfile();
    return UserProfile.fromJson(jsonDecode(json));
  }

  Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfile, jsonEncode(profile.toJson()));
    // 同时记录体重历史
    await _addWeightRecord(profile.currentWeightKg, profile.updatedAt);
  }

  // ─── Weight History ────────────────────────────────

  Future<List<Map<String, dynamic>>> loadWeightHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyWeightHistory);
    if (json == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(json));
  }

  Future<void> _addWeightRecord(double weightKg, DateTime date) async {
    final history = await loadWeightHistory();
    // 同一天只保留最新
    final today = date.toIso8601String().substring(0, 10);
    history.removeWhere(
      (r) => (r['date'] as String).startsWith(today),
    );
    history.add({'weight': weightKg, 'date': date.toIso8601String()});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyWeightHistory, jsonEncode(history));
  }

  // ─── Diet Records ──────────────────────────────────

  Future<List<DietRecord>> loadDietRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyDietRecords);
    if (json == null) return [];
    final list = List<Map<String, dynamic>>.from(jsonDecode(json));
    return list.map((e) => DietRecord.fromJson(e)).toList();
  }

  Future<void> saveDietRecords(List<DietRecord> records) async {
    final trimmed = records.take(_maxDietRecords).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyDietRecords,
      jsonEncode(trimmed.map((r) => r.toJson()).toList()),
    );
  }

  Future<void> addDietRecord(DietRecord record) async {
    final records = await loadDietRecords();
    records.insert(0, record);
    await saveDietRecords(records);
  }

  Future<void> deleteDietRecord(String id) async {
    final records = await loadDietRecords();
    records.removeWhere((r) => r.id == id);
    await saveDietRecords(records);
  }

  /// 获取今日饮食总卡路里
  Future<double> getTodayCalories() async {
    final records = await loadDietRecords();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final filtered = records
        .where((r) => r.date.toIso8601String().startsWith(today));
    double total = 0.0;
    for (final r in filtered) {
      total += r.calories;
    }
    return total;
  }

  // ─── Exercise Plans ────────────────────────────────

  Future<List<ExercisePlan>> loadPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyPlans);
    if (json == null) return [];
    final list = List<Map<String, dynamic>>.from(jsonDecode(json));
    return list.map((e) => ExercisePlan.fromJson(e)).toList();
  }

  Future<void> savePlans(List<ExercisePlan> plans) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyPlans,
      jsonEncode(plans.map((p) => p.toJson()).toList()),
    );
  }
}
