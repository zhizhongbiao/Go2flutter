
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'counter_provider.g.dart';

@riverpod
class Counter extends _$Counter{

  @override
  int build()=>0;

  // 修改状态的方法
  void increment() => state++;

  void decrement() => state--;

  void reset() => state = 0;

}