
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'post_provider.g.dart';

@riverpod
class PostProvider extends _$PostProvider {

  @override
  Future<String> build(String params) async {
    return "post $params";
  }

}
