import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // 远程服务器地址
  static const String baseUrl = 'http://39.105.113.213:3001/api';
  static const Duration _timeout = Duration(seconds: 15);

  void _log(String msg) {
    final ts = DateTime.now().toIso8601String();
    debugPrint('[$ts] [API] $msg');
  }

  /// 批量上传轨迹点
  Future<Map<String, dynamic>> uploadTrackPoints({
    required String sessionId,
    required List<Map<String, dynamic>> points,
  }) async {
    final url = '$baseUrl/track-points/batch';
    final body = jsonEncode({
      'session_id': sessionId,
      'points': points,
    });
    _log('POST $url session=$sessionId points=${points.length}');

    try {
      final response = await http
          .post(Uri.parse(url), headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(_timeout);

      _log('响应: HTTP ${response.statusCode} body=${response.body.length > 200 ? "${response.body.substring(0, 200)}..." : response.body}');

      if (response.statusCode == 200) {
        _log('上传成功');
        return jsonDecode(response.body);
      } else {
        _log('上传失败 HTTP ${response.statusCode}: ${response.body}');
        throw Exception('上传失败: HTTP ${response.statusCode}, 响应: ${response.body}');
      }
    } on SocketException catch (e) {
      _log('Socket 异常: $e');
      throw Exception('无法连接服务器: ${e.message}');
    } on HttpException catch (e) {
      _log('HTTP 异常: $e');
      throw Exception('HTTP 错误: ${e.message}');
    } on FormatException catch (e) {
      _log('响应格式错误: $e');
      throw Exception('服务器响应格式异常: $e');
    }
  }

  /// 获取所有会话列表
  Future<List<Map<String, dynamic>>> getSessions() async {
    final url = '$baseUrl/sessions';
    _log('GET $url');
    try {
      final response = await http.get(Uri.parse(url)).timeout(_timeout);
      _log('响应: HTTP ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['sessions']);
      } else {
        throw Exception('获取会话列表失败: HTTP ${response.statusCode}, 响应: ${response.body}');
      }
    } on SocketException catch (e) {
      _log('Socket 异常: $e');
      throw Exception('无法连接服务器: ${e.message}');
    } on FormatException catch (e) {
      _log('响应格式错误: $e');
      throw Exception('服务器响应格式异常: $e');
    }
  }

  /// 获取某个会话的轨迹点
  Future<Map<String, dynamic>> getSessionTrackPoints(String sessionId) async {
    final url = '$baseUrl/sessions/$sessionId/track-points';
    _log('GET $url');
    try {
      final response = await http.get(Uri.parse(url)).timeout(_timeout);
      _log('响应: HTTP ${response.statusCode}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('获取轨迹点失败: HTTP ${response.statusCode}, 响应: ${response.body}');
      }
    } on SocketException catch (e) {
      _log('Socket 异常: $e');
      throw Exception('无法连接服务器: ${e.message}');
    } on FormatException catch (e) {
      _log('响应格式错误: $e');
      throw Exception('服务器响应格式异常: $e');
    }
  }

  /// 获取会话实时统计
  Future<Map<String, dynamic>> getSessionStats(String sessionId) async {
    final url = '$baseUrl/sessions/$sessionId/stats';
    _log('GET $url');
    try {
      final response = await http.get(Uri.parse(url)).timeout(_timeout);
      _log('响应: HTTP ${response.statusCode}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('获取统计失败: HTTP ${response.statusCode}, 响应: ${response.body}');
      }
    } on SocketException catch (e) {
      _log('Socket 异常: $e');
      throw Exception('无法连接服务器: ${e.message}');
    } on FormatException catch (e) {
      _log('响应格式错误: $e');
      throw Exception('服务器响应格式异常: $e');
    }
  }

  /// 删除会话
  Future<void> deleteSession(String sessionId) async {
    final url = '$baseUrl/sessions/$sessionId';
    _log('DELETE $url');
    try {
      final response = await http.delete(Uri.parse(url)).timeout(_timeout);
      _log('响应: HTTP ${response.statusCode}');
      if (response.statusCode != 200) {
        throw Exception('删除失败: HTTP ${response.statusCode}');
      }
    } on SocketException catch (e) {
      _log('Socket 异常: $e');
      throw Exception('无法连接服务器: ${e.message}');
    }
  }

  // ── 减重模块 ──────────────────────────────────

  /// 获取用户档案
  Future<Map<String, dynamic>> getProfile() async {
    final url = '$baseUrl/profile';
    _log('GET $url');
    final response = await http.get(Uri.parse(url)).timeout(_timeout);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('获取档案失败');
  }

  /// 更新用户档案
  Future<void> updateProfile(Map<String, dynamic> profile) async {
    final url = '$baseUrl/profile';
    _log('PUT $url');
    final response = await http.put(Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(profile)).timeout(_timeout);
    if (response.statusCode != 200) throw Exception('更新档案失败');
  }

  /// 获取体重历史
  Future<List<Map<String, dynamic>>> getWeightHistory() async {
    final url = '$baseUrl/weight-history';
    final response = await http.get(Uri.parse(url)).timeout(_timeout);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['records']);
    }
    throw Exception('获取体重历史失败');
  }

  /// 添加体重记录
  Future<void> addWeightRecord(double weightKg) async {
    final url = '$baseUrl/weight-history';
    await http.post(Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'weight_kg': weightKg})).timeout(_timeout);
  }

  /// 获取饮食记录
  Future<List<Map<String, dynamic>>> getDietRecords({String? date}) async {
    var url = '$baseUrl/diet-records';
    if (date != null) url += '?date=$date';
    final response = await http.get(Uri.parse(url)).timeout(_timeout);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['records']);
    }
    throw Exception('获取饮食记录失败');
  }

  /// 添加饮食记录
  Future<void> addDietRecord(Map<String, dynamic> record) async {
    final url = '$baseUrl/diet-records';
    await http.post(Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(record)).timeout(_timeout);
  }

  /// 删除饮食记录
  Future<void> deleteDietRecord(String id) async {
    final url = '$baseUrl/diet-records/$id';
    await http.delete(Uri.parse(url)).timeout(_timeout);
  }

  /// 获取运动计划
  Future<List<Map<String, dynamic>>> getPlans() async {
    final url = '$baseUrl/plans';
    final response = await http.get(Uri.parse(url)).timeout(_timeout);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['plans']);
    }
    throw Exception('获取计划失败');
  }

  /// 添加运动计划
  Future<void> addPlan(Map<String, dynamic> plan) async {
    final url = '$baseUrl/plans';
    await http.post(Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(plan)).timeout(_timeout);
  }

  /// 更新运动计划
  Future<void> updatePlan(String id, Map<String, dynamic> plan) async {
    final url = '$baseUrl/plans/$id';
    await http.put(Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(plan)).timeout(_timeout);
  }

  /// 删除运动计划
  Future<void> deletePlan(String id) async {
    final url = '$baseUrl/plans/$id';
    await http.delete(Uri.parse(url)).timeout(_timeout);
  }
}
