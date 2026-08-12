import { useCallback, useEffect, useState } from 'react';
import {
  Button,
  Card,
  DatePicker,
  Descriptions,
  Drawer,
  Input,
  Select,
  Space,
  Table,
  Tag,
  Typography,
  message,
} from 'antd';
import {
  ClearOutlined,
  ReloadOutlined,
  SearchOutlined,
} from '@ant-design/icons';
import axios from 'axios';
import dayjs, { Dayjs } from 'dayjs';
import { API_BASE_URL } from '../config';

const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 15000,
});

interface ErrorLog {
  id: number;
  request_id: string;
  level: string;
  source: string;
  message: string;
  stack_trace: string | null;
  context: string | null;
  platform: string | null;
  app_version: string | null;
  device_id: string | null;
  url: string | null;
  created_at: string;
}

const levelColors: Record<string, string> = {
  error: 'red',
  warning: 'orange',
  info: 'blue',
  debug: 'default',
};

// 后端 created_at 为 UTC（如 "2026-08-11 07:28:55"），转换为本地时间展示
const formatTime = (utc: string) => {
  if (!utc) return '--';
  return dayjs(utc.replace(' ', 'T') + 'Z').format('YYYY-MM-DD HH:mm:ss');
};

// 格式化 context JSON 字符串
const formatContext = (raw: string | null) => {
  if (!raw) return '(无)';
  try {
    return JSON.stringify(JSON.parse(raw), null, 2);
  } catch {
    return raw;
  }
};

function ErrorLogs() {
  const [logs, setLogs] = useState<ErrorLog[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);

  // 筛选条件
  const [level, setLevel] = useState<string | undefined>();
  const [keyword, setKeyword] = useState('');
  const [requestId, setRequestId] = useState('');
  const [source, setSource] = useState('');
  const [range, setRange] = useState<[Dayjs | null, Dayjs | null] | null>(
    null,
  );

  const [detail, setDetail] = useState<ErrorLog | null>(null);

  const fetchLogs = useCallback(async () => {
    setLoading(true);
    try {
      const params: Record<string, unknown> = { page, page_size: pageSize };
      if (level) params.level = level;
      if (keyword.trim()) params.keyword = keyword.trim();
      if (requestId.trim()) params.request_id = requestId.trim();
      if (source.trim()) params.source = source.trim();
      if (range?.[0]) {
        // toISOString() 为 UTC 时间，转成与数据库一致的 "YYYY-MM-DD HH:mm:ss"
        params.start = range[0]
          .toISOString()
          .slice(0, 19)
          .replace('T', ' ');
      }
      if (range?.[1]) {
        params.end = range[1]
          .toISOString()
          .slice(0, 19)
          .replace('T', ' ');
      }
      const res = await api.get('/errors', { params });
      setLogs(res.data.logs || []);
      setTotal(res.data.total || 0);
    } catch (e) {
      message.error('获取异常日志失败，请确认 API 服务已启动');
      console.error('fetch error logs failed:', e);
    } finally {
      setLoading(false);
    }
  }, [level, keyword, requestId, source, range, page, pageSize]);

  useEffect(() => {
    fetchLogs();
  }, [fetchLogs]);

  const resetFilters = () => {
    setLevel(undefined);
    setKeyword('');
    setRequestId('');
    setSource('');
    setRange(null);
    setPage(1);
  };

  const columns = [
    {
      title: 'ID',
      dataIndex: 'id',
      width: 70,
      render: (id: number) => <Typography.Text type="secondary">#{id}</Typography.Text>,
    },
    {
      title: '级别',
      dataIndex: 'level',
      width: 90,
      render: (lv: string) => <Tag color={levelColors[lv] ?? 'default'}>{lv}</Tag>,
    },
    {
      title: '时间',
      dataIndex: 'created_at',
      width: 170,
      render: formatTime,
    },
    {
      title: '来源',
      dataIndex: 'source',
      width: 140,
      render: (s: string) => <Tag>{s || '-'}</Tag>,
    },
    {
      title: '消息',
      dataIndex: 'message',
      ellipsis: true,
      render: (msg: string) => (
        <Typography.Text style={{ fontFamily: 'monospace' }}>{msg}</Typography.Text>
      ),
    },
    {
      title: '请求 ID',
      dataIndex: 'request_id',
      width: 220,
      ellipsis: true,
      render: (rid: string) => (
        <Typography.Text style={{ fontFamily: 'monospace' }} copyable>
          {rid}
        </Typography.Text>
      ),
    },
    {
      title: '设备',
      dataIndex: 'device_id',
      width: 150,
      ellipsis: true,
      render: (d: string | null) => d || '-',
    },
    {
      title: '操作',
      width: 90,
      render: (_: unknown, record: ErrorLog) => (
        <Button type="link" size="small" onClick={() => setDetail(record)}>
          查看
        </Button>
      ),
    },
  ];

  return (
    <Card
      style={{ margin: 16, height: 'calc(100vh - 88px)', overflow: 'auto' }}
      title={
        <Space>
          <Typography.Text strong style={{ fontSize: 16 }}>
            异常日志
          </Typography.Text>
          <Typography.Text type="secondary" style={{ fontSize: 13 }}>
            共 {total} 条（类似 Sentry 的轻量实现）
          </Typography.Text>
        </Space>
      }
      extra={
        <Button icon={<ReloadOutlined />} onClick={fetchLogs} loading={loading}>
          刷新
        </Button>
      }
    >
      <Space wrap style={{ marginBottom: 16 }}>
        <Select
          placeholder="级别"
          allowClear
          style={{ width: 110 }}
          value={level}
          onChange={setLevel}
          options={['error', 'warning', 'info', 'debug'].map((lv) => ({
            value: lv,
            label: lv,
          }))}
        />
        <Input
          placeholder="关键词 (消息/堆栈)"
          style={{ width: 180 }}
          value={keyword}
          onChange={(e) => setKeyword(e.target.value)}
          onPressEnter={fetchLogs}
          allowClear
        />
        <Input
          placeholder="请求 ID"
          style={{ width: 240 }}
          value={requestId}
          onChange={(e) => setRequestId(e.target.value)}
          onPressEnter={fetchLogs}
          allowClear
        />
        <Input
          placeholder="来源"
          style={{ width: 140 }}
          value={source}
          onChange={(e) => setSource(e.target.value)}
          onPressEnter={fetchLogs}
          allowClear
        />
        <DatePicker.RangePicker
          value={range}
          onChange={(dates) => setRange(dates)}
          showTime
        />
        <Button type="primary" icon={<SearchOutlined />} onClick={fetchLogs}>
          查询
        </Button>
        <Button icon={<ClearOutlined />} onClick={resetFilters}>
          重置
        </Button>
      </Space>

      <Table<ErrorLog>
        rowKey="id"
        size="small"
        loading={loading}
        columns={columns}
        dataSource={logs}
        pagination={{
          current: page,
          pageSize,
          total,
          showSizeChanger: true,
          showTotal: (t) => `共 ${t} 条`,
          onChange: (p, ps) => {
            setPage(p);
            setPageSize(ps);
          },
        }}
      />

      {/* 详情抽屉 */}
      <Drawer
        title={
          detail ? (
            <Space>
              异常详情
              <Tag color={levelColors[detail.level] ?? 'default'}>
                {detail.level}
              </Tag>
            </Space>
          ) : (
            '异常详情'
          )
        }
        width={720}
        open={detail != null}
        onClose={() => setDetail(null)}
      >
        {detail && (
          <>
            <Descriptions
              size="small"
              bordered
              column={2}
              style={{ marginBottom: 16 }}
            >
              <Descriptions.Item label="ID">#{detail.id}</Descriptions.Item>
              <Descriptions.Item label="时间">
                {formatTime(detail.created_at)}
              </Descriptions.Item>
              <Descriptions.Item label="请求 ID" span={2}>
                <Typography.Text style={{ fontFamily: 'monospace' }} copyable>
                  {detail.request_id}
                </Typography.Text>
              </Descriptions.Item>
              <Descriptions.Item label="来源">{detail.source || '-'}</Descriptions.Item>
              <Descriptions.Item label="平台">{detail.platform || '-'}</Descriptions.Item>
              <Descriptions.Item label="App 版本">
                {detail.app_version || '-'}
              </Descriptions.Item>
              <Descriptions.Item label="设备">
                <Typography.Text
                  style={{ fontFamily: 'monospace', fontSize: 12 }}
                  ellipsis
                >
                  {detail.device_id || '-'}
                </Typography.Text>
              </Descriptions.Item>
              <Descriptions.Item label="出错接口" span={2}>
                <Typography.Text
                  style={{ fontFamily: 'monospace', fontSize: 12 }}
                >
                  {detail.url || '-'}
                </Typography.Text>
              </Descriptions.Item>
            </Descriptions>

            <Typography.Title level={5}>消息</Typography.Title>
            <pre style={{ whiteSpace: 'pre-wrap', wordBreak: 'break-all' }}>
              {detail.message}
            </pre>

            <Typography.Title level={5}>堆栈</Typography.Title>
            <pre
              style={{
                maxHeight: 320,
                overflow: 'auto',
                background: '#f6f6f6',
                padding: 12,
                borderRadius: 8,
                whiteSpace: 'pre-wrap',
                wordBreak: 'break-all',
              }}
            >
              {detail.stack_trace || '(无)'}
            </pre>

            <Typography.Title level={5}>上下文</Typography.Title>
            <pre
              style={{
                maxHeight: 320,
                overflow: 'auto',
                background: '#f6f6f6',
                padding: 12,
                borderRadius: 8,
                whiteSpace: 'pre-wrap',
                wordBreak: 'break-all',
              }}
            >
              {formatContext(detail.context)}
            </pre>
          </>
        )}
      </Drawer>
    </Card>
  );
}

export default ErrorLogs;
