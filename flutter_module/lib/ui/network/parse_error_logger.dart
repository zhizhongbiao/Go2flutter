

import 'package:dio/src/options.dart';
import 'package:dio/src/response.dart';

class ParseErrorLogger{
  void logError(Object e, StackTrace s, RequestOptions options, {required Response<Map<String, dynamic>>response}) {}
}