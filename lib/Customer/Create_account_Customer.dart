import 'dart:math';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import '../Login_page.dart'; // تأكد من أن المسار صحيح
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

import 'Login_page_Customer.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: EmailSignUpStepcust(),
  ));
}

class EmailSignUpStepcust extends StatefulWidget {
  const EmailSignUpStepcust({super.key});

  @override
  State<EmailSignUpStepcust> createState() => _EmailSignUpStepcust();
}

class _EmailSignUpStepcust extends State<EmailSignUpStepcust> {
  final supabase = Supabase.instance.client;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  String? errorMessage;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool loading = false;

  /// ✅ التحقق من صحة صيغة البريد الإلكتروني
  bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  Future<void> _signUpWithEmail() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirm = confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() {
        errorMessage = "جميع الحقول مطلوبة";
        loading = false;
      });
      return;
    }

    if (!isValidEmail(email)) {
      setState(() {
        errorMessage = "يرجى إدخال بريد إلكتروني صحيح";
        loading = false;
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        errorMessage = "كلمة المرور يجب أن تكون 6 أحرف على الأقل";
        loading = false;
      });
      return;
    }

    if (password != confirm) {
      setState(() {
        errorMessage = "كلمة المرور غير متطابقة";
        loading = false;
      });
      return;
    }

    try {
      // 🔍 التحقق من وجود البريد في جدول Customer_full_profile
      final customerEmail = await supabase
          .from('Customer_full_profile')
          .select('email')
          .eq('email', email)
          .maybeSingle();

      // 🔍 التحقق من وجود البريد في جدول users_full_profile
      final userEmail = await supabase
          .from('users_full_profile')
          .select('email')
          .eq('email', email)
          .maybeSingle();

      if (customerEmail != null || userEmail != null) {
        setState(() {
          errorMessage = "البريد الإلكتروني مستخدم مسبقًا من قبل عميل أو تاجر.";
          loading = false;
        });
        return;
      }

      // ✅ البريد غير موجود → نكمل إلى صفحة تعبئة البيانات
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateAccountStep1(
            email: email,
            password: password,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        errorMessage = "حدث خطأ أثناء التحقق من البريد.";
      });
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: BackButton(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text(" أدخل بريدك الإلكتروني", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: "البريد الإلكتروني",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: "كلمة المرور",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => obscurePassword = !obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: confirmPasswordController,
                obscureText: obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: "تأكيد كلمة المرور",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  suffixIcon: IconButton(
                    icon: Icon(obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => obscureConfirmPassword = !obscureConfirmPassword),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (errorMessage != null)
                Text(errorMessage!, style: const TextStyle(color: Colors.red)),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: loading ? null : _signUpWithEmail,
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("إنشاء الحساب", style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}



class CreateAccountStep1 extends StatelessWidget {
  final String email;
  final String password;

  const CreateAccountStep1({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  Widget build(BuildContext context) {
    final TextEditingController nameController = TextEditingController();

    return Directionality(
      textDirection:
      TextDirection.rtl, // لجعل الصفحة بالكامل من اليسار إلى اليمين
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        backgroundColor: Colors.white, // تعيين الخلفية إلى اللون الأبيض
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "ما هو اسمك ؟",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'الاسم بالكامل',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade800, // تحديد لون الزر
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  if (nameController.text.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => NumberInputScreen(
                            email: email,
                            password: password,
                            ownerName: nameController.text,
                          )), // الانتقال للخطوة التالية
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("لا يمكن ترك الاسم فارغ !!"),
                      backgroundColor: Colors.red,
                    ));
                  }
                },
                child: const Center(
                  child: Text(
                    "الخطوة التالية",
                    style: TextStyle(
                        fontSize: 18,
                        color: Color.fromARGB(255, 255, 255, 255)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NumberInputScreen extends StatefulWidget {
  final String ownerName;
  final String email;
  final String password;

  const NumberInputScreen({super.key,
    required this.ownerName,
    required this.email,
    required this.password,
  });

  @override
  _NumberInputScreenState createState() => _NumberInputScreenState();
}

class _NumberInputScreenState extends State<NumberInputScreen> {
  bool isPhoneValid = false;
  String? phoneNumber;
  final ScrollController _scrollController = ScrollController();
  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _checkPhoneNumber() async {
    try {
      // 🔍 تحقق في جدول العملاء
      final customerPhone = await supabase
          .from('Customer_full_profile')
          .select('phone')
          .eq('phone', phoneNumber!)
          .maybeSingle();

      // 🔍 تحقق في جدول التجار
      final userPhone = await supabase
          .from('users_full_profile')
          .select('phone')
          .eq('phone', phoneNumber!)
          .maybeSingle();

      if (customerPhone != null || userPhone != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('رقم الهاتف مستخدم مسبقًا من قبل عميل أو تاجر!'),
          backgroundColor: Colors.red,
        ));
        return;
      }

      // ✅ الرقم غير موجود → ننتقل للخطوة التالية
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LocationStep(
            ownerName: widget.ownerName,
            phoneNumber: phoneNumber!,
            email: widget.email,
            password: widget.password,
          ),
        ),
      );
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('خطأ في الاتصال بالخادم: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    var screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'قم بإدخال رقم الهاتف ',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.ltr,
             child:  IntlPhoneField(
                decoration: InputDecoration(
                  labelStyle: const TextStyle(fontSize: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                initialCountryCode: 'IQ',
                onTap: _scrollToBottom,
                onChanged: (phone) {
                  setState(() {
                    phoneNumber = phone.completeNumber;
                    isPhoneValid = phone.number.length == 10;
                  });
                },
                style: const TextStyle(fontSize: 16),
              ),
          ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isPhoneValid ? _checkPhoneNumber : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPhoneValid
                      ? Colors.teal.shade800
                      : Colors.grey.shade400,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'التحقق من رقم الهاتف',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class LocationStep extends StatefulWidget {
  final String ownerName;
  final String phoneNumber;
  final String email;
  final String password;

  const LocationStep({
    super.key,
    required this.ownerName,
    required this.phoneNumber,
    required this.email,
    required this.password,
  });

  @override
  _LocationStepState createState() => _LocationStepState();
}

class _LocationStepState extends State<LocationStep> {
  String? selectedCity;
  String? selectedDistrict;
  String? selectedGander;

  final List<String> Gander = ['ذكر', 'انثى'];

  final List<String> cities = [
    'بغداد', 'البصرة', 'نينوى', 'أربيل', 'كربلاء', 'النجف', 'السليمانية',
    'كركوك', 'دهوك', 'الأنبار', 'ديالى', 'واسط', 'ميسان', 'بابل', 'ذي قار',
    'صلاح الدين', 'المثنى', 'القادسية', 'حلبجة'
  ];

  final Map<String, List<String>> districts = {
    'بغداد': ['الرصافة', 'الكرخ', 'الأعظمية', 'الكرادة', 'المنصور', 'مدينة الصدر', 'الشعلة', 'الغزالية', 'الزعفرانية', 'اليرموك', 'الحسينية', 'الحرية', 'بغداد الجديدة', 'المدائن', 'الطارمية', 'أبو غريب', 'الكاظمية', 'المحمودية', 'الزوراء', 'الشعب', 'الصدر الأول', 'الصدر الثاني', 'أخرى'],
    'البصرة': ['البصرة', 'الهارثة', 'أبو الخصيب', 'الزبير', 'القرنة', 'الفاو', 'شط العرب', 'المدينة', 'سفوان', 'الدير', 'أخرى'],
    'نينوى': ['الموصل', 'الحمدانية', 'تلكيف', 'سنجار', 'تلعفر', 'الحضر', 'البعاج', 'مخمور', 'أخرى'],
    'أربيل': ['أربيل', 'بنصلاوة', 'سوران', 'شقلاوة', 'جومان', 'كويسنجق', 'ميركسور', 'خبات', 'مخمور', 'ريف أربيل', 'أخرى'],
    'كربلاء': ['كربلاء', 'عين تمر', 'الهندية', 'الحر', 'الحسينية', 'أخرى'],
    'النجف': ['النجف', 'الكوفة', 'المناذرة', 'المشخاب', 'أخرى'],
    'السليمانية': ['السليمانية', 'قره داغ', 'شهرزور', 'سيد صادق', 'حلبجة', 'بنجوين', 'رانية', 'دوكان', 'دربندخان', 'كلار', 'جمجمال', 'ماوت', 'بشدر', 'كفري', 'شاربازير', 'أخرى'],
    'كركوك': ['كركوك', 'الحويجة', 'داقوق', 'الدبس', 'أخرى'],
    'دهوك': ['دهوك', 'سميل', 'زاخو', 'العمادية', 'عقرة', 'شيخان', 'بردرش', 'أخرى'],
    'الأنبار': ['الرمادي', 'الفلوجة', 'هيت', 'حديثة', 'القائم', 'راوة', 'الرطبة', 'عانة', 'الخالدية', 'الكرمة', 'العامرية', 'أخرى'],
    'ديالى': ['بعقوبة', 'المقدادية', 'الخالص', 'خانقين', 'بلدروز', 'كفري', 'خان بني سعد', 'مندلي', 'أخرى'],
    'واسط': ['الكوت', 'الصويرة', 'الحي', 'النعمانية', 'بدرة', 'جصان', 'أخرى'],
    'ميسان': ['العمارة', 'علي الغربي', 'الميمونة', 'قلعة صالح', 'المجر الكبير', 'الكحلاء', 'أخرى'],
    'بابل': ['الحلة', 'المحاويل', 'الهاشمية', 'المسيب', 'الحمزة الغربي', 'القاسم', 'كوثى', 'الإسكندرية', 'النيل', 'الكفل', 'أخرى'],
    'ذي قار': ['الناصرية', 'الشطرة', 'الرفاعي', 'قلعة سكر', 'سوق الشيوخ', 'الإصلاح', 'الغراف', 'أخرى'],
    'صلاح الدين': ['تكريت', 'سامراء', 'بيجي', 'بلد', 'الدور', 'العلم', 'الشرقاط', 'طوز خورماتو', 'أخرى'],
    'المثنى': ['السماوة', 'الرميثة', 'الخضر', 'الوركاء', 'السلمان', 'أخرى'],
    'القادسية': ['الديوانية', 'عفك', 'الشامية', 'الحمزة', 'آل بدير', 'سومر', 'الدغارة', 'نفر', 'السنية', 'الشافعية', 'أخرى'],
    'حلبجة': ['حلبجة', 'خورمال', 'بيارا', 'سيد صادق', 'أخرى'],
  };

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: BackButton(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("اختر المحافظة", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text("بعد اختيارك للمحافظة قم بأختيار القضاء او الناحية الذي تتواجد به", style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 30),
                DropdownButtonFormField<String>(
                  value: selectedCity,
                  decoration: InputDecoration(
                    labelText: 'المحافظة',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: cities.map((city) => DropdownMenuItem<String>(
                    value: city,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(city, textDirection: TextDirection.rtl),
                    ),
                  )).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedCity = value;
                      selectedDistrict = null;
                    });
                  },
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: selectedDistrict,
                  decoration: InputDecoration(
                    labelText: 'القضاء او الناحية',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: selectedCity != null
                      ? districts[selectedCity]!.map((district) => DropdownMenuItem<String>(
                    value: district,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(district, textDirection: TextDirection.rtl),
                    ),
                  )).toList()
                      : [],
                  onChanged: (value) {
                    setState(() => selectedDistrict = value);
                  },
                ),
                const SizedBox(height: 20),
                const Text("اختر الجنس", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text("قم بأختيار الجنس بالشكل الصحيح لضمان الحصول على المميزات الكاملة", style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 30),
                DropdownButtonFormField<String>(
                  value: selectedGander,
                  decoration: InputDecoration(
                    labelText: 'الجنس',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: Gander.map((g) => DropdownMenuItem<String>(
                    value: g,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(g, textDirection: TextDirection.rtl),
                    ),
                  )).toList(),
                  onChanged: (value) => setState(() => selectedGander = value),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade800,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      if (selectedCity != null && selectedDistrict != null && selectedGander != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MapAndImageSelectionScreen(
                              ownerName: widget.ownerName,
                              phoneNumber: widget.phoneNumber,
                              password: widget.password,
                              email: widget.email,
                              selectedCity: selectedCity!,
                              selectedDistrict: selectedDistrict!,
                              selectedGander: selectedGander!,
                            ),
                          ),
                        );                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("لا يمكن ترك المحافظة او القضاء او الجنس فارغاً !!"),
                          backgroundColor: Colors.red,
                        ));
                      }
                    },
                    child: const Text("الخطوة التالية", style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class MapAndImageSelectionScreen extends StatefulWidget {
  final String ownerName; // تعريف الباراميتر
  final String phoneNumber; // إذا كنت تريد تمرير أكثر من قيمة
  final String password;
  final String selectedCity; // إذا كنت تريد تمرير أكثر من قيمة
  final String selectedDistrict; // إذا كنت تريد تمرير أكثر من قيمة
  final String selectedGander; // إذا كنت تريد تمرير أكثر من قيمة
  final String email;

  const MapAndImageSelectionScreen({
    super.key,
    required this.ownerName,
    required this.phoneNumber,
    required this.password,
    required this.selectedCity,
    required this.selectedDistrict,
    required this.selectedGander,
    required this.email,
  });

  @override
  _MapAndImageSelectionScreenState createState() =>
      _MapAndImageSelectionScreenState();
}

class _MapAndImageSelectionScreenState
    extends State<MapAndImageSelectionScreen> {
  bool _saving = false;

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  final supabase = Supabase.instance.client;

  Future<void> _submitUserData2() async {
    setState(() => _saving = true);

    try {
      print("🚀 بدء إنشاء الحساب...");

      final authResponse = await supabase.auth.signUp(
        email: widget.email,
        password: widget.password,
      );

      final user = authResponse.user;
      if (user == null) {
        throw Exception("⚠️ فشل في إنشاء حساب المستخدم.");
      }
      print("✅ تم إنشاء الحساب: user_id = ${user.id}");

      await OneSignal.login(user.id);
      print("🔔 تم تسجيل OneSignal");

      String? base64Image;
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        base64Image = base64Encode(bytes);
        print("🖼️ تم تحويل الصورة إلى base64 (${base64Image.substring(0, 20)}...)");
      } else {
        print("🖼️ لا توجد صورة مرفقة.");
      }

      String hashedPassword = sha256.convert(utf8.encode(widget.password)).toString();
      print("🔐 Hash كلمة المرور: $hashedPassword");

      // ✅ طباعة كل البيانات قبل الإضافة
      final Map<String, dynamic> insertData = {
        'id': user.id,
        'email': widget.email,
        'phone': widget.phoneNumber,
        'display_name': widget.ownerName,
        'password_hash': hashedPassword,
        'gender': widget.selectedGander,
        'city': widget.selectedCity,
        'district': widget.selectedDistrict,
        'profile_image_base64': base64Image ?? '',
        'created_at': DateTime.now().toIso8601String(),
        'onesignal_player_id': user.id,
      };

      print("📦 البيانات التي سيتم إدخالها في الجدول Customer_full_profile:");
      insertData.forEach((key, value) => print("  $key: $value"));

      // ✅ تنفيذ الإدخال
      final insertResponse = await supabase.from('Customer_full_profile').insert(insertData);
      print("✅ تم إدخال البيانات بنجاح: $insertResponse");

      _showSuccessDialog();
    } catch (e) {
      print("❌ خطأ أثناء عملية التسجيل: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("❌ حدث خطأ: $e"),
        backgroundColor: Colors.red,
      ));
    } finally {
      setState(() => _saving = false);
    }
  }




  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ZoomIn(
          duration: const Duration(seconds: 1),
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 80),
                const SizedBox(height: 20),
                const Text(
                  'تم إنشاء الحساب بنجاح',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'شكراً لك على إنشاء الحساب. نأمل لك تجربة مميزة!',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const Login_page_Customer()),
                          (Route<dynamic> route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade800,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'الانتقال إلى تسجيل الدخول',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
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

  // اختيار صورة من المعرض
  Future<void> _pickImageFromGallery() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  // التقاط صورة بالكاميرا
  Future<void> _captureImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: Column(
          children: [
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.teal.shade800,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: _selectedImage != null
                            ? Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        )
                            : const Center(
                          child: Text(
                            'لم يتم اختيار صورة شخصية',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickImageFromGallery,
                            icon: const Icon(
                              Icons.photo,
                              color: Colors.white,
                            ),
                            label: const Text(
                              "اختر صورة من المعرض",
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade800,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 15, horizontal: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _captureImage,
                            icon: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                            ),
                            label: const Text(
                              "التقط صورة",
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade800,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 15, horizontal: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
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
            ElevatedButton(
              onPressed: _saving ? null : _submitUserData2,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade800,
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
                  : const Text(
                "حفظ بيانات الحساب ",
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
