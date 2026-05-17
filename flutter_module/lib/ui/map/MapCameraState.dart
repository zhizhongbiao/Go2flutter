import 'package:maplibre_gl/maplibre_gl.dart';

/// 专门用于管理地图相机状态的简单模型，避免频繁 setState
class MapCameraState {
  final LatLng center;
  final double zoom;
  MapCameraState(this.center, this.zoom);
}