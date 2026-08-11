import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/error_report.dart';
import '../services/error_reporter_service.dart';

/// 异常日志仓库（Data 层）：消费 ErrorReporterService，
/// 负责离线缓冲与重试，保证异常"不丢失、不吞掉"。
class ErrorReportRepository {
  ErrorReportRepository({required ErrorReporterService service})
      : _service = service;

  final ErrorReporterService _service;

  static const String _pendingKey = 'pending_error_reports';

  /// 上报异常：成功则顺带重试积压队列；
  /// 失败（如离线）时输出到控制台并持久化到本地，下次启动/下次上报时重试。
  Future<void> report(ErrorReport report) async {
    try {
      await _service.report(report);
      await flushPending();
    } catch (e) {
      debugPrint('[ErrorReporter] 上报失败，已暂存待重试: $e\n$report');
      await _enqueuePending(report);
    }
  }

  /// 重试积压队列（App 启动时调用）
  Future<void> flushPending() async {
    final pending = await _loadPending();
    if (pending.isEmpty) return;
    debugPrint('[ErrorReporter] 尝试补报 ${pending.length} 条积压异常');
    for (final report in pending) {
      try {
        await _service.report(report);
      } catch (e) {
        debugPrint('[ErrorReporter] 补报失败，保留在队列: $e\n$report');
        return; // 网络仍不可用，保留剩余队列，下次再试
      }
    }
    await _clearPending();
  }

  // ── 队列持久化 ──────────────────────────────────

  Future<void> _enqueuePending(ErrorReport report) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await _loadPending();
      list.add(report);
      await prefs.setString(
        _pendingKey,
        jsonEncode(list.map((r) => r.toJson()).toList()),
      );
    } catch (e) {
      // 持久化本身失败：至少输出到控制台，不吞掉
      debugPrint('[ErrorReporter] 积压队列持久化失败: $e\n$report');
    }
  }

  Future<List<ErrorReport>> _loadPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingKey);
      if (raw == null || raw.isEmpty) return [];
      final list = List<Map<String, dynamic>>.from(jsonDecode(raw));
      return list.map(_fromJson).whereType<ErrorReport>().toList();
    } catch (e) {
      debugPrint('[ErrorReporter] 读取积压队列失败: $e');
      return [];
    }
  }

  Future<void> _clearPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingKey);
    } catch (e) {
      debugPrint('[ErrorReporter] 清理积压队列失败: $e');
    }
  }

  /// 将后端字段格式的 Map 还原为领域模型
  ErrorReport? _fromJson(Map<String, dynamic> json) {
    try {
      return ErrorReport(
        requestId: json['request_id'] as String,
        level: json['level'] as String? ?? 'error',
        source: json['source'] as String? ?? 'unknown',
        message: json['message'] as String,
        stackTrace: json['stack_trace'] as String?,
        context: json['context'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(json['context'] as Map)
            : null,
        platform: json['platform'] as String?,
        appVersion: json['app_version'] as String?,
        deviceId: json['device_id'] as String?,
        url: json['url'] as String?,
      );
    } catch (e) {
      debugPrint('[ErrorReporter] 队列数据解析失败: $e');
      return null;
    }
  }
}
