import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// API签名工具类 - 防止数据篡改
class SignatureUtils {
  static const String _appId = 'record_app_v2';
  static const String _secretKey = '5K8m#9cN@rP2xV7y';

  /// 生成API请求签名
  ///
  /// [method] HTTP方法 (GET, POST, PUT, DELETE)
  /// [path] URL路径 (不包含域名和查询参数)
  /// [body] 请求体
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
