import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/signature_utils.dart';

/// 安全管理服务 - 密钥和敏感信息管理
class SecurityService {
  static SecurityService? _instance;
  static SecurityService get instance => _instance ??= SecurityService._();
  SecurityService._();

  SharedPreferences? _prefs;

  /// 初始化安全服务
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    
    // 检查是否需要生成新的设备ID
    if (!await _hasDeviceId()) {
      await _generateDeviceId();
    }
  }

  /// 获取设备唯一ID
  Future<String> getDeviceId() async {
    await _ensureInitialized();
    return _prefs!.getString('device_id') ?? '';
  }

  /// 获取当前密钥版本
  Future<int> getKeyVersion() async {
    await _ensureInitialized();
    return _prefs!.getInt('key_version') ?? 1;
  }

  /// 触发密钥轮换（用于安全更新）
  Future<void> rotateKeys() async {
    await _ensureInitialized();
    final currentVersion = await getKeyVersion();
    await _prefs!.setInt('key_version', currentVersion + 1);
    
    if (kDebugMode) {
      print('🔄 密钥已轮换，新版本: ${currentVersion + 1}');
    }
  }

  /// 安全存储敏感数据
  Future<void> storeSecureData(String key, String value) async {
    await _ensureInitialized();
    
    // 在实际生产环境中，这里应该使用更安全的加密方式
    // 如：flutter_secure_storage 包
    final deviceId = await getDeviceId();
    final obfuscatedValue = _obfuscateData(value, deviceId);
    await _prefs!.setString('secure_$key', obfuscatedValue);
  }

  /// 安全获取敏感数据
  Future<String?> getSecureData(String key) async {
    await _ensureInitialized();
    
    final obfuscatedValue = _prefs!.getString('secure_$key');
    if (obfuscatedValue == null) return null;
    
    final deviceId = await getDeviceId();
    return _deobfuscateData(obfuscatedValue, deviceId);
  }

  /// 清理安全数据
  Future<void> clearSecureData() async {
    await _ensureInitialized();
    
    final keysToRemove = <String>[];
    for (final key in _prefs!.getKeys()) {
      if (key.startsWith('secure_')) {
        keysToRemove.add(key);
      }
    }
    
    for (final key in keysToRemove) {
      await _prefs!.remove(key);
    }
    
    if (kDebugMode) {
      print('🔒 安全数据已清理，删除 ${keysToRemove.length} 项');
    }
  }

  /// 标记Nonce已使用（防止重放攻击）
  void markNonceUsed(String nonce) {
    NonceManager.markNonceUsed(nonce);
  }

  /// 检查Nonce是否已使用
  bool isNonceUsed(String nonce) {
    return NonceManager.isNonceUsed(nonce);
  }

  /// 数据混淆（基础保护，生产环境建议更强加密）
  String _obfuscateData(String data, String key) {
    final dataBytes = utf8.encode(data);
    final keyBytes = utf8.encode(key);
    
    final result = <int>[];
    for (int i = 0; i < dataBytes.length; i++) {
      result.add(dataBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    
    return base64Encode(result);
  }

  /// 数据去混淆
  String _deobfuscateData(String obfuscatedData, String key) {
    try {
      final obfuscatedBytes = base64Decode(obfuscatedData);
      final keyBytes = utf8.encode(key);
      
      final result = <int>[];
      for (int i = 0; i < obfuscatedBytes.length; i++) {
        result.add(obfuscatedBytes[i] ^ keyBytes[i % keyBytes.length]);
      }
      
      return utf8.decode(result);
    } catch (e) {
      if (kDebugMode) {
        print('🔓 数据去混淆失败: $e');
      }
      return '';
    }
  }

  /// 生成设备唯一ID
  Future<void> _generateDeviceId() async {
    await _ensureInitialized();
    
    // 生成基于时间戳和设备信息的ID
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    final deviceId = 'device_${timestamp}_$random';
    
    await _prefs!.setString('device_id', deviceId);
    
    if (kDebugMode) {
      print('🔑 生成新设备ID: $deviceId');
    }
  }

  /// 检查是否有设备ID
  Future<bool> _hasDeviceId() async {
    await _ensureInitialized();
    return _prefs!.containsKey('device_id');
  }

  /// 确保初始化
  Future<void> _ensureInitialized() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }
  }
}