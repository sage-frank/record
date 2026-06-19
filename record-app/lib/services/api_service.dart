import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // 远程服务器地址
  static const String baseUrl = 'http://39.105.113.213:3000/api';
  static const Duration _timeout = Duration(seconds: 10);

  /// 批量上传轨迹点
  Future<Map<String, dynamic>> uploadTrackPoints({
    required String sessionId,
    required List<Map<String, dynamic>> points,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/track-points/batch'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'session_id': sessionId,
              'points': points,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('上传失败 HTTP ${response.statusCode}: ${response.body}');
        throw Exception('上传失败: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      debugPrint('网络连接失败: $e');
      throw Exception('无法连接服务器，请检查网络');
    } on http.ClientException catch (e) {
      debugPrint('HTTP 客户端异常: $e');
      throw Exception('网络请求异常: $e');
    } on FormatException catch (e) {
      debugPrint('响应格式错误: $e');
      throw Exception('服务器响应异常');
    }
  }

  /// 获取所有会话列表
  Future<List<Map<String, dynamic>>> getSessions() async {
    final response = await http
        .get(Uri.parse('$baseUrl/sessions'))
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['sessions']);
    } else {
      throw Exception('获取会话列表失败: ${response.statusCode}');
    }
  }

  /// 获取某个会话的轨迹点
  Future<Map<String, dynamic>> getSessionTrackPoints(String sessionId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/sessions/$sessionId/track-points'))
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('获取轨迹点失败: ${response.statusCode}');
    }
  }

  /// 获取会话实时统计
  Future<Map<String, dynamic>> getSessionStats(String sessionId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/sessions/$sessionId/stats'))
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('获取统计失败: ${response.statusCode}');
    }
  }
}
