import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http_io;
import '../utils/signature_utils.dart';
import 'security_service.dart';

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

  /// 通用签名请求方法
  Future<Map<String, dynamic>> _signedRequest({
    required String method,
    required String url,
    Map<String, dynamic>? body,
    bool expectsList = false,
  }) async {
    final path = SignatureUtils.extractPath(url);
    final headers = await _addSignatureHeaders(
      method: method,
      path: path,
      body: body,
    );

    late http.Response response;
    
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

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      // 验证服务器响应签名
      if (!_verifyServerResponse(response, data)) {
        _log('服务器响应签名验证失败');
        throw Exception('服务器响应签名验证失败');
      }
      
      if (expectsList) {
        return {'records': List<Map<String, dynamic>>.from(data['records'] ?? data)};
      }
      
      return data;
    } else {
      throw Exception('API请求失败: HTTP ${response.statusCode}, 响应: ${response.body}');
    }
  }

  /// 验证服务器响应
  bool _verifyServerResponse(http.Response response, Map<String, dynamic> bodyData) {
    final signature = response.headers['x-server-signature'] ?? '';
    final timestamp = response.headers['x-timestamp'] ?? '';
    final nonce = response.headers['x-nonce'] ?? '';

    if (signature.isEmpty || timestamp.isEmpty || nonce.isEmpty) {
      _log('服务器响应缺少签名信息');
      return false;
    }

    // 检查Nonce重放攻击
    if (SecurityService.instance.isNonceUsed(nonce)) {
      _log('检测到可能的重放攻击，Nonce已使用: $nonce');
      return false;
    }

    // 标记Nonce为已使用
    SecurityService.instance.markNonceUsed(nonce);

    // 验证签名
    final isValid = SignatureUtils.verifyResponseSignature(
      serverSignature: signature,
      timestamp: timestamp,
      nonce: nonce,
      body: bodyData,
    );

    if (!isValid) {
      _log('服务器响应签名验证失败');
    }

    return isValid;
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
    final requestBody = {'session_id': sessionId, 'points': points};
    final path = SignatureUtils.extractPath(url);
    
    _log('POST $url session=$sessionId points=${points.length}');

    try {
      final headers = await _addSignatureHeaders(
        method: 'POST',
        path: path,
        body: requestBody,
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
        
        // 验证服务器响应签名
        if (!_verifyServerResponse(response, data)) {
          _log('服务器响应签名验证失败');
          throw Exception('服务器响应签名验证失败');
        }
        
        _log('上传成功');
        return data;
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
