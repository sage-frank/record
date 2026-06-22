import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class ApiService {
  // 远程服务器地址（nginx 代理 HTTPS）
  static const String baseUrl = 'https://39.105.113.213:3000/api';
  static const Duration _timeout = Duration(seconds: 15);

  /// 创建 HTTP 客户端（开发环境跳过自签名证书验证）
  http.Client _createClient() {
    // 只在 debug 模式跳过证书验证，release 需要正规证书
    if (kDebugMode) {
      final ctx = SecurityContext(withTrustedRoots: false);
      return IOClient(
        HttpClient(context: ctx)..badCertificateCallback = (_, __, ___) => true,
      );
    }
    return http.Client();
  }

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
      final client = _createClient();
      try {
        final response = await client
            .post(Uri.parse(url), headers: {'Content-Type': 'application/json'}, body: body)
            .timeout(_timeout);

        _log('响应: HTTP ${response.statusCode} body=${response.body.length > 200 ? "${response.body.substring(0, 200)}..." : response.body}');

        if (response.statusCode == 200) {
          _log('上传成功');
          return jsonDecode(response.body);
        } else {
          _log('上传失败 HTTP ${response.statusCode}: ${response.body}');
          throw Exception('上传失败: HTTP ${response.statusCode}');
        }
      } finally {
        client.close();
      }
    } on SocketException catch (e) {
      _log('网络连接失败: $e');
      throw Exception('无法连接服务器，请检查网络');
    } on HandshakeException catch (e) {
      _log('SSL 握手失败: $e');
      throw Exception('SSL证书验证失败');
    } on http.ClientException catch (e) {
      _log('HTTP 客户端异常: $e');
      throw Exception('网络请求异常: $e');
    } on FormatException catch (e) {
      _log('响应格式错误: $e');
      throw Exception('服务器响应异常');
    }
  }

  /// 获取所有会话列表
  Future<List<Map<String, dynamic>>> getSessions() async {
    final url = '$baseUrl/sessions';
    _log('GET $url');
    final client = _createClient();
    try {
      final response = await client.get(Uri.parse(url)).timeout(_timeout);
      _log('响应: HTTP ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['sessions']);
      } else {
        throw Exception('获取会话列表失败: ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  /// 获取某个会话的轨迹点
  Future<Map<String, dynamic>> getSessionTrackPoints(String sessionId) async {
    final url = '$baseUrl/sessions/$sessionId/track-points';
    _log('GET $url');
    final client = _createClient();
    try {
      final response = await client.get(Uri.parse(url)).timeout(_timeout);
      _log('响应: HTTP ${response.statusCode}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('获取轨迹点失败: ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  /// 获取会话实时统计
  Future<Map<String, dynamic>> getSessionStats(String sessionId) async {
    final url = '$baseUrl/sessions/$sessionId/stats';
    _log('GET $url');
    final client = _createClient();
    try {
      final response = await client.get(Uri.parse(url)).timeout(_timeout);
      _log('响应: HTTP ${response.statusCode}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('获取统计失败: ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }
}
