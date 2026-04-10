import 'package:flutter/material.dart';

class MyStatelessPage extends StatelessWidget {
  const MyStatelessPage({super.key});

  void _back(BuildContext ctx) {
    Navigator.of(ctx).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(child: Text("BAck"),onTap: (){
          _back(context);
        },),
      ],
    );
  }
}


