import 'package:flutter/material.dart';
import 'package:installment/utils/connection_watcher.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'Customars.dart'; // استيراد صفحة الإعدادات الشخصية
import 'Mony_baky.dart';
import 'Mony_tasded.dart';
import 'Dashbord.dart';
import 'NoInternetScreen.dart';
import 'OtherForm.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'SubscriptionPage.dart';
import 'UpdateState.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {


  int currentTab = 0;
  final PageStorageBucket bucket = PageStorageBucket();

  final List<Widget> screens = [
    const Dashbord(),
    const Mony_baky(),
    const MonyTasded(),
    const Customars(),
    const Otherform(),
  ];

  final List<Map<String, dynamic>> _navItems = [
    {'icon': Icons.home, 'label': 'الرئيسية'},
    {'icon': Icons.attach_money, 'label': 'الأقساط'},
    {'icon': Icons.shopping_cart_checkout, 'label': 'التسديدات'},
    {'icon': Icons.person, 'label': 'الحسابات'},
    {'icon': Icons.open_in_new, 'label': 'أخرى'},
  ];

  Widget currentScreen = const Dashbord();

  void _onTabSelected(int index) {
    setState(() {
      currentTab = index;
      currentScreen = screens[index];
    });
  }
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      checkAndShowUpdate(context);
      await NoInternetScreen.checkConnectionAndShow(context);
      await checkSubscriptionStatus(context); // ✅ هنا يتم فحص الاشتراك
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkAndShowUpdate(context);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NoInternetScreen.checkConnectionAndShow(context);
    });

    Future.delayed(Duration.zero, () {
      ConnectionWatcher.startMonitoring(context);
    });
  }
  static Future<void> checkAndShowUpdate(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version;
print(currentVersion);
    final response = await Supabase.instance.client
        .from('app_updates')
        .select()
        .eq('platform', 'android')
        .maybeSingle();

    final latestVersion = response?['latest_version'];
    final changelog = response?['changelog'] ?? '';
    final updateUrl = response?['play_store_url'];

    if (latestVersion != null &&
        latestVersion != currentVersion &&
        updateUrl != null) {
      if (latestVersion != null &&
          latestVersion != currentVersion &&
          updateUrl != null) {
        await showGeneralDialog(
          context: context,
          barrierDismissible: false,
          barrierLabel: "تحديث",
          pageBuilder: (context, anim1, anim2) {
            return WillPopScope(
              onWillPop: () async => false,
              child: UpdateScreen(
                changelog: changelog,
                updateUrl: updateUrl,
              ),
            );
          },
        );
      }
    }
  }


  Future<void> checkSubscriptionStatus(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');

    // ❗️إذا لم يوجد userId، أظهر نافذة الاشتراك مباشرة
    if (userId == null) {
      await _showSubscriptionDialog(context, null, 'غير معروف');
      return;
    }

    final response = await Supabase.instance.client
        .from('subscriptions')
        .select()
        .eq('user_id', userId)
        .order('end_date', ascending: false)
        .maybeSingle();

    final endDateStr = response?['end_date'];
    final type = response?['type'] ?? 'غير معروف';
    final now = DateTime.now();

    final endDate = endDateStr != null ? DateTime.tryParse(endDateStr) : null;

    // ❗️إذا لم توجد نهاية اشتراك، أو انتهى الاشتراك → إظهار النافذة
    if (endDate == null || endDate.isBefore(now)) {
      await _showSubscriptionDialog(context, endDate, type);
    }
  }

  Future<void> _showSubscriptionDialog(BuildContext context, DateTime? endDate, String type) async {
    final remainingDays = endDate != null && endDate.isAfter(DateTime.now())
        ? endDate.difference(DateTime.now()).inDays
        : null;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.all(20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ الأنيميشن
              SizedBox(
                height: 180,
                child: Lottie.asset(
                  'assets/Animation/Animationupgradeplan.json',
                  repeat: true,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                endDate == null
                    ? ' لا يوجد اشتراك نشط لهذا الحساب.'
                    : remainingDays != null
                    ? 'عدد الأيام المتبقية على انتهاء الاشتراك: $remainingDays يوم'
                    : 'انتهى اشتراكك بتاريخ:\n${endDate.toLocal().toString().split(' ')[0]}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'نوع الاشتراك: $type',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop(); // أغلق الدايالوگ الحالي

                  // افتح صفحة الاشتراك وانتظر حتى يعود
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const SubscriptionPage(),
                  ));

                  // بعد الرجوع من صفحة الدفع، تحقق مرة أخرى من حالة الاشتراك
                  await checkSubscriptionStatus(context);
                },
                label: const Text('تجديد الاشتراك الآن',style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold,fontSize: 14),),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: PageStorage(bucket: bucket, child: currentScreen),
        bottomNavigationBar: SafeArea(
          child: Container(
            height: 55,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_navItems.length, (index) {
                final isSelected = currentTab == index;
                final item = _navItems[index];

                return GestureDetector(
                  onTap: () => _onTabSelected(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    padding: isSelected
                        ? const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
                        : const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.deepPurple.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item['icon'] as IconData,
                          color: isSelected ? Color(0xFF273c75) : Colors.grey,
                          size: 24,
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          Text(
                            item['label'] as String,
                            style: const TextStyle(
                              color:  Color(0xFF273c75),
                              fontWeight: FontWeight.bold,
                              fontSize: 15
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    ConnectionWatcher.stopMonitoring();
    super.dispose();
  }
}