import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:ketamiz/src/lan_localization/load_places.dart';
import 'package:ketamiz/src/ui/auth/login_screen.dart';
import 'package:ketamiz/src/ui/language/language_selection_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/push_service.dart';
import '../../theme/app_theme.dart';
import '../menu/main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _setLanguage();
    _loadAndNavigate();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _scaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Image.asset(
              'assets/logos/ketamiz-logo.png',
              width: 200,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadAndNavigate() async {
    await Future.wait([
      LocationData.loadPlaces(context),
      Future.delayed(const Duration(milliseconds: 2000)),
    ]);
    _nextScreen();
  }

  Future<void> _setLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('language');
    if (savedLang != null && mounted) {
      final localizationDelegate = LocalizedApp.of(context).delegate;
      await localizationDelegate.changeLocale(Locale(savedLang));
    }
  }

  Future<void> _nextScreen() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final hasLanguage = prefs.getString('language') != null;
    final isLoggedIn = !(prefs.getBool('isFirst') ?? true);

    if (!mounted) return;
    Widget destination;
    if (!hasLanguage) {
      destination = const LanguageSelectionScreen();
    } else if (isLoggedIn) {
      // Already authenticated — make sure the FCM token is registered/refreshed
      // (it may have rotated or permission may have changed since last run).
      PushNotificationService.instance.registerToken();
      destination = const MainScreen();
    } else {
      destination = const LoginScreen();
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
  }
}
