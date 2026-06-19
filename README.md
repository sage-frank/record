# 运动位置记录 App

一个运动位置记录系统，包含三个子项目。

## 项目结构

| 子项目 | 技术栈 | 用途 |
|--------|--------|------|
| `record-api` | Rust (Axum + SQLite) | 后端 API，接收和查询位置数据 |
| `record-app` | Flutter | 移动端运动 App，记录跑步轨迹 |
| `record-web` | React + Leaflet + Ant Design | 管理后台，展示运动记录和地图 |

## 技术架构

```
┌──────────────┐     ┌──────────────┐
│  record-app  │     │  record-web  │
│  (Flutter)   │     │   (React)    │
│  GPS 采集     │     │  管理后台    │
└──────┬───────┘     └──────┬───────┘
       │   HTTP REST        │
       └──────────┬─────────┘
                  ▼
          ┌──────────────┐
          │  record-api  │
          │  (Rust/Axum) │
          └──────┬───────┘
                 │
                 ▼
          ┌──────────────┐
          │   SQLite     │
          └──────────────┘
```

## 数据模型

```sql
track_points (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id  TEXT NOT NULL,
  latitude    REAL NOT NULL,
  longitude   REAL NOT NULL,
  altitude    REAL,
  speed       REAL,
  steps       INTEGER DEFAULT 0,
  timestamp   TEXT NOT NULL,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
)
```

## API 端点

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/track-points` | 上报单个位置点 |
| POST | `/api/track-points/batch` | 批量上报位置点 |
| GET | `/api/sessions` | 获取所有运动会话列表 |
| GET | `/api/sessions/:id/track-points` | 获取某次会话的轨迹点 |
| GET | `/api/sessions/:id/stats` | 获取会话实时统计 |
| DELETE | `/api/sessions/:id` | 删除一次运动记录 |

## 快速开始

### 1. 启动 API (Rust)

```bash
cd record-api
cargo run --release
# 服务启动在 http://0.0.0.0:3000
```

### 2. 启动 Web 管理后台

```bash
cd record-web
npm install
npm run dev
# 访问 http://localhost:5173
```

### 3. 运行 Flutter App

```bash
cd record-app
flutter pub get
flutter run
# 或构建 APK
flutter build apk --release
```

### 服务器部署

将 `record-api` 部署到服务器：

```bash
# 上传到服务器
scp -r record-api user@your-server:~/

# SSH 登录后启动
ssh user@your-server
cd record-api
nohup cargo run --release &
```

更新 App 端 API 地址：修改 `record-app/lib/services/api_service.dart` 中的 `baseUrl` 为服务器地址。

## 技术栈详情

### record-api
- Web 框架: Axum 0.7
- 数据库: SQLite (rusqlite, bundled)
- 序列化: serde + serde_json
- 跨域: tower-http cors
- 异步运行时: tokio
- UUID: uuid v4

### record-app
- 状态管理: provider
- GPS 定位: geolocator
- 地图: flutter_map + latlong2
- 网络请求: http
- UUID: uuid

### record-web
- 构建工具: Vite
- UI 框架: React 18 + Ant Design 5
- 地图: react-leaflet + leaflet
- HTTP: axios
- 时间处理: dayjs
