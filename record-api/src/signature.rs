use axum::{
    extract::State,
    http::{HeaderMap, StatusCode},
    response::{IntoResponse, Response},
};
use hmac::{Hmac, Mac};
use sha2::{Digest, Sha256};
use std::collections::VecDeque;
use std::sync::{Arc, Mutex};
use std::time::{SystemTime, UNIX_EPOCH};
use tracing::{debug, warn};

type HmacSha256 = Hmac<Sha256>;

const APP_KEY: &str = "record_app_v2";
const SECRET_KEY: &str = "5K8m#9cN@rP2xV7y";
const TIMESTAMP_THRESHOLD_SECONDS: u64 = 300; // 5 minutes

/// 请求体大小上限（防恶意超大 body 打爆内存）
const MAX_BODY_BYTES: usize = 32 * 1024 * 1024;

/// 防重放 nonce 队列最大长度（超限时按时间驱逐最旧的）
const MAX_NONCES: usize = 1000;

/// 签名状态：按 (时间戳, nonce) 有序记录已使用的 nonce，
/// 驱逐时从队头（最旧）开始，避免随机驱逐导致 5 分钟窗口内 nonce 可被重放。
#[derive(Clone)]
pub struct SignatureState {
    used_nonces: Arc<Mutex<VecDeque<(u64, String)>>>,
}

impl SignatureState {
    pub fn new() -> Self {
        Self {
            used_nonces: Arc::new(Mutex::new(VecDeque::new())),
        }
    }

    /// 原子标记 nonce 为已使用（锁内查重 + 插入 + 驱逐）。
    /// 返回 false 表示该 nonce 已被使用（重放攻击）。
    pub fn mark_nonce_used(&self, nonce: String, timestamp: u64) -> bool {
        let mut nonces = self.used_nonces.lock().unwrap_or_else(|e| e.into_inner());
        if nonces.iter().any(|(_, n)| n == &nonce) {
            return false;
        }
        nonces.push_back((timestamp, nonce));
        // 驱逐过期（超出 5 分钟窗口）与超量的 nonce，队头即最旧
        let cutoff = timestamp.saturating_sub(TIMESTAMP_THRESHOLD_SECONDS);
        while let Some((ts, _)) = nonces.front() {
            if *ts < cutoff || nonces.len() > MAX_NONCES {
                nonces.pop_front();
            } else {
                break;
            }
        }
        true
    }
}

/// 签名校验错误：认证语义与响应状态码与重构前一致
#[derive(Debug, thiserror::Error)]
pub enum SignatureError {
    #[error("Missing required signature headers")]
    MissingHeaders,
    #[error("Timestamp expired or invalid")]
    InvalidTimestamp,
    #[error("Invalid app key")]
    InvalidAppKey,
    #[error("Replay attack detected")]
    DuplicateNonce,
    #[error("Signature verification failed")]
    InvalidSignature,
    #[error("Parse Error: {0}")]
    ParseError(String),
    #[error("Request body too large")]
    PayloadTooLarge,
}

impl IntoResponse for SignatureError {
    fn into_response(self) -> Response {
        let status = match self {
            SignatureError::DuplicateNonce => StatusCode::FORBIDDEN,
            SignatureError::InvalidSignature => StatusCode::UNAUTHORIZED,
            SignatureError::PayloadTooLarge => StatusCode::PAYLOAD_TOO_LARGE,
            _ => StatusCode::BAD_REQUEST,
        };

        (status, format!("{{\"error\": \"{}\"}}", self)).into_response()
    }
}

/// 验证签名
pub fn verify_signature(
    method: &str,
    path: &str,
    timestamp: u64,
    nonce: &str,
    body_hash: &str,
    signature: &str,
) -> bool {
    let sign_string = format!("{method}|{path}|{timestamp}|{nonce}|{body_hash}");

    let mut mac =
        HmacSha256::new_from_slice(SECRET_KEY.as_bytes()).expect("HMAC can take key of any size");
    mac.update(sign_string.as_bytes());

    let signature_bytes = hex::decode(signature);
    if signature_bytes.is_err() {
        return false;
    }

    mac.verify_slice(&signature_bytes.unwrap()).is_ok()
}

/// 生成 body hash
pub fn hash_body(body: &[u8]) -> String {
    let mut hasher = Sha256::new();
    hasher.update(body);
    hex::encode(hasher.finalize())
}

/// 生成随机 nonce（保留给客户端/调试使用）
#[allow(dead_code)]
pub fn generate_nonce() -> String {
    use rand::Rng;
    const CHARSET: &[u8] = b"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

    let mut rng = rand::thread_rng();
    (0..16)
        .map(|_| {
            let idx = rng.gen_range(0..CHARSET.len());
            CHARSET[idx] as char
        })
        .collect()
}

/// 签名验证中间件：
/// 1. 校验头完整性 / app key / 时间戳；
/// 2. 读取请求体（限制大小）计算 body hash；
/// 3. 验证 HMAC 签名；
/// 4. 签名通过后才原子标记 nonce（防无效请求污染防重放池）。
pub async fn signature_middleware(
    State(signature_state): State<SignatureState>,
    headers: HeaderMap,
    req: axum::extract::Request,
    next: axum::middleware::Next,
) -> Result<Response, SignatureError> {
    let path = req.uri().path().to_string();

    // 只读接口放行签名：GET 无副作用，Web 端（无签名实现）查询使用；
    // 写操作（POST/PUT/DELETE）保留签名校验，App 端均携带签名不受影响。
    if path.starts_with("/debug") || path == "/" {
        return Ok(next.run(req).await);
    }

    if req.method() == axum::http::Method::GET {
        return Ok(next.run(req).await);
    }

    // 提取签名头
    let signature = headers
        .get("x-signature")
        .and_then(|v| v.to_str().ok())
        .ok_or(SignatureError::MissingHeaders)?;

    let timestamp = headers
        .get("x-timestamp")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.parse::<u64>().ok())
        .ok_or(SignatureError::MissingHeaders)?;

    let nonce = headers
        .get("x-nonce")
        .and_then(|v| v.to_str().ok())
        .ok_or(SignatureError::MissingHeaders)?;

    let app_key = headers
        .get("x-app-key")
        .and_then(|v| v.to_str().ok())
        .ok_or(SignatureError::MissingHeaders)?;

    // 校验 App Key
    if app_key != APP_KEY {
        warn!("Invalid app key: {}", app_key);
        return Err(SignatureError::InvalidAppKey);
    }

    // 校验时间戳（防过期重放）
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|_| SignatureError::InvalidTimestamp)?;

    if (now.as_secs() as i64 - timestamp as i64).abs() > TIMESTAMP_THRESHOLD_SECONDS as i64 {
        warn!(
            "Timestamp expired: {} (current: {})",
            timestamp,
            now.as_secs()
        );
        return Err(SignatureError::InvalidTimestamp);
    }

    // 读取请求体（限制大小，防内存 DoS）
    // 先按 Content-Length 预检，超限直接 413，避免读取大 body 浪费内存
    if let Some(len) = headers
        .get("content-length")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.parse::<usize>().ok())
    {
        if len > MAX_BODY_BYTES {
            return Err(SignatureError::PayloadTooLarge);
        }
    }
    let (parts, body) = req.into_parts();
    let body_bytes = axum::body::to_bytes(body, MAX_BODY_BYTES)
        .await
        .map_err(|e| SignatureError::ParseError(format!("Failed to read request body: {e}")))?;
    if body_bytes.len() > MAX_BODY_BYTES {
        return Err(SignatureError::PayloadTooLarge);
    }
    let body_hash = hash_body(&body_bytes);

    // 重新构建请求
    let req = axum::extract::Request::from_parts(parts, axum::body::Body::from(body_bytes));

    // 验证签名
    if !verify_signature(
        req.method().as_str(),
        &path,
        timestamp,
        nonce,
        &body_hash,
        signature,
    ) {
        warn!("Signature verification failed: {} {}", req.method(), path);
        return Err(SignatureError::InvalidSignature);
    }

    // 签名验证通过后才标记 nonce（原子防重放）
    if !signature_state.mark_nonce_used(nonce.to_string(), timestamp) {
        warn!("Duplicate nonce detected: {}", nonce);
        return Err(SignatureError::DuplicateNonce);
    }

    debug!("Signature OK: {} {}", req.method(), path);

    Ok(next.run(req).await)
}
