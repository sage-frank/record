import 'dart:convert';

import '../../domain/models/error_report.dart';
import '../../utils/http_client_provider.dart';
import '../../utils/signature_utils.dart';

/// 异常上报服务（Data 层）：负责将异常日志签名上报到后端 /api/errors。
/// 无状态，只做 HTTP 交互，不包含缓冲/重试逻辑（由 Repository 负责）。
class ErrorReporterService {
  ErrorReporterService({required this.baseUrl});

  /// API 基础地址（含 /api 后缀），与 ApiService 保持一致
  final String baseUrl;

  static const Duration _timeout = Duration(seconds: 10);

  /// 上报单条异常日志；失败时抛出异常，由调用方决定如何处理
  Future<void> report(ErrorReport report) async {
    const path = '/api/errors';
    final body = report.toJson();
    final headers = SignatureUtils.generateSignature(
      method: 'POST',
      path: path,
      body: body,
    );

    final response = await HttpClientProvider.get()
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {
            ...headers,
            'Content-Type': 'application/json',
            'X-Request-Id': report.requestId,
          },
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception(
        '异常上报失败: HTTP ${response.statusCode}: ${response.body}',
      );
    }
  }
}
