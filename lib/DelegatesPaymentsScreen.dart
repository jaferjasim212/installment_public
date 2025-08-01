import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DelegatesPaymentsScreen extends StatefulWidget {
  const DelegatesPaymentsScreen({super.key});

  @override
  _DelegatesPaymentsScreen createState() => _DelegatesPaymentsScreen();
}

class _DelegatesPaymentsScreen extends State<DelegatesPaymentsScreen> with SingleTickerProviderStateMixin {

  Map<String, dynamic>? lastInstallmentItem;
  List<Map<String, dynamic>> installments = [];
  bool loading = true;
  DateTime? startDate;
  DateTime? endDate;
  final intl.DateFormat formatter = intl.DateFormat('yyyy-MM-dd');
  Set<dynamic> expandedCardIds = {};
  String searchType = 'cust_name';
  String searchLabel = 'اسم العميل';
  String searchQuery = '';
  int selectedFilter = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String? selectedGroup;
  late TextEditingController _searchController;
  // --- Delegates filter additions ---
  List<Map<String, dynamic>> delegates = [];
  String? selectedDelegateId;
  double totalPaidAmount = 0.0;
  double totalProfit = 0.0;
  double totalPrincipal = 0.0;

  Future<void> _loadDelegates() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');
    if (userId == null) return;

    final data = await Supabase.instance.client
        .from('delegates')
        .select()
        .eq('user_id', userId);

    setState(() {
      delegates = List<Map<String, dynamic>>.from(data);
    });
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      if (searchType != 'group_id') {
        setState(() {
          searchQuery = _searchController.text;
        });
      }
    });
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );
    _animationController.forward();

    // ✅ تعيين المندوب كبداية إلى "بدون مندوب"
    selectedDelegateId = 'no_delegate';

    // Set initial filter to "عرض تسديدات اليوم فقط"
    selectedFilter = 1;
    _loadDelegates();
    Future.delayed(const Duration(milliseconds: 300), () {
      _loadPaymentofdate();
    });
  }
  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void calculateTotals(List<Map<String, dynamic>> data) {
    double paidSum = 0.0;
    double profitSum = 0.0;
    double principalSum = 0.0;

    for (var item in data) {
      final paid = double.tryParse(item['amount_paid'].toString()) ?? 0.0;
      final rate = double.tryParse(item['installments']!['interest_rate'].toString()) ?? 0.0;
      final profit = paid * rate / 100;
      final principal = paid - profit;

      paidSum += paid;
      profitSum += profit;
      principalSum += principal;
    }

    setState(() {
      totalPaidAmount = paidSum;
      totalProfit = profitSum;
      totalPrincipal = principalSum;
    });
  }

  Future<void> _loadPaymentofdate() async {
    // إذا لم يكن هناك تاريخ محدد مسبقًا، يتم تعيين تاريخ اليوم
    if (startDate == null && endDate == null) {
      final now = DateTime.now();
      startDate = DateTime(now.year, now.month, now.day);
      endDate = startDate;
    }
    setState(() => loading = true);
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');
    if (userId == null) return;

    try {
      final formatter = intl.DateFormat('yyyy-MM-dd');
      final String todayStr = formatter.format(DateTime.now());

      List<Map<String, dynamic>> allData = [];
      int page = 0;
      const int pageSize = 1000;
      bool hasMore = true;

      while (hasMore) {
        // Build the query with delegate filter
        var query = Supabase.instance.client
            .from('payments')
            .select('*, customers(cust_name), installments(item_type, sponsor_name, interest_rate), groups(group_name), delegates(username)')
            .eq('user_id', userId)
            .eq('payment_date', todayStr);
        // Delegate filter:
        if (selectedDelegateId == 'no_delegate') {
          query = query.filter('delegate_id', 'is', null);
        } else if (selectedDelegateId != null && selectedDelegateId!.isNotEmpty) {
          query = query.eq('delegate_id', selectedDelegateId!);
        }
        final response = await query
            .range(page * pageSize, (page + 1) * pageSize - 1)
            .order('created_at', ascending: false);

        final List<Map<String, dynamic>> batch = List<Map<String, dynamic>>.from(response);

        List<Map<String, dynamic>> filteredPageData = batch.where((item) {
          dynamic value;

          if (searchType == 'cust_name') {
            value = item['customers']?['cust_name'];
          } else if (searchType == 'item_type' || searchType == 'sponsor_name') {
            value = item['installments']?[searchType];
          } else if (searchType == 'group_id') {
            value = item['groups']?['group_name'];
          } else if (searchType == 'notes') {
            value = item['notes'];
          } else {
            value = item[searchType];
          }

          bool matchesSearch;
          if (searchType == 'group_id') {
            if (selectedGroup == 'none') {
              matchesSearch = item['group_id'] == null || item['group_id'].toString().isEmpty;
            } else {
              matchesSearch = item['group_id'] != null && item['group_id'].toString() == selectedGroup;
            }
          } else {
            matchesSearch = value != null &&
                value.toString().toLowerCase().contains(searchQuery.toLowerCase());
          }

          return matchesSearch;
        }).toList();

        allData.addAll(filteredPageData);
        hasMore = batch.length == pageSize;
        page++;
      }

      setState(() {
        installments = allData;
        loading = false;
      });
      calculateTotals(installments);
    } catch (e) {
      print('❌ خطأ في تحميل الدفعات: $e');
      setState(() => loading = false);
    }
  }

  Future<void> _loadPayment() async {
    setState(() => loading = true);
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');
    if (userId == null) return;

    try {
      final formatter = intl.DateFormat('yyyy-MM-dd');
      List<Map<String, dynamic>> allData = [];
      int page = 0;
      const int pageSize = 1000;
      bool hasMore = true;

      while (hasMore) {
        // Build the query with delegate filter
        var query = Supabase.instance.client
            .from('payments')
            .select('*, customers(cust_name), installments(item_type, sponsor_name, interest_rate), groups(group_name), delegates(username)')
            .eq('user_id', userId);
        // Delegate filter:
        if (selectedDelegateId == 'no_delegate') {
          query = query.filter('delegate_id', 'is', null);
        } else if (selectedDelegateId != null && selectedDelegateId!.isNotEmpty) {
          query = query.eq('delegate_id', selectedDelegateId!);
        }
        final response = await query
            .range(page * pageSize, (page + 1) * pageSize - 1)
            .order('created_at', ascending: false);


        final List<Map<String, dynamic>> batch = List<Map<String, dynamic>>.from(response);

        // تصفية البيانات يدويًا حسب نوع البحث والتاريخ
        List<Map<String, dynamic>> filteredPageData = batch.where((item) {
          dynamic value;

          if (searchType == 'cust_name') {
            value = item['customers']?['cust_name'];
          } else if (searchType == 'item_type' || searchType == 'sponsor_name') {
            value = item['installments']?[searchType];
          } else if (searchType == 'group_id') {
            value = item['groups']?['group_name'];
          } else if (searchType == 'notes') {
            value = item['notes'];
          } else {
            value = item[searchType];
          }

          bool matchesSearch;
          if (searchType == 'group_id') {
            if (selectedGroup == 'none') {
              matchesSearch = item['group_id'] == null || item['group_id'].toString().isEmpty;
            } else {
              matchesSearch = item['group_id'] != null && item['group_id'].toString() == selectedGroup;
            }
          } else {
            matchesSearch = value != null &&
                value.toString().toLowerCase().contains(searchQuery.toLowerCase());
          }

          // شرط التصفية حسب التاريخ
          bool matchesDate = true;
          if (startDate != null && endDate != null) {
            final paymentDate = DateTime.tryParse(item['payment_date'] ?? '');
            if (paymentDate == null) return false;
            matchesDate = paymentDate.isAfter(startDate!.subtract(const Duration(days: 1))) &&
                paymentDate.isBefore(endDate!.add(const Duration(days: 1)));
          }

          return matchesSearch && matchesDate;
        }).toList();

        allData.addAll(filteredPageData);
        hasMore = batch.length == pageSize;
        page++;
      }

      setState(() {
        installments = allData;
        loading = false;
      });
      calculateTotals(installments);
    } catch (e) {
      print('❌ خطأ في تحميل الدفعات: $e');
      setState(() => loading = false);
    }
  }



  Future<void> _pickDateRangeDialog() async {
    DateTime? localStart = startDate ?? DateTime.now();
    DateTime? localEnd = endDate ?? DateTime.now().add(const Duration(days: 30));

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: DraggableScrollableSheet(
            initialChildSize: 0.5,
            maxChildSize: 0.9,
            minChildSize: 0.3,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 60,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 15),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, -0.5),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: ModalRoute.of(context)!.animation!,
                          curve: Curves.easeOutQuint,
                        )),
                        child: const Text(
                          'تحديد فترة البحث',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // تاريخ البداية
                      ScaleTransition(
                        scale: CurvedAnimation(
                          parent: ModalRoute.of(context)!.animation!,
                          curve: Curves.easeOutBack,
                        ),
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.calendar_today, color: Colors.teal, size: 28),
                            title: Text('من: ${formatter.format(localStart!)}',
                                style: const TextStyle(fontSize: 16)),
                            trailing: const Icon(Icons.arrow_drop_down, color: Colors.teal),
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              final date = await showDatePicker(
                                context: context,
                                initialDate: localStart,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: Colors.teal,
                                        onPrimary: Colors.white,
                                        surface: Colors.white,
                                        onSurface: Colors.black,
                                      ),
                                      dialogBackgroundColor: Colors.white,
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (date != null) {
                                setState(() => localStart = date);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // تاريخ النهاية
                      ScaleTransition(
                        scale: CurvedAnimation(
                          parent: ModalRoute.of(context)!.animation!,
                          curve: Interval(0.1, 1.0, curve: Curves.easeOutBack),
                        ),
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.calendar_today, color: Colors.teal, size: 28),
                            title: Text('إلى: ${formatter.format(localEnd!)}',
                                style: const TextStyle(fontSize: 16)),
                            trailing: const Icon(Icons.arrow_drop_down, color: Colors.teal),
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              final date = await showDatePicker(
                                context: context,
                                initialDate: localEnd,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: Colors.teal,
                                        onPrimary: Colors.white,
                                        surface: Colors.white,
                                        onSurface: Colors.black,
                                      ),
                                      dialogBackgroundColor: Colors.white,
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (date != null) {
                                setState(() => localEnd = date);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),

                      // زر التأكيد
                      ElasticIn(
                        duration: const Duration(milliseconds: 1200),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(context).pop();
                            Future.delayed(const Duration(milliseconds: 300), () {
                              setState(() {
                                startDate = localStart;
                                endDate = localEnd;
                              });

                              if (searchType == 'group_id' && selectedGroup != null && selectedGroup != 'none') {
                                searchQuery = selectedGroup!;
                              }

                              _loadPayment();
                            });
                          },
                          icon: const Icon(Icons.check_circle_outline, size: 24),
                          label: const Text('تأكيد الفترة', style: TextStyle(fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 5,
                            shadowColor: Colors.teal.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildInstallmentCard(Map<String, dynamic> i, dynamic cardId) {
    final isExpanded = expandedCardIds.contains(cardId);
    final customerName = i['customers']?['cust_name'] ?? 'غير معروف';
    final paidAmount = double.tryParse(i['amount_paid'].toString()) ?? 0;
    final paymentDate = i['payment_date'] ?? '';
    final formatter = intl.DateFormat('yyyy-MM-dd');
    final interestRate = double.tryParse(i['installments']?['interest_rate']?.toString() ?? '0') ?? 0.0;
    final profit = paidAmount * interestRate / 100;
    final principal = paidAmount - profit;

    String formatCurrency(dynamic number) {
      final formatter = intl.NumberFormat('#,##0', 'ar');
      return formatter.format(number);
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.5),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOut,
        )),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    if (isExpanded) {
                      expandedCardIds.remove(cardId);
                    } else {
                      expandedCardIds.add(cardId);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildRow('المبلغ المسدد:', '${formatCurrency(paidAmount)} د.ع'),
                      _buildRow('تاريخ الدفع:', formatter.format(DateTime.parse(paymentDate))),
                      _buildRow('الصنف:', i['installments']?['item_type']),

                      if (isExpanded) ...[
                        const Divider(height: 20),
                        _buildRow('نسبة الفائدة :', '${interestRate.toStringAsFixed(2)} ٪'),
                        _buildRow('ربح الدفعة :', '${formatCurrency(profit)} د.ع'),
                        _buildRow('رأس مال الدفعة :', '${formatCurrency(principal)} د.ع'),
                        const Divider(height: 20),

                        _buildRow(  'الملاحظات',
                            i['sponsor_name'] == null || i['sponsor_name'].isEmpty
                                ? 'لا توجد ملاحظات'
                                : i['sponsor_name']
                        ),


                        _buildRow(  'اسم الكفيل',
                            i['sponsor_name'] == null || i['sponsor_name'].isEmpty
                                ? 'لا يوجد كفيل'
                                : i['sponsor_name']
                        ),
                        _buildRow('حساب المندوب:', i['delegates']?['username']?? 'لا يوجد مندوب'),

                        _buildRow('اسم المجموعة:', i['groups']?['group_name'] ?? 'لا توجد مجموعة'),
                        _buildRow(
                          'تاريخ الإدخال:',
                          intl.DateFormat('yyyy-MM-dd – hh:mm a').format(DateTime.parse(i['created_at'])),
                        ),
                      ],
                      Align(
                        alignment: Alignment.center,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(scale: animation, child: child);
                          },
                          child: Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            key: ValueKey<bool>(isExpanded),
                            color: Colors.teal,
                            size: 30,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildRow(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value ?? '---',
              style: TextStyle(
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF2196F3),
                Color(0xFF64B5F6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        title: const Text(
          'نافذة تسديدات المندوبين',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
      ),

      body: _buildMainContent(),
    );
  }
  Widget _buildSummaryBox(String title, double amount, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 10,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${intl.NumberFormat('#,##0', 'ar').format(amount)} د.ع',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      key: const ValueKey('content-column'),
      children: [
        // يظهر فورًا
        SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutQuart,
          )),
          child: FadeTransition(
            opacity: _animationController,
            child: _buildSearchAndFilterSection(),
          ),
        ),
        // هنا نعرض مؤشر التحميل بدل القائمة أثناء التحميل فقط
        Expanded(
          child: loading
              ? _buildLoadingIndicator()
              : SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.5),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _animationController,
                    curve: Curves.easeOutQuart,
                  )),
                  child: FadeTransition(
                    opacity: _animationController,
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            itemCount: installments.length,
                            itemBuilder: (context, index) {
                              final payment = installments[index];
                              return _buildInstallmentCard(payment, payment['id']);
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildSummaryBox('💵 المبلغ المستلم', totalPaidAmount, Colors.teal),
                                    _buildSummaryBox('📈 الربح', totalProfit, Colors.orange),
                                    _buildSummaryBox('💼 رأس المال', totalPrincipal, Colors.blueGrey),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 7),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '📌 عدد الأقساط المستلمة: ${installments.length}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/Animation/Animationserch.json',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 20),
          const Text(
            'جاري تحميل البيانات...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.teal,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterSection() {
    return Material(
      elevation: 4,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // --- Delegate Dropdown ---
            DropdownButtonFormField<String>(
              value: selectedDelegateId,
              decoration: const InputDecoration(
                labelText: 'اختر المندوب',
                border: OutlineInputBorder(),
              ),
              items: ([
                const DropdownMenuItem<String>(value: 'no_delegate', child: Text('بدون مندوب')),
                ...delegates.map((delegate) {
                  return DropdownMenuItem<String>(
                    value: delegate['id'],
                    child: Text(delegate['username'] ?? delegate['id'] ?? ''),
                  );
                }).toList(),
              ]).cast<DropdownMenuItem<String>>(),
              onChanged: (value) {
                setState(() {
                  selectedDelegateId = value;
                  // إذا لم يكن هناك تاريخ محدد مسبقًا، يتم تعيين تاريخ اليوم
                  if (startDate == null && endDate == null) {
                    final now = DateTime.now();
                    startDate = DateTime(now.year, now.month, now.day);
                    endDate = startDate;
                  }
                });
                _loadPayment();
              },
            ),
            const SizedBox(height: 10),

            // Date range display (يظهر أولاً)
            if (startDate != null && endDate != null)
              FadeInDown(
                from: 30,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'من ${intl.DateFormat('yyyy/MM/dd', 'ar').format(startDate!)} '
                        'إلى ${intl.DateFormat('yyyy/MM/dd', 'ar').format(endDate!)}',
                    style: const TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 8),

            FadeInDown(
              from: 10,
              delay: const Duration(milliseconds: 200),
              child: _buildActionButtons(),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: FadeIn(
            delay: const Duration(milliseconds: 300),
            child: ElevatedButton.icon(
              onPressed: _pickDateRangeDialog,
              icon: const Icon(Icons.date_range, size: 20, color: Colors.white,),
              label: const Text('بحث بالتاريخ', style: TextStyle(fontWeight: FontWeight.bold),),
              style: _getButtonStyle(),
            ),
          ),
        ),
      ],
    );
  }
  ButtonStyle _getButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.teal,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 5,
      shadowColor: Colors.teal.withOpacity(0.5),
    );
  }

}
