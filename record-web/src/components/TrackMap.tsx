import { useEffect, useMemo, useRef, useState } from 'react';
import {
  MapContainer,
  TileLayer,
  Polyline,
  Marker,
  Popup,
  useMap,
} from 'react-leaflet';
import L from 'leaflet';

// 修复 Leaflet 默认图标问题（兜底）
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

/** 主题：A=暗色沉浸（默认） / B=浅色精致 */
type Theme = 'dark' | 'light';
type MapBase = 'dark' | 'satellite' | 'standard';

// ── 底图源 ──────────────────────────────────────────

/** 高德标准图（含标注） */
const GAODE_STANDARD =
  'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}';
/** 高德纯卫图 */
const GAODE_SATELLITE =
  'https://webst0{s}.is.autonavi.com/appmaptile?style=6&x={x}&y={y}&z={z}';
/** CartoDB 深色底图（优先），失败时回退到高德标准图 + CSS 深色滤镜 */
const CARTO_DARK =
  'https://{s}.basemaps.cartocdn.com/dark_matter/{z}/{x}/{y}{r}.png';

const TILE_SUBDOMAINS = ['1', '2', '3', '4'];
const CARTO_SUBDOMAINS = ['a', 'b', 'c', 'd'];

/** 滤镜回退模式的瓦片错误阈值 */
const TILE_ERROR_THRESHOLD = 4;

// ── 速度色标（双主题） ──────────────────────────────

/** A 暗色：荧光霓虹（0 青 → 绿 → 黄 → 红） */
const DARK_SPEED_STOPS: [number, [number, number, number]][] = [
  [0, [34, 211, 238]], // #22d3ee
  [0.35, [74, 222, 128]], // #4ade80
  [0.65, [250, 204, 21]], // #facc15
  [1, [248, 113, 113]], // #f87171
];

/** B 浅色：杂志墨色（0 蓝 → 青 → 绿 → 黄 → 橙） */
const LIGHT_SPEED_STOPS: [number, [number, number, number]][] = [
  [0, [37, 99, 235]], // #2563eb
  [0.3, [8, 145, 178]], // #0891b2
  [0.55, [22, 163, 74]], // #16a34a
  [0.8, [202, 138, 4]], // #ca8a04
  [1, [234, 88, 12]], // #ea580c
];

/** 速度(m/s) → 主题色标插值 */
function speedColor(speed: number | null, theme: Theme): string {
  const stops = theme === 'dark' ? DARK_SPEED_STOPS : LIGHT_SPEED_STOPS;
  // 无速度数据：使用主题光晕色（CSS 变量，随主题自动切换）
  if (speed == null) return 'var(--tm-glow)';
  const t = Math.min(1, Math.max(0, speed / 5));
  for (let i = 1; i < stops.length; i++) {
    if (t <= stops[i][0]) {
      const [t0, c0] = stops[i - 1];
      const [t1, c1] = stops[i];
      const k = (t - t0) / (t1 - t0);
      const mix = (a: number, b: number) => Math.round(a + (b - a) * k);
      return `rgb(${mix(c0[0], c1[0])},${mix(c0[1], c1[1])},${mix(c0[2], c1[2])})`;
    }
  }
  return `rgb(${stops[stops.length - 1][1].join(',')})`;
}

/** Haversine 球面距离（km） */
function haversineKm(a: [number, number], b: [number, number]): number {
  const R = 6371;
  const dLat = ((b[0] - a[0]) * Math.PI) / 180;
  const dLon = ((b[1] - a[1]) * Math.PI) / 180;
  const s =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((a[0] * Math.PI) / 180) *
      Math.cos((b[0] * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(s));
}

/** 两点方位角（0=北，顺时针，度） */
function bearingDeg(a: [number, number], b: [number, number]): number {
  const f1 = (a[0] * Math.PI) / 180;
  const f2 = (b[0] * Math.PI) / 180;
  const dLon = ((b[1] - a[1]) * Math.PI) / 180;
  const y = Math.sin(dLon) * Math.cos(f2);
  const x = Math.cos(f1) * Math.sin(f2) - Math.sin(f1) * Math.cos(f2) * Math.cos(dLon);
  return ((Math.atan2(y, x) * 180) / Math.PI + 360) % 360;
}

/** 秒 → mm:ss 或 h:mm:ss */
function fmtDuration(secs: number): string {
  if (secs <= 0) return '--:--';
  const h = Math.floor(secs / 3600);
  const m = Math.floor((secs % 3600) / 60);
  const s = Math.floor(secs % 60);
  const mm = m.toString().padStart(2, '0');
  const ss = s.toString().padStart(2, '0');
  return h > 0 ? `${h}:${mm}:${ss}` : `${mm}:${ss}`;
}

/**
 * 解析全端统一格式 yyyy-MM-dd HH:mm:ss 为毫秒时间戳。
 * 先转为标准 ISO（T 分隔）再 parse，避免不同浏览器对空格格式解析不一致。
 */
function parseTimestamp(ts: string): number {
  return Date.parse(ts.replace(' ', 'T'));
}

/** 配速 → mm:ss/km */
function fmtPace(minPerKm: number): string {
  if (!isFinite(minPerKm) || minPerKm <= 0) return '--:--';
  const m = Math.floor(minPerKm);
  const s = Math.round((minPerKm - m) * 60);
  return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
}

// ── 视野自适应 ──────────────────────────────────────

function MapBoundsUpdater({ points }: { points: [number, number][] }) {
  const map = useMap();

  useEffect(() => {
    if (points.length > 0) {
      const bounds = L.latLngBounds(points);
      map.fitBounds(bounds, { padding: [56, 56] });
    }
  }, [points, map]);

  return null;
}

// ── 主组件 ──────────────────────────────────────────

export default function TrackMap({ points, showLiveStats, sessionStats }: Props) {
  const [theme, setTheme] = useState<Theme>(
    () => (localStorage.getItem('record-map-theme') as Theme) || 'dark',
  );
  const [base, setBase] = useState<MapBase>(
    () => (localStorage.getItem('record-map-base') as MapBase) || 'dark',
  );
  const [cartoFailed, setCartoFailed] = useState(
    () => localStorage.getItem('record-map-dark-fallback') === '1',
  );
  const tileErrorCount = useRef(0);

  const positions: [number, number][] = useMemo(
    () => points.map((p) => [p.latitude, p.longitude]),
    [points],
  );

  // 速度彩色分段：总段数控制在 80 以内
  const segments = useMemo(() => {
    if (points.length < 2) return [];
    const chunk = Math.max(1, Math.ceil(points.length / 80));
    const segs: { pts: [number, number][]; color: string }[] = [];
    for (let i = 0; i + 1 < points.length; i += chunk) {
      const slice = points.slice(i, Math.min(i + chunk + 1, points.length));
      if (slice.length < 2) break;
      const speeds = slice
        .map((p) => p.speed)
        .filter((s): s is number => s != null);
      const avg = speeds.length
        ? speeds.reduce((a, b) => a + b, 0) / speeds.length
        : null;
      segs.push({
        pts: slice.map((p) => [p.latitude, p.longitude] as [number, number]),
        color: speedColor(avg, theme),
      });
    }
    return segs;
  }, [points, theme]);

  // 方向箭头：全程约 6 个，沿轨迹均匀分布
  const arrows = useMemo(() => {
    if (positions.length < 4) return [];
    const step = Math.max(12, Math.ceil(positions.length / 6));
    const list: { pos: [number, number]; deg: number }[] = [];
    for (let i = 0; i < positions.length - 1; i += step) {
      list.push({
        pos: positions[i],
        deg: bearingDeg(positions[i], positions[i + 1]),
      });
    }
    return list;
  }, [positions]);

  // 轨迹统计（距离/时长/配速/步数）
  const stats = useMemo(() => {
    if (positions.length < 2) return null;
    let dist = 0;
    for (let i = 1; i < positions.length; i++) {
      dist += haversineKm(positions[i - 1], positions[i]);
    }
    const first = points[0];
    const last = points[points.length - 1];
    const t0 = parseTimestamp(first.timestamp);
    const t1 = parseTimestamp(last.timestamp);
    const secs = isFinite(t0) && isFinite(t1) && t1 > t0 ? (t1 - t0) / 1000 : 0;
    const totalSteps = points.reduce((s, p) => s + (p.steps ?? 0), 0);
    return {
      distanceKm: dist,
      duration: fmtDuration(secs),
      pace: fmtPace(secs / 60 / Math.max(dist, 0.001)),
      totalSteps,
    };
  }, [points, positions]);

  // 迷你速度曲线（SVG polyline 点串）
  const speedCurve = useMemo(() => {
    if (points.length < 2) return null;
    const speeds = points.map((p) => p.speed ?? 0);
    const max = Math.max(...speeds, 1);
    const stepX = 240 / (points.length - 1);
    return speeds
      .map((s, i) => `${(i * stepX).toFixed(1)},${(42 - (s / max) * 34).toFixed(1)}`)
      .join(' ');
  }, [points]);

  // 深色底图回退：CartoDB 瓦片加载失败 → 高德标准图 + CSS 深色滤镜
  const handleTileError = () => {
    if (base !== 'dark' || cartoFailed) return;
    tileErrorCount.current += 1;
    if (tileErrorCount.current >= TILE_ERROR_THRESHOLD) {
      setCartoFailed(true);
      localStorage.setItem('record-map-dark-fallback', '1');
    }
  };

  const switchTheme = (next: Theme) => {
    setTheme(next);
    localStorage.setItem('record-map-theme', next);
    // 联动推荐底图：暗色→深色底图；浅色→高德标准图（用户可再手动改）
    const recommended: MapBase = next === 'dark' ? 'dark' : 'standard';
    setBase(recommended);
    localStorage.setItem('record-map-base', recommended);
  };

  const switchBase = (next: MapBase) => {
    setBase(next);
    localStorage.setItem('record-map-base', next);
  };

  const center: [number, number] =
    positions.length > 0
      ? positions[Math.floor(positions.length / 2)]
      : [39.9042, 116.4074];

  const darkUrl = cartoFailed ? GAODE_STANDARD : CARTO_DARK;
  const darkSubdomains = cartoFailed ? TILE_SUBDOMAINS : CARTO_SUBDOMAINS;
  const isLight = theme === 'light';

  return (
    <div
      className={[
        'trackmap',
        isLight ? 'trackmap--light' : 'trackmap--dark',
        cartoFailed && base === 'dark' ? 'trackmap--filtered' : '',
      ]
        .filter(Boolean)
        .join(' ')}
    >
      <MapContainer
        center={center}
        zoom={13}
        style={{ height: '100%', width: '100%' }}
      >
        {base === 'dark' ? (
          <TileLayer
            key={cartoFailed ? 'gaode-dark' : 'carto-dark'}
            url={darkUrl}
            subdomains={darkSubdomains}
            maxZoom={18}
            attribution="&copy; OpenStreetMap | &copy; 高德"
            eventHandlers={{ tileerror: handleTileError }}
          />
        ) : (
          <TileLayer
            key={base}
            url={base === 'satellite' ? GAODE_SATELLITE : GAODE_STANDARD}
            subdomains={TILE_SUBDOMAINS}
            maxZoom={18}
            attribution="&copy; OpenStreetMap | &copy; 高德"
          />
        )}

        {/* 霓虹/水墨光晕底轨 */}
        {positions.length >= 2 && (
          <Polyline
            positions={positions}
            pathOptions={{
              color: isLight ? '#3b82f6' : '#22d3ee',
              weight: 9,
              opacity: isLight ? 0.12 : 0.16,
              lineCap: 'round',
              lineJoin: 'round',
            }}
          />
        )}

        {/* 速度彩色分段 + 流动虚线 */}
        {segments.map((seg, i) => (
          <Polyline
            key={i}
            positions={seg.pts}
            pathOptions={{
              color: seg.color,
              weight: 3.5,
              opacity: 0.95,
              lineCap: 'round',
              lineJoin: 'round',
              dashArray: '7 9',
              className: 'track-flow',
            }}
          />
        ))}

        {/* 方向箭头 */}
        {arrows.map((a, i) => (
          <Marker
            key={`arrow-${i}`}
            position={a.pos}
            icon={L.divIcon({
              className: 'tm-arrow',
              html: `<svg viewBox="0 0 24 24" style="width:14px;height:14px;transform:rotate(${a.deg}deg)"><path d="M12 2 L20 20 L12 15 L4 20 Z"/></svg>`,
              iconSize: [14, 14],
              iconAnchor: [7, 7],
            })}
          />
        ))}

        {/* 起点 */}
        {positions.length > 0 && (
          <Marker
            position={positions[0]}
            icon={L.divIcon({
              className: 'tm-marker',
              html: '<div class="tm-dot tm-dot--start"><span class="tm-dot__core"></span></div>',
              iconSize: [20, 20],
              iconAnchor: [10, 10],
            })}
          >
            <Popup>
              <div>
                <b>起点</b>
                <br />
                时间: {points[0]?.timestamp ?? '--'}
              </div>
            </Popup>
          </Marker>
        )}

        {/* 终点 / 实时位置 */}
        {positions.length > 1 && (
          <Marker
            position={positions[positions.length - 1]}
            icon={L.divIcon({
              className: 'tm-marker',
              html: '<div class="tm-dot tm-dot--end"><span class="tm-dot__core"></span></div>',
              iconSize: [20, 20],
              iconAnchor: [10, 10],
            })}
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

        {/* 中间采样点 */}
        {positions.length > 3 &&
          positions.slice(-5, -1).map((pos, i) => (
            <Marker
              key={`mid-${i}`}
              position={pos}
              icon={L.divIcon({
                className: 'tm-mid',
                html: '<span></span>',
                iconSize: [9, 9],
                iconAnchor: [4, 4],
              })}
            >
              <Popup>
                <div>
                  步数: {points[points.length - 5 + i]?.steps ?? 0}
                  <br />
                  速度: {points[points.length - 5 + i]?.speed?.toFixed(1) ?? '--'} m/s
                </div>
              </Popup>
            </Marker>
          ))}

        <MapBoundsUpdater points={positions} />
      </MapContainer>

      {/* 空态 */}
      {positions.length === 0 && (
        <div className="trackmap__empty">
          <span>暂无轨迹数据</span>
        </div>
      )}

      {/* 统计浮层（玻璃拟态） */}
      {stats && (
        <div className="trackmap__stats">
          <span className={`trackmap__live ${showLiveStats ? 'is-live' : ''}`}>
            {showLiveStats ? '实时监控中' : '轨迹统计'}
          </span>
          <div className="trackmap__stats-grid">
            <div>
              <em>距离</em>
              <strong>
                {stats.distanceKm.toFixed(2)}
                <i>km</i>
              </strong>
            </div>
            <div>
              <em>时长</em>
              <strong>{stats.duration}</strong>
            </div>
            <div>
              <em>配速</em>
              <strong>
                {stats.pace}
                <i>/km</i>
              </strong>
            </div>
            <div>
              <em>步数</em>
              <strong>{stats.totalSteps}</strong>
            </div>
          </div>
          {speedCurve && (
            <svg
              className="trackmap__curve"
              viewBox="0 0 240 44"
              preserveAspectRatio="none"
            >
              <polyline points={speedCurve} fill="none" strokeWidth="1.6" vectorEffect="non-scaling-stroke" />
              <polygon points={`0,44 ${speedCurve} 240,44`} />
            </svg>
          )}
        </div>
      )}

      {/* 左下角控制台：主题 + 底图 */}
      <div className="trackmap__controls">
        <div className="trackmap__group">
          {(
            [
              ['dark', '暗色沉浸'],
              ['light', '浅色精致'],
            ] as [Theme, string][]
          ).map(([key, label]) => (
            <button
              key={key}
              type="button"
              title={`切换到${label}主题`}
              className={theme === key ? 'is-active' : ''}
              onClick={() => switchTheme(key)}
            >
              {label}
            </button>
          ))}
        </div>
        <div className="trackmap__group-divider" />
        <div className="trackmap__group">
          {(
            [
              ['dark', '深色底图'],
              ['satellite', '卫星'],
              ['standard', '标准'],
            ] as [MapBase, string][]
          ).map(([key, label]) => (
            <button
              key={key}
              type="button"
              title={`切换到${label}`}
              className={base === key ? 'is-active' : ''}
              onClick={() => switchBase(key)}
            >
              {label}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
