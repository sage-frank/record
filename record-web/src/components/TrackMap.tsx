import { useEffect, useMemo } from 'react';
import {
  MapContainer,
  TileLayer,
  Polyline,
  Marker,
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
  timestamp: string;
}

interface Props {
  points: TrackPoint[];
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

export default function TrackMap({ points }: Props) {
  const positions: [number, number][] = useMemo(
    () => points.map((p) => [p.latitude, p.longitude]),
    [points],
  );

  const center: [number, number] =
    positions.length > 0
      ? positions[Math.floor(positions.length / 2)]
      : [39.9042, 116.4074];

  // 起点和终点标记样式
  const startIcon = L.divIcon({
    className: '',
    html: '<div style="background:#52c41a;width:12px;height:12px;border-radius:50%;border:2px solid white;box-shadow:0 0 4px rgba(0,0,0,0.3)"></div>',
    iconSize: [16, 16],
    iconAnchor: [8, 8],
  });

  const endIcon = L.divIcon({
    className: '',
    html: '<div style="background:#ff4d4f;width:12px;height:12px;border-radius:50%;border:2px solid white;box-shadow:0 0 4px rgba(0,0,0,0.3)"></div>',
    iconSize: [16, 16],
    iconAnchor: [8, 8],
  });

  return (
    <MapContainer
      center={center}
      zoom={13}
      style={{ height: '100%', width: '100%' }}
    >
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
        url="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
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
        <Marker position={positions[0]} icon={startIcon} />
      )}

      {/* 终点标记 */}
      {positions.length > 1 && (
        <Marker position={positions[positions.length - 1]} icon={endIcon} />
      )}

      {/* 自动调整视野 */}
      <MapBoundsUpdater points={positions} />
    </MapContainer>
  );
}
