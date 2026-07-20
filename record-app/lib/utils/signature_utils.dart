import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// API签名工具类 - 防止数据篡改
class SignatureUtils {
  static const String _appId = 'record_app_v2';
  static const String _secretKey = '5K8m#9cN@rP2xV7y';
  static const Duration _timestampThreshold = Duration(minutes: 5);

  /// 生成API请求签名
  /// 
  /// [method] HTTP方法 (GET, POST, PUT, DELETE)
  /// [path] URL路径 (不包含域名和查询参数)
  /// [body] 请求体
  /// [timestamp] 时间戳 (Unix秒)
  /// [nonce] 随机字符串
  static Map<String, String> generateSignature({
    required String method,
    required String path,
    required Map<String, dynamic>? body,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final nonce = _generateNonce();
    
    // 生成body hash
    final bodyStr = body != null ? jsonEncode(body) : '';
    final bodyHash = sha256.convert(utf8.encode(bodyStr)).toString();
    
    // 生成签名字符串
    final signString = '$method|$path|$timestamp|$nonce|$bodyHash';
    
    // 计算HMAC-SHA256签名
    final key = utf8.encode(_secretKey);
    final bytes = utf8.encode(signString);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    
    return {
      'X-App-Key': _appId,
      'X-Timestamp': timestamp.toString(),
      'X-Nonce': nonce,
      'X-Signature': digest.toString(),
    };
  }
  
  /// 验证服务器响应签名
  static bool verifyResponseSignature({
    required String serverSignature,
    required String timestamp,
    required String nonce,
    required Map<String, dynamic> body,
  }) {
    try {
      final serverTimestamp = int.parse(timestamp);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      // 验证时间戳有效性
      if ((now - serverTimestamp).abs() > _timestampThreshold.inSeconds) {
        return false;
      }
      
      // 生成期望的签名
      final bodyStr = jsonEncode(body);
      final bodyHash = sha256.convert(utf8.encode(bodyStr)).toString();
      
      final signString = 'RESPONSE|/api|$serverTimestamp|$nonce|$bodyHash';
      final key = utf8.encode(_secretKey);
      final bytes = utf8.encode(signString);
      final hmacSha256 = Hmac(sha256, key);
      final expectedSignature = hmacSha256.convert(bytes).toString();
      
      return serverSignature == expectedSignature;
    } catch (e) {
      return false;
    }
  }
  
  /// 生成随机Nonce
  static String _generateNonce() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(16, (index) => chars[random.nextInt(chars.length)]).join();
  }
  
  /// 提取URL路径（去除域名和查询参数）
  static String extractPath(String url) {
    final uri = Uri.parse(url);
    return uri.path;
  }
}

/// 已使用Nonce管理（防止重放攻击）
class NonceManager {
  static final Set<String> _usedNonces = <String>{};
  
  /// 检查Nonce是否已使用
  static bool isNonceUsed(String nonce) {
    return _usedNonces.contains(nonce);
  }
  
  /// 标记Nonce为已使用
  static void markNonceUsed(String nonce) {
    _usedNonces.add(nonce);
    
    // 清理过期的Nonce（超过阈值时间）
    _cleanupExpiredNonces();
  }
  
  /// 清理过期Nonce
  static void _cleanupExpiredNonces() {
    // 保持Nonce集合大小合理，避免无限增长
    if (_usedNonces.length > 1000) {
      final toRemove = _usedNonces.length - 500;
      final removeList = _usedNonces.take(toRemove).toList();
      for (final nonce in removeList) {
        _usedNonces.remove(nonce);
      }
    }
  }
}