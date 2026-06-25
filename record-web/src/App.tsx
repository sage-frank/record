import { useState, useEffect, useCallback, useRef } from 'react';
import {
  Layout,
  List,
  Typography,
  message,
  Spin,
  Empty,
  Button,
  Popconfirm,
  Tag,
  Statistic,
  Card,
  Row,
  Col,
} from 'antd';
import {
  HistoryOutlined,
  DeleteOutlined,
  ReloadOutlined,
  EnvironmentOutlined,
  ClockCircleOutlined,
  FieldNumberOutlined,
  DashboardOutlined,
  PauseOutlined,
  PlayCircleOutlined,
} from '@ant-design/icons';
import axios from 'axios';
import dayjs from 'dayjs';
import TrackMap from './components/TrackMap';

// API 基础地址：开发时直接请求后端，不走 Vite 代理
const api = axios.create({
  baseURL: 'http://39.105.113.213:3001',
  timeout: 15000,
});

const { Sider, Content } = Layout;
const { Text } = Typography;

interface Session {
  session_id: string;
  start_time: string;
  end_time: string;
  point_count: number;
  total_steps: number;
}

interface TrackPoint {
  id: number;
  session_id: string;
  latitude: number;
  longitude: number;
  altitude: number | null;
  speed: number | null;
  steps: number | null;
  timestamp: string;
}

interface SessionStats {
  session_id: string;
  point_count: number;
  total_steps: number;
  start_time: string;
  last_latitude: number;
  last_longitude: number;
  last_timestamp: string;
}

function App() {
  const [sessions, setSessions] = useState<Session[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedSession, setSelectedSession] = useState<Session | null>(null);
  const [trackPoints, setTrackPoints] = useState<TrackPoint[]>([]);
  const [pointsLoading, setPointsLoading] = useState(false);
  const [sessionStats, setSessionStats] = useState<SessionStats | null>(null);
  const [isPolling, setIsPolling] = useState(false);
  const pollingRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const fetchSessions = useCallback(async () => {
    setLoading(true);
    try {
      const res = await api.get('/api/sessions');
      setSessions(res.data.sessions || []);
    } catch {
      message.error('获取会话列表失败，请确认 API 服务已启动');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchSessions();
  }, [fetchSessions]);

  // 清理轮询
  useEffect(() => {
    return () => {
      if (pollingRef.current) {
        clearInterval(pollingRef.current);
        pollingRef.current = null;
      }
      setIsPolling(false);
    };
  }, []);

  const fetchTrackPoints = async (sessionId: string) => {
    setPointsLoading(true);
    try {
      const [pointsRes, statsRes] = await Promise.all([
        api.get(`/api/sessions/${sessionId}/track-points`),
        api.get(`/api/sessions/${sessionId}/stats`),
      ]);
      setTrackPoints(pointsRes.data.points || []);
      if (statsRes.data.found) {
        setSessionStats(statsRes.data.stats);
      }
    } catch {
      message.error('获取轨迹点失败');
    } finally {
      setPointsLoading(false);
    }
  };

  // 启动实时轮询
  const startPolling = (sessionId: string) => {
    if (pollingRef.current) clearInterval(pollingRef.current);
    setIsPolling(true);
    pollingRef.current = setInterval(async () => {
      try {
        const [pointsRes, statsRes] = await Promise.all([
          api.get(`/api/sessions/${sessionId}/track-points`),
          api.get(`/api/sessions/${sessionId}/stats`),
        ]);
        setTrackPoints(pointsRes.data.points || []);
        if (statsRes.data.found) {
          setSessionStats(statsRes.data.stats);
        }
      } catch {
        // 静默失败，继续轮询
      }
    }, 3000); // 每 3 秒刷新
  };

  const stopPolling = () => {
    if (pollingRef.current) {
      clearInterval(pollingRef.current);
      pollingRef.current = null;
    }
    setIsPolling(false);
  };

  const handleSelectSession = (session: Session) => {
    setSelectedSession(session);
    fetchTrackPoints(session.session_id);
    startPolling(session.session_id);
  };

  const handleDelete = async (sessionId: string) => {
    try {
      await api.delete(`/api/sessions/${sessionId}`);
      message.success('删除成功');
      if (selectedSession?.session_id === sessionId) {
        setSelectedSession(null);
        setTrackPoints([]);
        setSessionStats(null);
        stopPolling();
      }
      fetchSessions();
    } catch {
      message.error('删除失败');
    }
  };

  const formatTime = (iso: string) => {
    return dayjs(iso).format('YYYY-MM-DD HH:mm:ss');
  };

  return (
    <Layout style={{ height: '100vh' }}>
      {/* 左侧会话列表 */}
      <Sider
        width={360}
        style={{
          background: '#fff',
          borderRight: '1px solid #f0f0f0',
          overflow: 'auto',
        }}
      >
        <div
          style={{
            padding: '16px 16px 12px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            borderBottom: '1px solid #f0f0f0',
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <HistoryOutlined style={{ fontSize: 20, color: '#1677ff' }} />
            <Text strong style={{ fontSize: 16 }}>
              运动记录
            </Text>
          </div>
          <Button
            icon={<ReloadOutlined />}
            size="small"
            onClick={fetchSessions}
            loading={loading}
          />
        </div>

        {loading ? (
          <div style={{ textAlign: 'center', padding: 40 }}>
            <Spin />
          </div>
        ) : sessions.length === 0 ? (
          <Empty description="暂无运动记录" style={{ marginTop: 80 }} />
        ) : (
          <List
            dataSource={sessions}
            renderItem={(session) => {
              const isSelected =
                selectedSession?.session_id === session.session_id;
              return (
                <List.Item
                  onClick={() => handleSelectSession(session)}
                  style={{
                    padding: '12px 16px',
                    cursor: 'pointer',
                    background: isSelected ? '#e6f4ff' : '#fff',
                    borderLeft: isSelected
                      ? '3px solid #1677ff'
                      : '3px solid transparent',
                    transition: 'background 0.2s',
                  }}
                  actions={[
                    <Popconfirm
                      key="delete"
                      title="确定删除该运动记录？"
                      onConfirm={(e) => {
                        e?.stopPropagation();
                        handleDelete(session.session_id);
                      }}
                      onCancel={(e) => e?.stopPropagation()}
                    >
                      <Button
                        type="text"
                        danger
                        size="small"
                        icon={<DeleteOutlined />}
                        onClick={(e) => e.stopPropagation()}
                      />
                    </Popconfirm>,
                  ]}
                >
                  <List.Item.Meta
                    title={
                      <Text strong={isSelected}>
                        {formatTime(session.start_time)}
                      </Text>
                    }
                    description={
                      <div>
                        <Text type="secondary" style={{ fontSize: 12 }}>
                          轨迹: {session.point_count} 点
                        </Text>
                        <Text type="secondary" style={{ fontSize: 12, marginLeft: 12 }}>
                          步数: {session.total_steps ?? 0}
                        </Text>
                        <br />
                        <Text type="secondary" style={{ fontSize: 12 }}>
                          {formatTime(session.start_time)} ~{' '}
                          {formatTime(session.end_time)}
                        </Text>
                      </div>
                    }
                  />
                </List.Item>
              );
            }}
          />
        )}
      </Sider>

      {/* 右侧地图 + 统计 */}
      <Content style={{ background: '#f5f5f5' }}>
        {selectedSession ? (
          <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
            {/* 统计面板 */}
            <div
              style={{
                padding: '12px 24px',
                background: '#fff',
                borderBottom: '1px solid #f0f0f0',
              }}
            >
              <Row gutter={16}>
                <Col span={6}>
                  <Statistic
                    title="轨迹点数"
                    value={sessionStats?.point_count ?? trackPoints.length}
                    prefix={<EnvironmentOutlined />}
                    valueStyle={{ fontSize: 18 }}
                  />
                </Col>
                <Col span={6}>
                  <Statistic
                    title="总步数"
                    value={sessionStats?.total_steps ?? 0}
                    prefix={<FieldNumberOutlined />}
                    valueStyle={{ fontSize: 18 }}
                  />
                </Col>
                <Col span={6}>
                  <Statistic
                    title="开始时间"
                    value={sessionStats?.start_time ? formatTime(sessionStats.start_time) : formatTime(selectedSession.start_time)}
                    prefix={<ClockCircleOutlined />}
                    valueStyle={{ fontSize: 14 }}
                  />
                </Col>
                <Col span={6}>
                  <Statistic
                    title="最后更新"
                    value={
                      sessionStats?.last_timestamp
                        ? formatTime(sessionStats.last_timestamp)
                        : '--'
                    }
                    prefix={<DashboardOutlined />}
                    valueStyle={{ fontSize: 14 }}
                  />
                  <div style={{ marginTop: 4, display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                    <Tag color={isPolling ? 'processing' : 'default'}>
                      {isPolling ? '实时监控中' : '监控已暂停'}
                    </Tag>
                    <Button
                      size="small"
                      type={isPolling ? 'default' : 'primary'}
                      icon={isPolling ? <PauseOutlined /> : <PlayCircleOutlined />}
                      onClick={() => {
                        if (!selectedSession) return;
                        if (isPolling) {
                          stopPolling();
                        } else {
                          fetchTrackPoints(selectedSession.session_id);
                          startPolling(selectedSession.session_id);
                        }
                      }}
                    >
                      {isPolling ? '暂停监控' : '开始监控'}
                    </Button>
                  </div>
                </Col>
              </Row>
            </div>

            {/* 地图 */}
            <div style={{ flex: 1, position: 'relative' }}>
              {pointsLoading ? (
                <div
                  style={{
                    display: 'flex',
                    justifyContent: 'center',
                    alignItems: 'center',
                    height: '100%',
                  }}
                >
                  <Spin tip="加载轨迹中..." />
                </div>
              ) : (
                <TrackMap
                  points={trackPoints}
                  showLiveStats={
                    isPolling && sessionStats != null
                  }
                  sessionStats={sessionStats}
                />
              )}
            </div>
          </div>
        ) : (
          <div
            style={{
              display: 'flex',
              justifyContent: 'center',
              alignItems: 'center',
              height: '100%',
            }}
          >
            <Empty description="请从左侧选择一个运动记录查看轨迹" />
          </div>
        )}
      </Content>
    </Layout>
  );
}

export default App;
