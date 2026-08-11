import 'dart:convert';
import 'package:uuid/uuid.dart';

/// 请求 ID 生成器：每次 API 请求生成唯一 ID，
/// 随请求头发送（X-Request-Id），异常上报时携带，供后端记录与跟踪
class RequestIdProvider {
  static const Uuid _uuid = Uuid();

  static String generate() => _uuid.v4();
}
