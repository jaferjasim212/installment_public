import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:installment/TypeAccount.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:app_links/app_links.dart';
import 'Customer/Dashbord_Customer.dart';
import 'DelegatesMonybaky.dart';
import 'HomePage.dart';
import 'Config.dart';
import 'OnboardingPage.dart';
import 'SplashVideoScreen.dart';
import 'PaymentSuccess.dart';
import 'dart:async';

Uri? _initialUri;
final ValueNotifier<Uri?> deepLinkNotifier = ValueNotifier(null);
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

late final AppLinks _appLinks;
StreamSubscription<Uri>? _sub;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseSecureConfig.initializeSupabase();

  await initOneSignal();

  runApp(const MyApp());
}

Future<void> initOneSignal() async {
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize("--");

  await OneSignal.Notifications.requestPermission(true);

  OneSignal.Notifications.addClickListener((event) {
    print("🔔 تم النقر على الإشعار: ${event.notification.title}");
  });
}


void _initDeepLinkListener() async {
  _appLinks = AppLinks();

  // الطريقة الجديدة لجلب الرابط الأولي
  try {
    final Uri? initialUri = await _appLinks.uriLinkStream.first;
    if (initialUri != null) {
      debugPrint('🚀 Initial deep link: $initialUri');
      deepLinkNotifier.value = initialUri;
    }
  } catch (err) {
    debugPrint('❌ Error getting initial deep link: $err');
  }

  // الاستماع لأي روابط أثناء تشغيل التطبيق
  _sub = _appLinks.uriLinkStream.listen((Uri uri) {
    debugPrint('🔗 Received deep link: $uri');
    deepLinkNotifier.value = uri;
  }, onError: (err) {
    debugPrint('❌ Deep link error: $err');
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initDeepLinkListener();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<Widget> getInitialScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

    if (!onboardingComplete) return ProfessionalOnboarding();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final isDelegate = prefs.getBool('isDelegate') ?? false;
    final isCustomerLoggedIn = prefs.getBool('isCustomerLoggedIn') ?? false;

    if (isCustomerLoggedIn) return const Dashbord_Customer();
    if (isDelegate) return const DelegatesMonybaky();
    if (isLoggedIn) return const HomePage();

    return const TypeAccount();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Uri?>(
      valueListenable: deepLinkNotifier,
      builder: (context, uri, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            fontFamily: 'Tajawal',
            primarySwatch: Colors.teal,
          ),
          home: SplashVideoScreen(
            nextScreen: getInitialScreen(),
          ),

          /// ✅ هذا هو مكان builder الصحيح:
          builder: (context, child) {
            if (uri != null &&
                uri.scheme == 'aksatpay' &&
                uri.host == 'payment_success') {
              Future.microtask(() {
                navigatorKey.currentState?.push(MaterialPageRoute(
                  builder: (_) => PaymentSuccessScreen(uri: uri),
                ));
                deepLinkNotifier.value = null;
              });
            }
            return child!;
          },
        );
      },
    );
  }
}