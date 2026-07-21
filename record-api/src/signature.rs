use axum::{ 
    extract::{State, Request},
    http::{HeaderMap, StatusCode},
    response::{IntoResponse, Response},
    middleware::Next,
};
use hmac::{Hmac, Mac};
use sha2::{Digest, Sha256};
use std::collections::HashSet;
use std::sync::{Arc, Mutex};
use std::time::{SystemTime, UNIX_EPOCH};
use tracing::{info, warn};

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

/// 生成响应签名
pub fn generate_response_signature(body: &str, timestamp: u64, nonce: &str) -> String {
    let body_hash = hash_body(body.as_bytes());
    let sign_string = format!("RESPONSE|/api|{}|{}|{}", timestamp, nonce, body_hash);
    
    let mut mac = HmacSha256::new_from_slice(SECRET_KEY.as_bytes())
        .expect("HMAC can take key of any size");
    mac.update(sign_string.as_bytes());
    
    hex::encode(mac.finalize().into_bytes())
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

    // 提取签名头 - 添加调试日志
    let signature = headers
        .get("x-signature")
        .and_then(|v| v.to_str().ok())
        .ok_or_else(|| {
            warn!("🔍 [DEBUG] Missing x-signature header. All headers: {:?}", headers);
            SignatureError::MissingHeaders
        })?;

    let timestamp = headers
        .get("x-timestamp")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.parse::<u64>().ok())
        .ok_or_else(|| {
            warn!("🔍 [DEBUG] Missing or invalid x-timestamp header");
            SignatureError::MissingHeaders
        })?;

    let nonce = headers
        .get("x-nonce")
        .and_then(|v| v.to_str().ok())
        .ok_or_else(|| {
            warn!("🔍 [DEBUG] Missing x-nonce header");
            SignatureError::MissingHeaders
        })?;

    let app_key = headers
        .get("x-app-key")
        .and_then(|v| v.to_str().ok())
        .ok_or_else(|| {
            warn!("🔍 [DEBUG] Missing x-app-key header");
            SignatureError::MissingHeaders
        })?;
    
    // 输出详细的签名调试信息
    info!("🔍 [SIGNATURE DEBUG] {} {}", req.method(), path);
    info!("  📋 Headers:");
    info!("    x-signature: {}", signature);
    info!("    x-timestamp: {}", timestamp);
    info!("    x-nonce: {}", nonce);
    info!("    x-app-key: {}", app_key);

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
    let method_str = req.method().as_str().to_string(); // 克隆method字符串
    let path_str = path.to_string(); // 克隆path字符串以便后续使用
    // 读取请求体来计算正确的body hash
    let (parts, body) = req.into_parts();
    let body_bytes = axum::body::to_bytes(body, usize::MAX)
        .await
        .map_err(|_| SignatureError::ParseError("Failed to read request body".to_string()))?;
    let body_hash = hash_body(&body_bytes);
    
    // 输出签名验证的详细信息
    info!("  📝 Body Hash: {}", body_hash);
    info!("  🔐 Expected Sign String: {}|{}|{}|{}|{}", method_str, path_str, timestamp, nonce, body_hash);
    
    // 重新构建请求以便后续处理
    let req = axum::extract::Request::from_parts(parts, axum::body::Body::from(body_bytes));

    if !verify_signature(&method_str, &path_str, timestamp, nonce, &body_hash, signature) {
        warn!("❌ [SIGNATURE FAILED] {} {}", method_str, path_str);
        warn!("  Provided Signature: {}", signature);
        // 计算期望的签名用于调试
        let sign_string = format!("{}|{}|{}|{}|{}", method_str, path_str, timestamp, nonce, body_hash);
        warn!("  Sign String: {}", sign_string);
        return Err(SignatureError::InvalidSignature);
    }
    
    info!("✅ [SIGNATURE OK] {} {}", method_str, path_str);

    // 签名验证通过，继续处理请求
    Ok(next.run(req).await)
}

/// 响应签名中间件 - 给所有成功响应添加签名头
pub async fn response_signature_middleware(
    req: axum::extract::Request,
    next: axum::middleware::Next,
) -> axum::http::Response<axum::body::Body> {
    let mut response = next.run(req).await;
    
    // 只对 200 响应添加签名
    if response.status().as_u16() == 200 {
        use std::time::{SystemTime, UNIX_EPOCH};
        use rand::Rng;
        
        let timestamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();
        
        // 生成新的 nonce 用于响应
        const CHARSET: &[u8] = b"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        let mut rng = rand::thread_rng();
        let nonce: String = (0..16)
            .map(|_| {
                let idx = rng.gen_range(0..CHARSET.len());
                CHARSET[idx] as char
            })
            .collect();
        
        // 获取响应体（注意：这里我们无法直接读取已经发送的响应体）
        // 所以我们需要一个 workaround：使用空 body hash 或者在 handler 层面处理
        
        // 由于无法读取流式响应的 body，我们暂时使用固定的签名方式
        // 实际生产环境应该使用 Body layer 来拦截和修改响应
        let signature = generate_response_signature("", timestamp, &nonce);
        
        if let Ok(sig_value) = signature.parse::<axum::http::HeaderValue>() {
            response.headers_mut().insert("x-server-signature", sig_value);
        }
        if let Ok(ts_value) = timestamp.to_string().parse::<axum::http::HeaderValue>() {
            response.headers_mut().insert("x-timestamp", ts_value);
        }
        if let Ok(nonce_value) = nonce.parse::<axum::http::HeaderValue>() {
            response.headers_mut().insert("x-nonce", nonce_value);
        }
        
        info!("📤 Added response signature headers");
    }
    
    response
}