import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_module/ui/network/api_service.dart';
import 'package:http/http.dart' as http;

class Network {
  /**
   * http 用法
   */

  Future<void> httpGet() async {
    final respon = await http.get(
      Uri.parse("https://jsonplaceholder.typicode.com/users/1"),
    );
    if (respon.statusCode == 200) {
      print("http get success: ${respon.body}");
    } else {
      print("http get failed: ${respon.statusCode}");
    }
  }

  Future<void> httpPost() async {
    final respon = await http.post(
      Uri.parse("https://jsonplaceholder.typicode.com/posts"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': 'test@example.com', 'password': '123456'}),
    );

    if (respon.statusCode == 200) {
      print("http get success: ${respon.body}");
    } else {
      print("http get failed: ${respon.statusCode}");
    }
  }

  /**
   * Dio用法：
   */

  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.example.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  void initDio() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = "jdkf";
          options.headers["Authorization"] = 'Bearer $token';
          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (e, handler) {
          return handler.next(e);
        },
      ),
    );
  }

  Future<void> dioGet() async {
    final respon = await dio.get("/users/1");
    if (respon.statusCode == 200) {
      print("http get success: ${respon.data}");
    } else {
      print("http get failed: ${respon.statusCode}");
    }
  }

  Future<void> dioPost() async {
    final respon = await dio.post(
      '/login',
      data: {'email': 'test@example.com', 'password': '123456'},
    );

    if (respon.statusCode == 200) {
      print("http get success: ${respon.data}");
    } else {
      print("http get failed: ${respon.statusCode}");
    }
  }

  //upload

  Future<void> upload() async {
    final resp = await dio.post(
      "/upload",
      data: FormData.fromMap({
        "file": MultipartFile.fromFile("/path/to/file.jpg"),
      }),
      onSendProgress: (count, total) {
        print('上传进度: ${(count / total * 100).toStringAsFixed(0)}%');
      },
    );
  }

  Future<void> dioCancel() async {
    final cancelToken = CancelToken();
    await dio.get('/long-request', cancelToken: cancelToken);
    //取消
    cancelToken.cancel();
  }


  void setupRetrofit(){
    final apiService = ApiService(dio);
  }
}
