import 'dart:convert';
import 'dart:typed_data';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:installment/Customer/EditeProfiledateCustomer.dart';
import 'package:installment/TypeAccount.dart';
import 'package:installment/aboutus.dart';
import 'package:lottie/lottie.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../DelegatesMonybaky.dart';
import '../EditeProfiledate.dart';

import 'package:crypto/crypto.dart';

import '../newsCustomer.dart';

class ProfileSetteng_Customr extends StatefulWidget {
  const ProfileSetteng_Customr({super.key});

  @override
  _ProfileSetteng_CustomrState createState() => _ProfileSetteng_CustomrState();
}

class _ProfileSetteng_CustomrState extends State<ProfileSetteng_Customr> {
  Uint8List? _profileImageBytes;
  final ImagePicker _picker = ImagePicker();
  String userName = '';
  String phoneNumber = '';
  bool _isRotating = false;
  double _rotationAngle = 0.0;
  final List<IconData> _arrows = [
    Icons.arrow_upward,
    Icons.arrow_forward,
    Icons.arrow_downward,
    Icons.arrow_back,
  ];
  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }
  void _toggleRotation() {
    setState(() {
      _isRotating = !_isRotating;
      _rotationAngle = _isRotating ? 1 : 0;
    });


  }

// وفي الـ GestureDetector:

  Future<void> _loadUserProfile() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('CustomerUserID');
    print("⚠️ خطأ أثناء جلب بيانات المستخدم: $userId");
    if (userId != null) {
      // تحقق مما إذا كانت البيانات مخزنة في الذاكرة المحلية
      String? cachedProfile = prefs.getString('cachedProfile');

      if (cachedProfile != null) {
        // إذا كانت البيانات مخزنة، استخدمها
        Map<String, dynamic> profileData = jsonDecode(cachedProfile);
        setState(() {
          userName = profileData['display_name'];
          phoneNumber = profileData['phone'];
          _profileImageBytes = profileData['profile_image_base64'] != null
              ? base64Decode(profileData['profile_image_base64'])
              : null;
        });
      }

      try {
        // جلب البيانات من قاعدة البيانات
        final response = await Supabase.instance.client
            .from('Customer_full_profile')
            .select('display_name, phone, profile_image_base64')
            .eq('id', userId.toString())
            .single();

        // ignore: unnecessary_null_comparison
        if (response != null) {
          setState(() {
            userName = response['display_name'];
            phoneNumber = response['phone'];
            _profileImageBytes = response['profile_image_base64'] != null
                ? base64Decode(response['profile_image_base64'])
                : null;
          });

          // تخزين البيانات في الذاكرة المحلية
          prefs.setString(
              'cachedProfile',
              jsonEncode({
                'display_name': userName,
                'phone': phoneNumber,
                'profile_image_base64': _profileImageBytes != null
                    ? base64Encode(_profileImageBytes!)
                    : null,
              }));
        }
      } catch (e) {
        print("⚠️ خطأ أثناء جلب بيانات المستخدم: $e");
        // إذا فشل الاتصال بقاعدة البيانات، استخدم البيانات المخزنة
        if (cachedProfile == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("لا يوجد اتصال بالإنترنت")),
          );
        }
      }
    }
  }

  Future<void> _changeProfilePicture() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('CustomerUserID');

      if (userId != null) {
        try {
          await Supabase.instance.client
              .from('Customer_full_profile')
              .update({'profile_image_base64': base64Encode(bytes)}).eq(
              'id', userId);

          setState(() {
            _profileImageBytes = bytes;
          });

          // تحديث البيانات في الذاكرة المحلية
          prefs.setString(
              'cachedProfile',
              jsonEncode({
                'display_name': userName,
                'phone': phoneNumber,
                'profile_image_base64': base64Encode(bytes),
              }));
        } catch (e) {
          print("⚠️ خطأ أثناء تحديث صورة الملف الشخصي: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("لا يوجد اتصال بالإنترنت")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl, // 👈 من اليسار إلى اليمين
      child: Scaffold(

        body: SingleChildScrollView(
          child: Column(

            children: [

              _buildProfileHeader(),
              const SizedBox(height: 10),
              _buildSettingsOption("تغيير معلومات الحساب",
                  "تغيير رمز الحساب والمعلومات الشخصية", Icons.edit),

              _buildSettingsOption("الشكوى والاقتراحات", "", Icons.mail),
              _buildSettingsOption("عن التطبيق", "", Icons.info),
              const SizedBox(height: 30),
              _buildLogoutOption("تسجيل خروج", Icons.logout, Colors.red),
              _buildLogoutOption("تبديل الى حساب التاجر", Icons.swap_horiz, Colors.red),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _changeProfilePicture,
            child: CircleAvatar(
              radius: 40,
              backgroundImage: _profileImageBytes != null
                  ? MemoryImage(_profileImageBytes!)
                  : const AssetImage('assets/images/profile.png')
              as ImageProvider,
              backgroundColor: Colors.grey[200],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName.isNotEmpty ? userName : "",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  phoneNumber.isNotEmpty ? phoneNumber : "",
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          // زر التحويل مع الحركة
        ],
      ),
    );
  }


  Widget _buildSettingsOption(String title, String subtitle, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.teal),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        subtitle: subtitle.isNotEmpty
            ? Text(subtitle, style: TextStyle(color: Colors.grey[600]))
            : null,
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey,
          size: 15,
        ),
        onTap: () {
          if (title == "تغيير معلومات الحساب") {
            _showPasswordVerificationDialog(context, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EditProfileDataCustomer()),
              );
            });
          }
          if (title == "الشكوى والاقتراحات") {
            _showFeedbackDialog(context, Colors.teal); // أو أي لون تريده
          }
          if (title == "عن التطبيق") {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => AboutUsPage()),
            );
          }

          // يمكنك إضافة المزيد من الحالات هنا إذا لزم الأمر
        },
      ),
    );
  }

  Widget _buildLogoutOption(String title, IconData icon, Color iconColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: iconColor),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
        onTap: () async {
          if (title == "تسجيل خروج") {
            SharedPreferences prefs = await SharedPreferences.getInstance();

            await OneSignal.logout(); // ← تسجيل الخروج من OneSignal
            await prefs.clear();      // ← مسح بيانات المستخدم

            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const TypeAccount()),
                  (Route<dynamic> route) => false,
            );
          }
    else if (title == "تبديل الى حساب التاجر") {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    await OneSignal.logout(); // ← تسجيل الخروج من OneSignal
    await prefs.clear();      // ← مسح بيانات المستخدم

    Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (context) => const TypeAccount()),
    (Route<dynamic> route) => false,
    );
    }
        },
      ),
    );
  }

}


void _showFeedbackDialog(BuildContext context, Color mainColor) {
  String selectedType = 'شكوى';
  TextEditingController contentController = TextEditingController();
  List<Map<String, dynamic>> previousFeedback = [];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 24,
        ),
        child: StatefulBuilder(
          builder: (context, setState) {
            if (previousFeedback.isEmpty) {
              SharedPreferences.getInstance().then((prefs) async {
                final customerId = prefs.getString('CustomerID');
                if (customerId != null) {
                  final data = await Supabase.instance.client
                      .from('customer_feedback')
                      .select()
                      .eq('customer_id', customerId)
                      .order('created_at', ascending: false);
                  setState(() {
                    previousFeedback = List<Map<String, dynamic>>.from(data);
                  });
                }
              });
            }

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('الشكوى والاقتراحات',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: mainColor)),
                  const SizedBox(height: 12),
                  ToggleButtons(
                    isSelected: [selectedType == 'شكوى', selectedType == 'مقترح'],
                    onPressed: (index) {
                      setState(() {
                        selectedType = index == 0 ? 'شكوى' : 'مقترح';
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    selectedColor: Colors.white,
                    fillColor: mainColor,
                    children: const [
                      Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('شكوى')),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('مقترح')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: contentController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'اكتب هنا...',
                      labelStyle: const TextStyle(color: Colors.black),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (previousFeedback.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('السجل السابق:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        ...previousFeedback.map((entry) {
                          final isGood = entry['isgood'];
                          String statusText;
                          Color statusColor;

                          if (isGood == null) {
                            statusText = 'قيد الانتظار ⏳';
                            statusColor = Colors.orange;
                          } else if (isGood == true) {
                            statusText = 'تم القبول ✅';
                            statusColor = Colors.green;
                          } else {
                            statusText = 'تم الرفض ❌';
                            statusColor = Colors.red;
                          }
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // أيقونة النوع
                                    Container(
                                      margin: const EdgeInsets.all(12),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: entry['type'] == 'شكوى' ? Colors.red[50] : Colors.blue[50],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        entry['type'] == 'شكوى' ? Icons.report : Icons.lightbulb,
                                        color: entry['type'] == 'شكوى' ? Colors.red : Colors.blue,
                                        size: 24,
                                      ),
                                    ),
                                    // المحتوى
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(entry['type'],
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                )),
                                            const SizedBox(height: 4),
                                            Text(entry['content'], style: const TextStyle(fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // الحالة على الحافة اليسرى
                                Positioned(
                                  left: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.only(
                                        bottomRight: Radius.circular(12),
                                        topLeft: Radius.circular(12),

                                      ),
                                      border: Border.all(color: statusColor),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        ),
                      ],
                    )
                  else
                    const Text('لا توجد شكاوى أو اقتراحات سابقة.'),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),

                        icon: const Icon(Icons.close,color: Colors.white,),
                        label: const Text('إغلاق',style: TextStyle(fontWeight: FontWeight.bold,color: Colors.white,fontSize: 16),),

                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final content = contentController.text.trim();
                          if (content.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('يرجى كتابة محتوى الشكوى أو المقترح')),
                            );
                            return;
                          }

                          final prefs = await SharedPreferences.getInstance();
                          final customerId = prefs.getString('CustomerID');
                          if (customerId == null) return;

                          await Supabase.instance.client.from('customer_feedback').insert({
                            'customer_id': customerId,
                            'type': selectedType,
                            'content': content,

                          });

                          Navigator.pop(context); // إغلاق نافذة الشكوى
                          _showPayDialog(context);
                        },
                        icon: const Icon(Icons.send,color: Colors.white,),
                        label: const Text('إرسال',style: TextStyle(fontWeight: FontWeight.bold,color: Colors.white,fontSize: 16),),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}
void _showPayDialog(BuildContext context) {
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
                'assets/Animation/Animationsupport2.json',
                height: 120,
                repeat: false,
              ),
              const SizedBox(height: 12),
              const Text(
                'تم تقديم طلبك بنجاح ..',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'شكراً لك على تقديم المساعدة.. تابع حالة الطلب الخاص بك في حالة تم قبوله أو رفضه. قد يستغرق ذلك حتى 72 ساعة في الوضع الطبيعي.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCF274F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'إغلاق',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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

void _showPasswordVerificationDialog(BuildContext context, VoidCallback onVerified) {
  TextEditingController passwordController = TextEditingController();
  bool isChecking = false;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return ZoomIn(
            duration: const Duration(milliseconds: 600),
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.asset('assets/Animation/Animationpassword.json', height: 100),
                  const Text('أدخل كلمة مرور حسابك لتعديل بيانات الحساب'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),

                  TextButton(
                    onPressed: () async {
                      launchCustomUrl('https://wa.me/7739090603');
                    },
                    child: const Text(
                      'نسيت كلمة المرور؟',
                      style: TextStyle(
                        color: Colors.teal,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      isChecking
                          ? CircularProgressIndicator()
                          : ElevatedButton.icon(
                        icon: Icon(Icons.security),
                        label: Text('تحقق', style: TextStyle(color: Colors.white, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          setState(() => isChecking = true);

                          final prefs = await SharedPreferences.getInstance();
                          final userId = prefs.getString('CustomerUserID');
                          if (userId == null) return;

                          final password = passwordController.text.trim();
                          final digest = sha256.convert(utf8.encode(password)).toString();

                          final user = await Supabase.instance.client
                              .from('Customer_full_profile')
                              .select()
                              .eq('id', userId)
                              .eq('password_hash', digest)
                              .maybeSingle();

                          setState(() => isChecking = false);

                          if (user != null) {
                            Navigator.of(context).pop(); // إغلاق نافذة التحقق
                            onVerified(); // تنفيذ العملية
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('كلمة المرور غير صحيحة')),
                            );
                          }
                        },
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('إلغاء', style: TextStyle(color: Colors.white, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFCF274F),
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
          );
        },
      );
    },
  );
}
Future<void> launchCustomUrl(String urlString) async {
  final Uri url = Uri.parse(urlString); // تحويل النص إلى Uri
  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
    throw 'Could not launch $urlString';
  }
}
