import 'package:flutter_module/ui/riverpod/providers/counter_provider.dart';
import 'package:flutter_module/ui/riverpod/providers/post_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cart_provider.g.dart';

@riverpod
class Cart extends _$Cart {
  @override
  List<Cart> build() {
    /**
     * 在build函数watch或者监听都可以；
     */
    int watchCount = ref.watch(counterProvider);
    ref.listen(counterProvider, (previous, next) {

    });
    return [];
  }

  void addItem(Cart c) {
    /**
     * 在普通的函数中建议只是read读取数据；
     */

    int count =ref.read(counterProvider);
    state = [...state, c];
  }


}
