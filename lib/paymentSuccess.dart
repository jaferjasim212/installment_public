import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:installment/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'HomePage.dart';
import 'package:flutter/services.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final Uri uri;

  const PaymentSuccessScreen({super.key, required this.uri});

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  String status = 'loading'; // loading, successful, failed
  String? orderId;
  final _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _checkPaymentStatus();
  }

  Future<void> _checkPaymentStatus() async {
    try {
      debugPrint("🚀 بدء التحقق من حالة الدفع...");
      final currentUri = widget.uri;

      if (currentUri == null) {
        debugPrint("❌ currentUri = null");
        setState(() => status = 'failed');
        return;
      }

      final id = currentUri.queryParameters['order_id'];
      debugPrint("📦 order_id: $id");

      if (id == null || id.isEmpty) {
        debugPrint("❌ order_id غير موجود");
        setState(() => status = 'failed');
        return;
      }

      setState(() => orderId = id);

      final pending = await Supabase.instance.client
          .from('pending_payments')
          .select('user_id')
          .eq('order_id', id)
          .maybeSingle();

      debugPrint("📥 نتيجة pending_payments: $pending");

      if (pending == null || pending['user_id'] == null) {
        debugPrint("❌ لا يوجد user_id لهذا order_id");
        setState(() => status = 'failed');
        return;
      }

      final userId = pending['user_id'];
      debugPrint("✅ user_id: $userId");

      for (int attempt = 1; attempt <= 15; attempt++) {
        debugPrint("🔁 محاولة $attempt للتحقق من حالة الدفع...");

        final payment = await Supabase.instance.client
            .from('subscription_payments')
            .select('status, order_id')
            .eq('user_id', userId)
            .eq('order_id', id)
            .limit(1)
            .maybeSingle();

        if (payment != null && payment['status'] == 'successful') {
          debugPrint("✅ حالة الدفع ناجحة");
          setState(() => status = 'successful');
          await _playSuccessSound();
          return;
        }

        await Future.delayed(const Duration(seconds: 2)); // ⏳ 2 ثانية انتظار
      }
      debugPrint("❌ لم يتم العثور على دفعة ناجحة بعد كل المحاولات");
      setState(() => status = 'failed');
    } catch (e) {
      debugPrint("❌ خطأ أثناء التحقق من حالة الدفع: $e");
      setState(() => status = 'failed');
    }
  }


  Future<void> _playSuccessSound() async {
    try {
      await _audioPlayer.play(AssetSource('Sound/scsesssave.wav'));
    } catch (e) {
      debugPrint("❌ فشل تشغيل الصوت: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    Widget mainContent;

    if (status == 'loading') {
      mainContent = Lottie.asset(
        'assets/Animation/Animationloading.json',
        width: 400,
        height: 400,
        repeat: true,
      );
    } else if (status == 'successful') {
      mainContent = Stack(
        alignment: Alignment.center,
        children: [
          Lottie.asset(
            'assets/Animation/Animationcelebration.json',
            repeat: false,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 600,
                height: 400,
                child: Lottie.asset(
                  'assets/Animation/Animationsuccessful.json',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "تم الدفع بنجاح.. نتمنى لك تجربة رائعة 🎉",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      );
    } else {
      mainContent = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/Animation/Animationfailed.json',
            width: 200,
          ),
          const SizedBox(height: 16),
          const Text(
            "فشلت عملية الدفع لأسباب غير معروفة.\nيرجى التواصل مع الدعم إذا كنت تحتاج المساعدة.",
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: mainContent),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomePage()),
                  (Route<dynamic> route) => false,
            );
          },
          child: const Text(
            "العودة إلى الصفحة الرئيسية",
            style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}