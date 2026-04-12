

import 'package:flutter_module/base/log/loger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';


part 'base_url_notifier.g.dart';
@riverpod
class BaseUrlNotifier extends _$BaseUrlNotifier{

  int count=0;

  @override
  String build()=>'https://api.example.com';

  void change() {
    count=count+1;
    state='https://api.example.com/$count';
    Loger.d("base url changed to $state");
  }
}