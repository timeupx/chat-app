import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  // Ensure Flutter bindings are ready before doing async work pre-runApp.
  WidgetsFlutterBinding.ensureInitialized();

  // Keep a media / web codec failure from wiping the whole UI to white.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught platform error: $error\n$stack');
    return true;
  };

  // Loads key/value pairs from the .env file bundled as an asset (see
  // pubspec.yaml `flutter.assets`) so dotenv.env['BASE_URL'] is available
  // everywhere in the app.
  try {
    await dotenv.load(fileName: '.env');
  } catch (e, st) {
    debugPrint('Failed to load .env (continuing): $e\n$st');
  }

  runZonedGuarded(() {
    runApp(const MainApp());
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error\n$stack');
  });
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'Chat App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: const LoginScreen(),
      ),
    );
  }
}
