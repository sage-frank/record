use hmac::{Hmac, Mac};
use sha2::{Digest, Sha256};
use std::collections::HashSet;
use std::sync::{Arc, Mutex};
use std::time::{SystemTime, UNIX_EPOCH};
use tracing::warn;

type HmacSha256 = Hmac<Sha256>;

const SECRET_KEY: &str = "5K8m#9cN@rP2xV7y";

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