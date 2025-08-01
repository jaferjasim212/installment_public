import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'PaymentRedirectPage.dart';

class SubscriptionPage extends StatelessWidget {
  const SubscriptionPage({super.key});


  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        backgroundColor: Colors.teal,
        duration: const Duration(seconds: 4),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FadeInLeft(
          child: const Text(
            "خطط الاشتراك",
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

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // الاشتراك السنوي
            _buildPlanCard(
              context,
              title: "الاشتراك السنوي",
              price: "75,000 د.ع",
              period: "/ سنة",
              oldPrice: "90,000 د.ع",
              description: [
                "كل ميزات الاشتراك الشهري",
                "دعم فني مميز 24/7",
                "ذاكرة تخزين غير محدودة",
                "ارسال اشعارات غير محدودة",
              ],
              features: [true, true, true],
              color: const Color(0xFFFF8F00),
              isPopular: true,
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                final userId = prefs.getString('UserID');

                if (userId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PaymentRedirectPage(
                        amount: 75000, // بالدينار العراقي
                        userId: userId,
                      ),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 20),

            // الاشتراك الشهري
            _buildPlanCard(
              context,
              title: "الاشتراك الشهري",
              price: "10,000 د.ع",
              period: "/ شهر",
              oldPrice: "15,000 د.ع",
              description: [
                "إدارة غير محدودة للأقساط",
                "إرسال إشعارات تلقائية",
                "عدد مندوبين غير محدود",
                "مجموعات غير محدودة",
                "رسالة واتس اب مخصصة",
                "تعديل بيانات الوصل قبل الطباعة",
                "ذاكرة تخزين محدودة",
                "ارسال اشعارات محدودة",
              ],
              features: [true, true, true],
              color: const Color(0xFF009688),
              isPopular: false,
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                final userId = prefs.getString('UserID');

                if (userId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PaymentRedirectPage(
                        amount: 10000, // بالدينار العراقي
                        userId: userId,
                      ),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 20),

            // الاشتراك اليومي
            _buildPlanCard(
              context,
              title: "الاشتراك اليومي",
              price: "0 د.ع",
              period: "/ يوم واحد",
              oldPrice: "2,000 د.ع",
              description: [
                "استخدام التطبيق لمدة 24 ساعة",
                "كل ميزات الاشتراك الشهري",
              ],
              features: [true, true, true],
              color: const  Color(0xFF4A6B8A),
              isPopular: false,
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                final userId = prefs.getString('UserID');
                if (userId == null) return;

                final now = DateTime.now();
                final startOfMonth = DateTime(now.year, now.month, 1);

                // 1. تحقق إذا استخدم اليوم المجاني خلال هذا الشهر
                final existingFreeTrial = await Supabase.instance.client
                    .from('subscription_payments')
                    .select()
                    .eq('user_id', userId)
                    .eq('payment_method', 'Free Trial')
                    .gte('paid_at', startOfMonth.toIso8601String());

                if (existingFreeTrial.isNotEmpty) {
                  _showMessage(context, '❌ لقد استخدمت اليوم المجاني لهذا الشهر مسبقًا.');
                  return;
                }

                // 2. تحقق من الاشتراك الحالي
                final sub = await Supabase.instance.client
                    .from('subscriptions')
                    .select()
                    .eq('user_id', userId)
                    .order('end_date', ascending: false)
                    .maybeSingle();

                final isExpired = sub == null || sub['end_date'] == null
                    || DateTime.tryParse(sub['end_date'])!.isBefore(now);

                if (!isExpired) {
                  _showMessage(context, '✅ لا يمكنك استخدام اليوم المجاني الآن لأن اشتراكك لا يزال فعالاً.');
                  return;
                }

                // 3. إدخال سجل الدفع المجاني
                final insertPayment = await Supabase.instance.client
                    .from('subscription_payments')
                    .insert({
                  'user_id': userId,
                  'subscription_type': 'daily',
                  'amount_paid': 0,
                  'payment_method': 'Free Trial',
                  'status': 'successful',
                  'paid_at': now.toIso8601String(),
                })
                    .select()
                    .maybeSingle();

                if (insertPayment == null) {
                  _showMessage(context, '❌ فشل حفظ بيانات اليوم المجاني.');
                  return;
                }

                final paymentId = insertPayment['id'];
                final newStart = now;
                final newEnd = now.add(const Duration(days: 1));

                if (sub == null) {
                  // 4A. لا يوجد اشتراك سابق → إنشاء اشتراك جديد
                  await Supabase.instance.client
                      .from('subscriptions')
                      .insert({
                    'user_id': userId,
                    'start_date': newStart.toIso8601String(),
                    'end_date': newEnd.toIso8601String(),
                    'type': 'daily',
                    'is_active': true,
                    'payment_id': paymentId,
                  });
                } else {
                  // 4B. يوجد اشتراك سابق منتهي → تحديثه
                  await Supabase.instance.client
                      .from('subscriptions')
                      .update({
                    'start_date': newStart.toIso8601String(),
                    'end_date': newEnd.toIso8601String(),
                    'type': 'daily',
                    'is_active': true,
                    'payment_id': paymentId,
                  })
                      .eq('user_id', userId);
                }

                _showMessage(context, '✅ تم تفعيل اليوم المجاني بنجاح حتى ${newEnd.toLocal().toString().split(' ')[0]}');
              },
            ),

            const SizedBox(height: 20),

            // الأسئلة الشائعة
            FadeInUp(
              delay: const Duration(milliseconds: 1000),
              child: ExpansionTile(
                initiallyExpanded: false,
                collapsedBackgroundColor: Colors.white.withOpacity(0.7),
                backgroundColor: Colors.white,
                title: const Text(
                  "الأسئلة الشائعة",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                children: [
                  _buildFAQItem(
                    "هل يمكنني الترقية من الشهري إلى السنوي؟",
                    "نعم، يمكنك الترقية في أي وقت وسيتم اضافة المدة المتبقية من اشتراكك الحالي الى الاشتراك القادم.",
                  ),
                  _buildFAQItem(
                    "هل يوجد ضمان استرداد الأموال؟",
                    "نحن نقدم خطة مجانية لمدة 14 يوم يمكنك في هذه الفترة استخدام جميع مميزات التطبيق لمعرفة هل هو مناسب لعملك ام لا .. لذلك لا يوجد ضمان استرداد الاموال في الوقت الحالي لكن اذا صادفتك مشكله تواصل مع فريق الدعم.",
                  ),
                  _buildFAQItem(
                    "كيف يمكنني إلغاء الاشتراك؟",
                    "عند ترك التطبيق سيتم اللغاء اشتراكك بشكل تلقائي ولا يوجد تجديد اشتراك بشكل تلقائي الا بشكل يدوي .",
                  ),
                  _buildFAQItem(
                    "هل بياناتي محفوظة وآمنة؟",
                    "نعم، نحن تحاول جاهدين على جعل بياناتك غير مصرح بالوصول لها بأستخدام أحدث تقنيات الأمان لحماية البيانات، بما في ذلك التشفير والتخزين الآمن على خوادم موثوقة. اذ لا يمكن لأي جهة خارجية الوصول إلى بياناتك دون إذنك.",
                  ),
                  _buildFAQItem(
                    "ماذا يحدث لبياناتي بعد انتهاء الاشتراك؟",
                    "تبقى بياناتك محفوظة في قاعدة البيانات لفترة 3 سنوات بعد انتهاء الاشتراك، ويمكنك استعادتها في حال قمت بالتجديد. بعد مرور الفترة بدون تجديد، قد يتم حذف البيانات تلقائيًا مع إرسال تنبيه مسبق لك.",
                  ),
                  _buildFAQItem(
                    "هل يمكنني استخدام الاشتراك على أكثر من جهاز؟",
                    "نعم، يمكنك استخدام اشتراكك على أكثر من جهاز طالما أنك تستخدم نفس الحساب . ولا يُسمح باستخدام الاشتراك على أكثر من جهاز من قِبل أشخاص مختلفين.",
                  ),
                  _buildFAQItem(
                    "هل التطبيق يعمل بدون إنترنت؟",
                    "يحتاج التطبيق إلى الاتصال بالإنترنت لعمل جميع الوضائف بشكل صحيح.",
                  ),
                  _buildFAQItem(
                    "هل توجد خصومات أو عروض خاصة؟",
                    "نعم، نقدم خصومات موسمية وعروضًا حصرية من وقت لآخر. تأكد من تفعيل الإشعارات لدينا حتى لا تفوتك أي فرصة!",
                  ),
                  _buildFAQItem(
                    "هل يمكنني نقل الاشتراك إلى حساب آخر؟",
                    "لأسباب أمنية، لا يمكن نقل الاشتراك إلى حساب آخر بشكل مباشر. لكن يمكنك التواصل مع الدعم الفني إذا كانت هناك حالة خاصة وسنقوم بمساعدتك.",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

          ],
        ),
      ),
    );
  }
  Widget _buildPlanCard(
      BuildContext context, {
        required String title,
        required String price,
        required String period,
        required String oldPrice,
        required List<String> description,
        required List<bool> features,
        required Color color,
        required bool isPopular,
        required VoidCallback onTap,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
              Colors.white,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (isPopular)
              Positioned(
                top: -10,
                right: -10,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(

                  ),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: color),
                    ),
                    if (isPopular)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "موصى به",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: color),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      period,
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600]),
                    ),
                    const Spacer(),
                    Text(
                      oldPrice,
                      style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                          decoration: TextDecoration.lineThrough),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                ...description.map((feature) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: color,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feature,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      elevation: 5,
                      shadowColor: color.withOpacity(0.4),
                    ),
                    child: const Text(
                      "اشترك الآن",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String feature, String monthly, String yearly) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              feature,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              monthly,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF009688)),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              yearly,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF8F00)),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14),
          ),
          const SizedBox(height: 5),
          Text(
            answer,
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700]),
          ),
          const Divider(height: 20),
        ],
      ),
    );
  }


}