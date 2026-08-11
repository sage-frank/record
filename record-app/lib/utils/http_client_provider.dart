import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http_io;

/// 统一 HTTP 客户端提供者：信任自签名证书（与服务端当前证书策略一致）
class HttpClientProvider {
  static http.Client? _client;

  static http.Client get() {
    if (_client != null) return _client!;
    final inner = HttpClient();
    inner.badCertificateCallback = (cert, host, port) => true;
    _client = http_io.IOClient(inner);
    return _client!;
  }
}
