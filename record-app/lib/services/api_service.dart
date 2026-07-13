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
}
