import 'dart:async';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'DashbordDitels/LateInstallmentsDialog.dart';
import 'DashbordDitels/InstallmentsDialogtoday.dart';
import 'ProfileSetteng.dart';
import 'DashbordDitels/TodayInstallmenrsDialog.dart';
import 'DashbordDitels/TodayPaymentsDialog.dart';


class Dashbord extends StatefulWidget {
  const Dashbord({super.key});

  @override
  State<Dashbord> createState() => _DashbordState();
}

class _DashbordState extends State<Dashbord> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  List<Map<String, dynamic>> _newsList = [];
  List<Map<String, dynamic>> _imageNewsList = [];
  Timer? _pageTimer;
  int _currentPageIndex = 0;
  bool _isLoadingNews = true;
  bool _isLoadingStats = true;
  Map<String, dynamic> _stats = {};
  final supabase = Supabase.instance.client;
  bool showPaymentsAmount = true;
  Map<String, dynamic>? _subscription;
  bool _showSubscriptionDetails = true;
  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadInitialData();
    _loadVisibilityPreference();
    _loadSubscription();
    _loadPinPreference();

  }
  Future<void> _loadPinPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _showSubscriptionDetails = prefs.getBool('show_subscription_details') ?? true;
    setState(() {});
  }

  Future<void> _savePinPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_subscription_details', value);
  }

  int getRemainingDays(Map<String, dynamic> sub) {
    final endDateStr = sub['end_date'];
    final endDate = DateTime.tryParse(endDateStr);
    if (endDate == null) return 0;
    return endDate.difference(DateTime.now()).inDays;
  }

  Future<void> _loadSubscription() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('UserID');
    if (userId == null) return;

    final response = await Supabase.instance.client
        .from('subscriptions')
        .select()
        .eq('user_id', userId)
        .eq('is_active', true)
        .maybeSingle();

    setState(() {
      _subscription = response;
    });
  }

  Future<void> _loadVisibilityPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      showPaymentsAmount = prefs.getBool('showPaymentsAmount') ?? true;
    });
  }

  Future<void> _toggleVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      showPaymentsAmount = !showPaymentsAmount;
      prefs.setBool('showPaymentsAmount', showPaymentsAmount);
    });
  }

  Future<void> _loadInitialData() async {
    await _loadNewsData();
    await _loadStatsData();

    final linkedCount = await getLinkedCustomerCount();
    final delegateCount = await getDelegateCount();

    setState(() {
      _stats['linkedCustomers'] = linkedCount;
      _stats['delegateCount'] = delegateCount;
    });

    _startAutoScroll();
  }


  Future<int> getDelegateCount() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');
    if (userId == null) return 0;

    final response = await Supabase.instance.client
        .from('delegates')
        .select('id') // جلب الـ id فقط يكفي
        .eq('user_id', userId);

    if (response is List) {
      return response.length;
    } else {
      return 0;
    }
  }



  void _showNewsDialog(Map<String, dynamic> newsItem) {
    final title = newsItem['title'] ?? 'بدون عنوان';
    final content = newsItem['content'] ?? 'بدون وصف';
    final createdAt = newsItem['created_at'];
    final linkUrl = newsItem['link_url'] ?? '';
    final imageUrl = newsItem['image_url'] ?? '';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {

        return ZoomIn(
          duration: const Duration(milliseconds: 700),
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // الصورة (عرض كامل)
                  if (imageUrl.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            backgroundColor: Colors.transparent,
                            child: InteractiveViewer(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.network(imageUrl),
                              ),
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: Image.network(
                          imageUrl,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 200,
                            color: Colors.grey[200],
                            child: const Center(child: Text('تعذر تحميل الصورة')),
                          ),
                        ),
                      ),
                    ),

                  // محتوى الخبر
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // العنوان
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // التاريخ
                        if (createdAt != null)
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                intl.DateFormat('yyyy-MM-dd - hh:mm a').format(DateTime.parse(createdAt)),
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        const SizedBox(height: 12),

                        // محتوى الخبر
                        Text(
                          content,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // أزرار التحكم
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (linkUrl.isNotEmpty) {
                                    await launchUrl(Uri.parse(linkUrl),
                                        mode: LaunchMode.externalApplication);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[700],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.open_in_new, size: 18),
                                    SizedBox(width: 8),
                                    Text('فتح الخبر'),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey[700],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text('إغلاق'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadNewsData() async {
    setState(() => _isLoadingNews = true);
    try {
      final news = await supabase
          .from('news')
          .select('id, title, content, is_public, target_user_id, created_at, image_url, link_url')
          .or('is_public.eq.true,target_user_id.eq.${Supabase.instance.client.auth.currentUser?.id}')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> imageNews = news.where((item) {
        final url = item['image_url']?.toString().trim();
        return url != null && url.isNotEmpty;
      }).toList();

      setState(() {
        _newsList = List<Map<String, dynamic>>.from(news);
        _imageNewsList = imageNews;
        _isLoadingNews = false;
      });
    } catch (e) {
      setState(() => _isLoadingNews = false);
    }
  }


  Future<void> _loadStatsData() async {
    setState(() => _isLoadingStats = true);
    try {
      final stats = await _fetchDashboardStats();
      setState(() {
        _stats = stats;
        _isLoadingStats = false;
      });
    } catch (e) {
      setState(() => _isLoadingStats = false);
    }
  }

  void _startAutoScroll() {
    _pageTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
      if (_pageController.hasClients && mounted && _imageNewsList.length > 1) {
        _currentPageIndex = (_currentPageIndex + 1) % _imageNewsList.length;
        _pageController.animateToPage(
          _currentPageIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              _buildNewsSection(),
              if (_subscription != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      if (_showSubscriptionDetails || getRemainingDays(_subscription!) <= 5)
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.verified_user_rounded, color: Colors.green, size: 20),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  getSubscriptionText(_subscription!),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: IconButton(
                          iconSize: 20,
                          icon: Icon(
                            _showSubscriptionDetails ? Icons.push_pin : Icons.push_pin_outlined,
                            color: getRemainingDays(_subscription!) <= 5 ? Colors.grey : Colors.black,
                          ),
                          onPressed: getRemainingDays(_subscription!) <= 5
                              ? null
                              : () async {
                            setState(() {
                              _showSubscriptionDetails = !_showSubscriptionDetails;
                            });
                            await _savePinPreference(_showSubscriptionDetails);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              _buildStatsSection(), // إذا كانت هذه تحتاج مساحة كبيرة، لفها بـ SizedBox أو اجعلها scrollable أيضاً
            ],
          ),
        ),      ),
    );
  }

  String getSubscriptionText(Map<String, dynamic> sub) {
    final type = sub['type'];
    final endDateStr = sub['end_date'];
    if (type == null || endDateStr == null) return "اشتراك غير معروف";

    final endDate = DateTime.tryParse(endDateStr);
    if (endDate == null) return "تاريخ غير صالح";

    final remainingDays = endDate.difference(DateTime.now()).inDays;

    String label;
    switch (type) {
      case 'free_trial':
        label = "النسخة التجريبية";
        break;
      case 'monthly':
        label = "الاشتراك الشهري";
        break;
      case 'yearly':
        label = "الاشتراك السنوي";
        break;
      case 'daily':
        label = "الاشتراك اليومي";
        break;
      default:
        label = "نوع غير معروف";
    }

    return "$label - تبقى $remainingDays يوم";
  }
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,

      automaticallyImplyLeading: false,
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
            Container(
              color: Colors.black.withOpacity(0.2),
            ),
          ],
        ),
      ),      elevation: 4,
      title: FadeIn(
        child: Row(
          children: [

            const Text(
              ' الصفحة الرئيسية',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),

      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: ElevatedButton.icon(
            onPressed: _showProfileSheet,
            icon: SizedBox(
              width: 30,
              height: 30,
              child: Image.asset(
                'assets/images/settings.png',
                fit: BoxFit.contain,
              ),
            ),
            label: const Text(
              '',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFe6a82b),
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              elevation: 2,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],



    );
  }

  void _showProfileSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.90,
        minChildSize: 0.5,
        maxChildSize: 1.0,
        expand: false,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const Expanded(child: ProfilePage()),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildNewsSection() {
    if (_isLoadingNews) return _buildNewsLoadingShimmer();
    if (_imageNewsList.isEmpty) return _buildNoNewsMessage();
    return _buildNewsSlider();
  }

  Widget _buildNewsLoadingShimmer() {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: MediaQuery.of(context).size.width - 32, // نفس عرض صورة الخبر
                height: 220, // نفس الارتفاع
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoNewsMessage() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        "لا توجد أخبار جديدة",
        style: TextStyle(color: Colors.grey, fontSize: 16),
      ),
    );
  }

  Widget _buildNewsSlider() {
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: _imageNewsList.length,
                onPageChanged: (index) {
                  setState(() => _currentPageIndex = index);
                },
                itemBuilder: (context, index) {
                  return _buildNewsItem(_imageNewsList[index]);
                },
              ),
              if (_imageNewsList.length > 1)
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_imageNewsList.length, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPageIndex == index ? 12 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPageIndex == index
                              ? Colors.white
                              : Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNewsItem(Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () {
        _showNewsDialog(item);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                item['image_url'],
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[100],
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 40, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text('تعذر تحميل الصورة', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildStatsSection() {
    if (_isLoadingStats) return _buildStatsLoadingShimmer();
    if (_stats.isEmpty) return const Center(child: Text('تعذر تحميل البيانات'));
    return _buildStatsContent();
  }
  Widget _buildStatsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // الصف الأول من المربعات
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.3,
            children: [
              _buildDashboardCard(
                title: "مستحقين اليوم",
                count: _stats['dueToday'] ?? 0,
                color: const Color(0xFFFFA726),
                icon: Icons.schedule,
                isMoney: false,
                gradientColors: [const Color(0xFF673AB7), const Color(0xFFFF7043)],
              ),
              _buildDashboardCard(
                title: "متأخرين",
                count: _stats['late'] ?? 0,
                color: const Color(0xFFEF5350),
                icon: Icons.error_outline,
                isMoney: false,
                gradientColors: [const Color(0xFFEF5350), const Color(0xFFE53935)],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // الصف الثاني من المربعات
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.3,
            children: [
              _buildDashboardCard(
                title: "أقساط اليوم",
                count: _stats['newInstallmentsToday'] ?? 0,
                color: const Color(0xFF42A5F5),
                icon: Icons.today,
                isMoney: false,
                gradientColors: [const Color(0xFF2196F3), const Color(0xFF00BCD4)],
              ),
              _buildDashboardCard(
                title: "عدد العملاء",
                count: _stats['customerCount'] ?? 0,
                color: const Color(0xFF009688),
                icon: Icons.group,
                isMoney: false,
                gradientColors: [const Color( 0xFF2196F3 ), const Color(0xFF009688)],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildDashboardCardmony(
            title: "المبالغ المستلمة اليوم",
            count: showPaymentsAmount ? (_stats['paymentsToday'] ?? 0) : 0,
            color: const Color(0xFF2c3e50),
            icon: Icons.attach_money,
            isMoney: true,
            gradientColors: [const Color(0xFFecf0f1), const Color(0xFFecf0f1)],
            isFullWidth: true,
            showToggleEye: true,
          ),
        ),

        const SizedBox(height: 24),

           Column(
              children: [
                _buildStatCard(
                  title: "كل الأقساط",
                  count: _stats['allInstallments'] ?? 0,
                  color: const Color(0xFF5C6BC0),
                  iconWidget: Lottie.asset(
                    'assets/Animation/Animationdocument.json',
                    height: 60,

                    fit: BoxFit.contain,
                  ),
                ),
                _buildStatCard(
                  title: "العملاء المرتبطين",
                  count: _stats['linkedCustomers'] ?? 0,
                  color: const Color(0xFFAB47BC),
                  iconWidget: Lottie.asset(
                    'assets/Animation/Animationpeople.json',
                    height: 60,
                    fit: BoxFit.contain,
                  ),
                ),
                _buildStatCard(
                  title: "المندوبين",
                  count: _stats['delegateCount'] ?? 0,
                  color: const Color(0xFF8D6E63),
                  iconWidget: Lottie.asset(
                    'assets/Animation/Animationemail.json',
                    height: 60,

                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),

      ],
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required num count,
    required Color color,
    required IconData icon,
    required bool isMoney,
    required List<Color> gradientColors,
    bool isFullWidth = false,
    bool showToggleEye = false, // ✅ أضف هذا

  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 300;
        // ارتفاع كارت ثابت لتجنب overflow
        return SizedBox(
          height: 150,
          child: GestureDetector(
            onTap: () {
              Widget dialog;

              if (title.contains('مستحقين اليوم')) {
                dialog = const TodayInstallmentsDialog();
              } else if (title.contains('متأخرين')) {
                dialog = const LateInstallmentsDialog();
              } else if (title.contains('أقساط اليوم')) {
                dialog = const InstallmentsDialogtoday();
              } else if (title.contains('المبالغ المستلمة اليوم')) {
                dialog = const TodayPaymentsDialog();
              }  else {
                       return;
              }

              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                isScrollControlled: true,
                builder: (_) => dialog,
              );
            },
            child: Container(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: Colors.white, size: isSmallScreen ? 18 : 20),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (showToggleEye)
                        IconButton(
                          icon: Icon(
                            showPaymentsAmount ? Icons.visibility : Icons.visibility_off,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: _toggleVisibility,
                        ),
                    ],
                  ),

                  const Spacer(),
                  Center(
                    child: Text(
                      isMoney
                          ? (showToggleEye && !showPaymentsAmount
                          ? '---'
                          : '${intl.NumberFormat("#,##0").format(count)} د.ع')
                          : '${intl.NumberFormat("#,##0").format(count)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 24 : 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 10,
                            color: Colors.black.withOpacity(0.2),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: (count / 100).clamp(0.0, 1.0),
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDashboardCardmony({
    required String title,
    required num count,
    required Color color,
    required IconData icon,
    required bool isMoney,
    required List<Color> gradientColors,
    bool isFullWidth = false,
    bool showToggleEye = false, // ✅ أضف هذا

  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 300;
        // ارتفاع كارت ثابت لتجنب overflow
        return SizedBox(
          height: 150,
          child: GestureDetector(
            onTap: () {
              Widget dialog;

             if (title.contains('المبالغ المستلمة اليوم')) {
                dialog = const TodayPaymentsDialog();
              }  else {
                return;
              }

              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                isScrollControlled: true,
                builder: (_) => dialog,
              );
            },
            child: Container(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: Colors.white, size: isSmallScreen ? 18 : 20),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (showToggleEye)
                        IconButton(
                          icon: Icon(
                            showPaymentsAmount ? Icons.visibility : Icons.visibility_off,
                            color: Colors.black,
                            size: 20,
                          ),
                          onPressed: _toggleVisibility,
                        ),
                    ],
                  ),

                  const Spacer(),
                  Center(
                    child: Text(
                      isMoney
                          ? (showToggleEye && !showPaymentsAmount
                          ? '---'
                          : '${intl.NumberFormat("#,##0").format(count)} د.ع')
                          : '${intl.NumberFormat("#,##0").format(count)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 22 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        shadows: [
                          Shadow(
                            blurRadius: 10,
                            color: Colors.black.withOpacity(0.2),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: (count / 100).clamp(0.0, 1.0),
                      backgroundColor: Colors.black.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  Widget _buildStatCard({
    required String title,
    required int count,
    required Color color,
    Widget? iconWidget, // ← إضافة هذا
    IconData? icon,     // ← الحفاظ على الخيار القديم
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Row(
          children: [
            // ✅ أيقونة داخل دائرة
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: iconWidget ??
                    Icon(icon, color: color, size: 20), // ← استخدام Lottie إذا موجود
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsLoadingShimmer() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.3,
            children: List.generate(4, (_) => _buildShimmerDashboardCard(
              gradientColors: [Colors.grey[300]!, Colors.grey[200]!],
            ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (_) => _buildShimmerCircleStat()),
          ),
        ],
      ),
    );
  }


  Widget _buildShimmerCircleStat() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 60,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerDashboardCard({required List<Color> gradientColors}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
            Container(
              height: 24,
              width: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: 0.6,
                backgroundColor: Colors.white,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<int> getLinkedCustomerCount() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');

    if (userId == null) return 0;

    final response = await Supabase.instance.client
        .from('customer_links')
        .select('id')
        .eq('user_id', userId)
        .eq('is_active', true); // اختياري: شرط الربط الفعّال فقط

    return response.length;
  }

  Future<Map<String, dynamic>> _fetchDashboardStats() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');
    if (userId == null) return {};

    final today = DateTime.now();
    final todayStr = intl.DateFormat('yyyy-MM-dd').format(today);

    final installmentResponse = await supabase
        .from('installments')
        .select('id, due_date, created_at, start_date, remaining_amount')
        .eq('user_id', userId);

    final filteredInstallments = installmentResponse.where((i) {
      final remaining = num.tryParse(i['remaining_amount'].toString()) ?? 0;
      return remaining > 0;
    }).toList();

    final allInstallmentsCount = filteredInstallments.length;

    final newInstallmentsToday = filteredInstallments
        .where((i) => (i['start_date'] as String?)?.startsWith(todayStr) ?? false)
        .length;

    final lateInstallments = filteredInstallments.where((i) {
      final dueDateStr = i['due_date'];
      if (dueDateStr == null) return false;
      final dueDate = DateTime.tryParse(dueDateStr);
      if (dueDate == null) return false;
      final now = DateTime(today.year, today.month, today.day);
      return dueDate.isBefore(now);
    }).length;

    final dueTodayInstallments = filteredInstallments.where((i) {
      final dueDateStr = i['due_date'];
      if (dueDateStr == null) return false;
      final dueDate = DateTime.tryParse(dueDateStr);
      if (dueDate == null) return false;
      final now = DateTime(today.year, today.month, today.day);
      return dueDate.year == now.year && dueDate.month == now.month && dueDate.day == now.day;
    }).length;

    final paymentsResponse = await supabase
        .from('payments')
        .select('payment_date, amount_paid')
        .eq('user_id', userId);

    final paymentsTodayTotal = paymentsResponse
        .where((p) => (p['payment_date'] as String).startsWith(todayStr))
        .map((p) => double.tryParse(p['amount_paid'].toString()) ?? 0.0)
        .fold(0.0, (sum, value) => sum + value);

    List<Map<String, dynamic>> allCustomers = [];
    int page = 0;
    const int pageSize = 1000;
    bool hasMore = true;

    while (hasMore) {
      final response = await supabase
          .from('customers')
          .select('id, type')
          .eq('user_id', userId)
          .range(page * pageSize, (page + 1) * pageSize - 1);

      final List<Map<String, dynamic>> batch = List<Map<String, dynamic>>.from(response);
      allCustomers.addAll(batch);

      if (batch.length < pageSize) {
        hasMore = false;
      } else {
        page++;
      }
    }

    final customerCount = allCustomers.where((c) => c['type'] == 'حساب عميل').length;

    return {
      'newInstallmentsToday': newInstallmentsToday,
      'dueToday': dueTodayInstallments,
      'late': lateInstallments,
      'paymentsToday': paymentsTodayTotal,
      'customerCount': customerCount,
      'allInstallments': allInstallmentsCount,
    };
  }
}
