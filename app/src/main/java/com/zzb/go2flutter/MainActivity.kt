package com.zzb.go2flutter

import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import com.zzb.go2flutter.flutter.ChannelManager
import com.zzb.go2flutter.flutter.FlutterEngineManager
import com.zzb.go2flutter.ui.theme.Go2flutterTheme
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : ComponentActivity(), ( MethodCall, MethodChannel.Result) -> Unit {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            Go2flutterTheme {
                Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
                    Greeting(
                        name = "Flutter",
                        modifier = Modifier
                            .padding(innerPadding)
                            .clickable {
                                Toast.makeText(this, "Fuck go 2 Flutter", Toast.LENGTH_SHORT).show()
//                            startActivity(FlutterActivity.createDefaultIntent(this))
                                startActivity(
                                    FlutterActivity
                                        .withCachedEngine("Flutter")
                                        .build(this)
                                )
                            }
                    )
                }
            }
        }

        ChannelManager
            .initChannel(
                FlutterEngineManager
                    .getFlutterEngine(this,"Flutter"))
            .channelHandler=
            this@MainActivity
    }

    override fun invoke(
        p1: MethodCall,
        p2: MethodChannel.Result
    ) {
        Toast.makeText(this,"Ffffffdfhg", Toast.LENGTH_LONG).show()
    }
}

@Composable
fun Greeting(name: String, modifier: Modifier = Modifier) {
    Text(
        text = "Hello $name!",
        modifier = modifier
    )
}

@Preview(showBackground = true)
@Composable
fun GreetingPreview() {
    Go2flutterTheme {
        Greeting("Android")
    }
}