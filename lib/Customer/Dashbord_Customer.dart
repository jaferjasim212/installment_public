import 'dart:async';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ProfileSetteng_Customr.dart';

class Dashbord_Customer extends StatefulWidget {
  const Dashbord_Customer({super.key});

  @override
  State<Dashbord_Customer> createState() => _Dashbord_CustomerState();
}

class _Dashbord_CustomerState extends State<Dashbord_Customer>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  List<Map<String, dynamic>> _newsList = [];
  List<Map<String, dynamic>> _imageNewsList = [];
  Timer? _pageTimer;
  int _currentPageIndex = 0;
  bool _isLoadingNews = true;
  Future<List<Map<String, dynamic>>>? _merchantsFuture;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadInitialData();
    _merchantsFuture = _fetchAllMerchants();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingLinkRequests(context);
    });
  }

  Future<void> _loadInitialData() async {
    await _loadNewsData();
    _startAutoScroll();
  }

  Future<void> _loadNewsData() async {
    setState(() => _isLoadingNews = true);
    try {
      final news = await _fetchDashboardNews();
      final imageNews = news.where((item) {
        final url = item['image_url']?.toString().trim();
        return url != null && url.isNotEmpty;
      }).toList();

      setState(() {
        _newsList = news;
        _imageNewsList = imageNews;
        _isLoadingNews = false;
      });
    } catch (e) {
      setState(() => _isLoadingNews = false);
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
        backgroundColor: Colors.grey[50],
        appBar: _buildModernAppBar(),
        body: RefreshIndicator(
          onRefresh: _loadInitialData,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildModernNewsSection()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: FadeInRight(
                    child: Text(
                      'أقساطك',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ),
              ),
              _buildModernMerchantsList(),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildModernAppBar() {
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

  Widget _buildModernNewsSection() {
    if (_isLoadingNews) return _buildModernNewsShimmer();
    if (_imageNewsList.isEmpty) return _buildNoNewsMessage();

    return SizedBox(
      height: 200,
      child: PageView.builder(
        controller: _pageController,
        itemCount: _imageNewsList.length,
        onPageChanged: (index) => setState(() => _currentPageIndex = index),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GestureDetector(
              onTap: () => _showModernNewsDialog(_imageNewsList[index]),
              child: Hero(
                tag: 'news-${_imageNewsList[index]['id']}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      Image.network(
                        _imageNewsList[index]['image_url'],
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Colors.grey[200]),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black.withOpacity(0.3), Colors.transparent],
                          ),
                        ),
                      ),

                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernNewsShimmer() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              width: MediaQuery.of(context).size.width - 32,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
      child: Center(
        child: Text(
          'لا توجد أخبار جديدة',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildModernMerchantsList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _merchantsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Center(
                child: Text(
                  'لا يوجد تجار مرتبطين بحسابك',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          );
        }

        final merchants = snapshot.data!;
        return SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              final merchant = merchants[index];
              return FadeInUp(
                delay: Duration(milliseconds: 100 * index),
                child: _buildMerchantCard(merchant),
              );
            },
            childCount: merchants.length,
          ),
        );
      },
    );
  }

  Widget _buildMerchantCard(Map<String, dynamic> merchant) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 13, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.9),
            blurRadius: 22,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

          title: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12), // 🔺 Padding يدوي
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.teal[100],
                  child: Icon(Icons.store, color: Colors.teal[800]),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchant['display_name'] ?? 'تاجر',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (merchant['phone'] != null)
                      Text(
                        merchant['phone'],
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: (merchant['installments'] as List).map((installment) {
                  return _buildInstallmentItem(installment);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstallmentItem(Map<String, dynamic> installment) {
    final dueDateStr = installment['due_date'] ?? 'غير محدد';
    final numberFormat = intl.NumberFormat('#,##0', 'en_US');

    final remainingAmount = numberFormat.format(double.tryParse(installment['remaining_amount'].toString()) ?? 0);
    final paidAmount = numberFormat.format(double.tryParse(installment['paid_amount'].toString()) ?? 0);
    final itemType = installment['item_type'] ?? 'غير محدد';

    // ✅ تحويل التاريخ إلى DateTime
    DateTime? dueDate;
    try {
      dueDate = DateTime.parse(dueDateStr);
    } catch (_) {
      dueDate = null;
    }

    // ✅ تحديد إذا التاريخ أكبر من اليوم
    final isFuture = dueDate != null && dueDate.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isFuture ? Colors.red[100] : Colors.grey[50], // 🔴 إذا التاريخ أكبر من اليوم
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        title: Text(
          itemType,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'استحقاق: $dueDateStr',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.money_off, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'متبقي: $remainingAmount د.ع',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.payments, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'مدفوع: $paidAmount د.ع',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.receipt_long, color: Colors.teal),
          onPressed: () => _showPaymentsDetails(installment),
        ),
      ),
    );
  }
  void _showPaymentsDetails(Map<String, dynamic> installment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    'سجل الدفعات',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: Supabase.instance.client
                          .from('payments')
                          .select('payment_date, amount_paid')
                          .eq('installment_id', installment['id']),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final payments = snapshot.data ?? [];
                        final totalPaid = payments.fold<double>(
                            0, (sum, payment) => sum + (payment['amount_paid'] ?? 0));

                        return Column(
                          children: [
                            payments.isEmpty
                                ? Expanded(
                              child: Center(
                                child: Text(
                                  'لا توجد دفعات مسجلة',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ),
                            )
                                : Expanded(
                              child: ListView.separated(
                                controller: controller,
                                itemCount: payments.length,
                                separatorBuilder: (_, __) => const Divider(height: 16),
                                itemBuilder: (context, index) {
                                  final payment = payments[index];
                                  return ListTile(
                                    leading: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.teal[50],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            color: Colors.teal[800],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      '${intl.NumberFormat('#,##0', 'en_US').format(double.tryParse(payment['amount_paid'].toString()) ?? 0)} د.ع',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      payment['payment_date'].toString().split('T')[0],
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    trailing: Icon(Icons.check_circle, color: Colors.teal[400]),
                                  );
                                },
                              ),
                            ),
                            if (payments.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.teal[50],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'المجموع',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal[800],
                                      ),
                                    ),
                                    Text(
                                      '${intl.NumberFormat('#,##0', 'en_US').format(totalPaid)} د.ع',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal[800],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showModernNewsDialog(Map<String, dynamic> newsItem) {
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
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (createdAt != null)
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                intl.DateFormat('yyyy-MM-dd - hh:mm a').format(
                                  DateTime.parse(createdAt),
                                ),
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        const SizedBox(height: 12),
                        Text(
                          content,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (linkUrl.isNotEmpty) {
                                    await launchUrl(
                                      Uri.parse(linkUrl),
                                      mode: LaunchMode.externalApplication,
                                    );
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
              const Expanded(child: ProfileSetteng_Customr()),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchDashboardNews() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('CustomerID');
    if (userId == null) return [];

    final response = await Supabase.instance.client
        .from('newsCustomer')
        .select('*')
        .or('is_public.eq.true,target_user_id.eq.$userId')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _checkPendingLinkRequests(BuildContext context) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    final pendingLinks = await Supabase.instance.client
        .from('customer_links')
        .select('id, user_id, users_full_profile(display_name)')
        .eq('customer_profile_id', uid)
        .eq('is_active', false);

    for (final link in pendingLinks) {
      final customerLinkId = link['id'];
      final merchantName = link['users_full_profile']?['display_name'] ?? 'تاجر غير معروف';

      // عرض Dialog طلب الربط
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('طلب ربط حساب'),
          content: Text('هل توافق على ربط حسابك مع التاجر "$merchantName"؟'),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  print('🆔 customerLinkId: $customerLinkId');
                  final result = await Supabase.instance.client
                      .from('customer_links')
                      .update({'is_active': true})
                      .eq('id', customerLinkId)
                      .select(); // ✅ أضف هذه
                  debugPrint('✅ تم التحديث: $result');
                } catch (e) {
                  debugPrint('❌ خطأ في التحديث: $e');
                }
                Navigator.of(context).pop();
              },
              child: const Text('موافقة'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('رفض'),
            ),
          ],
        ),
      );
    }
  }  Future<List<Map<String, dynamic>>> _fetchAllMerchants() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return [];

    final links = await Supabase.instance.client
        .from('customer_links')
        .select('user_id, customer_table_id')
        .eq('customer_profile_id', uid)
        .eq('is_active', true);

    if (links.isEmpty) return [];

    final merchantIds = links.map((e) => e['user_id']).toList();
    final customerIds = links.map((e) => e['customer_table_id']).toList();

    final merchants = await Supabase.instance.client
        .from('users_full_profile')
        .select('id, display_name, phone')
        .inFilter('id', merchantIds);

    final installments = await Supabase.instance.client
        .from('installments')
        .select('id, customer_id, due_date, remaining_amount,item_type')
        .inFilter('customer_id', customerIds);

    final payments = await Supabase.instance.client
        .from('payments')
        .select('installment_id, amount_paid')
        .inFilter('customer_id', customerIds);

    return merchants.map((merchant) {
      final merchantId = merchant['id'];
      final customerLink = links.firstWhere((e) => e['user_id'] == merchantId);
      final customerId = customerLink['customer_table_id'];
      final merchantInstallments = installments
          .where((inst) => inst['customer_id'] == customerId)
          .map((inst) {
        final relatedPayments = payments.where((p) => p['installment_id'] == inst['id']);
        final paidAmount = relatedPayments.fold<double>(0, (sum, p) => sum + (p['amount_paid'] ?? 0));
        return {
          ...inst,
          'paid_amount': paidAmount.toStringAsFixed(2),
        };
      })
          .toList();

      return {
        'display_name': merchant['display_name'],
        'phone': merchant['phone'],
        'installments': merchantInstallments,
      };
    }).toList();
  }

}