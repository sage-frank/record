[OPEN]

## Session
- sessionId: api-calls-not-visible
- symptom: App 端更新数据后，看不到后端接口调用痕迹

## Hypotheses
- A: App 实际请求的是远程 baseUrl（或别的环境），用户查看的是另一台后端日志，所以“看不到调用”
- B: App 侧请求失败后走了本地兜底缓存（try/catch 吞掉错误），导致看起来像“没调用”
- C: 后端对应接口没有打 info 日志（只记录了跑步轨迹相关接口），所以即使请求到了也看不到
- D: 设备网络/HTTP 明文限制导致请求被拦截（Android cleartext / iOS ATS），请求根本没发出去
- E: App 发出了请求，但数据未变（参数没变/服务端拒绝），用户误判为“没调用”

## Evidence Plan
- 在 App 的 ApiService 加入“向 Debug Server 上报每次请求/响应”的插桩（不改业务逻辑）
- 复现：在 App 上执行“更新体重 / 新增饮食 / 新建计划 / 编辑档案”
- 从 Debug Server 的日志确定：是否发起请求、请求 URL、HTTP 状态码、错误信息

