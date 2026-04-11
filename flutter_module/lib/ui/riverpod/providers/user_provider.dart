import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_provider.g.dart';

class User {
  final int id;
  final String name;

  User({required this.id, required this.name});
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
