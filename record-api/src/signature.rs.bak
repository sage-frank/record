use axum::{
    extract::State,
    http::{HeaderMap, StatusCode},
    response::{IntoResponse, Response},
    middleware::Next,
};
use hmac::{Hmac, Mac};
use sha2::{Digest, Sha256};
use std::collections::HashSet;
use std::sync::{Arc, Mutex};
use std::time::{SystemTime, UNIX_EPOCH};
use tracing::warn;

type HmacSha256 = Hmac<Sha256>;

const APP_KEY: &str = "record_app_v2";
const SECRET_KEY: &str = "5K8m#9cN@rP2xV7y";
const TIMESTAMP_THRESHOLD_SECONDS: u64 = 300; // 5 minutes

#[derive(Clone)]
pub struct SignatureState {
    used_nonces: Arc<Mutex<HashSet<String>>>,
}

impl SignatureState {
    pub fn new() -> Self {
        Self {
            used_nonces: Arc::new(Mutex::new(HashSet::new())),
        }
    }

    pub fn is_nonce_used(&self, nonce: &str) -> bool {
        self.used_nonces
            .lock()
            .unwrap()
            .contains(nonce)
    }

    pub fn mark_nonce_used(&self, nonce: String) {
        let mut nonces = self.used_nonces.lock().unwrap();
        nonces.insert(nonce);

        if nonces.len() > 1000 {
            let to_remove = nonces.len() - 500;
            let remove_keys: Vec<String> = nonces.iter().take(to_remove).cloned().collect();
            for key in remove_keys {
                nonces.remove(&key);
            }
        }
    }
}

#[derive(Debug)]
pub enum SignatureError {
    MissingHeaders,
    InvalidTimestamp,
    InvalidAppKey,
    DuplicateNonce,
    InvalidSignature,
    ParseError(String),
}

impl std::fmt::Display for SignatureError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            SignatureError::MissingHeaders => write!(f, "Missing required signature headers"),
            SignatureError::InvalidTimestamp => write!(f, "Timestamp expired or invalid"),
            SignatureError::InvalidAppKey => write!(f, "Invalid app key"),
            SignatureError::DuplicateNonce => write!(f, "Replay attack detected"),
            SignatureError::InvalidSignature => write!(f, "Signature verification failed"),
            SignatureError::ParseError(msg) => write!(f, "Parse Error: {}", msg),
        }
    }
}

impl IntoResponse for SignatureError {
    fn into_response(self) -> Response {
        let status = match self {
            SignatureError::DuplicateNonce => StatusCode::FORBIDDEN,
            SignatureError::InvalidSignature => StatusCode::UNAUTHORIZED,
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
    
    let mut mac = HmacSha256::new_from_slice(SECRET_KEY.as_bytes())
        .expect("HMAC can take key of any size");
    mac.update(sign_string.as_bytes());
    
    let signature_bytes = hex::decode(signature);
    if signature_bytes.is_err() {
        return false;
    }
    
    mac.verify_slice(&signature_bytes.unwrap())
        .is_ok()
}

/// 生成body hash
pub fn hash_body(body: &[u8]) -> String {
    let mut hasher = Sha256::new();
    hasher.update(body);
    hex::encode(hasher.finalize())
}

/// 生成随机nonce
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

/// 签名验证中间件
pub async fn signature_middleware(
    State(signature_state): State<SignatureState>,
    headers: HeaderMap,
    req: axum::extract::Request,
    next: axum::middleware::Next,
) -> Result<Response, SignatureError> {
    let path = req.uri().path();
    
    // Skip signature verification for debug endpoints and health checks
    if path.starts_with("/debug") || path == "/" {
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

    // 验证App Key
    if app_key != APP_KEY {
        warn!("Invalid app key: {}", app_key);
        return Err(SignatureError::InvalidAppKey);
    }

    // 验证时间戳
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|_| SignatureError::InvalidTimestamp)?;
    
    if (now.as_secs() as i64 - timestamp as i64).abs() > TIMESTAMP_THRESHOLD_SECONDS as i64 {
        warn!("Timestamp expired: {} (current: {})", timestamp, now.as_secs());
        return Err(SignatureError::InvalidTimestamp);
    }

    // 检查重放攻击
    if signature_state.is_nonce_used(nonce) {
        warn!("Duplicate nonce detected: {}", nonce);
        return Err(SignatureError::DuplicateNonce);
    }

    // 标记Nonce为已使用
    signature_state.mark_nonce_used(nonce.to_string());

    // 验证签名
    let method = req.method().as_str();
    let body_hash = ""; // 简化版本，后续可添加body hash验证

    if !verify_signature(method, path, timestamp, nonce, body_hash, signature) {
        warn!("Invalid signature for request: {} {}", method, path);
        return Err(SignatureError::InvalidSignature);
    }

    // 签名验证通过，继续处理请求
    Ok(next.run(req).await)
}