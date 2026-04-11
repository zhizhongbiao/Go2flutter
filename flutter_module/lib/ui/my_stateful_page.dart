import 'dart:ffi';

import 'package:flutter/material.dart';

import 'my_stateless_page.dart';


class MyStatefulPage extends StatefulWidget {
  const MyStatefulPage({super.key});

  @override
  State<MyStatefulPage> createState() => _MyStatefulPageState();
}

class _MyStatefulPageState extends State<MyStatefulPage> {
  int counter = 3;
  Array<Int> list = Array(3);

  @override
  void initState() {
    super.initState();
  }

  @override
  void setState(VoidCallback fn) {
    // TODO: implement setState
    super.setState(fn);
  }

  void _go2StatelessPage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const MyStatelessPage()));

    /**
     * 执行该函数会标记该State对象需要重新构建，
     * Flutter框架会在下一帧调用对应该state的widget需要build方法来更新UI。
     */
    setState((){
      counter++;
    });

  }

  void _back() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              _go2StatelessPage();
            },
            child: Text('Counter: $counter'),
          ),
          GestureDetector(
            onTap: () {
              _back();
            },
            child: Text('BACK'),
          ),
        ],
      ),
    );
  }
}
