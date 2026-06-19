import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // 远程服务器地址
  static const String baseUrl = 'http://39.105.113.213:3000/api';

  /// 批量上传轨迹点
  Future<Map<String, dynamic>> uploadTrackPoints({
    required String sessionId,
    required List<Map<String, dynamic>> points,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/track-points/batch'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'session_id': sessionId,
        'points': points,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('上传失败: ${response.statusCode}');
    }
  }

  /// 获取所有会话列表
  Future<List<Map<String, dynamic>>> getSessions() async {
    final response = await http.get(Uri.parse('$baseUrl/sessions'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['sessions']);
    } else {
      throw Exception('获取会话列表失败: ${response.statusCode}');
    }
  }

  /// 获取某个会话的轨迹点
  Future<Map<String, dynamic>> getSessionTrackPoints(String sessionId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/sessions/$sessionId/track-points'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('获取轨迹点失败: ${response.statusCode}');
    }
  }

  /// 获取会话实时统计
  Future<Map<String, dynamic>> getSessionStats(String sessionId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/sessions/$sessionId/stats'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('获取统计失败: ${response.statusCode}');
    }
  }
}
