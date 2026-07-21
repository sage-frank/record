import 'package:flutter/material.dart';
import 'dart:convert';

/// API 调试助手 - 用于显示请求/响应的详细信息
class DebugHelper {
  /// 调试模式开关
  static bool isEnabled = true;
  
  /// 存储最近的调试信息
  static final List<DebugInfo> _debugLogs = [];
  
  /// 最大保存的日志数量
  static const int _maxLogSize = 50;
  
  /// 添加调试日志
  static void log({
    required String method,
    required String url,
    required Map<String, String> headers,
    dynamic body,
    int? statusCode,
    String? responseBody,
    DateTime? timestamp,
  }) {
    if (!isEnabled) return;
    
    final info = DebugInfo(
      timestamp: timestamp ?? DateTime.now(),
      method: method,
      url: url,
      headers: headers,
      body: body,
      statusCode: statusCode,
      responseBody: responseBody,
    );
    
    _debugLogs.insert(0, info);
    if (_debugLogs.length > _maxLogSize) {
      _debugLogs.removeLast();
    }
  }
  
  /// 获取所有日志
  static List<DebugInfo> get logs => List.unmodifiable(_debugLogs);
  
  /// 清空日志
  static void clear() => _debugLogs.clear();
  
  /// 显示调试面板（Overlay）
  static void showDebugPanel(BuildContext context) {
    if (!isEnabled) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DebugPanel(),
    );
  }
}

/// 调试信息数据类
class DebugInfo {
  final DateTime timestamp;
  final String method;
  final String url;
  final Map<String, String> headers;
  final dynamic body;
  final int? statusCode;
  final String? responseBody;
  
  DebugInfo({
    required this.timestamp,
    required this.method,
    required this.url,
    required this.headers,
    this.body,
    this.statusCode,
    this.responseBody,
  });
  
  /// 获取格式化的时间戳
  String get formattedTime => 
    '${timestamp.hour.toString().padLeft(2, '0')}:'
    '${timestamp.minute.toString().padLeft(2, '0')}:'
    '${timestamp.second.toString().padLeft(2, '0')}';
}

/// 调试面板 Widget
class DebugPanel extends StatefulWidget {
  @override
  _DebugPanelState createState() => _DebugPanelState();
}

class _DebugPanelState extends State<DebugPanel> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.bug_report, color: Colors.green[400]),
                    SizedBox(width: 8),
                    Text(
                      'API 调试面板',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // 清空按钮
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.grey[400]),
                      onPressed: () {
                        setState(() {
                          DebugHelper.clear();
                        });
                      },
                      tooltip: '清空日志',
                    ),
                    // 关闭按钮
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 日志列表
          Expanded(
            child: DebugHelper.logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey[600]),
                      SizedBox(height: 16),
                      Text(
                        '暂无调试日志',
                        style: TextStyle(color: Colors.grey[500], fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: DebugHelper.logs.length,
                  itemBuilder: (context, index) {
                    final info = DebugHelper.logs[index];
                    return _buildDebugCard(info);
                  },
                ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDebugCard(DebugInfo info) {
    final isSuccess = info.statusCode == null || info.statusCode == 200;
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Color(0xFF2D2D2D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isSuccess ? Colors.green : Colors.red,
            shape: BoxShape.circle,
          ),
        ),
        title: Text(
          '${info.method} ${info.url.split('/').last}',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          '${info.formattedTime} ${info.statusCode != null ? "| ${info.statusCode}" : ""}',
          style: TextStyle(color: Colors.grey[400]!, fontSize: 12),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // URL
                _buildSection('URL', info.url, Icons.link),
                SizedBox(height: 12),
                
                // Headers
                _buildSection('Headers', 
                  info.headers.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
                  Icons.vpn_key,
                ),
                SizedBox(height: 12),
                
                // Body
                if (info.body != null)
                  ...[
                    _buildSection('Body',
                      const JsonEncoder.withIndent('  ').convert(info.body),
                      Icons.data_object,
                    ),
                    SizedBox(height: 12),
                  ],
                
                // Response
                if (info.responseBody != null)
                  _buildSection('Response', 
                    info.responseBody!.length > 500 
                      ? '${info.responseBody!.substring(0, 500)}...' 
                      : info.responseBody!,
                    Icons.receipt_long,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSection(String title, String content, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.blue[400]),
            SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: Colors.blue[400],
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            content,
            style: TextStyle(
              color: Colors.green[300],
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

/// 浮动调试按钮 - 可以放在任何页面
class DebugFloatingButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (!DebugHelper.isEnabled) return SizedBox.shrink();
    
    return Positioned(
      right: 16,
      bottom: 80,
      child: SizedBox(
        width: 40,
        height: 40,
        child: FloatingActionButton(
          backgroundColor: Colors.orange[700],
          heroTag: 'debug_button',
          onPressed: () => DebugHelper.showDebugPanel(context),
          child: Icon(Icons.bug_report, size: 20, color: Colors.white),
          tooltip: '打开调试面板',
        ),
      ),
    );
  }
}
