import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert'; // لـ jsonEncode و jsonDecode
import 'package:http/http.dart' as http; // لـ http.post

class PaymentRedirectPage extends StatelessWidget {
  final int amount;
  final String userId;


  const PaymentRedirectPage({
    super.key,
    required this.amount,
    required this.userId,
  });


  void _openPaymentURL(int amount) async {
    try {
      // 1. جلب userId من SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userIdd = prefs.getString('UserID');
      if (userIdd == null) {
        debugPrint("❌ لم يتم العثور على userId في SharedPreferences");
        return;
      }

      final credentials = base64Encode(
        utf8.encode('--'),
      );

      // 3. تنظيف userId من الفواصل
      final cleanedUserId = userIdd.replaceAll('-', '');
      if (cleanedUserId.length < 24) {
        debugPrint("❌ userId غير صالح لإنشاء orderId: $cleanedUserId");
        return;
      }

      // 4. أخذ أول 24 خانة
      final shortId = cleanedUserId.substring(0, 24);

      // 5. توليد الوقت بصيغة HHmmss
      final now = DateTime.now();
      final timestamp = "${now.hour.toString().padLeft(2, '0')}"
          "${now.minute.toString().padLeft(2, '0')}"
          "${now.second.toString().padLeft(2, '0')}";

      // 6. دمج الـ orderId
      final orderId = "$shortId$timestamp";
      debugPrint("🆔 Generated orderId: $orderId (${orderId.length} chars)");

      // 7. حفظ orderId في جدول pending_payments
      final insertResponse = await Supabase.instance.client
          .from('pending_payments')
          .insert({
        "user_id": userIdd,
        "order_id": orderId,
        "created_at": now.toIso8601String(),
      })
          .select()
          .single();

      if (insertResponse == null || insertResponse['order_id'] == null) {
        debugPrint("❌ فشل في إدخال order_id إلى قاعدة البيانات أو لم تُرجع بيانات.");
        return;
      }

      // 8. تجهيز بيانات الطلب
      final bodyData = {
        "amount": amount,
        "currency": "IQD",
        "country": "IQ",
        "order_id": orderId,
        "redirect_url": "--",
        "webhook_url": "--",
        "transaction_type": "Retail",
        "description": "دفع رسوم اشتراك",
      };

      // 9. إرسال الطلب إلى بوابة القاصة
      final response = await http.post(
        Uri.parse("--"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $credentials',
        },
        body: jsonEncode(bodyData),
      );

      debugPrint("🔵 statusCode: ${response.statusCode}");
      debugPrint("📦 response body: ${response.body}");

      // 10. فتح صفحة الدفع إذا تم بنجاح
      if (response.statusCode == 201 || response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final token = json["token"];
        final paymentUrl = Uri.parse("https://pay.alqaseh.com/pay/$token");
        if (!await launchUrl(paymentUrl, mode: LaunchMode.externalApplication)) {
          debugPrint("❌ لا يمكن فتح الرابط");
        }
      } else {
        debugPrint("❌ فشل في إنشاء الدفع: ${response.body}");
      }

    } catch (e) {
      debugPrint("❌ خطأ أثناء إنشاء الدفع: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedAmount = intl.NumberFormat("#,##0", "en_US").format(amount);

    return Scaffold(
      appBar: AppBar(
        title: FadeInDown(
          child: const Text(
            "الدفع بأمان",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        flexibleSpace: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Lottie.asset(
                'assets/Animation/Animationapppar.json',
                fit: BoxFit.cover,
                repeat: true,
                alignment: Alignment.topCenter,
              ),
              Container(color: Colors.black.withOpacity(0.4)),
            ],
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "سياسة الأمان:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "تتم عملية الدفع من خلال بوابة دفع مشفرة وآمنة تابعة لشركة القاصة. لا نقوم بحفظ بيانات البطاقة أو تمريرها عبر تطبيقنا.",
              style: TextStyle(fontSize: 14, color: Colors.black),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // شعار القاصة
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // شعار القاصة
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          "assets/Icon/qasalogo.png",
                          height: 200,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // زر الانتقال
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openPaymentURL(amount),
                        icon: const Icon(Icons.payment, color: Colors.white),
                        label: Text(
                          "الانتقال إلى بوابة الدفع",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily, // 🔁 نفس خط التطبيق
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          elevation: 8,
                          shadowColor: Colors.teal.withOpacity(0.4),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),

            Text(
              "المبلغ المطلوب: $formattedAmount د.ع",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}