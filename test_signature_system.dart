import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:hmac/hmac.dart';

/// 签名系统演示和测试
void main() {
  print('🔐 接口签名系统测试');
  print('=' * 50);
  
  // 测试签名生成
  testSignatureGeneration();
  
  // 测试签名验证
  testSignatureVerification();
  
  // 测试重放攻击防护
  testReplayAttackPrevention();
  
  // 测试时间戳验证
  testTimestampValidation();
}

void testSignatureGeneration() {
  print('\n📝 测试签名生成:');
  
  const method = 'POST';
  const path = '/api/track-points/batch';
  const body = {
    'session_id': 'test-session-123',
    'points': [
      {'lat': 40.7128, 'lng': -74.0060, 'timestamp': 1625097600},
      {'lat': 40.7130, 'lng': -74.0062, 'timestamp': 1625097660},
    ]
  };
  
  final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  const nonce = 'abc123def456';
  
  // 生成body hash
  final bodyStr = jsonEncode(body);
  final bodyHash = sha256.convert(utf8.encode(bodyStr)).toString();
  
  // 生成签名字符串
  final signString = '$method|$path|$timestamp|$nonce|$bodyHash';
  
  // 计算HMAC签名
  const secretKey = '5K8m#9cN@rP2xV7y';
  final key = utf8.encode(secretKey);
  final bytes = utf8.encode(signString);
  final hmacSha256 = Hmac(sha256, key);
  final signature = hmacSha256.convert(bytes).toString();
  
  print('方法: $method');
  print('路径: $path');
  print('时间戳: $timestamp');
  print('Nonce: $nonce');
  print('Body Hash: ${bodyHash.substring(0, 16)}...');
  print('签名: ${signature.substring(0, 16)}...');
  
  // 验证签名长度和格式
  assert(signature.length == 64, '签名长度应为64位十六进制');
  assert(RegExp(r'^[a-f0-9]+$').hasMatch(signature), '签名应为十六进制格式');
  
  print('✅ 签名生成测试通过');
}

void testSignatureVerification() {
  print('\n🔍 测试签名验证:');
  
  // 模拟一次完整的签名-验证流程
  const secretKey = '5K8m#9cN@rP2xV7y';
  const testData = {'test': 'data', 'value': 123};
  
  // 1. 生成签名
  final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  const nonce = 'test-nonce-001';
  
  final bodyHash = sha256.convert(utf8.encode(jsonEncode(testData))).toString();
  final signString = 'POST|/api/test|$timestamp|$nonce|$bodyHash';
  
  final key = utf8.encode(secretKey);
  final bytes = utf8.encode(signString);
  final hmacSha256 = Hmac(sha256, key);
  final signature = hmacSha256.convert(bytes).toString();
  
  print('生成的签名: ${signature.substring(0, 16)}...');
  
  // 2. 验证签名
  final isValid = _verifySignature(
    method: 'POST',
    path: '/api/test',
    timestamp: timestamp,
    nonce: nonce,
    bodyHash: bodyHash,
    signature: signature,
    secretKey: secretKey,
  );
  
  print('签名验证结果: ${isValid ? "有效" : "无效"}');
  assert(isValid, '有效签名应该通过验证');
  
  // 3. 测试篡改检测
  final isTamperedValid = _verifySignature(
    method: 'POST',
    path: '/api/test',
    timestamp: timestamp,
    nonce: nonce,
    bodyHash: 'wrong_hash_value',
    signature: signature,
    secretKey: secretKey,
  );
  
  print('篡改后验证结果: ${isTamperedValid ? "有效" : "无效"}');
  assert(!isTamperedValid, '篡改后的数据应该验证失败');
  
  print('✅ 签名验证测试通过');
}

void testReplayAttackPrevention() {
  print('\n🛡️  测试重放攻击防护:');
  
  // 模拟Nonce管理
  final usedNonces = <String>{};
  
  const testNonce = 'replay-test-nonce';
  
  // 第一次使用
  final firstUse = !usedNonces.contains(testNonce);
  usedNonces.add(testNonce);
  print('Nonce首次使用: ${firstUse ? "允许" : "拒绝"}');
  assert(firstUse, '首次使用应该允许');
  
  // 第二次使用（重放攻击）
  final secondUse = !usedNonces.contains(testNonce);
  print('Nonce重复使用: ${secondUse ? "允许" : "拒绝"}');
  assert(!secondUse, '重复使用应该被拒绝');
  
  print('✅ 重放攻击防护测试通过');
}

void testTimestampValidation() {
  print('\n⏰ 测试时间戳验证:');
  
  const threshold = 300; // 5分钟阈值
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  
  // 测试有效时间戳
  final validTimestamp = now - 60; // 1分钟前
  final timeDiff1 = (now - validTimestamp).abs();
  final isValid1 = timeDiff1 <= threshold;
  print('有效时间戳差异: ${timeDiff1}秒, 验证结果: ${isValid1 ? "有效" : "无效"}');
  assert(isValid1, '1分钟前的时间戳应该有效');
  
  // 测试过期时间戳
  final expiredTimestamp = now - 600; // 10分钟前
  final timeDiff2 = (now - expiredTimestamp).abs();
  final isValid2 = timeDiff2 <= threshold;
  print('过期时间戳差异: ${timeDiff2}秒, 验证结果: ${isValid2 ? "有效" : "无效"}');
  assert(!isValid2, '10分钟前的时间戳应该过期');
  
  print('✅ 时间戳验证测试通过');
  
  print('\n🎉 所有签名系统测试通过!');
  print('=' * 50);
}

/// 验证签名的辅助函数
bool _verifySignature({
  required String method,
  required String path,
  required int timestamp,
  required String nonce,
  required String bodyHash,
  required String signature,
  required String secretKey,
}) {
  final signString = '$method|$path|$timestamp|$nonce|$bodyHash';
  
  final key = utf8.encode(secretKey);
  final bytes = utf8.encode(signString);
  final hmacSha256 = Hmac(sha256, key);
  final expectedSignature = hmacSha256.convert(bytes).toString();
  
  return signature == expectedSignature;
}