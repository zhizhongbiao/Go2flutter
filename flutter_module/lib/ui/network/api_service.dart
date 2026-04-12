
import 'package:dio/dio.dart';
import 'package:flutter_module/ui/riverpod/providers/user_provider.dart';
import 'package:retrofit/http.dart';

import '../constructor/constructor.dart';

part 'api_service.g.dart';


@RestApi(baseUrl: "https://jsonplaceholder.typicode.com")
abstract class ApiService {

  factory ApiService(Dio dio,{String baseUrl}) = _ApiService;

  @GET("/users/{id}")
  Future<User> getUser(@Path("id")String id);

  @POST("/login")
  Future<LoginResponse> post(@Body()LoginRequest request);

}


class LoginRequest{}
class LoginResponse{}

