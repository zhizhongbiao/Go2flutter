import 'package:flutter/material.dart';

mixin MixinNavigation {

  void back(BuildContext ctx) => Navigator.of(ctx).pop();

  void navPage(BuildContext ctx, Widget widget) {
    Navigator.of(ctx).push(
      MaterialPageRoute(
        builder: (ctx) {
          return widget;
        },
      ),
    );
  }
}
