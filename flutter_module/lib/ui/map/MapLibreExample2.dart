import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:path_provider/path_provider.dart';

import 'constants.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 设计思路对比
//
// ❌ 旧方案（有 IO 压力）：
//    维护一个"全量大文件"，每次追加都：
//      读旧文件（线性增长）→ 写新文件（线性增长）
//    30分钟后：读写各 150MB，手机 IO 撑不住
//
// ✅ 新方案（恒定 IO）：
//    每批数据 → 独立小文件（写一次，永不修改）
//    MapLibre 叠加多个 Source 显示所有历史数据
//    每次增量 IO = 当前批次大小（固定 ~1MB，与历史总量无关）
//    10个小文件自动合并成1个，防止 Source 数量无限增长
//
// 文件结构示意：
//   lidar_chunk_0.geojson  ← 初始8万点，写完永不读写
//   lidar_chunk_1.geojson  ← 增量6000点
//   lidar_chunk_2.geojson  ← 增量6000点
//   ...（超过10个时自动合并）
// ═══════════════════════════════════════════════════════════════════════════

// ─── Isolate 消息类（顶层，可跨 Isolate 传递）────────────────────────────

class _GenArgs {
  final SendPort sendPort;
  final int count;
  final double centerLat;
  final double centerLon;
  final String filePath;
  const _GenArgs({
    required this.sendPort,
    required this.count,
    required this.centerLat,
    required this.centerLon,
    required this.filePath,
  });
}

class _WriteArgs {
  final SendPort sendPort;
  final Float32List chunk;
  final String filePath;
  const _WriteArgs({
    required this.sendPort,
    required this.chunk,
    required this.filePath,
  });
}

class _MergeArgs {
  final SendPort sendPort;
  final List<String> inputPaths;
  final String outputPath;
  const _MergeArgs({
    required this.sendPort,
    required this.inputPaths,
    required this.outputPath,
  });
}

// ─── Isolate 顶层函数 ─────────────────────────────────────────────────────

/// 随机生成点云并写入文件（初始批次）
void _generateChunkIsolate(_GenArgs args) {
  final rng  = Random();
  final sink = File(args.filePath).openSync(mode: FileMode.write);
  sink.writeStringSync('{"type":"FeatureCollection","features":[');

  for (int i = 0; i < args.count; i++) {
    final lon = args.centerLon + (rng.nextDouble() - 0.5) * 0.012;
    final lat = args.centerLat + (rng.nextDouble() - 0.5) * 0.012;
    final iv  = rng.nextDouble();
    if (i > 0) sink.writeStringSync(',');
    sink.writeStringSync(_feat(lon, lat, iv));
  }

  sink.writeStringSync(']}');
  sink.flushSync();
  sink.closeSync();
  args.sendPort.send('file://${args.filePath}');
}

/// 把 Float32List 写入文件（增量批次）
/// IO量 = 当前批次大小，与历史总量完全无关
void _writeChunkIsolate(_WriteArgs args) {
  final chunk      = args.chunk;
  final pointCount = chunk.length ~/ 3;
  final sink       = File(args.filePath).openSync(mode: FileMode.write);
  sink.writeStringSync('{"type":"FeatureCollection","features":[');

  for (int i = 0; i < pointCount; i++) {
    final lon = chunk[i * 3];
    final lat = chunk[i * 3 + 1];
    final iv  = chunk[i * 3 + 2];
    if (i > 0) sink.writeStringSync(',');
    sink.writeStringSync(_feat(lon, lat, iv));
  }

  sink.writeStringSync(']}');
  sink.flushSync();
  sink.closeSync();
  args.sendPort.send('file://${args.filePath}');
}

/// 合并多个小 GeoJSON 文件为一个（不解析 JSON，直接字符串拼接）
/// 只在触发合并时执行一次，合并后小文件删除
void _mergeFilesIsolate(_MergeArgs args) {
  final sink = File(args.outputPath).openSync(mode: FileMode.write);
  sink.writeStringSync('{"type":"FeatureCollection","features":[');

  bool firstFeature = true;
  for (final path in args.inputPaths) {
    final content = File(path).readAsStringSync();
    // 固定格式：{"type":"FeatureCollection","features":[...]}
    // 直接提取方括号内的内容，避免 JSON 解析开销
    final start    = content.indexOf('[') + 1;
    final end      = content.lastIndexOf(']');
    if (start >= end) continue;
    final inner    = content.substring(start, end).trim();
    if (inner.isEmpty) continue;
    if (!firstFeature) sink.writeStringSync(',');
    sink.writeStringSync(inner);
    firstFeature = false;
  }

  sink.writeStringSync(']}');
  sink.flushSync();
  sink.closeSync();
  args.sendPort.send('file://${args.outputPath}');
}

String _feat(double lon, double lat, double iv) =>
    '{"type":"Feature",'
        '"geometry":{"type":"Point","coordinates":[${lon.toStringAsFixed(6)},${lat.toStringAsFixed(6)}]},'
        '"properties":{"i":${iv.toStringAsFixed(3)}}}';

// ─── 记录每个已添加到地图的 Chunk ────────────────────────────────────────

class _ChunkMeta {
  final String sourceId;
  final String layerId;
  final String fileUri;
  final int    pointCount;
  const _ChunkMeta({
    required this.sourceId,
    required this.layerId,
    required this.fileUri,
    required this.pointCount,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// 主页面
// ═══════════════════════════════════════════════════════════════════════════

class PointCloudMapPage extends StatefulWidget {
  const PointCloudMapPage({super.key});
  @override
  State<PointCloudMapPage> createState() => _PointCloudMapPageState();
}

class _PointCloudMapPageState extends State<PointCloudMapPage> {
  MapLibreMapController? _controller;

  bool    _mapReady        = false;
  bool    _pipelineRunning = false;
  int     _totalPoints     = 0;
  int     _chunkIdx        = 0;   // 递增 ID，保证 source/layer ID 唯一
  String? _tempDir;

  final List<_ChunkMeta> _addedChunks   = []; // 已在地图上的 chunk
  final List<_ChunkMeta> _pendingChunks = []; // 地图未 ready 时暂存

  // 合并阈值：超过此数量触发合并
  static const _mergeThreshold = 10;
  // 每次合并的 chunk 数量
  static const _mergeCount     = 8;

  Timer? _simulationTimer;

  // ── 生命周期 ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _controller?.dispose();
    _cleanupFiles();
    super.dispose();
  }

  Future<void> _init() async {
    _tempDir = (await getTemporaryDirectory()).path;
    await _addChunk(isInitial: true, count: 80000);
  }

  // ── 路径 / ID 生成 ────────────────────────────────────────────────────────

  String _filePath(int idx)   => '$_tempDir/lidar_chunk_$idx.geojson';
  String _sourceId(int idx)   => 'lidar_src_$idx';
  String _layerId(int idx)    => 'lidar_lyr_$idx';

  // ═══════════════════════════════════════════════════════════════════════
  // 核心：添加一批点（初始 or 增量）
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _addChunk({required bool isInitial, required int count}) async {
    if (_tempDir == null) return;
    if (!isInitial && _pipelineRunning) return;

    _pipelineRunning = true;
    if (mounted) setState(() {});

    try {
      final idx  = _chunkIdx++;
      final path = _filePath(idx);
      final rp   = ReceivePort();

      if (isInitial) {
        // 初始批次：Isolate 随机生成 + 写文件
        await Isolate.spawn(_generateChunkIsolate, _GenArgs(
          sendPort:  rp.sendPort,
          count:     count,
          centerLat: latLon.latitude,
          centerLon: latLon.longitude,
          filePath:  path,
        ));
      } else {
        // 增量批次：主线程生成 Float32List（6000点 < 1ms），Isolate 写文件
        final chunk = _buildFloat32Chunk(count);
        await Isolate.spawn(_writeChunkIsolate, _WriteArgs(
          sendPort: rp.sendPort,
          chunk:    chunk,
          filePath: path,
        ));
      }

      final fileUri = await rp.first as String;
      rp.close();

      _totalPoints += count;
      final meta = _ChunkMeta(
        sourceId:   _sourceId(idx),
        layerId:    _layerId(idx),
        fileUri:    fileUri,
        pointCount: count,
      );

      if (_mapReady && _controller != null) {
        await _attachToMap(meta);
        // 超过阈值时触发合并（在后台异步执行，不阻塞当前帧）
        if (_addedChunks.length >= _mergeThreshold) {
          _mergeOldChunksAsync();
        }
      } else {
        _pendingChunks.add(meta);
      }

    } finally {
      _pipelineRunning = false;
      if (mounted) setState(() {});
    }
  }

  /// 快速生成 Float32List（主线程可接受，6000点 < 1ms）
  Float32List _buildFloat32Chunk(int count) {
    final rng  = Random();
    final data = Float32List(count * 3);
    final cLat = latLon.latitude;
    final cLon = latLon.longitude;
    for (int i = 0; i < count; i++) {
      final base     = i * 3;
      data[base]     = cLon + (rng.nextDouble() - 0.5) * 0.012;
      data[base + 1] = cLat + (rng.nextDouble() - 0.5) * 0.012;
      data[base + 2] = rng.nextDouble();
    }
    return data;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 添加 Source + Layer 到地图
  // 每次只传一个短 URI 字符串给 Platform Channel，零序列化开销
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _attachToMap(_ChunkMeta meta) async {
    final c = _controller;
    if (c == null) return;

    await c.addSource(
      meta.sourceId,
      GeojsonSourceProperties(
        data:           meta.fileUri, // file:// 路径，Native 侧读文件，不经过 Dart
        maxzoom:        18,
        buffer:         64,
        tolerance:      0.5,
        cluster:        true,
        clusterMaxZoom: 15,
        clusterRadius:  40,
      ),
    );

    // 聚合圆（远景）
    await c.addCircleLayer(
      meta.sourceId,
      '${meta.layerId}_cls',
      CircleLayerProperties(
        circleRadius: ['step', ['get', 'point_count'], 12, 200, 20, 2000, 28],
        circleColor:  ['step', ['get', 'point_count'],
          '#1a6b2e', 200, '#2db352', 2000, '#52d46e'],
        circleOpacity:       0.72,
        circleStrokeWidth:   1.0,
        circleStrokeColor:   '#ffffff',
        circleStrokeOpacity: 0.18,
      ),
      filter: ['has', 'point_count'],
    );

    // 单点圆（近景，颜色/大小 GPU data-driven）
    await c.addCircleLayer(
      meta.sourceId,
      meta.layerId,
      CircleLayerProperties(
        circleRadius: [
          'interpolate', ['linear'], ['zoom'],
          15, 1.5,  18, 3.0,  20, 7.0,
        ],
        circleColor: [
          'interpolate', ['linear'], ['get', 'i'],
          0.0, '#00ff88',
          0.5, '#ffdd00',
          1.0, '#ff2200',
        ],
        circleOpacity: 0.85,
        circleBlur:    0.1,
      ),
      filter: ['!', ['has', 'point_count']],
    );

    _addedChunks.add(meta);
    debugPrint('✅ chunk ${meta.sourceId} 已添加，当前 source 数: ${_addedChunks.length}');
    if (mounted) setState(() {});
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 自动合并：防止 Source 数量无限增长
  //
  // IO 分析：
  //   合并 8 个 6000点的文件 ≈ 读 8×1MB + 写 1×8MB = 16MB（一次性，可接受）
  //   合并后删除 8 个旧文件，磁盘空间不累积
  //   触发频率：每新增 10 个 chunk 触发一次（约每 50 秒一次）
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _mergeOldChunksAsync() async {
    if (_addedChunks.length < _mergeCount) return;
    final c = _controller;
    if (c == null) return;

    final toMerge    = _addedChunks.take(_mergeCount).toList();
    final mergedIdx  = _chunkIdx++;
    final mergedPath = _filePath(mergedIdx);

    debugPrint('🔄 合并 $_mergeCount 个旧 chunk...');

    // Isolate 里合并文件（字符串拼接，不解析 JSON）
    final rp = ReceivePort();
    await Isolate.spawn(_mergeFilesIsolate, _MergeArgs(
      sendPort:   rp.sendPort,
      inputPaths: toMerge.map((m) => m.fileUri.replaceFirst('file://', '')).toList(),
      outputPath: mergedPath,
    ));
    final mergedUri = await rp.first as String;
    rp.close();

    // 从地图移除旧 layer/source，删除旧文件
    for (final old in toMerge) {
      try {
        await c.removeLayer(old.layerId);
        await c.removeLayer('${old.layerId}_cls');
        await c.removeSource(old.sourceId);
        File(old.fileUri.replaceFirst('file://', '')).deleteSync();
      } catch (e) {
        debugPrint('⚠️ 移除旧 chunk 失败: $e');
      }
    }
    _addedChunks.removeRange(0, _mergeCount);

    // 添加合并后的大文件
    final mergedMeta = _ChunkMeta(
      sourceId:   _sourceId(mergedIdx),
      layerId:    _layerId(mergedIdx),
      fileUri:    mergedUri,
      pointCount: toMerge.fold(0, (s, m) => s + m.pointCount),
    );
    // 插到头部（时间最早）
    await _attachToMap(mergedMeta);
    _addedChunks.remove(mergedMeta);
    _addedChunks.insert(0, mergedMeta);

    debugPrint('✅ 合并完成，当前 source 数: ${_addedChunks.length}');
  }

  // ── MapLibre 回调 ────────────────────────────────────────────────────────

  void _onMapCreated(MapLibreMapController c) {
    _controller = c;
  }

  Future<void> _onStyleLoaded() async {
    _mapReady = true;
    // 把 pending 队列里所有 chunk 添加到地图
    for (final meta in _pendingChunks) {
      await _attachToMap(meta);
    }
    _pendingChunks.clear();
    if (mounted) setState(() {});

    // 地图 ready 后开始定时模拟
    _startSimulation();
  }

  void _startSimulation() {
    _simulationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _addChunk(isInitial: false, count: 6000);
    });
  }

  // ── 清理 ──────────────────────────────────────────────────────────────────

  void _cleanupFiles() {
    try {
      final dir = Directory(_tempDir ?? '');
      if (!dir.existsSync()) return;
      dir.listSync()
          .whereType<File>()
          .where((f) => f.path.contains('lidar_chunk_'))
          .forEach((f) { try { f.deleteSync(); } catch (_) {} });
    } catch (_) {}
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('割草机 LiDAR 点云地图'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
              '${(_totalPoints / 1000).toStringAsFixed(0)}K pts'
                  ' · ${_addedChunks.length} src',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          MapLibreMap(
            initialCameraPosition: CameraPosition(target: latLon, zoom: 18.0),
            styleString: styleUrl,
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            trackCameraPosition: true,
            myLocationEnabled: false,
            compassEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
          ),

          // 轻量更新指示（不挡操作）
          if (_pipelineRunning)
            Positioned(
              top: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12, height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: Colors.greenAccent),
                    ),
                    SizedBox(width: 6),
                    Text('更新中…',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
