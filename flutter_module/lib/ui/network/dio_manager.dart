

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../base/log/loger.dart';
import 'base_url_notifier.dart';

part 'dio_manager.g.dart';


@riverpod
Dio dio(Ref ref) {
 final baseUrl = ref.watch(baseUrlProvider);
 Loger.d("dio provider created");
  final dio = Dio(
    BaseOptions(
      baseUrl:baseUrl ,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      contentType: 'application/json; charset=utf-8',
    ),
  );

  setUpDio(dio);

  ref.onDispose((){
    dio.close();
  });

  return dio;
}

void setUpDio(Dio dio) {
  // dio.interceptors.add(AuthInterceptor(ref));
  dio.interceptors.add(LogInterceptor(responseBody: true));
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