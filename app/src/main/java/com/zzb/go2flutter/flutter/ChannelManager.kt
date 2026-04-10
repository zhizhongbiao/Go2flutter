package com.zzb.go2flutter.flutter

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BasicMessageChannel
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec

object ChannelManager : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    const val METHOD_CHANNEL_ID = "methodChannelId"
    const val EVENT_CHANNEL_ID = "eventChannelId"
    const val BASIC_CHANNEL_ID = "basicChannelId"

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var bmc: BasicMessageChannel<Any>

    var channelHandler: ((call: MethodCall, result: MethodChannel.Result) -> Unit)? = null


    fun initChannel(engine: FlutterEngine) = apply {
        /**
         * methodChannel是双向通信的
         */
        methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL_ID)
            .apply { setMethodCallHandler(this@ChannelManager) }

        /**
         * 单向的，只能从原生流向Flutter
         */
        eventChannel = EventChannel(engine.dartExecutor.binaryMessenger, EVENT_CHANNEL_ID)
            .apply { setStreamHandler(this@ChannelManager) }

        bmc = BasicMessageChannel<Any>(
            engine.dartExecutor.binaryMessenger,
            BASIC_CHANNEL_ID, StandardMessageCodec()
        )
            .apply {
                setMessageHandler { any, reply ->
                    //收到msg
                    reply.reply("收到消息：$any")
                }
            }
    }

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result
    ) {

        /**
         * run in main Thread
         */
        when (call.method) {
            "getBatteryLevel" -> {
                val name = call.argument<String>("name")
                val batteryLevel = name.hashCode()
                if (batteryLevel > 0)
                    result.success(batteryLevel)
                else
                    result.error("UNAVAILABLE", "Battery level not available.", null)
            }

            else -> result.notImplemented()
        }

        channelHandler?.invoke(call, result)

    }


    fun sendBmc(msg: Any) {
        bmc.send(msg) { reply ->
            //收到的回复reply
        }
    }


    fun invokeFlutterMethod(
        methodName: String,
        params: Map<String, Any>,
        cb: MethodChannel.Result?
    ) {
        methodChannel.invokeMethod(methodName, params, cb)
    }

    var eventSink: EventChannel.EventSink? = null

    override fun onListen(p0: Any?, event: EventChannel.EventSink?) {
        //获取事件sink
        eventSink = event
    }

    fun sendEvent2Flutter(params: Any) {
        eventSink?.success(params)
    }

    override fun onCancel(p0: Any?) {
        //清空事件sink，释放资源
        eventSink = null
    }


    fun releaseChannel() {
        methodChannel
            .setMethodCallHandler(null)
        eventSink = null
        eventChannel.setStreamHandler(null)

    }

}