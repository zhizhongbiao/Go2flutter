
import 'package:dio/dio.dart';
import 'package:flutter_module/ui/riverpod/providers/user_provider.dart';
import 'package:json_annotation/json_annotation.dart';
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



@JsonSerializable()
class LoginRequest{
  LoginRequest();
  factory LoginRequest.fromJson(Map<String, dynamic> json) => _$LoginRequestFromJson(json);
  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);
}

@JsonSerializable()
class LoginResponse{
  LoginResponse();

  factory LoginResponse.fromJson(Map<String, dynamic> json) => _$LoginResponseFromJson(json);
  Map<String, dynamic> toJson() => _$LoginResponseToJson(this);

}

