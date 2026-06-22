import { useEffect, useMemo } from 'react';
import {
  MapContainer,
  TileLayer,
  Polyline,
  Marker,
  Popup,
  useMap,
} from 'react-leaflet';
import L from 'leaflet';

// 修复 Leaflet 默认图标问题
import icon from 'leaflet/dist/images/marker-icon.png';
import iconShadow from 'leaflet/dist/images/marker-shadow.png';

const DefaultIcon = L.icon({
  iconUrl: icon,
  shadowUrl: iconShadow,
  iconSize: [25, 41],
  iconAnchor: [12, 41],
});

L.Marker.prototype.options.icon = DefaultIcon;

interface TrackPoint {
  id: number;
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

interface Props {
  points: TrackPoint[];
  showLiveStats?: boolean;
  sessionStats?: SessionStats | null;
}

// 自动适配地图视野
function MapBoundsUpdater({ points }: { points: [number, number][] }) {
  const map = useMap();

  useEffect(() => {
    if (points.length > 0) {
      const bounds = L.latLngBounds(points);
      map.fitBounds(bounds, { padding: [50, 50] });
    }
  }, [points, map]);

  return null;
}

export default function TrackMap({ points, showLiveStats, sessionStats }: Props) {
  const positions: [number, number][] = useMemo(
    () => points.map((p) => [p.latitude, p.longitude]),
    [points],
  );

  const center: [number, number] =
    positions.length > 0
      ? positions[Math.floor(positions.length / 2)]
      : [39.9042, 116.4074];

  // 起点标记样式
  const startIcon = L.divIcon({
    className: '',
    html: '<div style="background:#52c41a;width:12px;height:12px;border-radius:50%;border:2px solid white;box-shadow:0 0 4px rgba(0,0,0,0.3)"></div>',
    iconSize: [16, 16],
    iconAnchor: [8, 8],
  });

  // 终点/实时位置标记样式
  const endIcon = L.divIcon({
    className: '',
    html: '<div style="background:#ff4d4f;width:14px;height:14px;border-radius:50%;border:2px solid white;box-shadow:0 0 6px rgba(255,0,0,0.5);animation:pulse 1.5s infinite"></div>',
    iconSize: [18, 18],
    iconAnchor: [9, 9],
  });

  // 中间点标记
  const pointIcon = L.divIcon({
    className: '',
    html: '<div style="background:#1677ff;width:6px;height:6px;border-radius:50%;border:1px solid white"></div>',
    iconSize: [10, 10],
    iconAnchor: [5, 5],
  });

  return (
    <MapContainer
      center={center}
      zoom={13}
      style={{ height: '100%', width: '100%' }}
    >
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> | &copy; 高德'
        url="https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}"
        subdomains={['1', '2', '3', '4']}
        maxZoom={18}
      />

      {/* 轨迹线 */}
      {positions.length >= 2 && (
        <Polyline
          positions={positions}
          color="#1677ff"
          weight={4}
          opacity={0.8}
        />
      )}

      {/* 起点标记 */}
      {positions.length > 0 && (
        <Marker position={positions[0]} icon={startIcon}>
          <Popup>起点</Popup>
        </Marker>
      )}

      {/* 终点/实时位置标记 */}
      {positions.length > 1 && (
        <Marker
          position={positions[positions.length - 1]}
          icon={endIcon}
        >
          <Popup>
            <div>
              <b>{showLiveStats ? '实时位置' : '终点'}</b>
              <br />
              步数: {points[points.length - 1]?.steps ?? 0}
              <br />
              时间: {points[points.length - 1]?.timestamp ?? '--'}
            </div>
          </Popup>
        </Marker>
      )}

      {/* 中间点（仅显示最近几个） */}
      {positions.length > 3 &&
        positions.slice(-5, -1).map((pos, i) => (
          <Marker key={i} position={pos} icon={pointIcon}>
            <Popup>
              步数: {points[points.length - 5 + i]?.steps ?? 0}
            </Popup>
          </Marker>
        ))}

      {/* 实时统计浮层 */}
      {showLiveStats && sessionStats && (
        <div
          style={{
            position: 'absolute',
            top: 10,
            right: 10,
            zIndex: 1000,
            background: 'rgba(255,255,255,0.95)',
            padding: '8px 12px',
            borderRadius: 8,
            boxShadow: '0 2px 8px rgba(0,0,0,0.15)',
            fontSize: 12,
          }}
        >
          <div>📍 位置: {sessionStats.last_latitude.toFixed(5)}, {sessionStats.last_longitude.toFixed(5)}</div>
          <div>👣 步数: {sessionStats.total_steps}</div>
          <div>📊 点数: {sessionStats.point_count}</div>
        </div>
      )}

      <MapBoundsUpdater points={positions} />
    </MapContainer>
  );
}
