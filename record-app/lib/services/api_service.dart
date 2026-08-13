import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../data/repositories/error_repository.dart';
import '../utils/error_reporter.dart';
import '../utils/http_client_provider.dart';
import '../utils/request_id_provider.dart';
import '../utils/signature_utils.dart';
import '../utils/debug_helper.dart';

class ApiService {
  ApiService({ErrorReportRepository? errorRepository})
      : _errorRepository = errorRepository;

  /// 异常上报仓库（可选注入，用于请求失败时自动上报）
  final ErrorReportRepository? _errorRepository;

  // 远程服务器地址
  static const String baseUrl = 'https://39.105.113.213:3000/api';

  // 创建支持自签名证书的 HTTP 客户端
  static http.Client _getHttpClient() => HttpClientProvider.get();
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

  /// 显示调试对话框 - 显示请求的详细信息
  void _showDebugDialog(
    String method,
    String url,
    Map<String, String> headers,
    Map<String, dynamic>? body,
  ) {
    // 使用 DebugHelper 记录日志
    DebugHelper.log(
      method: method,
      url: url,
      headers: headers,
      body: body,
    );

    // 同时输出到控制台
    final bodyStr = body != null ? const JsonEncoder.withIndent('  ').convert(body) : '(无请求体)';

    _log('🔍 [DEBUG REQUEST]');
    _log('  Method: $method');
    _log('  URL: $url');
    _log('  Headers:');
    headers.forEach((key, value) {
      _log('    $key: $value');
    });
    _log('  Body: $bodyStr');

    // 控制台详细输出
    debugPrint('\n🔍 ════════════════════════════════════════════════════');
    debugPrint('📡 API 请求调试信息');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('Method: $method');
    debugPrint('URL: $url');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('Headers:');
    headers.forEach((key, value) {
      debugPrint('  🔑 $key: $value');
    });
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    if (body != null && body.isNotEmpty) {
      debugPrint('Body:');
      debugPrint(bodyStr);
    } else {
      debugPrint('Body: (空)');
    }
    debugPrint('════════════════════════════════════════════════════\n');
  }

  /// 添加签名到请求
  Future<Map<String, String>> _addSignatureHeaders({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? existingHeaders,
  }) async {
    final signature = SignatureUtils.generateSignature(
      method: method,
      path: path,
      body: body,
    );

    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...?existingHeaders,
      ...signature,
    };

    return headers;
  }

  /// 调试模式开关 - 设置为 false 可关闭调试弹窗
  static bool debugMode = true;

  /// 通用签名请求方法
  Future<Map<String, dynamic>> _signedRequest({
    required String method,
    required String url,
    Map<String, dynamic>? body,
    bool expectsList = false,
  }) async {
    final path = SignatureUtils.extractPath(url);
    // 每次请求生成唯一请求 ID，供后端记录跟踪、异常关联
    final requestId = RequestIdProvider.generate();
    final headers = await _addSignatureHeaders(
      method: method,
      path: path,
      body: body,
      existingHeaders: {'X-Request-Id': requestId},
    );

    // 调试模式：输出详细的请求信息
    if (debugMode) {
      _showDebugDialog(method, url, headers, body);
    }

    late http.Response response;
    try {
      switch (method.toUpperCase()) {
        case 'GET':
          response = await _getHttpClient().get(Uri.parse(url), headers: headers).timeout(_timeout);
          break;
        case 'POST':
          response = await _getHttpClient()
              .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
              .timeout(_timeout);
          break;
        case 'PUT':
          response = await _getHttpClient()
              .put(Uri.parse(url), headers: headers, body: jsonEncode(body))
              .timeout(_timeout);
          break;
        case 'DELETE':
          response = await _getHttpClient().delete(Uri.parse(url), headers: headers).timeout(_timeout);
          break;
        default:
          throw Exception('不支持的HTTP方法: $method');
      }
    } catch (e, st) {
      // 请求异常：上报（携带请求 ID），然后继续向外抛出，不允许吞掉
      _reportRequestError(
        method: method,
        url: url,
        requestId: requestId,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }

    // 调试：记录响应信息
    if (debugMode) {
      _log('📥 [DEBUG RESPONSE] Status: ${response.statusCode}');
      _log('   Body: ${response.body.length > 200 ? response.body.substring(0, 200) + "..." : response.body}');
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (debugMode) {
        debugPrint('✅ [REQUEST SUCCESS] $method $url');
      }

      if (expectsList) {
        // 兼容不同的响应格式：records, sessions, plans
        final List<dynamic> rawList;
        if (data['records'] != null) {
          rawList = List<dynamic>.from(data['records']);
        } else if (data['sessions'] != null) {
          rawList = List<dynamic>.from(data['sessions']);
        } else if (data['plans'] != null) {
          rawList = List<dynamic>.from(data['plans']);
        } else {
          // 如果都没有，假设整个 data 就是列表
          rawList = data is List ? List<dynamic>.from(data) : [data];
        }

        // 安全地转换为 Map 列表
        final List<Map<String, dynamic>> mappedList = rawList.map((item) {
          if (item is Map<String, dynamic>) {
            return item;
          } else if (item is Map) {
            return Map<String, dynamic>.from(item);
          } else {
            return {'data': item};
          }
        }).toList();

        return {'records': mappedList};
      }

      return data;
    } else {
      if (debugMode) {
        debugPrint('❌ [REQUEST FAILED] $method $url - ${response.statusCode}');
        debugPrint('   Response: ${response.body}');
      }
      // 非 200 响应：上报（携带请求 ID），然后抛出异常
      _reportRequestError(
        method: method,
        url: url,
        requestId: requestId,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
      throw Exception('API请求失败: HTTP ${response.statusCode}, 响应: ${response.body}');
    }
  }

  /// 请求失败自动上报（携带请求 ID，供后端关联追踪）
  void _reportRequestError({
    required String method,
    required String url,
    required String requestId,
    Object? error,
    StackTrace? stackTrace,
    int? statusCode,
    String? responseBody,
  }) {
    final repository = _errorRepository;
    if (repository == null) {
      debugPrint('[ApiService] 请求失败（未注入错误上报，仅输出）: $method $url -> $error');
      return;
    }
    final message = statusCode != null
        ? 'API请求失败: HTTP $statusCode'
        : 'API请求异常: $error';
    ErrorReporter.reportError(
      message: message,
      source: 'api_service',
      error: statusCode != null ? null : error,
      stackTrace: stackTrace,
      url: url,
      requestId: requestId,
      context: {
        'method': method,
        if (statusCode != null) 'status': statusCode,
        if (responseBody != null && responseBody.isNotEmpty)
          'response_body': responseBody.length > 2000
              ? '${responseBody.substring(0, 2000)}...'
              : responseBody,
      },
    );
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
    } catch (e) {
      _log('调试事件上报失败: $e');
    }
  }

  /// 批量上传轨迹点
  Future<Map<String, dynamic>> uploadTrackPoints({
    required String sessionId,
    required List<Map<String, dynamic>> points,
  }) async {
    final url = '$baseUrl/track-points/batch';
    final requestBody = {'session_id': sessionId, 'points': points};
    final path = SignatureUtils.extractPath(url);
    // 每次上传生成唯一请求 ID，供后端记录跟踪、异常关联
    final requestId = RequestIdProvider.generate();

    _log('POST $url session=$sessionId points=${points.length}');

    try {
      final headers = await _addSignatureHeaders(
        method: 'POST',
        path: path,
        body: requestBody,
        existingHeaders: {'X-Request-Id': requestId},
      );

      final response = await _getHttpClient()
          .post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode(requestBody),
          )
          .timeout(_timeout);

      _log(
        '响应: HTTP ${response.statusCode} body=${response.body.length > 200 ? "${response.body.substring(0, 200)}..." : response.body}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        _log('上传成功');
        return data;
      } else {
        _log('上传失败 HTTP ${response.statusCode}: ${response.body}');
        _reportRequestError(
          method: 'POST',
          url: url,
          requestId: requestId,
          statusCode: response.statusCode,
          responseBody: response.body,
        );
        throw Exception(
          '上传失败: HTTP ${response.statusCode}, 响应: ${response.body}',
        );
      }
    } on SocketException catch (e, st) {
      _log('Socket 异常: $e');
      _reportRequestError(
        method: 'POST',
        url: url,
        requestId: requestId,
        error: e,
        stackTrace: st,
      );
      throw Exception('无法连接服务器: ${e.message}');
    } on HttpException catch (e, st) {
      _log('HTTP 异常: $e');
      _reportRequestError(
        method: 'POST',
        url: url,
        requestId: requestId,
        error: e,
        stackTrace: st,
      );
      throw Exception('HTTP 错误: ${e.message}');
    } on FormatException catch (e, st) {
      _log('响应格式错误: $e');
      _reportRequestError(
        method: 'POST',
        url: url,
        requestId: requestId,
        error: e,
        stackTrace: st,
      );
      throw Exception('服务器响应格式异常: $e');
    }
  }

  /// 获取所有会话列表
  Future<List<Map<String, dynamic>>> getSessions() async {
    final url = '$baseUrl/sessions';
    _log('GET $url');
    try {
      final data = await _signedRequest(
        method: 'GET',
        url: url,
        expectsList: true,
      );
      return List<Map<String, dynamic>>.from(data['records']);
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
      final data = await _signedRequest(
        method: 'GET',
        url: url,
      );
      return data;
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
      final data = await _signedRequest(
        method: 'GET',
        url: url,
      );
      return data;
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
      await _signedRequest(
        method: 'DELETE',
        url: url,
      );
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
    try {
      final data = await _signedRequest(
        method: 'GET',
        url: url,
      );
      return data;
    } on FormatException catch (e) {
      _log('响应格式错误: $e');
      throw Exception('服务器响应格式异常: $e');
    }
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
      await _signedRequest(
        method: 'PUT',
        url: url,
        body: profile,
      );
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'A',
          msg: 'response PUT /profile',
          data: {'status': 200},
        ),
      );
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
      final data = await _signedRequest(
        method: 'GET',
        url: url,
        expectsList: true,
      );
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'A',
          msg: 'response GET /weight-history',
          data: {'status': 200},
        ),
      );
      return List<Map<String, dynamic>>.from(data['records']);
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
      await _signedRequest(
        method: 'POST',
        url: url,
        body: {'weight_kg': weightKg},
      );
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'A',
          msg: 'response POST /weight-history',
          data: {'status': 200},
        ),
      );
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
      await _signedRequest(
        method: 'DELETE',
        url: url,
      );
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'A',
          msg: 'response DELETE /weight-history',
          data: {'status': 200},
        ),
      );
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
      final data = await _signedRequest(
        method: 'GET',
        url: url,
        expectsList: true,
      );
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'A',
          msg: 'response GET /diet-records',
          data: {'status': 200},
        ),
      );
      return List<Map<String, dynamic>>.from(data['records']);
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
      await _signedRequest(
        method: 'POST',
        url: url,
        body: record,
      );
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'A',
          msg: 'response POST /diet-records',
          data: {'status': 200},
        ),
      );
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
      await _signedRequest(
        method: 'DELETE',
        url: url,
      );
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'A',
          msg: 'response DELETE /diet-records',
          data: {'status': 200},
        ),
      );
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
      final data = await _signedRequest(
        method: 'GET',
        url: url,
        expectsList: true,
      );
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'A',
          msg: 'response GET /plans',
          data: {'status': 200},
        ),
      );
      return List<Map<String, dynamic>>.from(data['records']);
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
      await _signedRequest(
        method: 'POST',
        url: url,
        body: plan,
      );
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'A',
          msg: 'response POST /plans',
          data: {'status': 200},
        ),
      );
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
      await _signedRequest(
        method: 'PUT',
        url: url,
        body: plan,
      );
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'A',
          msg: 'response PUT /plans',
          data: {'status': 200},
        ),
      );
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
      await _signedRequest(
        method: 'DELETE',
        url: url,
      );
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'A',
          msg: 'response DELETE /plans',
          data: {'status': 200},
        ),
      );
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
