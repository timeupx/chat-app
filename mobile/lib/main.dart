import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:livekit_client/livekit_client.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'theme/bigo_theme.dart';

Future<void> main() async {
  // Ensure Flutter bindings are ready before doing async work pre-runApp.
  WidgetsFlutterBinding.ensureInitialized();

  // Loads key/value pairs from the .env file bundled as an asset (see
  // pubspec.yaml `flutter.assets`) so dotenv.env['BASE_URL'] is available
  // everywhere in the app.
  await dotenv.load(fileName: '.env');

  // Android's default LiveKit "communication" audio mode starts Bluetooth SCO
  // whenever a headset is paired, which shows the system banner
  // "… is using the bluetooth microphone". Media mode uses the phone mic
  // instead and avoids that overlay for live rooms.
  //
  // The playback AudioAttributes of the WebRTC audio device module can only be
  // set here, at plugin init — `Helper.setAndroidAudioConfiguration()` later
  // only reconfigures routing, not the stream itself. Without this, remote
  // audio plays on the voice-call stream, which Android pins to the earpiece
  // no matter what speakerphone is set to. Media/speech makes a live room
  // behave like Bigo: loudspeaker on the media volume slider.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await webrtc.WebRTC.initialize(options: {
      'bypassVoiceProcessing': true,
      'androidAudioConfiguration': webrtc.AndroidAudioConfiguration(
        manageAudioFocus: true,
        androidAudioMode: webrtc.AndroidAudioMode.normal,
        androidAudioFocusMode: webrtc.AndroidAudioFocusMode.gain,
        androidAudioStreamType: webrtc.AndroidAudioStreamType.music,
        androidAudioAttributesUsageType:
            webrtc.AndroidAudioAttributesUsageType.media,
        androidAudioAttributesContentType:
            webrtc.AndroidAudioAttributesContentType.speech,
        forceHandleAudioRouting: true,
      ).toMap(),
    });
    // Still needed so the SDK's own audio management knows we bypassed voice
    // processing; the WebRTC init above already ran so it is a no-op natively.
    await LiveKitClient.initialize(bypassVoiceProcessing: true);
  }

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'Stage Live',
        debugShowCheckedModeBanner: false,
        theme: buildBigoTheme(),
        home: const LoginScreen(),
      ),
    );
  }
}
