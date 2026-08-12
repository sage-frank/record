// 后端 API 配置 —— 唯一配置源
// App.tsx / ErrorLogs.tsx 的 axios baseURL 与 vite.config.ts 的代理目标均引用此处，
// 需要改后端地址时只需修改这一个文件。

// 浏览器端请求路径：使用相对路径 /api，由 Vite dev server 代理（或生产 nginx 反代）转发，
// 避免浏览器直连 https://...:3000 时的自签名证书错误（ERR_CERT_AUTHORITY_INVALID）。
export const API_BASE_URL = '/api';

// Vite dev server 的代理目标：直连 Rust 后端（http，无 TLS），绕过 nginx 证书问题。
// 注意：3001 为后端真实监听端口（nginx 将 https:3000 反代到 3001）。
export const API_PROXY_TARGET = 'http://39.105.113.213:3001';
