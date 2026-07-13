import 'dart:math';
import 'package:latlong2/latlong.dart';

/// WGS-84 → GCJ-02 坐标转换（火星坐标系）
/// GPS 设备输出 WGS-84，高德地图使用 GCJ-02

const double _pi = 3.141592653589793;
const double _a = 6378245.0;
const double _ee = 0.00669342162296594323;

double _transformLat(double x, double y) {
  double ret = -100.0 +
      2.0 * x +
      3.0 * y +
      0.2 * y * y +
      0.1 * x * y +
      0.2 * sqrt(x.abs());
  ret += ((20.0 * sin(6.0 * x * _pi) + 20.0 * sin(2.0 * x * _pi)) * 2.0) / 3.0;
  ret += ((20.0 * sin(y * _pi) + 40.0 * sin((y / 3.0) * _pi)) * 2.0) / 3.0;
  ret += ((160.0 * sin((y / 12.0) * _pi) + 320.0 * sin((y * _pi) / 30.0)) * 2.0) / 3.0;
  return ret;
}


double _transformLng(double x, double y) {
  double ret = 300.0 +
      x +
      2.0 * y +
      0.1 * x * x +
      0.1 * x * y +
      0.1 * sqrt(x.abs());
  ret += ((20.0 * sin(6.0 * x * _pi) + 20.0 * sin(2.0 * x * _pi)) * 2.0) / 3.0;
  ret += ((20.0 * sin(x * _pi) + 40.0 * sin((x / 3.0) * _pi)) * 2.0) / 3.0;
  ret += ((150.0 * sin((x / 12.0) * _pi) + 300.0 * sin((x / 30.0) * _pi)) * 2.0) / 3.0;
  return ret;
}

/// 单个坐标 WGS-84 → GCJ-02
LatLng wgs84ToGcj02(double lat, double lng) {
  if (lat < 0.01 || lng < 0.01) return LatLng(lat, lng);
  final dLat = _transformLat(lng - 105.0, lat - 35.0);
  final dLng = _transformLng(lng - 105.0, lat - 35.0);
  final radLat = (lat / 180.0) * _pi;
  double magic = sin(radLat);
  magic = 1 - _ee * magic * magic;
  final sqrtMagic = sqrt(magic);
  final dLatFinal = (dLat * 180.0) / (((_a * (1 - _ee)) / (magic * sqrtMagic)) * _pi);
  final dLngFinal = (dLng * 180.0) / ((_a / sqrtMagic) * cos(radLat) * _pi);
  return LatLng(lat + dLatFinal, lng + dLngFinal);
}
