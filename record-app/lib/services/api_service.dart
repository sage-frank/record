import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http_io;

class ApiService {
  // 远程服务器地址
  static const String baseUrl = 'https://39.105.113.213:3000/api';
  static http.Client? _customClient;

  // 创建支持自签名证书的 HTTP 客户端
  static http.Client _getHttpClient() {
    if (_customClient != null) return _customClient!;

    // 创建一个信任所有证书的 HttpClient
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) => true;
    
    // 使用 IOClient 来包装我们的 HttpClient
    _customClient = http_io.IOClient(client);
    return _customClient!;
  }
  static const String _debugServerUrl = String.fromEnvironment(
    'DEBUG_SERVER_URL',
    defaultValue: '',
  );

  static const String _debugSessionId = String.fromEnvironment(
    'DEBUG_SESSION_ID',
    defaultValue: 'api-calls-not-visible',
  );
  static const String _debugRunId = String.fromEnvironment(
    'DEBUG_RUN_ID',
    defaultValue: 'pre',
  );
  static const Duration _timeout = Duration(seconds: 15);
  static const Duration _debugTimeout = Duration(seconds: 2);

  void _log(String msg) {
    final ts = DateTime.now().toIso8601String();
    debugPrint('[$ts] [API] $msg');
  }

  Future<void> _reportDebugEvent({
    required String hypothesisId,
    required String msg,
    Map<String, dynamic>? data,
  }) async {
    if (_debugServerUrl.isEmpty) return;
    try {
      await http
          .post(
            Uri.parse(_debugServerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'sessionId': _debugSessionId,
              'runId': _debugRunId,
              'hypothesisId': hypothesisId,
              'location': 'api_service.dart',
              'msg': '[DEBUG] $msg',
              'data': {'baseUrl': baseUrl, ...(data ?? const {})},
              'ts': DateTime.now().millisecondsSinceEpoch,
            }),
          )
          .timeout(_debugTimeout);
    } catch (_) {}
  }

  /// 批量上传轨迹点
  Future<Map<String, dynamic>> uploadTrackPoints({
    required String sessionId,
    required List<Map<String, dynamic>> points,
  }) async {
    final url = '$baseUrl/track-points/batch';
    final body = jsonEncode({'session_id': sessionId, 'points': points});
    _log('POST $url session=$sessionId points=${points.length}');

    try {
      final response = await _getHttpClient()
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(_timeout);

      _log(
        '响应: HTTP ${response.statusCode} body=${response.body.length > 200 ? "${response.body.substring(0, 200)}..." : response.body}',
      );

      if (response.statusCode == 200) {
        _log('上传成功');
        return jsonDecode(response.body);
      } else {
        _log('上传失败 HTTP ${response.statusCode}: ${response.body}');
        throw Exception(
          '上传失败: HTTP ${response.statusCode}, 响应: ${response.body}',
        );
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
      final response = await _getHttpClient().get(Uri.parse(url)).timeout(_timeout);
      _log('响应: HTTP ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['sessions']);
      } else {
        throw Exception(
          '获取会话列表失败: HTTP ${response.statusCode}, 响应: ${response.body}',
        );
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
      final response = await _getHttpClient().get(Uri.parse(url)).timeout(_timeout);
      _log('响应: HTTP ${response.statusCode}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          '获取轨迹点失败: HTTP ${response.statusCode}, 响应: ${response.body}',
        );
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
      final response = await _getHttpClient().get(Uri.parse(url)).timeout(_timeout);
      _log('响应: HTTP ${response.statusCode}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          '获取统计失败: HTTP ${response.statusCode}, 响应: ${response.body}',
        );
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
      final response = await _getHttpClient().delete(Uri.parse(url)).timeout(_timeout);
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
    final response = await _getHttpClient().get(Uri.parse(url)).timeout(_timeout);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('获取档案失败');
  }

  /// 更新用户档案
  Future<void> updateProfile(Map<String, dynamic> profile) async {
    final url = '$baseUrl/profile';
    _log('PUT $url');
    unawaited(
      _reportDebugEvent(
        hypothesisId: 'A',
        msg: 'request PUT /profile',
        data: {'method': 'PUT', 'url': url},
      ),
    );
    try {
      final response = await _getHttpClient()
          .put(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(profile),
          )
          .timeout(_timeout);
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'A',
          msg: 'response PUT /profile',
          data: {'status': response.statusCode},
        ),
      );
      if (response.statusCode != 200) throw Exception('更新档案失败');
    } catch (e) {
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'B',
          msg: 'error PUT /profile',
          data: {'error': e.toString()},
        ),
      );
      rethrow;
    }
  }

  /// 获取体重历史
  Future<List<Map<String, dynamic>>> getWeightHistory() async {
    final url = '$baseUrl/weight-history';
    unawaited(
      _reportDebugEvent(
        hypothesisId: 'A',
        msg: 'request GET /weight-history',
        data: {'method': 'GET', 'url': url},
      ),
    );
    try {
      final response = await _getHttpClient().get(Uri.parse(url)).timeout(_timeout);
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'A',
          msg: 'response GET /weight-history',
          data: {'status': response.statusCode},
        ),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['records']);
      }
      throw Exception('获取体重历史失败');
    } catch (e) {
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'B',
          msg: 'error GET /weight-history',
          data: {'error': e.toString()},
        ),
      );
      rethrow;
    }
  }

  /// 添加体重记录
  Future<void> addWeightRecord(double weightKg) async {
    final url = '$baseUrl/weight-history';
    unawaited(
      _reportDebugEvent(
        hypothesisId: 'A',
        msg: 'request POST /weight-history',
        data: {'method': 'POST', 'url': url, 'weight_kg': weightKg},
      ),
    );
    try {
      final response = await _getHttpClient()
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'weight_kg': weightKg}),
          )
          .timeout(_timeout);
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'A',
          msg: 'response POST /weight-history',
          data: {'status': response.statusCode},
        ),
      );
      if (response.statusCode != 200) {
        throw Exception('添加体重记录失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'B',
          msg: 'error POST /weight-history',
          data: {'error': e.toString()},
        ),
      );
      rethrow;
    }
  }

  /// 删除体重记录
  Future<void> deleteWeightRecord(int id) async {
    final url = '$baseUrl/weight-history/$id';
    unawaited(
      _reportDebugEvent(
        hypothesisId: 'A',
        msg: 'request DELETE /weight-history',
        data: {'method': 'DELETE', 'url': url, 'id': id},
      ),
    );
    try {
      final response = await _getHttpClient().delete(Uri.parse(url)).timeout(_timeout);
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'A',
          msg: 'response DELETE /weight-history',
          data: {'status': response.statusCode},
        ),
      );
      if (response.statusCode != 200) {
        throw Exception('删除体重记录失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'B',
          msg: 'error DELETE /weight-history',
          data: {'error': e.toString()},
        ),
      );
      rethrow;
    }
  }

  /// 获取饮食记录
  Future<List<Map<String, dynamic>>> getDietRecords({String? date}) async {
    var url = '$baseUrl/diet-records';
    if (date != null) url += '?date=$date';
    unawaited(
      _reportDebugEvent(
        hypothesisId: 'A',
        msg: 'request GET /diet-records',
        data: {'method': 'GET', 'url': url, 'date': date},
      ),
    );
    try {
      final response = await _getHttpClient().get(Uri.parse(url)).timeout(_timeout);
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'A',
          msg: 'response GET /diet-records',
          data: {'status': response.statusCode},
        ),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['records']);
      }
      throw Exception('获取饮食记录失败');
    } catch (e) {
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'B',
          msg: 'error GET /diet-records',
          data: {'error': e.toString()},
        ),
      );
      rethrow;
    }
  }

  /// 添加饮食记录
  Future<void> addDietRecord(Map<String, dynamic> record) async {
    final url = '$baseUrl/diet-records';
    unawaited(
      _reportDebugEvent(
        hypothesisId: 'A',
        msg: 'request POST /diet-records',
        data: {'method': 'POST', 'url': url},
      ),
    );
    try {
      final response = await _getHttpClient()
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(record),
          )
          .timeout(_timeout);
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'A',
          msg: 'response POST /diet-records',
          data: {'status': response.statusCode},
        ),
      );
      if (response.statusCode != 200) {
        throw Exception('添加饮食记录失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'B',
          msg: 'error POST /diet-records',
          data: {'error': e.toString()},
        ),
      );
      rethrow;
    }
  }

  /// 删除饮食记录
  Future<void> deleteDietRecord(String id) async {
    final url = '$baseUrl/diet-records/$id';
    unawaited(
      _reportDebugEvent(
        hypothesisId: 'A',
        msg: 'request DELETE /diet-records',
        data: {'method': 'DELETE', 'url': url, 'id': id},
      ),
    );
    try {
      final response = await _getHttpClient().delete(Uri.parse(url)).timeout(_timeout);
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'A',
          msg: 'response DELETE /diet-records',
          data: {'status': response.statusCode},
        ),
      );
      if (response.statusCode != 200) {
        throw Exception('删除饮食记录失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'B',
          msg: 'error DELETE /diet-records',
          data: {'error': e.toString()},
        ),
      );
      rethrow;
    }
  }

  /// 获取运动计划
  Future<List<Map<String, dynamic>>> getPlans() async {
    final url = '$baseUrl/plans';
    unawaited(
      _reportDebugEvent(
        hypothesisId: 'A',
        msg: 'request GET /plans',
        data: {'method': 'GET', 'url': url},
      ),
    );
    try {
      final response = await _getHttpClient().get(Uri.parse(url)).timeout(_timeout);
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'A',
          msg: 'response GET /plans',
          data: {'status': response.statusCode},
        ),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['plans']);
      }
      throw Exception('获取计划失败');
    } catch (e) {
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'B',
          msg: 'error GET /plans',
          data: {'error': e.toString()},
        ),
      );
      rethrow;
    }
  }

  /// 添加运动计划
  Future<void> addPlan(Map<String, dynamic> plan) async {
    final url = '$baseUrl/plans';
    unawaited(
      _reportDebugEvent(
        hypothesisId: 'A',
        msg: 'request POST /plans',
        data: {'method': 'POST', 'url': url},
      ),
    );
    try {
      final response = await _getHttpClient()
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(plan),
          )
          .timeout(_timeout);
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'A',
          msg: 'response POST /plans',
          data: {'status': response.statusCode},
        ),
      );
      if (response.statusCode != 200) {
        throw Exception('添加计划失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'B',
          msg: 'error POST /plans',
          data: {'error': e.toString()},
        ),
      );
      rethrow;
    }
  }

  /// 更新运动计划
  Future<void> updatePlan(String id, Map<String, dynamic> plan) async {
    final url = '$baseUrl/plans/$id';
    unawaited(
      _reportDebugEvent(
        hypothesisId: 'A',
        msg: 'request PUT /plans',
        data: {'method': 'PUT', 'url': url, 'id': id},
      ),
    );
    try {
      final response = await _getHttpClient()
          .put(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(plan),
          )
          .timeout(_timeout);
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'A',
          msg: 'response PUT /plans',
          data: {'status': response.statusCode},
        ),
      );
      if (response.statusCode != 200) {
        throw Exception('更新计划失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'B',
          msg: 'error PUT /plans',
          data: {'error': e.toString()},
        ),
      );
      rethrow;
    }
  }

  /// 删除运动计划
  Future<void> deletePlan(String id) async {
    final url = '$baseUrl/plans/$id';
    unawaited(
      _reportDebugEvent(
        hypothesisId: 'A',
        msg: 'request DELETE /plans',
        data: {'method': 'DELETE', 'url': url, 'id': id},
      ),
    );
    try {
      final response = await _getHttpClient().delete(Uri.parse(url)).timeout(_timeout);
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'A',
          msg: 'response DELETE /plans',
          data: {'status': response.statusCode},
        ),
      );
      if (response.statusCode != 200) {
        throw Exception('删除计划失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'B',
          msg: 'error DELETE /plans',
          data: {'error': e.toString()},
        ),
      );
      rethrow;
    }
  }
}


