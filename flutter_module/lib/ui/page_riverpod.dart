import 'package:flutter/material.dart';
import 'package:flutter_module/ui/network/dio_manager.dart';
import 'package:flutter_module/ui/network/repository.dart';
import 'package:flutter_module/ui/riverpod/providers/counter_provider.dart';
import 'package:flutter_module/ui/riverpod/providers/post_provider.dart';
import 'package:flutter_module/ui/riverpod/providers/provider_string.dart';
import 'package:flutter_module/ui/riverpod/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'network/base_url_notifier.dart';

class PageRiverpod extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    final userAsync = ref.watch(userProvider);
    final postAsync = ref.watch(postProviderProvider("hello"));

    final str = ref.watch(providerStringProvider);

    final myRepos= ref.watch(myRepository);

    final countNotifier = ref.read(counterProvider.notifier);

    final strNotifier = ref.read(providerStringProvider.notifier);
    final userNotifier = ref.read(userProvider.notifier);

    final baseUrlNotifier = ref.read(baseUrlProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text("Riverpod 3.x Counter")),
      body: _buildCenterColumn(count, str, userAsync, postAsync),
      floatingActionButton: _buildButtonRow(
        countNotifier,
        strNotifier,
        userNotifier,
        baseUrlNotifier,
      ),
    );
  }

  Column _buildCenterColumn(
    int count,
    String str,
    AsyncValue<User> userAsync,
    AsyncValue<String> post,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Counter: $count', style: TextStyle(fontSize: 24)),
        const SizedBox(height: 20),
        Text('String: $str', style: TextStyle(fontSize: 24)),
        const SizedBox(height: 20),
        userAsync.when(
          data: (user) => Text('用户: ${user.name} - ${user.id}'),
          loading: () => CircularProgressIndicator(),
          error: (err, stack) => Text('错误: $err'),
        ),
        const SizedBox(height: 20),
        Text('post: ${post.value}', style: TextStyle(fontSize: 24)),
      ],
    );
  }

  Row _buildButtonRow(
    Counter countNotifier,
    ProviderString strNotifier,
    UserNotifier userNotifier,
    BaseUrlNotifier baseUrlNotifier,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FloatingActionButton(
          onPressed: countNotifier.decrement,
          child: Icon(Icons.remove),
        ),
        const SizedBox(width: 20),
        FloatingActionButton(
          onPressed: countNotifier.increment,
          child: Icon(Icons.add),
        ),
        const SizedBox(width: 20),
        FloatingActionButton(onPressed: strNotifier.fuck, child: Text("fuck")),
        const SizedBox(width: 20),
        FloatingActionButton(
          onPressed: strNotifier.screw,
          child: Text("screw"),
        ),

        const SizedBox(width: 20),
        FloatingActionButton(
          // onPressed: userNotifier.refresh,
          onPressed: baseUrlNotifier.change,
          child: Text("refresh"),
        ),
      ],
    );
  }
}
