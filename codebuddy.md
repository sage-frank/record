# 运动位置记录 App — 开发计划

## 项目概述

一个运动位置记录系统，包含三个子项目：

| 子项目 | 技术栈 | 用途 |
|--------|--------|------|
| `record-api` | Rust (Axum + SQLite) | 后端 API，接收和查询位置数据 |
| `record-app` | Flutter | 移动端运动 App，记录跑步轨迹 |
| `record-web` | React + Leaflet | 管理后台，展示运动记录和地图 |

## 数据模型

```
track_points 表:
├── id          INTEGER PRIMARY KEY AUTOINCREMENT
├── session_id  TEXT NOT NULL (运动会话 ID)
├── latitude    REAL NOT NULL (纬度)
├── longitude   REAL NOT NULL (经度)
├── altitude    REAL (海拔，可选)
├── speed       REAL (速度 m/s，可选)
├── timestamp   TEXT NOT NULL (ISO 8601 时间戳)
└── created_at  TEXT NOT NULL
```

## API 端点

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /api/track-points | 上报单个位置点 |
| POST | /api/track-points/batch | 批量上报位置点 |
| GET | /api/sessions | 获取所有运动会话列表 |
| GET | /api/sessions/:id/track-points | 获取某次会话的所有轨迹点 |
| DELETE | /api/sessions/:id | 删除一次运动记录 |

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
          │  REST API    │
          └──────┬───────┘
                 │
                 ▼
          ┌──────────────┐
          │   SQLite     │
          │  (本地文件)   │
          └──────────────┘
```

## 实施步骤

| 步骤 | 内容 | 子项目 |
|------|------|--------|
| Step 1 | 搭建 Rust API：数据模型、数据库初始化、CRUD 接口 | record-api |
| Step 2 | 初始化 Flutter 项目：GPS 定位、位置采集、上传 | record-app |
| Step 3 | 初始化 React 项目：会话列表、Leaflet 地图轨迹展示 | record-web |

## record-api (Rust)

- Web 框架: Axum
- 数据库: SQLite (rusqlite)
- 序列化: serde + serde_json
- 跨域: tower-http cors
- 异步运行时: tokio

## record-app (Flutter)

- 状态管理: provider
- GPS 定位: geolocator
- 地图: flutter_map + latlong2
- 网络请求: http

## record-web (React)

- 构建工具: Vite
- 地图: react-leaflet + leaflet
- HTTP: axios
- UI: Ant Design
- 时间: dayjs
