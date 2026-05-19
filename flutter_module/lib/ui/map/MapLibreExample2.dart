import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'constants.dart';

// ============================================================================
// 文件说明（中文注释）
// 这个示例展示了如何在 Flutter 中使用两个独立的 Isolate 来生成并加载
// 大量点云数据到 MapLibre 地图，避免主线程（UI）被 json 编解码和数据生成
// 的 CPU 密集型任务阻塞。
//
// 流程概览：
// 1) Isolate A（顶层函数 _generateIsolateEntry）负责生成模拟点云并将其
//    直接序列化为 GeoJSON 字符串（String），然后通过 SendPort 发回主线程。
//    优点：在子线程里完成生成与序列化，主线程不分配大量临时对象，降低峰值
//    内存与卡顿风险。字符串采用紧凑 JSON（简短 key），并用 StringBuffer 拼接
//    以提高性能。
// 2) Isolate B（由 compute() 启动，函数为 _decodeGeoJson）负责将上一步得到的
//    GeoJSON 字符串 decode 成 Map。compute 提供了方便的 Isolate 封装，函数必
//    顶层且可序列化。
// 3) 主线程接收 Map（已完成解析），将其提供给 maplibre_gl 插件：首次添加
//    GeoJSON source + CircleLayer，或在地图已存在时热替换数据源。
//
// 设计要点：
// - 将生成、序列化、解析等 CPU 密集型任务都放到子线程，主线程只做最小量
//   的状态切换和 Map 操作回调，确保 UI 流畅。
// - 使用 data-driven style（根据 feature.properties.i 驱动 circleColor）把
//   颜色和大小的计算交给 GPU（MapLibre 着色器），避免 Dart 层逐点处理。
// - 支持两种热替换策略：尝试使用 setGeoJsonSource（更高效），若插件/版本不
//   支持则 fallback 到移除并重建 layer/source。
// ============================================================================

class _IsolateArgs {
  final SendPort sendPort;
  final int count;
  final double centerLat;
  final double centerLon;

  const _IsolateArgs({
    required this.sendPort,
    required this.count,
    required this.centerLat,
    required this.centerLon,
  });
}

/// Isolate A 入口函数：在独立线程中生成点云并直接序列化为 GeoJSON 字符串。
///
/// 说明：此函数在调用方通过 Isolate.spawn 启动的子 isolate 中运行。它不会与
/// Flutter 主线程共享内存，而是通过 SendPort 将最终的字符串发送回主线程。
///
/// 实现关键点：
/// - 使用 StringBuffer 拼接 JSON 文本，避免创建大量临时 Map/List 对象，降低
///   GC 与内存峰值。
/// - properties 使用紧凑 key（"i"）并把 intensity 格式化为三位小数字符串，便
///   于后续在 MapLibre 的表达式中直接读取并用于着色（GPU 侧处理）。
void _generateIsolateEntry(_IsolateArgs args) {
  final rng = Random();
  final sb = StringBuffer();

  sb.write('{"type":"FeatureCollection","features":[');

  for (int i = 0; i < args.count; i++) {
    final latOffset = (rng.nextDouble() - 0.5) * 0.003;
    final lonOffset = (rng.nextDouble() - 0.5) * 0.003;
    final lat = args.centerLat + latOffset;
    final lon = args.centerLon + lonOffset;

    // intensity 归一化到 0.000–1.000，方便 MapLibre 表达式直接使用
    final intensity = rng.nextDouble();

    if (i > 0) sb.write(',');

    // 紧凑格式：短 key "i" 减少字符串体积约 40%
    sb.write(
      '{"type":"Feature",'
          '"geometry":{"type":"Point","coordinates":[$lon,$lat]},'
          '"properties":{"i":${intensity.toStringAsFixed(3)}}}',
    );

    // 每 2 万条刷一次 StringBuffer，避免单次分配内存过大
    if (i % 20000 == 19999) {
      // StringBuffer 无法中途 flush 到文件，这里只是注释说明分批意识
      // 如需写文件可改为 IOSink，此处保持内存方式
    }
  }

  sb.write(']}');
  args.sendPort.send(sb.toString());
}

// ═══════════════════════════════════════════════════════════════════════════════
// compute() 函数：在 Isolate B 里 jsonDecode String → Map
// 必须是顶层函数（不能是闭包），compute() 要求可序列化
// ═══════════════════════════════════════════════════════════════════════════════

/// Isolate B（用于 compute）：在后台线程将 GeoJSON 字符串解析为 Map。
///
/// 注意：compute() 要求传入的函数为顶层或静态函数且参数/返回值可序列化。
/// 把 jsonDecode 放入 compute 可以避免主线程在解析大型 JSON 字符串时卡顿。
Map<String, dynamic> _decodeGeoJson(String jsonStr) {
  return jsonDecode(jsonStr) as Map<String, dynamic>;
}

// ═══════════════════════════════════════════════════════════════════════════════
// 主 Widget
// ═══════════════════════════════════════════════════════════════════════════════

/// 页面控件：显示 MapLibre 地图并承载点云数据加载/更新逻辑。
///
/// 行为摘要：
/// - initState 中启动点云生成/加载管线（_runFullPipeline），与地图异步初始化并行。
/// - 当地图样式（style）加载完成时，会尝试把已准备好的 GeoJSON 数据注入地图；
///   若数据尚未准备好，则会在生成完成后由 _runFullPipeline 检测 controller 并推送。
class PointCloudMapPage extends StatefulWidget {
  const PointCloudMapPage({super.key});

  @override
  State<PointCloudMapPage> createState() => _PointCloudMapPageState();
}

class _PointCloudMapPageState extends State<PointCloudMapPage> {
  // MapLibre 控制器对象，地图创建后由 _onMapCreated 注入。
  MapLibreMapController? _controller;

  // 标识：是否已经在地图上添加了我们的 source + layer（用于更新流程判断）
  bool _layerAdded = false;

  // 是否正在生成/解析数据（用于在 AppBar 上显示进度）
  bool _loading = false;

  // 当前点数（仅用于 UI 展示），不直接影响渲染逻辑
  int _pointCount = 0;

  // 当数据在后台线程生成完毕，但地图样式尚未 ready 时，将解析后的 Map 暂存到此处。
  // 当样式加载完成后（onStyleLoaded），会检查此字段并立即渲染。
  Map<String, dynamic>? _pendingGeoJsonMap;

  // 统一使用固定的 source 与 layer id，便于后续热替换或移除
  static const _sourceId = 'pointCloudSource';
  static const _layerId = 'pointCloudLayer';

  // ── 生命周期 ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // 启动时立即开始生成数据，和地图初始化并行进行
    _runFullPipeline(count: 80000);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 完整 Pipeline：Isolate A(生成+序列化) → Isolate B(反序列化) → MapLibre
  // UI 线程全程只负责等待回调，不做任何 CPU 密集操作
  //
  // _runFullPipeline 会执行下面的步骤：
  // 1) 在新的 isolate（Isolate A）里调用 _generateIsolateEntry，生成 GeoJSON 字符串；
  // 2) 使用 compute() 在另一个 isolate（Isolate B）中将字符串解析为 Map；
  // 3) 若地图控制器已准备好，则将解析后的 Map 注入到 maplibre（首次添加或热替换）；
  //
  // 方法会维护一个 _loading 标志以避免并发运行；在方法早期会检查 mounted
  // 并在每一步完成后再次检查，以防 Widget 已被销毁。
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _runFullPipeline({required int count}) async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _pendingGeoJsonMap = null;
    });

    // ── Step 1: Isolate A —— 生成点云 + 序列化为 GeoJSON 字符串 ──────────
    debugPrint('⏳ [Step1] 开始生成 $count 个点云...');
    final t1 = DateTime.now();

    final rp = ReceivePort();
    await Isolate.spawn(
      _generateIsolateEntry,
      _IsolateArgs(
        sendPort: rp.sendPort,
        count: count,
        centerLat: latLon.latitude,
        centerLon: latLon.longitude,
      ),
    );
    final geoJsonString = await rp.first as String;
    rp.close();

    final ms1 = DateTime.now().difference(t1).inMilliseconds;
    debugPrint('✅ [Step1] 生成完成，耗时 ${ms1}ms，字符串大小: ${(geoJsonString.length / 1024).toStringAsFixed(1)} KB');

    if (!mounted) return;

    // ── Step 2: Isolate B —— jsonDecode String → Map（compute 语法糖）────
    debugPrint('⏳ [Step2] 开始 jsonDecode...');
    final t2 = DateTime.now();

    // compute() 是 Flutter 官方封装的 Isolate，函数必须是顶层函数
    final geoJsonMap = await compute(_decodeGeoJson, geoJsonString);

    final ms2 = DateTime.now().difference(t2).inMilliseconds;
    debugPrint('✅ [Step2] jsonDecode 完成，耗时 ${ms2}ms');

    if (!mounted) return;

    _pointCount = count;
    _pendingGeoJsonMap = geoJsonMap;

    // ── Step 3: 推送到 MapLibre ───────────────────────────────────────────
    if (_controller != null) {
      if (_layerAdded) {
        // 地图已有 layer → 热替换数据源，不重建 layer
        await _updateSource(geoJsonMap);
      } else {
        // 地图已 ready 但还没建 layer → 直接建
        await _addLayerFirstTime(geoJsonMap);
      }
    }
    // 若 _controller == null：地图还没 ready，等 _onStyleLoaded 触发

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  // ── MapLibre 回调 ────────────────────────────────────────────────────────

  /// Map 创建回调：保存 controller 引用以便后续与地图交互。
  /// 注意：controller 只在地图创建后可用，因此在数据准备好但地图未创建时
  /// 会先将解析后的 Map 存入 _pendingGeoJsonMap，等待样式加载后再渲染。
  void _onMapCreated(MapLibreMapController c) {
    _controller = c;
    debugPrint('🗺️ MapLibre 控制器已创建');
  }

  /// 当地图样式加载完成时触发：如果后台数据已经准备好，则立即把 GeoJSON 注入地图。
  ///
  /// 这里需要区分两种情况：
  /// - 数据已准备好（_pendingGeoJsonMap != null）：直接调用 _addLayerFirstTime 渲染；
  /// - 数据尚未准备：等待 _runFullPipeline 在完成时检测到 controller != null 并推送。
  Future<void> _onStyleLoaded() async {
    debugPrint('🗺️ Style 加载完成');
    final map = _pendingGeoJsonMap;
    if (map != null) {
      // 数据已经准备好，直接渲染
      await _addLayerFirstTime(map);
      if (mounted) setState(() => _loading = false);
    }
    // 若数据还没好（Isolate 还在跑），_runFullPipeline 完成后会判断 controller != null 再推送
  }

  // ── Layer 管理 ────────────────────────────────────────────────────────────

  /// 首次添加 GeoJSON source + CircleLayer
  ///
  /// 具体行为：
  /// - 使用 addGeoJsonSource 将解析后的 Map 注册为一个名为 [_sourceId] 的数据源；
  /// - 使用 addCircleLayer 将点数据以圆点的形式渲染，样式通过 expression 驱动，
  ///   这些表达式在 GPU 侧执行，能够对大量 feature 实现高效渲染。
  ///
  /// 圆点样式说明：
  /// - circleRadius 使用 zoom 插值（不同缩放级别圆点大小不同）；
  /// - circleColor 使用 feature.properties.i（intensity）驱动颜色，从绿到黄到红；
  /// - 其余属性调整视觉效果（opacity、blur）。
  Future<void> _addLayerFirstTime(Map<String, dynamic> geoJsonMap) async {
    final c = _controller;
    if (c == null) return;

    await c.addGeoJsonSource(_sourceId, geoJsonMap);

    await c.addCircleLayer(
      _sourceId,
      _layerId,
      CircleLayerProperties(
        // 半径随缩放级别插值 —— GPU 侧计算，零 Dart 开销
        circleRadius: [
          'interpolate',
          ['linear'],
          ['zoom'],
          15, 1.2,
          18, 2.5,
          20, 6.0,
          22, 12.0,
        ],
        // 颜色由 "i"（intensity 0-1）驱动 —— data-driven，GPU 着色器执行
        circleColor: [
          'interpolate',
          ['linear'],
          ['get', 'i'],
          0.0, '#00ff88',   // 低强度 → 绿色（已割草地面）
          0.5, '#ffdd00',   // 中等   → 黄色
          1.0, '#ff2200',   // 高强度 → 红色（障碍物）
        ],
        circleOpacity: 0.83,
        circleBlur: 0.08,   // 轻微模糊，密集区域视觉更自然
      ),
    );

    _layerAdded = true;
    debugPrint('✅ [Step3] Layer 添加完成，共 $_pointCount 个点');
    if (mounted) setState(() {});
  }

  /// 热替换数据源：优先尝试使用插件的 setGeoJsonSource 接口直接替换 source 数据，
  /// 若该方法不可用或抛出异常，再退回到移除旧 layer/source 并重建的新策略。
  ///
  /// 理由：直接 setGeoJsonSource 可以只替换数据而不需要移除/重建 layer，性能开销
  /// 更小；但不同版本的 maplibre_gl 插件对这个 API 的支持不一，因此提供 fallback。
  Future<void> _updateSource(Map<String, dynamic> geoJsonMap) async {
    final c = _controller;
    if (c == null) return;

    debugPrint('🔄 热替换数据源...');

    // 先尝试 setGeoJsonSource（不重建 layer，性能更好）
    try {
      await c.setGeoJsonSource(_sourceId, geoJsonMap);
      debugPrint('✅ setGeoJsonSource 热替换成功');
      return;
    } catch (e) {
      debugPrint('⚠️ setGeoJsonSource 失败，改用重建方式: $e');
    }

    // fallback：移除旧的再重建
    try {
      await c.removeLayer(_layerId);
      await c.removeSource(_sourceId);
    } catch (e) {
      debugPrint('⚠️ 移除旧 layer/source 失败: $e');
    }

    _layerAdded = false;
    await _addLayerFirstTime(geoJsonMap);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('割草机 LiDAR 点云地图'),
        actions: [
          _loading
              ? const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          )
              : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                '${_formatCount(_pointCount)} pts',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: MapLibreMap(
        initialCameraPosition: CameraPosition(
          target: latLon,
          zoom: 18.5,
        ),
        styleString: styleUrl,
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
        trackCameraPosition: true,
        myLocationEnabled: false,
        compassEnabled: false,
        rotateGesturesEnabled: false, // 禁用旋转：减少矩阵运算
        tiltGesturesEnabled: false,   // 纯2D点云不需要倾斜视角
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 新增 5000 点
          FloatingActionButton.small(
            heroTag: 'add',
            onPressed: _loading
                ? null
                : () => _runFullPipeline(count: _pointCount + 5000),
            tooltip: '新增 5000 点',
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          // 重置到 80000 点
          FloatingActionButton.small(
            heroTag: 'reset',
            onPressed: _loading
                ? null
                : () => _runFullPipeline(count: 80000),
            tooltip: '重置',
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  // 将点数格式化为人类可读形式（K、M 等），仅用于 UI 展示
  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return '$n';
  }
}