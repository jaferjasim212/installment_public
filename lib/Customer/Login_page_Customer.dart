import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:installment/Customer/Create_account_Customer.dart';
import 'package:lottie/lottie.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'Dashbord_Customer.dart';

void main() => runApp(
  const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Login_page_Customer(),
  ),
);

class Login_page_Customer extends StatefulWidget {
  const Login_page_Customer({super.key});

  @override
  _Login_page_Customer createState() => _Login_page_Customer();
}

class _Login_page_Customer extends State<Login_page_Customer> {
  bool _obscureText = true;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  void _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isCustomerLoggedIn') ?? false;
    if (isLoggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Dashbord_Customer()),
      );
    }
  }

  Future<void> _login() async {
    String input = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (input.isNotEmpty && password.isNotEmpty) {
      try {
        final supabase = Supabase.instance.client;
        SharedPreferences prefs = await SharedPreferences.getInstance();

        final isEmail = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(input);
        if (!isEmail) {
          throw Exception("يرجى إدخال بريد إلكتروني صالح");
        }

        final response = await supabase.auth.signInWithPassword(
          email: input,
          password: password,
        );

        if (response.user == null) {
          throw Exception("فشل تسجيل الدخول بالبريد الإلكتروني");
        }

        // ✅ تسجيل OneSignal
        await OneSignal.login(response.user!.id);

        final customer = await supabase
            .from('Customer_full_profile')
            .select('id')
            .eq('email', input)
            .maybeSingle();

        if (customer == null) {
          throw Exception("هذا الحساب غير مسجل كعميل.");
        }

        await prefs.setBool('isCustomerLoggedIn', true);
        await prefs.setString('CustomerUserID', response.user!.id);
        await prefs.setString('CustomerID', customer['id']);

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const Dashbord_Customer()),
              (Route<dynamic> route) => false, // يمنع الرجوع نهائياً
        );
      } catch (e) {
        print("❌ خطأ أثناء تسجيل الدخول: $e");
        _showerrorDialogdatesetting();
      }
    } else {
      _showerrorDialogdatesettingempty();
    }
  }

  void _showerrorDialogdatesetting() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ZoomIn(
          duration: const Duration(milliseconds: 700),
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/Animation/Animationerror.json',
                  height: 120,
                  repeat: false,
                ),
                const SizedBox(height: 12),
                const Text(
                  'خطأ في تسجيل الدخول ',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'تأكد من اسم المستحدم و كلمة المرور اذا كنت متأكد من البيانات ولا يمكنك تسجيل الدخول تواصل مع المبرمج!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFCF274F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      'اغلاق النافذة ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showerrorDialogdatesettingempty() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ZoomIn(
          duration: const Duration(milliseconds: 700),
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/Animation/Animationerror.json',
                  height: 120,
                  repeat: false,
                ),
                const SizedBox(height: 12),
                const Text(
                  'خطأ في تسجيل الدخول ',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'يرجى ادخال جميع الحقول المطلوبة : البريد الالكتروني و كلمة المرور',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFCF274F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      'اغلاق النافذة ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(

          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Stack(
                children: [
                  // ✅ الخلفية المتحركة تغطي كامل الجزء العلوي
                  Container(
                    height: 260, // عدّل حسب الحاجة
                    width: double.infinity,
                    child: Lottie.asset(
                      'assets/Animation/Animationbackcust.json',
                      fit: BoxFit.cover,
                    ),
                  ),

                  // ✅ النصوص في المقدمة
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 40, // يبدأ بعد شريط الحالة
                    right: 20,
                    left: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FadeInUp(
                          duration: const Duration(milliseconds: 1000),
                          child: const Text(
                            "تسجيل الدخول",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(blurRadius: 4, color: Colors.white, offset: Offset(0, 1))],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FadeInUp(
                          duration: const Duration(milliseconds: 1300),
                          child: const Text(
                            "مرحبًا بعودتك في حسابك ...",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              shadows: [Shadow(blurRadius: 2, color: Colors.white, offset: Offset(0, 1))],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Transform.translate(
                offset: const Offset(0, -40), // يصعد الجزء الأبيض ليغطي الخلفية
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      children: <Widget>[
                        const SizedBox(height: 60),
                        FadeInUp(
                          duration: const Duration(milliseconds: 1400),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color.fromRGBO(158, 158, 158, 1), // رصاصي معتدل
                                  blurRadius: 50,
                                  offset: Offset(0, 7),
                                ),
                              ],
                            ),
                            child: Directionality(
                              textDirection: TextDirection.rtl,
                              child: Column(
                                children: <Widget>[
                                  _buildTextField(
                                    hintText: "البريد الالكتروني",
                                    icon: Icons.email,
                                    controller: _phoneController,
                                  ),
                                  _buildTextField(
                                    hintText: "كلمة المرور",
                                    icon: Icons.lock,
                                    controller: _passwordController,
                                    obscureText: _obscureText,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureText
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureText = !_obscureText;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),
                        FadeInUp(
                          duration: const Duration(milliseconds: 1600),
                          child: MaterialButton(
                            onPressed: _login,
                            height: 50,
                            color: Color(0xFFD0A437),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: const Center(
                              child: Text(
                                "تسجيل الدخول",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,fontSize: 17
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 90),
                        FadeInUp(
                          duration: const Duration(milliseconds: 1700),
                          child: const Directionality(
                            textDirection: TextDirection.rtl,
                            child: Text(
                              "اذا كنت لا تمتلك حساب يمكنك انشاء حساب الان !",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: FadeInUp(
                                duration: const Duration(milliseconds: 1800),
                                child: MaterialButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const EmailSignUpStepcust(),
                                      ),
                                    );
                                  },
                                  height: 50,
                                  color: Color(0xFF6394D4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      "انشاء حساب جديد",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FadeInUp(
                                duration: const Duration(milliseconds: 1900),
                                child: MaterialButton(
                                  onPressed: () {
                                    // منطق الدعم
                                  },
                                  height: 50,
                                  color: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  child: const Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: Center(
                                      child: Text(
                                        " للدعم تواصل معنا !",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    required TextEditingController controller,
    Widget? suffixIcon,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.grey),
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: Colors.grey),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}
