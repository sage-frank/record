/// WGS-84 → GCJ-02 坐标转换（火星坐标系）
/// GPS 设备输出 WGS-84，高德地图使用 GCJ-02，直接叠加偏移 100-500 米

use std::f64::consts::PI;

const A: f64 = 6378245.0; // 长半轴
const EE: f64 = 0.00669342162296594323; // 扁率

fn transform_lat(x: f64, y: f64) -> f64 {
    let mut ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * x.abs().sqrt();
    ret += ((20.0 * (6.0 * x * PI).sin() + 20.0 * (2.0 * x * PI).sin()) * 2.0) / 3.0;
    ret += ((20.0 * (y * PI).sin() + 40.0 * ((y / 3.0) * PI).sin()) * 2.0) / 3.0;
    ret += ((160.0 * ((y / 12.0) * PI).sin() + 320.0 * ((y * PI) / 30.0).sin()) * 2.0) / 3.0;
    ret
}

fn transform_lng(x: f64, y: f64) -> f64 {
    let mut ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * x.abs().sqrt();
    ret += ((20.0 * (6.0 * x * PI).sin() + 20.0 * (2.0 * x * PI).sin()) * 2.0) / 3.0;
    ret += ((20.0 * (x * PI).sin() + 40.0 * ((x / 3.0) * PI).sin()) * 2.0) / 3.0;
    ret += ((150.0 * ((x / 12.0) * PI).sin() + 300.0 * ((x / 30.0) * PI).sin()) * 2.0) / 3.0;
    ret
}

/// 单个坐标 WGS-84 → GCJ-02，返回 (gcj_lat, gcj_lng)
pub fn wgs84_to_gcj02(lat: f64, lng: f64) -> (f64, f64) {
    if lat < 0.01 || lng < 0.01 {
        return (lat, lng);
    }
    let d_lat = transform_lat(lng - 105.0, lat - 35.0);
    let d_lng = transform_lng(lng - 105.0, lat - 35.0);
    let rad_lat = (lat / 180.0) * PI;
    let mut magic = rad_lat.sin();
    magic = 1.0 - EE * magic * magic;
    let sqrt_magic = magic.sqrt();
    let d_lat_final = (d_lat * 180.0) / (((A * (1.0 - EE)) / (magic * sqrt_magic)) * PI);
    let d_lng_final = (d_lng * 180.0) / ((A / sqrt_magic) * rad_lat.cos() * PI);
    (lat + d_lat_final, lng + d_lng_final)
}
