import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'constants.dart';

class PointCloudMapPage extends StatefulWidget {
  const PointCloudMapPage({super.key});

  @override
  State<PointCloudMapPage> createState() => _PointCloudMapPageState();
}

class _PointCloudMapPageState extends State<PointCloudMapPage> {
  MapLibreMapController? controller;
  List<PointCloudData> pointCloud = [];


  @override
  void initState() {
    super.initState();
    // 生成模拟数据
    pointCloud = generateSimulatedPointCloud(count: 500000);
  }

  void _onMapCreated(MapLibreMapController mapController) {
    controller = mapController;
    _addPointCloudLayer();
  }

  Future<void> _addPointCloudLayer() async {
    if (controller == null) return;

    // 将点云数据转为 MapLibre 支持的 Feature 格式
    final features = pointCloud.map((point) {
      return {
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [point.lon, point.lat]
        },
        "properties": {
          "height": point.height,
          "intensity": point.intensity,
        }
      };
    }).toList();

    await controller!.addGeoJsonSource("pointCloudSource", {
      "type": "FeatureCollection",
      "features": features,
    });

    // 添加 Circle Layer（高性能）
    await controller!.addCircleLayer(
      "pointCloudSource",
      "pointCloudLayer",
      CircleLayerProperties(
        circleRadius: 2.0,
        circleColor: [
          'interpolate',
          ['linear'],
          ['get', 'intensity'],
          0, '#00ff00',      // 低强度 - 绿色
          128, '#ffff00',    // 中等 - 黄色
          255, '#ff0000'     // 高强度 - 红色
        ],
        circleOpacity: 0.85,
      ),
    );

    print("✅ 点云 Layer 添加完成，共 ${pointCloud.length} 个点");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('割草机 LiDAR 点云地图'),
        actions: [
          Text("点数: ${pointCloud.length}  ", style: const TextStyle(fontSize: 16)),
        ],
      ),
      body: MapLibreMap(
        initialCameraPosition: const CameraPosition(
          target:  latLon,
          zoom: 18.5,
        ),
        styleString: styleUrl,
        onMapCreated: _onMapCreated,
        trackCameraPosition: true,
        myLocationEnabled: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 模拟实时新增点云
          setState(() {
            pointCloud.addAll(generateSimulatedPointCloud(count: 5000));
          });
          _addPointCloudLayer(); // 重新添加（实际项目建议增量更新）
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}



// point_cloud_data.dart

class PointCloudData {
  final double lat;
  final double lon;
  final double height;
  final double intensity;

  PointCloudData({
    required this.lat,
    required this.lon,
    required this.height,
    required this.intensity,
  });
}

// 生成模拟割草机 LiDAR 点云数据
List<PointCloudData> generateSimulatedPointCloud({
  int count = 80000,           // 可改成 200000+
  double centerLat = 22.94,
  double centerLon = 113.23,
}) {
  final random = Random();
  final points = <PointCloudData>[];

  for (int i = 0; i < count; i++) {
    // 高斯分布，模拟割草机工作区域
    final latOffset = random.nextDouble() * 0.003 - 0.0015;
    final lonOffset = random.nextDouble() * 0.003 - 0.0015;

    points.add(PointCloudData(
      lat: centerLat + latOffset,
      lon: centerLon + lonOffset,
      height: random.nextDouble() * 6.0,           // 0-6米高度
      intensity: random.nextDouble() * 255,        // 反射强度
    ));
  }
  return points;
}