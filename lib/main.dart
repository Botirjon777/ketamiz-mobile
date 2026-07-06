import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ketamiz/src/services/push_service.dart';
import 'package:ketamiz/src/theme/app_theme.dart';
import 'package:ketamiz/src/ui/splash/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = AppHttpOverrides();

  // Firebase Cloud Messaging. Native config files (google-services.json /
  // GoogleService-Info.plist) provide the options, so no args are needed.
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await PushNotificationService.instance.init();
    } catch (e) {
      debugPrint('Firebase init failed: $e');
    }
  }

  final prefs = await SharedPreferences.getInstance();
  final savedLanguage = prefs.getString('language') ?? 'uz';

  var delegate = await LocalizationDelegate.create(
    basePath: 'assets/i18n',
    fallbackLocale: 'en',
    supportedLocales: ['en', 'ru', 'uz'],
  );
  await delegate.changeLocale(Locale(savedLanguage));
  runApp(LocalizedApp(delegate, const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    var localizationDelegate = LocalizedApp.of(context).delegate;
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    return LocalizationProvider(
      state: LocalizationProvider.of(context).state,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: PushNotificationService.instance.navigatorKey,
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          localizationDelegate
        ],
        supportedLocales: localizationDelegate.supportedLocales,
        locale: localizationDelegate.currentLocale,
        theme: ThemeData(
          brightness: Brightness.light,
          canvasColor: Colors.transparent,
          platform: TargetPlatform.iOS,
          colorScheme: ColorScheme.fromSwatch().copyWith(
            primary: AppTheme.purple,
            secondary: AppTheme.blue,
            error: AppTheme.red,
            surface: AppTheme.bg,
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: AppTheme.bg,
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

class AppHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    // Use the default system certificate validation.
    // Only override to reject certificates that the system already rejects.
    // No blanket certificate bypassing — let the platform handle TLS properly.
    return super.createHttpClient(context);
  }
}
