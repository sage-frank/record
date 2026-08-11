/// 异常报告领域模型（上报到 record-api 的 /api/errors）
class ErrorReport {
  const ErrorReport({
    required this.requestId,
    required this.level,
    required this.source,
    required this.message,
    this.stackTrace,
    this.context,
    this.platform,
    this.appVersion,
    this.deviceId,
    this.url,
  });

  /// 客户端请求 ID：用于与具体 API 请求关联，后端据此跟踪
  final String requestId;

  /// 级别：error / warning / info / debug
  final String level;

  /// 来源标识，如 api_service / location_service / flutter
  final String source;

  final String message;
  final String? stackTrace;

  /// 附加上下文（键值对，可序列化为 JSON）
  final Map<String, dynamic>? context;
  final String? platform;
  final String? appVersion;
  final String? deviceId;
  final String? url;

  /// 序列化为后端接口字段
  Map<String, dynamic> toJson() {
    final ctx = <String, dynamic>{
      // 客户端发生时间（毫秒时间戳）；后端 created_at 是服务器时间，
      // 离线补报场景下以 client_ts 还原真实发生时间
      'client_ts': DateTime.now().millisecondsSinceEpoch,
      ...?context,
    };
    return {
      'request_id': requestId,
      'level': level,
      'source': source,
      'message': message,
      if (stackTrace != null && stackTrace!.isNotEmpty)
        'stack_trace': stackTrace,
      if (ctx.isNotEmpty) 'context': ctx,
      if (platform != null && platform!.isNotEmpty) 'platform': platform,
      if (appVersion != null && appVersion!.isNotEmpty)
        'app_version': appVersion,
      if (deviceId != null && deviceId!.isNotEmpty) 'device_id': deviceId,
      if (url != null && url!.isNotEmpty) 'url': url,
    };
  }

  @override
  String toString() =>
      'ErrorReport(level=$level, source=$source, requestId=$requestId, '
      'message=$message, url=$url)';
}
