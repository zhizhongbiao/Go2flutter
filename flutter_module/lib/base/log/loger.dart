import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

// l.t("Trace - 最细微的细节");
// l.d("Debug - 调试信息");
// l.i("Info - 普通运行状态");
// l.w("Warning - 警告，可能存在风险");
// l.e("Error - 业务报错", error: '404', stackTrace: StackTrace.current);
// l.f("Fatal - 致命错误，可能导致崩溃");

class Loger {

  Loger._forbid();

  // 仅在开发模式初始化
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2, // 打印两行调用栈
      colors: true, // 彩色输出
      printEmojis: true, // 打印 Emoji 标识级别
    ),
  );

  static void d(String message) {
    if (kDebugMode) {
      // 只在开发阶段打印
      _logger.d(message);
    }
  }

  static void e(String message, [dynamic error, StackTrace? stack]) {
    if (kDebugMode) {
      _logger.e(message, error: error, stackTrace: stack);
    }
    // 这里可以顺便把错误日志传给 Sentry 或 Bugly (生产环境)
  }
}
