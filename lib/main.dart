import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'services/api.dart';
import 'services/audio.dart';
import 'services/save_data.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SaveData.i.load();
  // Load sounds in the background so the app opens instantly.
  Audio.i.init(sound: SaveData.i.soundOn, music: SaveData.i.musicOn);
  // Connect to the game server in the background (the game works without it).
  Api.i.started = Api.i.init();
  runApp(const FlyingSlipperApp());
}

class FlyingSlipperApp extends StatefulWidget {
  const FlyingSlipperApp({super.key});

  @override
  State<FlyingSlipperApp> createState() => _FlyingSlipperAppState();
}

class _FlyingSlipperAppState extends State<FlyingSlipperApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Audio.i.startMusic();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Pause the music when the app goes to the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Audio.i.resumeMusic();
    } else if (state == AppLifecycleState.paused) {
      Audio.i.pauseMusic();
      // upload progress before Android may close the app
      Api.i.syncNow();
      Api.i.flushEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'دمپایی پرنده',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Vazirmatn',
        scaffoldBackgroundColor: C.bgTop,
        colorScheme: ColorScheme.fromSeed(seedColor: C.red),
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        }),
      ),
      // The whole app is right-to-left (Persian).
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const HomeScreen(),
    );
  }
}
