import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_module/base/channels/channel_manger.dart';
import 'package:flutter_module/ui/map/MapLibreExample.dart';
import 'package:flutter_module/ui/map/claude/screens/lawn_map_screen.dart';
import 'package:flutter_module/ui/my_stateful_page.dart';
import 'package:flutter_module/ui/page_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en', 'US'), Locale('zh', 'CN')],
      path: 'assets/translations', // 资源路径
      fallbackLocale: const Locale('en', 'US'), // 兜底语言
      child: const ProviderScope(child: MyApp()),
    ),
  );

}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This ui is the root of your application.
  @override
  Widget build(BuildContext context) {
    ChannelManger.instance.initChanel();
    return MaterialApp(
      // 2. 注入配置
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,

      // 关键：跟随 EasyLocalization 的状态
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or press Run > Flutter Hot Reload in a Flutter IDE). Notice that the
        // counter didn't reset back to zero; the application is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
      routes: {
        "/myPage": (context) => MyStatefulPage(),
        "/riverpod": (context) => PageRiverpod(),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This ui is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App ui) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // TODO: implement didChangeAppLifecycleState
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed: // App 回到前台
        print('App resumed（前台）');
        break;
      case AppLifecycleState.inactive: // App 处于非活跃状态（切换应用、接电话等）
        print('App inactive');
        break;
      case AppLifecycleState.paused: // App 进入后台
        print('App paused（后台）');
        break;
      case AppLifecycleState.detached: // App 被系统杀死或分离
        print('App detached');
        break;
      case AppLifecycleState.hidden: // Flutter 3.7+ 新增（完全隐藏）
        print('App hidden');
        break;
    }
  }

  void _go2MyPage() {
    // ChannelManger.instance.invokeMethod("method", {});
    // Navigator.of(context).push(MaterialPageRoute(builder: (context)=>const MyStatefulPage()));
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout ui. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout ui. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each ui.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: .center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _go2MyPage,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}



// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';


// void main() {
//   WidgetsFlutterBinding.ensureInitialized();
//
//   // Lock to portrait – point cloud map is designed for vertical layout.
//   // Remove if you want landscape support.
//   SystemChrome.setPreferredOrientations([
//     DeviceOrientation.portraitUp,
//     DeviceOrientation.landscapeLeft,
//     DeviceOrientation.landscapeRight,
//   ]);
//
//   // Full-screen immersive for maximum map area
//   SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
//     statusBarColor:         Colors.transparent,
//     statusBarBrightness:    Brightness.dark,
//     statusBarIconBrightness: Brightness.light,
//   ));
//
//   runApp(const LawnMapApp());
// }
//
// class LawnMapApp extends StatelessWidget {
//   const LawnMapApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'LiDAR Point Cloud Map',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         colorScheme: const ColorScheme.dark(
//           primary:   Color(0xff1db954),
//           secondary: Color(0xff52d46e),
//           surface:   Color(0xff0d1a0e),
//         ),
//         scaffoldBackgroundColor: const Color(0xff080f09),
//         useMaterial3: true,
//       ),
//       home: const LawnMapScreen(),
//     );
//   }
// }
