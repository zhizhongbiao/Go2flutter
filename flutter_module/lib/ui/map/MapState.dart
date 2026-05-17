import 'package:maplibre_gl/maplibre_gl.dart';

/// 地图状态模型，用于 ValueNotifier 局部刷新
class MapState {
  final LatLng center;
  final double zoom;
  MapState(this.center, this.zoom);
}