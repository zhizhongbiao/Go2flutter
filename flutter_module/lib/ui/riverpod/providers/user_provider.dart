import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_provider.g.dart';
// 1. 声明对应的生成文件名（格式：原文件名.g.dart）
// part 'user.g.dart';

@JsonSerializable()
class User {
  final int id;
  final String name;

  User({required this.id, required this.name});

  // 2. 必须手动声明这个工厂构造函数，它会调用生成的 _$UserFromJson
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  // 3. 必须手动声明这个方法，用于请求体发送
  Map<String, dynamic> toJson() => _$UserToJson(this);
}

@riverpod
class UserNotifier extends _$UserNotifier {
  int id = 18;

  @override
  Future<User> build() async {
    return await _getUser();
    // return User(id: 31, name: "zzb");
  }

  Future<User> _getUser() async {
    // final respon = await http.get(Uri.parse('https://jsonplaceholder.typicode.com/users/1'));
    // final data = jsonDecode(respon.body);
    return User(id: id, name: "zzb");
  }

  Future<void> refresh() async {

    id++;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await _getUser();
    });
  }
}
