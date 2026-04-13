

import 'package:dio/dio.dart';
import 'package:flutter_module/ui/constructor/constructor.dart';
import 'package:flutter_module/ui/network/dio_manager.dart';
import 'package:flutter_module/ui/network/parse_error_logger.dart';
import 'package:flutter_module/ui/network/repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:retrofit/http.dart';

import '../../base/log/loger.dart';
import '../riverpod/providers/user_provider.dart';

part 'my_api_service.g.dart';

@RestApi(baseUrl: "https://jsonplaceholder.typicode.com")
abstract class MyApiService {

  @GET("/users/{id}")
  Future<User> getUser(@Path("id")String id);

}

final myApiService = Provider((ref){
  final dio =ref.watch(dioProvider);
  Loger.d("myApiService provider created");
  return _MyApiService(dio,baseUrl: dio.options.baseUrl);
});

