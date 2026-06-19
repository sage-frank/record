import { useState, useEffect, useCallback } from 'react';
import {
  Layout,
  Menu,
  List,
  Typography,
  message,
  Spin,
  Empty,
  Button,
  Popconfirm,
} from 'antd';
import {
  HistoryOutlined,
  DeleteOutlined,
  ReloadOutlined,
} from '@ant-design/icons';
import axios from 'axios';
import dayjs from 'dayjs';
import TrackMap from './components/TrackMap';

const { Sider, Content } = Layout;
const { Text } = Typography;

interface Session {
  session_id: string;
  start_time: string;
  end_time: string;
  point_count: number;
}

interface TrackPoint {
  id: number;
  session_id: string;
  latitude: number;
  longitude: number;
  altitude: number | null;
  speed: number | null;
  timestamp: string;
}

function App() {
  const [sessions, setSessions] = useState<Session[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedSession, setSelectedSession] = useState<Session | null>(null);
  const [trackPoints, setTrackPoints] = useState<TrackPoint[]>([]);
  const [pointsLoading, setPointsLoading] = useState(false);

  const fetchSessions = useCallback(async () => {
    setLoading(true);
    try {
      const res = await axios.get('/api/sessions');
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

  const fetchTrackPoints = async (sessionId: string) => {
    setPointsLoading(true);
    try {
      const res = await axios.get(`/api/sessions/${sessionId}/track-points`);
      setTrackPoints(res.data.points || []);
    } catch {
      message.error('获取轨迹点失败');
    } finally {
      setPointsLoading(false);
    }
  };

  const handleSelectSession = (session: Session) => {
    setSelectedSession(session);
    fetchTrackPoints(session.session_id);
  };

  const handleDelete = async (sessionId: string) => {
    try {
      await axios.delete(`/api/sessions/${sessionId}`);
      message.success('删除成功');
      if (selectedSession?.session_id === sessionId) {
        setSelectedSession(null);
        setTrackPoints([]);
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
          <Empty
            description="暂无运动记录"
            style={{ marginTop: 80 }}
          />
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
                    borderLeft: isSelected ? '3px solid #1677ff' : '3px solid transparent',
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
                          轨迹点数: {session.point_count}
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

      {/* 右侧地图 */}
      <Content style={{ background: '#f5f5f5' }}>
        {selectedSession ? (
          <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
            <div
              style={{
                padding: '12px 24px',
                background: '#fff',
                borderBottom: '1px solid #f0f0f0',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
              }}
            >
              <Text strong>
                会话: {selectedSession.session_id.substring(0, 8)}...
                &nbsp;&nbsp;|&nbsp;&nbsp;
                {formatTime(selectedSession.start_time)}
              </Text>
              <Text type="secondary">
                共 {trackPoints.length} 个轨迹点
              </Text>
            </div>
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
                <TrackMap points={trackPoints} />
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
