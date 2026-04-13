import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Storage {
  Future<void> spSaveData() async {
    // 1. 获取实例
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // 2. 写入数据 (支持 int, double, bool, string, stringList)
    await prefs.setInt('user_id', 12345);
    await prefs.setString('user_token', 'ABC_XYZ_789');
    await prefs.setBool('is_dark_mode', true);
    await prefs.setStringList('search_history', [
      'Flutter',
      'Riverpod',
      'M4 Max',
    ]);
  }

  Future<void> readDate() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // 读取数据，如果 key 不存在，返回 null
    final int? userId = prefs.getInt('user_id');
    final String? token =
        prefs.getString('user_token') ?? 'default_value'; // 使用 ?? 处理默认值
    final List<String>? history = prefs.getStringList('search_history');
  }

  Future<void> removeAndDel() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // 删除特定 key
    await prefs.remove('user_token');

    // 清空所有数据 (慎用)
    await prefs.clear();
  }
}
