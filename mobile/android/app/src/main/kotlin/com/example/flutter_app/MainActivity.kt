package com.example.flutter_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private var makeup: MakeupChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        makeup = MakeupChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onDestroy() {
        makeup?.dispose()
        makeup = null
        super.onDestroy()
    }
}
