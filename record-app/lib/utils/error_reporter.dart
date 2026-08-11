import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/repositories/error_repository.dart';
import '../domain/models/error_report.dart';
import 'request_id_provider.dart';

/// 全局异常上报入口（门面）：
/// 供全局异常处理器（main.dart）与既有页面 catch 块使用。
///
/// 规则：不允许吞掉异常 —— 无论上报是否成功，异常都会先输出到控制台。
class ErrorReporter {
  static ErrorReportRepository? _repository;

  /// App 版本（与 pubspec.yaml 保持一致）
  static const String appVersion = '3.0.0';

  static void init(ErrorReportRepository repository) {
    _repository = repository;
  }

  /// 上报错误级异常（默认级别，所有 catch 到真实异常时使用）
  static void reportError({
    required String message,
    required String source,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    String? url,
    String? requestId,
  }) {
    _report(
      level: 'error',
      message: message,
      source: source,
      error: error,
      stackTrace: stackTrace,
      context: context,
      url: url,
      requestId: requestId,
    );
  }

  /// 上报警告级异常（防御性回退等非致命问题，Web 端可单独筛选）
  static void reportWarning({
    required String message,
    required String source,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    String? url,
    String? requestId,
  }) {
    _report(
      level: 'warning',
      message: message,
      source: source,
      error: error,
      stackTrace: stackTrace,
      context: context,
      url: url,
      requestId: requestId,
    );
  }

  static void _report({
    required String level,
    required String message,
    required String source,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    String? url,
    String? requestId,
  }) {
    // 第一步：输出到控制台 —— 即使上报失败，异常也必须可见
    debugPrint('[ErrorReporter][$level][$source] $message');
    if (error != null) debugPrint('  error: $error');
    if (stackTrace != null) debugPrint('  stack: $stackTrace');

    final repository = _repository;
    if (repository == null) {
      debugPrint('[ErrorReporter] 未初始化，无法上报（异常已输出到控制台）');
      return;
    }

    final report = ErrorReport(
      requestId: requestId ?? RequestIdProvider.generate(),
      level: level,
      source: source,
      message: error != null ? '$message: $error' : message,
      stackTrace: stackTrace?.toString(),
      context: context,
      platform: _platformName(),
      appVersion: appVersion,
      url: url,
    );
    // 上报为后台任务：不阻塞主流程，失败由 Repository 缓冲重试
    unawaited(repository.report(report));
  }

  /// 平台标识（兼容 Web，不使用 dart:io Platform）
  static String _platformName() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.toString().split('.').last;
  }
}
