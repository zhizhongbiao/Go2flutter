package com.zzb.go2flutter.flutter

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

object FlutterEngineManager {


    fun getFlutterEngine(ctx: Context, id:String): FlutterEngine{
        val engine = FlutterEngineCache.getInstance()[id]
        if (engine!=null)
            return engine

       return FlutterEngine(ctx).apply {
           dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
           FlutterEngineCache.getInstance().put(id,this)
        }
    }


    fun stopEngine(id:String){
        FlutterEngineCache.getInstance()[id]?.destroy()
    }

}