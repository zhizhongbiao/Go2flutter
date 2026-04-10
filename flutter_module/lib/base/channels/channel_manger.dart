import 'dart:async';
import 'package:flutter/services.dart';

class ChannelManger {
  static final instance = ChannelManger._();

  ChannelManger._();

  static const String methodChannelId = "methodChannelId";
  static const String eventChannelId = "eventChannelId";
  static const String basicChannelId = "basicChannelId";

  static const methodChannel = MethodChannel(methodChannelId);
  static const eventChannel = EventChannel(eventChannelId);
  static const bmc = BasicMessageChannel(basicChannelId,StandardMessageCodec());
  late StreamSubscription<dynamic>? _subscription;

  void initChanel() {
    /**
     * 监听原生的数据
     */
    methodChannel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'battery':
          return {"name": "zzb"};

        default:
          throw "not Found";
      }
    });

    /**
     * 监听数据流
     */
    _subscription = eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final type = event['type'];
          final data = event['data'];

          switch (type) {
            case "ff":
            default:
          }
        }
      },
      onError: (dynamic error) {},
      onDone: () {
        /**
         * done
         */
      },
    );

    /**
     * 双方都需要发送任意类型消息（不适合频繁方法调用），支持自定义编解码器
     * 监听
     */

    bmc.setMessageHandler((msg) async{
      /**
       * deal with msg
       */

      return "msg received";
    });

  }


  Future<Object?> bmc2Native(Object? msg) async{
    return bmc.send(msg);
  }

  Future<T?> invokeMethod<T>(String method, Map<String, dynamic> params) async {
    try {
      return await methodChannel.invokeMethod(method, params);
    } on PlatformException catch (e) {
      throw "invoke failed ${e.code} - ${e.message}";
    } on MissingPluginException catch (e) {
      throw "method not found - ${e.message}";
    }
  }

  void releaseChannel() {
    methodChannel.setMethodCallHandler(null);
    _subscription?.cancel();
    _subscription = null;
  }
}
