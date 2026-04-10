package com.zzb.go2flutter

import android.app.Application
import com.zzb.go2flutter.flutter.FlutterEngineManager

class App : Application() {


    override fun onCreate() {
        super.onCreate()
        FlutterEngineManager.getFlutterEngine(this,"Flutter")
    }
}