import 'package:flutter/material.dart';
import 'package:installment/TypeAccount.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class ProfessionalOnboarding extends StatefulWidget {
  @override
  _ProfessionalOnboardingState createState() => _ProfessionalOnboardingState();
}

class _ProfessionalOnboardingState extends State<ProfessionalOnboarding> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  double _pageOffset = 0.0;

  final List<OnboardingItem> _pages = [
    OnboardingItem(
      title: "مرحباً بك في أقساط",
      description: "أقساط دليلك السريع لإدارة عملك، وتتبع مستحقاتك وسرعة في أداء المهام بسهولة.",
      lottieAsset: 'assets/Animation/AnimationTarget.json',
      color1: Color(0xFF2196F3),
      color2: Color(0xFF00BCD4),
    ),
    OnboardingItem(
      title: "تتبع نشاط عملائك",
      description: "راقب عملائك وتقاريرهم، وتأكد من سير عملك بالطريق الصحيح.",
      lottieAsset: 'assets/Animation/Animationteam.json',
      color1: Color(0xFF673AB7),
      color2: Color(0xFF9C27B0),
    ),
    OnboardingItem(
      title: "إدارة الأموال بسهولة",
      description: "تابع المدفوعات اليومية والشهرية وتسديدات المندوبين من أي مكان.",
      lottieAsset: 'assets/Animation/Animationwaaall.json',
      color1: Colors.white,
      color2: Colors.white,
    ),
    OnboardingItem(
      title: "تقارير مفصلة",
      description: "احصل على رؤية شاملة من خلال لوحة التحكم الخاصة بك.",
      lottieAsset: 'assets/Animation/Animationre.json',
      color1: Color(0xFF009688), // أخضر زمردي (Teal)
      color2: Color(0xFF2196F3), // أزرق سماوي (Blue)
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _pageOffset = _pageController.page!;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => TypeAccount(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: Duration(milliseconds: 1000),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // الخلفية المتدرجة المتحركة
          AnimatedContainer(
            duration: Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ColorTween(
                    begin: _pages[_currentPage].color1,
                    end: _pages[(_currentPage + 1) % _pages.length].color1,
                  ).lerp(_pageOffset - _currentPage)!,
                  ColorTween(
                    begin: _pages[_currentPage].color2,
                    end: _pages[(_currentPage + 1) % _pages.length].color2,
                  ).lerp(_pageOffset - _currentPage)!,
                ],
              ),
            ),
          ),

          // الصفحات مع تأثير التمرير السلس
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final item = _pages[index];
              final delta = (index - _pageOffset);
              final angle = delta * 0.15;

              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                alignment: delta < 0
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // الصورة المتحركة مع تأثير التمرير
                      Expanded(
                        flex: 4,
                        child: Transform.translate(
                          offset: Offset(-50 * delta, 0),
                          child: Lottie.asset(
                            item.lottieAsset,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      // العنوان مع تأثير التلاشي
                      Opacity(
                        opacity: (1 - (delta.abs() * 2)).clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(100 * delta, 0),
                          child: GradientText(
                            item.title,
                            gradient: _currentPage == 2
                                ? const LinearGradient(colors: [Colors.black, Colors.black])
                                : LinearGradient(colors: [Colors.white, Colors.white.withOpacity(0.7)]),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // الوصف مع تأثير التلاشي
                      Opacity(
                        opacity: (1 - (delta.abs() * 2)).clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(100 * delta, 0),
                          child: Text(
                            item.description,
                            style: TextStyle(
                              fontSize: 18,
                              color: _currentPage == 2
                                  ? Colors.black
                                  : Colors.white.withOpacity(0.9),
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),

                      const Spacer(flex: 1),
                    ],                  ),
                ),
              );
            },
          ),

          // نقاط التوجيه
// نقاط التوجيه (تختفي في الصفحة الأخيرة)
          if (_currentPage != _pages.length - 1)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
          // زر البدء (يظهر فقط في الصفحة الأخيرة)
          if (_currentPage == _pages.length - 1)
            Positioned(
              bottom: 40,
              left: 50,
              right: 50,
              child: ScaleTransition(
                scale: AlwaysStoppedAnimation(1.0),
                child: ElevatedButton(
                  onPressed: _completeOnboarding,
                  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.white, // بديل لـ primary
    foregroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    elevation: 5,
                    shadowColor: Colors.black.withOpacity(0.3),
                  ),
                  child: Text(
                    "ابدأ الآن",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

        ],
      ),
    );
  }
}

class OnboardingItem {
  final String title;
  final String description;
  final String lottieAsset;
  final Color color1;
  final Color color2;

  OnboardingItem({
    required this.title,
    required this.description,
    required this.lottieAsset,
    required this.color1,
    required this.color2,
  });
}

class GradientText extends StatelessWidget {
  const GradientText(
      this.text, {
        required this.gradient,
        this.style,
      });

  final String text;
  final Gradient gradient;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(text, style: style),
    );
  }
}
