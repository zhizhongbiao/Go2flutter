

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class LifecyclePage extends StatefulWidget{


  @override
  State<StatefulWidget> createState() =>LifecycleState();


}


class LifecycleState extends State<LifecyclePage>{
  @override
  Widget build(BuildContext context) {
    //构建UI时
    return Scaffold(body: Text("data"),);
  }


  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    //State 对象被插入树中时（第一次创建）
  }


  @override
  void didChangeDependencies() {
    // TODO: implement didChangeDependencies
    super.didChangeDependencies();
    //依赖的 InheritedWidget 发生变化时
  }


  @override
  void didUpdateWidget(covariant LifecyclePage oldWidget) {
    // TODO: implement didUpdateWidget
    super.didUpdateWidget(oldWidget);

    //当 Widget 重新构建时（父 Widget 发生变化时）

  }


  @override
  void reassemble() {
    // TODO: implement reassemble
    super.reassemble();
    //热重载时，调试用的
  }

  @override
  void deactivate() {
    // TODO: implement deactivate
    super.deactivate();
    //widget 从树中被移除时
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    //State 对象被永久移除时（通常在页面销毁时调用）
  }

}