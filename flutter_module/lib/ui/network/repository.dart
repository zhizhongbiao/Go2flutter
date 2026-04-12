import 'package:dio/dio.dart';
import 'package:flutter_module/base/log/loger.dart';
import 'package:flutter_module/ui/constructor/constructor.dart';
import 'package:flutter_module/ui/network/api_service.dart';
import 'package:flutter_module/ui/network/dio_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../riverpod/providers/user_provider.dart';
import 'my_api_service.dart';

class Repository {
  static Repository? _instance;
  final ApiService apiService;

  Repository._(this.apiService);

  factory Repository(ApiService apiService) {
    _instance ??= Repository._(apiService);
    return _instance!;
  }

  Future<User> getUser() async {
    return await apiService.getUser("id");
  }

  Future<LoginResponse> login() async {
    return await apiService.post(LoginRequest());
  }
}



class MyRepository {

  final MyApiService api;

  MyRepository(this.api);

  Future<User> getUser() => api.getUser("id");

}


final myRepository = Provider((ref){
  final api =ref.watch(myApiService);
  Loger.d("myRepository provider created");
  return MyRepository(api);
});


