import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'Login_Page.dart';
import 'Customer/Login_page_Customer.dart';
import 'aboutus.dart';

class TypeAccount extends StatefulWidget {
  const TypeAccount({super.key});

  @override
  State<TypeAccount> createState() => _TypeAccountState();
}

class _TypeAccountState extends State<TypeAccount> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  double _xAxis = 0.0;
  double _yAxis = 0.0;
  StreamSubscription<AccelerometerEvent>? _sensorSubscription;

  @override
  void initState() {
    super.initState();

    // تهيئة الأنيميشن
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.forward();

    // الاشتراك في مستشعر الحركة
    _sensorSubscription = accelerometerEvents.listen((event) {
      setState(() {
        _xAxis = event.x.clamp(-3, 3); // تحديد قيمة قصوى للحركة
        _yAxis = event.y.clamp(-3, 3);
      });
    });
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel(); // إلغاء الاشتراك
    _animationController.dispose();
    super.dispose();
  }
  void _navigateWithTransition(Widget page) {
    _animationController.reverse().then((_) async {
      await Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 2.9, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
                child: child,
              ),
            );
          },
        ),
      );
      // بعد الرجوع من الصفحة، شغل الأنيميشن من جديد
      _animationController.forward();
    });
  }
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated Logo
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: SizedBox(
                          height: 230,
                          child: Lottie.asset(
                            'assets/Animation/Animationuser.json',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Cards with 3D tilt effect
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5.0),
                       child:  Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // العنوان العلوي
                            const Padding(
                              padding: EdgeInsets.only(top: 16.0),
                              child: Text(
                                'ابدأ باختيار نوع تسجيل الدخول ..',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            const SizedBox(height: 20),

                            GestureDetector(
                              onTap: () => _navigateWithTransition(const Login_page_Customer()),
                              child: Card(
                                color: const Color(0xFF0082FF),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                elevation: 6,
                                margin: const EdgeInsets.symmetric(horizontal: 20),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                                  child: Directionality( // 🔁 لضبط الاتجاه من اليمين
                                    textDirection: TextDirection.rtl,
                                    child: Row(
                                      children: [
                                        // الصورة على اليمين
                                        Lottie.asset(
                                          'assets/Animation/Animationemail.json',
                                          height: 60,
                                          fit: BoxFit.contain,
                                        ),
                                        const SizedBox(width: 12),

                                        // النصوص على يسار الصورة ولكن بمحاذاة يمين
                                        const Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'مستخدم عادي',
                                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'أدخل بياناتك الآن للدخول ..',
                                                style: TextStyle(color: Colors.white70, fontSize: 14),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),

                            GestureDetector(
                              onTap: () => _navigateWithTransition(const LoginPage()),
                              child: Card(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                elevation: 4,
                                margin: const EdgeInsets.symmetric(horizontal: 16),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20), // خليها نفس قيمة Card ليتطابق الشكل
                                    color: Colors.white,
                                    border: Border.all(
                                      color: Colors.blue, // لون الإطار
                                      width: 2,           // سماكة الإطار
                                    ),
                                  ),
                                  child: Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'صاحب أعمال',
                                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'انضم الآن للحصول على أفضل المميزات',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                        const SizedBox(height: 16),
                                        Center(
                                          child: Lottie.asset(
                                            'assets/Animation/Animationbullder.json',
                                            height: 160,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.error_outline, size: 28, color: Colors.black54),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AboutUsPage()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }




}