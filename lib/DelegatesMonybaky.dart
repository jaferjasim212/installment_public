import 'dart:async';
import 'dart:convert';
import 'package:animate_do/animate_do.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:ui' as ui;
import 'ShowDetiles.dart';
import 'TypeAccount.dart';
import 'print_bottom_sheet.dart';
import 'package:crypto/crypto.dart';

class DelegatesMonybaky extends StatefulWidget {
  const DelegatesMonybaky({super.key});

  @override
  _DelegatesMonybaky createState() => _DelegatesMonybaky();
}


class _DelegatesMonybaky extends State<DelegatesMonybaky> with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF2196F3), // تدرج أزرق
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
        elevation: 4,
        title: Align(
          alignment: Alignment.centerRight,
          child: Text(
            'نافذة الأقساط',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) => Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: child,
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  elevation: 0,
                ),
                icon: _isButtonLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.exit_to_app_rounded, color: Colors.white),
                label: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _isButtonLoading ? null : _showpayDialogexite,
              ),
            ),
          ),
        ],
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: _buildMainContent(),

    );
  }

  Map<String, dynamic>? lastInstallmentItem;
  List<Map<String, dynamic>> installments = [];
  bool loading = true;

  final intl.DateFormat formatter = intl.DateFormat('yyyy-MM-dd');
  Set<dynamic> expandedCardIds = {};
  String searchType = 'cust_name';
  String searchLabel = 'اسم العميل';
  String searchQuery = '';
  int selectedFilter = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String? selectedGroup;
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> filteredCustomers = [];
  final TextEditingController _selectedCustomerController = TextEditingController();
  String? selectedCustomerId;
  final TextEditingController _guarantorController = TextEditingController();
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _itemTypeController = TextEditingController();
  bool isNextEnabled = false;
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  String? selectedCustomerName;
  DateTime? saleDate;
  DateTime? dueDate;
  List<String> userGroups = [];
  final TextEditingController _salePriceController = TextEditingController();
  final TextEditingController _monthlyPaymentController = TextEditingController();
  final TextEditingController _remainingAmountController = TextEditingController();
  final ValueNotifier<bool> isSalePriceValid = ValueNotifier<bool>(true);
  final TextEditingController _notesController = TextEditingController();
  bool _isSaving = false;
  Map<String, int> customerInstallmentCounts = {}; // لتخزين عدد الأقساط لكل عميل
  bool _isButtonLoading = false;
  late TextEditingController _searchController2;
  int completedCount = 0;
  List<Map<String, dynamic>> filteredInstallments = [];
  bool isDateFilterActive = false;
  DateTime? startDate;
  DateTime? endDate;
  void _validateInputs() {
    setState(() {
      isNextEnabled = _selectedCustomerController.text.trim().isNotEmpty &&
          _itemTypeController.text.trim().isNotEmpty;
    });
  }

  @override
  void initState() {
    super.initState();
    _searchController2 = TextEditingController(text: searchQuery);

    _loadInstallmentCounts();
    _fetchUserGroups();

    _selectedCustomerController.addListener(_validateInputs);
    _itemTypeController.addListener(_validateInputs);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.forward();

    // تأخير تحميل البيانات حتى تظهر واجهة البحث أولًا
    Future.delayed(const Duration(milliseconds: 300), () {
      _loadInstallments();
    });
  }
  @override
  void dispose() {
    _animationController.dispose();
    _glowController.dispose();
    _selectedCustomerController.dispose();
    _itemTypeController.dispose();
    _guarantorController.dispose();
    _searchController.dispose();

    super.dispose();
  }

  Future<void> _loadInstallments() async {
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
        final response = await Supabase.instance.client
            .from('installments')
            .select('id, customer_id, sponsor_name, group_id, item_type, notes, sale_price, monthly_payment, remaining_amount, start_date, due_date, user_id, created_at, customers(cust_name), groups:fk_installments_group(group_name)')
            .eq('user_id', userId)
            .range(page * pageSize, (page + 1) * pageSize - 1)
            .order('created_at', ascending: false);

        final List<Map<String, dynamic>> batch = List<Map<String, dynamic>>.from(response);

        // فلترة البحث النصي
        List<Map<String, dynamic>> filteredPageData = batch;
        if (searchQuery.isNotEmpty || searchType == 'group_id') {
          filteredPageData = batch.where((item) {
            dynamic value;
            if (searchType == 'cust_name') {
              value = item['customers']?['cust_name'];
            } else if (searchType == 'item_type' || searchType == 'sponsor_name') {
              value = item[searchType];
            } else if (searchType == 'group_id') {
              value = item['groups']?['group_name'];
            } else if (searchType == 'notes') {
              value = item['notes'];
            } else {
              value = item[searchType];
            }

            if (searchType == 'group_id') {
              if (selectedGroup == 'none') {
                return item['group_id'] == null || item['group_id'].toString().isEmpty;
              } else {
                return item['group_id'] != null && item['group_id'].toString() == selectedGroup;
              }
            }

            return value != null && value.toString().toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();
        }

        // ✅ فلترة بالتاريخ فقط إذا كان الفلتر هو "عرض الجميع" أو "المستحقين والمتأخرين"
        if ((selectedFilter == 0 || selectedFilter == 1) &&
            isDateFilterActive &&
            startDate != null &&
            endDate != null) {
          filteredPageData = filteredPageData.where((item) {
            final startDateStr = item['start_date'];
            if (startDateStr == null) return false;
            final itemDate = DateTime.tryParse(startDateStr);
            if (itemDate == null) return false;
            return itemDate.isAfter(startDate!.subtract(const Duration(days: 1))) &&
                itemDate.isBefore(endDate!.add(const Duration(days: 1)));
          }).toList();
        }

        allData.addAll(filteredPageData);
        hasMore = batch.length == pageSize;
        page++;
      }

      // ✅ التصفية النهائية حسب selectedFilter
      List<Map<String, dynamic>> filteredData;
      if (selectedFilter == 0) {
        // عرض الجميع (بعد فلترة التاريخ إن وُجد)
        filteredData = allData;
      } else if (selectedFilter == 1) {
        // المستحقين والمتأخرين
        filteredData = allData.where((i) {
          final remaining = double.tryParse(i['remaining_amount'].toString()) ?? 0;
          return remaining > 0;
        }).toList();
      } else if (selectedFilter == 2) {
        // المنتهية فقط (يُعرض دائمًا دون تأثر بالتاريخ)
        filteredData = allData.where((i) {
          final remaining = double.tryParse(i['remaining_amount'].toString()) ?? 0;
          return remaining <= 0;
        }).toList();
      } else {
        filteredData = allData;
      }

      setState(() {
        installments = filteredData;
        loading = false;
      });
    } catch (e) {
      print('❌ خطأ في تحميل الأقساط: $e');
      setState(() => loading = false);
    }
  }

  void _showpayDialogexite() {
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
                  'assets/Animation/Animationexit.json',
                  height: 120,
                  repeat: true,
                ),
                const SizedBox(height: 12),
                const Text(
                  'هل انت متأكد من الخروج!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'عند تسجيل الخروج لن تسطيع العودة الى هذه النافذة الا اذا قام المدير بأدخالك مرة اخرى ',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();

                        if (!context.mounted) return;

                        Navigator.of(context).pop(); // غلق الديالوج

                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const TypeAccount()),
                              (route) => false,
                        );
                      },
                      icon: const Icon(Icons.exit_to_app_rounded, color: Colors.white),
                      label: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCF274F),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
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
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadUserGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');
    if (userId == null) return [];
    final data = await Supabase.instance.client
        .from('groups')
        .select()
        .eq('user_id', userId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(data);
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
                                isDateFilterActive = true; // ← تفعيل التصفية بالتاريخ
                              });
                              _loadInstallments();
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
    final imageBase64 = i['image_base64'];
    final hasImage = imageBase64 != null && imageBase64.isNotEmpty;

    final imageWidget = hasImage
        ? Image.memory(
      base64Decode(imageBase64),
      height: 120,
      fit: BoxFit.cover,
    )
        : null;

    final customerName = i['customers']?['cust_name'] ?? 'غير معروف';
    final remainingAmount = double.tryParse(i['remaining_amount'].toString()) ?? 0;
    final dueDate = DateTime.tryParse(i['due_date'] ?? '');
    final today = DateTime.now();
    final isDueToday = dueDate != null &&
        dueDate.year == today.year &&
        dueDate.month == today.month &&
        dueDate.day == today.day;


    final isCompleted = remainingAmount <= 0;

    String statusText = '';
    Color? statusColor;

    if (isCompleted) {
      statusText = 'مكتمل';
      statusColor = Colors.green[800];
    } else if (dueDate != null) {
      final diff = dueDate.difference(DateTime(today.year, today.month, today.day)).inDays;

      if (diff == 0) {
        statusText = 'مستحق اليوم';
        statusColor = Colors.orange[800];
      } else if (diff > 0) {
        statusText = 'تبقى $diff يوم ';
        statusColor = Colors.blue[800];
      } else {
        statusText = ' متأخر ${-diff} يوم ';
        statusColor = Color(0xFFCF274F);
      }
    } else {
      statusText = 'غير محدد';
      statusColor = Colors.grey[600];
    }

    if (isCompleted) {
      statusText = 'مكتمل';
      statusColor = Colors.green[800];
    } else if (dueDate != null) {
      final diff = dueDate.difference(DateTime(today.year, today.month, today.day)).inDays;

      if (diff == 0) {
        statusText = 'مستحق اليوم';
        statusColor = Colors.orange[800];
      } else if (diff > 0) {
        statusText = 'تبقى $diff يوم';
        statusColor = Colors.blue[800];
      } else {
        statusText = 'متأخر ${-diff} يوم';
        statusColor = Color(0xFFCF274F);
      }
    } else {
      statusText = 'غير محدد';
      statusColor = Colors.grey[600];
    }    // تنسيق المبالغ
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
                      // Header with status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            customerName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor?.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Basic info
                      _buildRow('نوع الصنف:', i['item_type']),
                      _buildRow('المبلغ المتبقي:', '${formatCurrency(i['remaining_amount'])} د.ع'),

                      // Expanded details
                      if (isExpanded) ...[
                        const Divider(height: 20),
                        _buildRow('اسم الكفيل:', i['sponsor_name']),
                        _buildRow('اسم المجموعة:',i['groups']?['group_name'] ?? 'لا توجد مجموعة'),
                        _buildRow('الملاحظات:', i['notes']),
                        _buildRow('المبلغ الكلي:', '${formatCurrency(i['sale_price'])} د.ع'),
                        _buildRow('القسط الشهري:', '${formatCurrency(i['monthly_payment'])} د.ع'),
                        _buildRow('تاريخ القسط:', i['start_date']),
                        _buildRow('تاريخ الاستحقاق:', i['due_date']),
                      ],

                      // Expand button
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
                color: Colors.black,
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

  Future<void> _showFilterDialog(int allCount, int dueCount, int completedCount) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
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
                          'تصفية النتائج',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // كل الخيارات مع onTap
                      ScaleTransition(
                        scale: CurvedAnimation(
                          parent: ModalRoute.of(context)!.animation!,
                          curve: Curves.easeOutBack,
                        ),
                        child: _buildFilterOption(
                          title: 'عرض الجميع ($allCount)',
                          value: 0,
                          icon: Icons.list,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              selectedFilter = 0;
                              filteredInstallments = installments.where((i) {
                                final remaining = double.tryParse(i['remaining_amount'].toString()) ?? 0;
                                return remaining > 0;
                              }).toList();
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),

                      ScaleTransition(
                        scale: CurvedAnimation(
                          parent: ModalRoute.of(context)!.animation!,
                          curve: Interval(0.2, 1.0, curve: Curves.easeOutBack),
                        ),
                        child: _buildFilterOption(
                          title: 'المستحقين فقط ($dueCount)',
                          value: 1,
                          icon: Icons.warning_amber_rounded,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              selectedFilter = 1;
                              filteredInstallments = installments.where((i) {
                                final remaining = double.tryParse(i['remaining_amount'].toString()) ?? 0;
                                final dueDate = DateTime.tryParse(i['due_date'] ?? '');
                                final today = DateTime.now();
                                return dueDate != null && remaining > 0 && !dueDate.isAfter(today);
                              }).toList();
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),

                      ScaleTransition(
                        scale: CurvedAnimation(
                          parent: ModalRoute.of(context)!.animation!,
                          curve: Interval(0.4, 1.0, curve: Curves.easeOutBack),
                        ),
                        child: _buildFilterOption(
                          title: 'الاقساط المنتهية ($completedCount)',
                          value: 2,
                          icon: Icons.check_circle_outline,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              selectedFilter = 2;
                              filteredInstallments = installments.where((i) {
                                final remaining = double.tryParse(i['remaining_amount'].toString()) ?? 0;
                                return remaining <= 0;
                              }).toList();
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),

                      ScaleTransition(
                        scale: CurvedAnimation(
                          parent: ModalRoute.of(context)!.animation!,
                          curve: Interval(0.6, 1.0, curve: Curves.easeOutBack),
                        ),
                        child: _buildFilterOption(
                          title: 'المستحقين اليوم',
                          value: 3,
                          icon: Icons.today,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              selectedFilter = 3;
                              filteredInstallments = installments.where((i) {
                                final dueDate = DateTime.tryParse(i['due_date'] ?? '');
                                final today = DateTime.now();
                                return dueDate != null &&
                                    dueDate.year == today.year &&
                                    dueDate.month == today.month &&
                                    dueDate.day == today.day;
                              }).toList();
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),

                      ScaleTransition(
                        scale: CurvedAnimation(
                          parent: ModalRoute.of(context)!.animation!,
                          curve: Interval(0.7, 1.0, curve: Curves.easeOutBack),
                        ),
                        child: _buildFilterOption(
                          title: 'ترتيب الاسم تصاعدي من أ الى ي',
                          value: 4,
                          icon: Icons.sort_by_alpha,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              selectedFilter = 4;
                              filteredInstallments = List.from(installments)..sort((a, b) {
                                return (a['customer_name'] ?? '').toString().compareTo((b['customer_name'] ?? '').toString());
                              });
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),

                      ScaleTransition(
                        scale: CurvedAnimation(
                          parent: ModalRoute.of(context)!.animation!,
                          curve: Interval(0.8, 1.0, curve: Curves.easeOutBack),
                        ),
                        child: _buildFilterOption(
                          title: 'ترتيب الاسم تنازلي من ي الى أ',
                          value: 5,
                          icon: Icons.sort_by_alpha_outlined,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              selectedFilter = 5;
                              filteredInstallments = List.from(installments)..sort((a, b) {
                                return (b['customer_name'] ?? '').toString().compareTo((a['customer_name'] ?? '').toString());
                              });
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),

                      ScaleTransition(
                        scale: CurvedAnimation(
                          parent: ModalRoute.of(context)!.animation!,
                          curve: Interval(0.85, 1.0, curve: Curves.easeOutBack),
                        ),
                        child: _buildFilterOption(
                          title: 'ترتيب حسب تاريخ الاستحقاق من (الأقدم الى الأحدث)',
                          value: 6,
                          icon: Icons.calendar_view_day,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              selectedFilter = 6;
                              filteredInstallments = List.from(installments)..sort((a, b) {
                                final aDate = DateTime.tryParse(a['due_date'] ?? '') ?? DateTime.now();
                                final bDate = DateTime.tryParse(b['due_date'] ?? '') ?? DateTime.now();
                                return aDate.compareTo(bDate);
                              });
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),

                      ScaleTransition(
                        scale: CurvedAnimation(
                          parent: ModalRoute.of(context)!.animation!,
                          curve: Interval(0.9, 1.0, curve: Curves.easeOutBack),
                        ),
                        child: _buildFilterOption(
                          title: 'ترتيب حسب تاريخ الاستحقاق من (الأحدث الى الأقدم)',
                          value: 7,
                          icon: Icons.calendar_today,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              selectedFilter = 7;
                              filteredInstallments = List.from(installments)..sort((a, b) {
                                final aDate = DateTime.tryParse(a['due_date'] ?? '') ?? DateTime.now();
                                final bDate = DateTime.tryParse(b['due_date'] ?? '') ?? DateTime.now();
                                return bDate.compareTo(aDate);
                              });
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(height: 25),
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

  Widget _buildFilterOption({
    required String title,
    required int value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              selectedFilter = value;

              // تفعيل أو تعطيل التاريخ بناءً على الفلتر
              // التاريخ مفعل فقط عند "عرض الجميع" و "المستحقين"
              if (value == 0 || value == 1) {
                isDateFilterActive = true;
              } else {
                isDateFilterActive = false;
              }
            });

            _loadInstallments();
            Navigator.of(context).pop();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selectedFilter == value ? Colors.teal : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      color: selectedFilter == value ? Colors.teal : Colors.black,
                      fontWeight: selectedFilter == value ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                Radio<int>(
                  value: value,
                  groupValue: selectedFilter,
                  onChanged: (val) {
                    if (val == null) return;
                    HapticFeedback.lightImpact();
                    setState(() {
                      selectedFilter = val;

                      if (val == 0 || val == 1) {
                        isDateFilterActive = true;
                      } else {
                        isDateFilterActive = false;
                      }
                    });

                    _loadInstallments();
                    Navigator.of(context).pop();
                  },
                  activeColor: Colors.teal,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  final GlobalKey previewContainer = GlobalKey();

  void _showpayDialog() {
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
                  'assets/Animation/Animationperent.json',
                  height: 120,
                  repeat: false,
                ),
                const SizedBox(height: 12),
                const Text(
                  'تم حفظ القسط بنجاح !',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  ' هل تود بطباعة وصل استلام للعميل ؟',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop(); // إغلاق النافذة الحالية

                        if (lastInstallmentItem == null) return;

                        final data = lastInstallmentItem!;
                        final paidText = data['paidText'] ?? '';
                        final paid = double.tryParse(paidText.replaceAll(',', '')) ?? 0;
                        final remaining = double.tryParse(data['remaining_amount'].toString()) ?? 0;
                        final updatedRemaining = remaining - paid;

                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                          ),

                          builder: (_) => PrintBottomSheet(
                            id: data['customer_id'].toString(), // ✅ هنا تنقل الـ ID
                            customerName: data['customers']?['cust_name'] ?? 'غير معروف',
                            itemName: data['item_type'] ?? '',
                            totalAmount: data['sale_price'].toString(),
                            remainingAmount: updatedRemaining.toString(),
                            paidAmount: paidText,
                            paymentDate: data['start_date'] ?? '',
                            dueDate: data['due_date'] ?? '',
                          ),
                        );
                      },
                      icon: const Icon(Icons.print, color: Colors.white),
                      label: const Text('نعم، اطبع', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFCF274F),
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
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReceiveInstallmentSheet(Map<String, dynamic> item) {
    final formatter = intl.DateFormat('yyyy-MM-dd');
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final controllers = {
      'paymentDate': TextEditingController(text: formatter.format(DateTime.now())),
      'dueDate': TextEditingController(text: formatter.format(DateTime.now().add(Duration(days: 30)))),
      'monthlyAmount': TextEditingController(text: intl.NumberFormat('#,##0.##', 'ar').format(item['monthly_payment'])),
      'salePrice': TextEditingController(text: intl.NumberFormat('#,##0.##', 'ar').format(item['sale_price'])),
      'remainingamount': TextEditingController(text: intl.NumberFormat('#,##0.##', 'ar').format(item['remaining_amount'])),
      'note': TextEditingController(),
    };

    bool showNotes = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: DraggableScrollableSheet(
                initialChildSize: 0.85,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                snap: true,
                snapSizes: [0.5, 0.85],
                builder: (context, scrollController) {
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 400),
                    curve: Curves.easeInOutBack,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[900] : Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: Column(
                          children: [
                            // Handle indicator
                            GestureDetector(
                              onVerticalDragUpdate: (details) {
                                if (details.primaryDelta! > 10) {
                                  Navigator.pop(context);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12, bottom: 16),
                                child: Container(
                                  width: 80,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[400]!.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                )
                                    .animate(onPlay: (controller) => controller.repeat())
                                    .shimmer(delay: 1000.ms, duration: 2000.ms)
                                    .scaleXY(end: 1.1, duration: 1000.ms, curve: Curves.easeInOut),
                              ),
                            ),

                            // العنوان
                            Text(
                              'استلام قسط',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: theme.primaryColor,
                              ),
                            ),

                            SizedBox(height: 12),
                            Divider(height: 1, thickness: 1, indent: 40, endIndent: 40, color: Colors.grey[300]),

                            // محتوى النافذة
                            Expanded(
                              child: SingleChildScrollView(
                                controller: scrollController,
                                physics: ClampingScrollPhysics(),
                                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                                child: Column(
                                  children: [
                                    // معلومات العميل
                                    _buildAnimatedSection(
                                      index: 0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.05),
                                              blurRadius: 8,
                                              offset: Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        padding: EdgeInsets.all(3),
                                        child: Column(
                                          children: [
                                            _buildInfoRow(
                                              'اسم العميل',
                                              item['customers']?['cust_name'],
                                              icon: Icons.person_outline,
                                            ),
                                            SizedBox(height: 12),
                                            _buildInfoRow(
                                              'الصنف',
                                              item['item_type'],
                                              icon: Icons.category_outlined,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    SizedBox(height: 24),

                                    // المعلومات المالية
                                    _buildAnimatedSection(
                                      index: 1,
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _buildAmountCard(
                                                  context: context,
                                                  label: 'المبلغ الكلي',
                                                  amount: controllers['salePrice']!.text,
                                                  icon: Icons.receipt_long_outlined,
                                                  color: Colors.deepPurple,
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              Expanded(
                                                child: _buildAmountCard(
                                                  context: context,
                                                  label: 'المبلغ المتبقي',
                                                  amount: controllers['remainingamount']!.text,
                                                  icon: Icons.account_balance_wallet_outlined,
                                                  color: Colors.orange,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    SizedBox(height: 24),

                                    // تواريخ الدفع
                                    _buildAnimatedSection(
                                      index: 2,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: _buildDateFieldbtn(
                                              label: 'تاريخ الدفع',
                                              controller: controllers['paymentDate']!,
                                              icon: Icons.calendar_today_outlined,
                                              onTap: () => _selectDate(
                                                context,
                                                controllers['paymentDate']!,
                                                formatter,
                                                setModalState,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: _buildDateFieldbtn(
                                              label: 'تاريخ الاستحقاق',
                                              controller: controllers['dueDate']!,
                                              icon: Icons.event_available_outlined,
                                              onTap: () => _selectDate(
                                                context,
                                                controllers['dueDate']!,
                                                formatter,
                                                setModalState,
                                                initialDate: DateTime.now().add(Duration(days: 30)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    SizedBox(height: 24),

                                    // القسط الشهري
                                    _buildAnimatedSection(
                                      index: 3,
                                      child: _buildMonthlyPaymentCard(
                                        context: context,
                                        controller: controllers['monthlyAmount']!,
                                        onChanged: (_) => setModalState(() {}),
                                      ),
                                    ),

                                    SizedBox(height: 24),

                                    // خيار إضافة ملاحظات
                                    _buildAnimatedSection(
                                      index: 4,
                                      child: Row(
                                        children: [
                                          Checkbox(
                                            value: showNotes,
                                            onChanged: (value) {
                                              setModalState(() {
                                                showNotes = value!;
                                                if (!showNotes) {
                                                  controllers['note']!.clear();
                                                }
                                              });
                                            },
                                            activeColor: theme.primaryColor,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                          ),
                                          Text('إضافة ملاحظات', style: TextStyle(fontSize: 14)),
                                          Spacer(),
                                          if (showNotes)
                                            Icon(Icons.notes, color: theme.primaryColor),
                                        ],
                                      ),
                                    ),

                                    // مربع الملاحظات
                                    if (showNotes)
                                      _buildAnimatedSection(
                                        index: 5,
                                        child: Container(
                                          margin: EdgeInsets.only(top: 8),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.blue.withOpacity(0.1),
                                                blurRadius: 10,
                                                offset: Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: TextField(
                                            controller: controllers['note'],
                                            maxLines: 3,
                                            style: TextStyle(fontSize: 14),
                                            decoration: InputDecoration(
                                              labelText: 'ملاحظات',
                                              labelStyle: TextStyle(color: Colors.blue[600]),
                                              hintText: 'اكتب أي ملاحظات تخص هذه الدفعة...',
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(16),
                                                borderSide: BorderSide.none,
                                              ),
                                              filled: true,
                                              fillColor: isDarkMode ? Colors.grey[800] : Colors.blue[50],
                                              prefixIcon: Icon(Icons.note_add_outlined, color: Colors.blue),
                                              contentPadding: EdgeInsets.all(16),
                                            ),
                                          ),
                                        ),
                                      ),

                                    SizedBox(height: 28),

                                    // زر التأكيد
                                    _buildAnimatedSection(
                                      index: 6,
                                      child: Material(
                                        elevation: 6,
                                        borderRadius: BorderRadius.circular(20),
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(20),
                                          onTap: () async {
                                            final paidText = controllers['monthlyAmount']!.text.replaceAll(',', '');
                                            final remainingText = controllers['remainingamount']!.text.replaceAll(',', '');

                                            final paid = double.tryParse(paidText) ?? 0;
                                            final remaining = double.tryParse(remainingText) ?? 0;

                                            if (paid > remaining) {
                                              _showerrorDialogfild();
                                              return;
                                            }
                                            final prefs = await SharedPreferences.getInstance();
                                            final userId = prefs.getString('UserID');
                                            final DelegateId = prefs.getString('DelegateID');

                                            if (userId == null) {
                                              _showErrorSnackbar(context, 'لا يمكن تحديد هوية المستخدم.');
                                              return;
                                            }

                                            final amountPaidText = controllers['monthlyAmount']!.text.replaceAll(',', '');
                                            final amountPaid = double.tryParse(amountPaidText) ?? 0;
                                            final paymentDate = controllers['paymentDate']!.text;
                                            final notes = controllers['note']?.text ?? '';

                                            // جلب الإعدادات من قاعدة البيانات
                                            final settings = await Supabase.instance.client
                                                .from('user_settings')
                                                .select()
                                                .eq('user_id', userId)
                                                .maybeSingle();

                                            if (settings == null) {
                                              _showErrorSnackbar(context, 'لم يتم العثور على إعدادات المستخدم.');
                                              return;
                                            }

                                            if (settings['no_past_due_date'] == true) {
                                              final todayStr = DateTime.now().toIso8601String().split('T').first;
                                              if (paymentDate != todayStr) {
                                                _showerrorDialogdatesettingdate();
                                                return;
                                              }
                                            }

                                            if (settings['no_zero_amount'] == true && amountPaid <= 0) {
                                              _showerrorDialogdatesettingzero();
                                              return;
                                            }


                                            final insertData = {
                                              'customer_id': item['customer_id'],
                                              'installment_id': item['id'],
                                              'payment_date': paymentDate,
                                              'amount_paid': amountPaid,
                                              'notes': notes,
                                              'user_id': userId,
                                              'group_id': item['group_id'],
                                              'created_at': DateTime.now().toIso8601String(),
                                              'delegate_id': DelegateId,

                                            };

                                            try {
                                              await Supabase.instance.client.from('payments').insert(insertData);
                                              final newRemainingAmount = (item['remaining_amount'] ?? 0) - amountPaid;
                                              final dueDateText = controllers['dueDate']!.text;

                                              await Supabase.instance.client
                                                  .from('installments')
                                                  .update({
                                                'remaining_amount': newRemainingAmount,
                                                'due_date': dueDateText, // ✅ تحديث تاريخ الاستحقاق
                                              })
                                                  .eq('id', item['id'])
                                                  .eq('user_id', userId);

                                              // حفظ بيانات القسط الأخير للطباعة
                                              lastInstallmentItem = {
                                                ...item,
                                                'paidText': controllers['monthlyAmount']?.text ?? '0',
                                              };
                                              Navigator.of(context).pop();
                                              _showpayDialog();
                                              _loadInstallments();
                                            } catch (e) {
                                              _showErrorSnackbar(context, 'فشل في حفظ القسط، حاول مجددًا.');
                                            }
                                          },
                                          child: Ink(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(20),
                                              gradient: LinearGradient(
                                                colors: [
                                                  theme.primaryColor,
                                                  Color.lerp(theme.primaryColor, Colors.black, 0.2)!,
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: theme.primaryColor.withOpacity(0.4),
                                                  blurRadius: 10,
                                                  offset: Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            padding: EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.check_circle_outlined, color: Colors.white, size: 26),
                                                SizedBox(width: 12),
                                                Text(
                                                  'تأكيد استلام القسط',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    SizedBox(height: 30),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMonthlyPaymentCard({
    required BuildContext context,
    required TextEditingController controller,
    Function(String)? onChanged,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50,
            Colors.white,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 1,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            child: Icon(Icons.monetization_on_outlined,
                size: 60,
                color: Colors.blue.withOpacity(0.1)),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'القسط الشهري',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: controller,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    prefixIcon: Icon(Icons.attach_money,
                        color: Colors.blue[700],
                        size: 28),
                    prefixIconConstraints: BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().shake(delay: 300.ms, hz: 4, curve: Curves.easeInOut);
  }

  Widget _buildAmountCard({
    required BuildContext context,
    required String label,
    required String amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }
// دالة مساعدة لاختيار التاريخ
  Future<void> _selectDate(BuildContext context, TextEditingController controller,
      intl.DateFormat formatter, Function setModalState, {DateTime? initialDate}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Theme.of(context).cardColor,
              onSurface: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      controller.text = formatter.format(picked);
      setModalState(() {});
    }
  }

// دالة لعرض رسالة النجاح
  void _showSuccessSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Text('تم استلام القسط بنجاح'),
          ],
        ),
        backgroundColor: Colors.teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: Duration(seconds: 2),
        margin: EdgeInsets.all(20),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Color(0xFFCF274F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: Duration(seconds: 3),
        margin: EdgeInsets.all(20),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }

// بناء قسم متحرك
  Widget _buildAnimatedSection({required int index, required Widget child}) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(0, (0.5 + index * 0.1)),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: ModalRoute.of(context)!.animation!,
        curve: Interval(0.1 * index, 1.0, curve: Curves.easeOutBack),
      )),
      child: FadeTransition(
        opacity: ModalRoute.of(context)!.animation!,
        child: child,
      ),
    );
  }

// بناء صف معلومات مع أيقونة
  Widget _buildInfoRow(String label, String? value, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        children: [
          if (icon != null)
            Icon(icon, size: 20, color: Colors.grey[600]),
          if (icon != null) const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: value ?? 'غير محدد',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
// بناء حقل رقمي
  Widget _buildNumberField({
    required String label,
    required TextEditingController controller,
    IconData? icon,
    bool enabled = true,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      style: TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Theme.of(context).primaryColor,
              width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIcon: icon != null ? Icon(icon, size: 22) : null,
        filled: true,
        fillColor: enabled ? Colors.transparent : Colors.grey[100],
      ),
    );
  }

// بناء حقل تاريخ
  Widget _buildDateFieldbtn({
    required String label,
    required TextEditingController controller,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: IgnorePointer(
        child: TextField(
          controller: controller,
          style: TextStyle(fontSize: 15),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.grey[600]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: Theme.of(context).primaryColor,
                  width: 1.5),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            prefixIcon: icon != null ? Icon(icon, size: 22) : null,
          ),
        ),
      ),
    );
  }

// بناء بطاقة ربح
  Widget _buildProfitCard({
    required String title,
    required double value,
    required Color color,
    required IconData icon,
  }) {
    final formattedValue = intl.NumberFormat('#,##0', 'ar').format(value);

    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      color: color.withOpacity(0.1),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    formattedValue,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadInstallmentCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');
    if (userId == null) return;

    final response = await Supabase.instance.client
        .from('installments')
        .select('customer_id')
        .eq('user_id', userId);

    final List data = response;
    customerInstallmentCounts.clear();

    for (var item in data) {
      final id = item['customer_id'].toString(); // ✅ هنا التعديل
      customerInstallmentCounts[id] = (customerInstallmentCounts[id] ?? 0) + 1;
    }
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
              label: const Text(
                'بحث بالتاريخ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: _getButtonStyle(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FadeIn(
            delay: const Duration(milliseconds: 300),
            child: ElevatedButton.icon(
              onPressed: () {
                final allCount = installments.where((i) {
                  final remaining = double.tryParse(i['remaining_amount'].toString()) ?? 0;
                  return remaining > 0;
                }).length;

                final dueCount = installments.where((i) {
                  final remaining = double.tryParse(i['remaining_amount'].toString()) ?? 0;
                  final dueDate = DateTime.tryParse(i['due_date'] ?? '');
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  return dueDate != null && remaining > 0 && !dueDate.isAfter(today);
                }).length;

                final completedItems = installments.where((i) {
                  final val = i['remaining_amount'];
                  if (val == null) return false;

                  // محاولة التحويل حتى لو كان النص داخل "علامات اقتباس"
                  final raw = val.toString().replaceAll('"', '');
                  final remaining = double.tryParse(raw) ?? 0;

                  return remaining <= 0;
                }).toList();

                for (var i in installments) {
                  final val = i['remaining_amount'];
                  final raw = val.toString().replaceAll('"', '');
                  final remaining = double.tryParse(raw);

                  print('---');
                  print('ID: ${i['id']}');
                  print('remaining_amount (raw): $val');
                  print('remaining_amount (cleaned): $raw');
                  print('parsed double: $remaining');
                  print('==> isCompleted: ${remaining != null && remaining <= 0}');
                }

                final _completed = completedItems.length;



                setState(() {
                  completedCount = _completed;
                });

                _showFilterDialog(allCount, dueCount, _completed);
              },
              icon: const Icon(Icons.filter_list, size: 20, color: Colors.white,),
              label: const Text('التصفية', style: TextStyle(fontWeight: FontWeight.bold),),
              style: _getButtonStyle(),
            ),
          ),
        ),
      ],
    );
  }


  Future<void> _fetchUserGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');
    if (userId == null) return;

    final response = await Supabase.instance.client
        .from('groups')
        .select('group_name')
        .eq('user_id', userId);

    setState(() {
      userGroups = List<String>.from(response.map((e) => e['group_name']));
    });
  }


  Future<void> _fetchCustomersWithInstallments() async {
    await _loadInstallmentCounts(); // ✅ لا يسبب setState هنا

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');
    if (userId == null) return;

    List<Map<String, dynamic>> allCustomers = [];
    int page = 0;
    const int pageSize = 1000;
    bool hasMore = true;

    try {
      while (hasMore) {
        final response = await Supabase.instance.client
            .from('customers')
            .select('id, cust_name, spon_name')
            .eq('user_id', userId)
            .range(page * pageSize, (page + 1) * pageSize - 1)
            .order('created_at', ascending: false);

        final List<Map<String, dynamic>> batch = List<Map<String, dynamic>>.from(response);
        allCustomers.addAll(batch);

        if (batch.length < pageSize) {
          hasMore = false;
        } else {
          page++;
        }
      }

      setState(() {
        customers = allCustomers;
        filteredCustomers = allCustomers;
        // ✅ لا داعي لـ loading = false هنا إذا ما بدأت بـ true
      });
    } catch (e) {
      print('❌ فشل في تحميل العملاء: $e');
    }
  }

  Future<void> _saveInstallment() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لم يتم العثور على المستخدم.')),
      );
      return;
    }

    if (selectedCustomerId==null || _itemTypeController.text.trim().isEmpty ||
        _salePriceController.text.trim().isEmpty || _monthlyPaymentController.text.trim().isEmpty ||
        _remainingAmountController.text.trim().isEmpty || saleDate == null || dueDate == null) {
      _showerrorDialogdate();
      return;
    }

    // ✅ جلب إعدادات المستخدم
    final userSetting = await Supabase.instance.client
        .from('user_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (userSetting == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لم يتم العثور على إعدادات المستخدم')),
      );
      return;
    }

    final noDuplicate = userSetting['no_duplicate_installments'] ?? false;

    // ✅ التحقق من وجود قسط سابق لنفس العميل إذا كان `no_duplicate_installments` مفعلًا
    if (noDuplicate == true) {
      final duplicateCheck = await Supabase.instance.client
          .from('installments')
          .select()
          .eq('user_id', userId)
          .eq('customer_id', selectedCustomerId!)
          .neq('remaining_amount', 0)
          .limit(1)
          .maybeSingle();

      if (duplicateCheck != null) {
        _showerrorDialogdatesetting();
        return;
      }
    }

    String? imageBase64;
    if (_selectedImage != null) {
      final bytes = await _selectedImage!.readAsBytes();
      imageBase64 = base64Encode(bytes);
    }

    final salePrice = int.tryParse(_salePriceController.text.replaceAll(',', '')) ?? 0;
    final monthlyPayment = int.tryParse(_monthlyPaymentController.text.replaceAll(',', '')) ?? 0;
    final remainingAmount = int.tryParse(_remainingAmountController.text.replaceAll(',', '')) ?? 0;

    if (monthlyPayment > salePrice) {
      _showerrorDialogdatepayup();
      return;
    }

    final groupId = await _getGroupIdByName(selectedGroup, userId);

    final insertData = {
      'customer_id': selectedCustomerId,
      'sponsor_name': _guarantorController.text.trim(),
      'group_id': groupId,
      'item_type': _itemTypeController.text.trim(),
      'notes': _notesController.text.trim(),
      'image_base64': imageBase64,
      'sale_price': salePrice,
      'monthly_payment': monthlyPayment,
      'remaining_amount': remainingAmount,
      'start_date': saleDate!.toIso8601String(),
      'due_date': dueDate!.toIso8601String(),
      'user_id': userId,
    };

    try {
      await Supabase.instance.client.from('installments').insert(insertData);
      _showSuccessDialog();
    } catch (e) {
      _showerrorDialog();
    }
  }
  void _showerrorDialogfild() {
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
                  'تعذر حفظ القسط!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'لا يمكن استلام مبلغ اكبر من المبلغ المتبقي!',
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

  void _showerrorDialogdatesettingdate() {
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
                  'تعذر حفظ القسط!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'لا يمكن استلام القسط لان تاريخ الاستلام لا يساوي تاريخ اليوم .. يمكنك تغير هذه الخاصية من الاعدادت',
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

  void _showerrorDialogdatesettingzero() {
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
                  'تعذر حفظ القسط!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'لا يمكن استلام قسط بقيمة صفر .. يمكن تغيير هذه الخاصية من الاعدادات',
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
                  'تعذر حفظ القسط!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'لا يمكن اضافة قسط جديد قبل انتهاء القسط القديم .. يمكنك تعديل هذه الخاصية من الاعدادات',
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


  Future<bool> _showDeleteConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        int countdown = 5;
        bool isButtonEnabled = false;

        return StatefulBuilder(
          builder: (context, setState) {
            // بدء العد التنازلي مرة واحدة
            if (countdown == 5) {
              Timer.periodic(const Duration(seconds: 1), (timer) {
                if (countdown == 0) {
                  timer.cancel();
                  setState(() => isButtonEnabled = true);
                } else {
                  setState(() => countdown--);
                }
              });
            }

            return ZoomIn(
              duration: const Duration(milliseconds: 600),
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Lottie.asset(
                      'assets/Animation/AnimationDeletecust.json',
                      height: 130,
                      repeat: false,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'هل أنت متأكد؟',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'سيتم حذف هذا القسط نهائيًا بما في ذلك المبالغ المسددة لهذا القسط.\n\nهل ترغب في المتابعة؟',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text(
                            'إلغاء',
                            style: TextStyle(fontSize: 16, color: Colors.black87),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: isButtonEnabled
                              ? () => Navigator.of(context).pop(true)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isButtonEnabled
                                ? const Color(0xFFCF274F)
                                : Colors.grey,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Text(
                              isButtonEnabled
                                  ? 'نعم، احذف'
                                  : 'انتظر (${countdown})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
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
    ) ?? false;
  }

  void _showerrorDialogdate() {
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
                  'تعذر حفظ القسط!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'يرجى ادخال جميع الحقول الاساسية',
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
  void _showerrorDialogdatepayup() {
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
                  'تعذر حفظ القسط!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'لا يمكن ان يكون التسديد الشهري اكبر من مبلغ القسط',
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
  void _showerrorDialog() {
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
                  'تعذر حفظ القسط!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'يرجى التحقق من الاتصال بالإنترنت وصحة البيانات المدخلة، ثم إعادة المحاولة.\n\n'
                      'إذا استمرت المشكلة، لا تتردد بالتواصل مع الدعم الفني.',
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
  void _showSuccessDialog() {
    final AudioPlayer _audioPlayer = AudioPlayer();
    _audioPlayer.play(AssetSource('Sound/scsesssave.wav'));

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
                  'assets/Animation/Animationseccess.json',
                  height: 120,
                  repeat: false,
                ),
                const SizedBox(height: 12),
                const Text(
                  'تمت العملية بنجاح!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '🎉 تم تسجيل القسط \nحان وقت البدء بأستلام أول دفعة من العميل.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context); // يغلق الـ Dialog أولاً
                    Navigator.pop(context); // يغلق نافذة BottomSheet

                    // تحميل الأقساط من جديد
                    await _loadInstallments();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      'العودة إلى نافذة الاقساط',
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

  Future<String?> _getGroupIdByName(String? groupName, String userId) async {
    if (groupName == null) return null;
    final result = await Supabase.instance.client
        .from('groups')
        .select('id')
        .eq('group_name', groupName)
        .eq('user_id', userId)
        .limit(1);
    if (result != null && result.isNotEmpty) {
      return result.first['id'] as String?;
    }
    return null;
  }

  void _showCustomerSelectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        final dialogHeight = keyboardHeight > 0
            ? screenHeight - keyboardHeight - 40 // 40 هو الهامش العلوي
            : screenHeight * 0.7;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setState) {
              return Dialog(
                insetPadding: EdgeInsets.zero,
                alignment: Alignment.center,
                child: Container(
                  width: MediaQuery.of(context).size.width > 800 ? 900 : MediaQuery.of(context).size.width * 0.9,
                  height: dialogHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Material(
                    borderRadius: BorderRadius.circular(20),
                    child: MediaQuery.removeViewInsets(
                      context: context,
                      removeBottom: true,
                      child: Column(
                        children: [
                          // الجزء العلوي الثابت
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Text(
                                  "أختر العميل من القائمة",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    labelText: "البحث عن العملاء",
                                    labelStyle: TextStyle(color: Colors.blueGrey),
                                    prefixIcon: Icon(Icons.search, color: Colors.blueGrey),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.blue),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      filteredCustomers = customers
                                          .where((e) => e['cust_name']
                                          .toString()
                                          .toLowerCase()
                                          .contains(value.toLowerCase()))
                                          .toList();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),

                          // قائمة العملاء مع إمكانية التمرير
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: Duration(milliseconds: 300),
                              child: filteredCustomers.isEmpty
                                  ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.search_off, size: 50, color: Colors.grey),
                                    SizedBox(height: 10),
                                    Text(
                                      "لا توجد نتائج",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              )
                                  : Scrollbar(
                                child: ListView.separated(
                                  key: ValueKey<int>(filteredCustomers.length),
                                  itemCount: filteredCustomers.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    indent: 16,
                                    endIndent: 16,
                                    color: Colors.grey[200],
                                  ),
                                  itemBuilder: (context, index) {
                                    final customer = filteredCustomers[index];
                                    return AnimatedPadding(
                                      duration: Duration(milliseconds: 200),
                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(10),
                                          onTap: () {
                                            setState(() {
                                              print("تم اختيار العميل: ${customer['cust_name']} والكفيل: ${customer['spon_name']}");

                                              selectedCustomerId = customer['id'];
                                              selectedCustomerName = customer['cust_name'];
                                              _selectedCustomerController.text = customer['cust_name'];
                                              _guarantorController.text = customer['spon_name'] ?? ''; // 👈 تعبئة حقل الكفيل
                                            });
                                            Navigator.pop(context);
                                          },

                                          splashColor: Colors.blue[100],
                                          highlightColor: Colors.blue[50],
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: ListTile(
                                              leading: Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: Colors.blue[50],
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.person_outline,
                                                  color: Colors.blue[700],
                                                ),
                                              ),
                                              title: Text(
                                                customer['cust_name'],
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                  color: customerInstallmentCounts.containsKey(customer['id']) ? Colors.green : Color(0xFFCF274F),

                                                ),
                                              ),
                                              trailing: Icon(
                                                Icons.arrow_forward_ios,
                                                size: 16,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),);
            },
          ),
        );
      },
    );
  }

  void _showInstallmentBottomSheet() {
    int currentStep = 0;
    saleDate = DateTime.now();
    dueDate = DateTime.now().add(Duration(days: 30));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, localSetState) {
              void validateInputsLocal() {
                localSetState(() {

                  isNextEnabled = _selectedCustomerController.text.trim().isNotEmpty &&
                      _itemTypeController.text.trim().isNotEmpty;
                });
              }

              final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
              final screenHeight = MediaQuery.of(context).size.height;

              return AnimatedPadding(
                padding: EdgeInsets.only(
                  bottom: keyboardHeight,
                  top: keyboardHeight > 0 ? 20 : 0,
                ),
                duration: Duration(milliseconds: 300),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: screenHeight * 0.9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                        offset: Offset(0, -5),
                      )
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Handle indicator
                        Container(
                          width: 50,
                          height: 5,
                          margin: EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),

                        // Title
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            "إضافة قسط جديد",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey[800],
                            ),
                          ),
                        ),

                        SizedBox(height: 16),

                        // Progress indicator
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: LinearProgressIndicator(
                            value: (currentStep + 1) / 2,
                            backgroundColor: Colors.grey[200],
                            color: Color(0xFF42A5F5),
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),

                        SizedBox(height: 16),

                        Flexible( // ✅ بدل Expanded
                          child: SingleChildScrollView(
                            physics: BouncingScrollPhysics(),
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (currentStep == 0) ...[
                                  GestureDetector(
                                    onTap: _showCustomerSelectionDialog,
                                    child: AbsorbPointer(
                                      child: TextFormField(
                                        controller: _selectedCustomerController,
                                        decoration: InputDecoration(
                                          labelText: "اسم العميل",
                                          hintText: "اختر العميل",
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                          suffixIcon: Icon(Icons.search, color: Color(0xFF42A5F5)),
                                          filled: true,
                                          fillColor: Colors.grey[50],
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 16),

                                  _buildGuarantorFieldWithGroupDropdown(),
                                  SizedBox(height: 16),

                                  TextFormField(
                                    controller: _itemTypeController,
                                    onChanged: (_) => validateInputsLocal(),
                                    decoration: InputDecoration(
                                      labelText: "نوع الصنف المباع",
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      prefixIcon: Icon(Icons.category, color: Color(0xFF42A5F5)),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                    ),
                                    maxLines: 2,
                                  ),

                                  SizedBox(height: 16),

                                  _buildTextField("ملاحظات القسط", controller: _notesController, icon: Icons.note, maxLines: 2),
                                  SizedBox(height: 16),

                                  // Image Picker Button
                                  AnimatedContainer(
                                    duration: Duration(milliseconds: 300),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: _selectedImage != null
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.blueAccent.withOpacity(0.1),
                                      border: Border.all(
                                        color: _selectedImage != null
                                            ? Colors.teal
                                            : Color(0xFF42A5F5),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () async {
                                          final image = await _showImagePickerBottomSheet(context);

                                          localSetState(() {
                                            _selectedImage = image; // ✅ مهم
                                          });

                                        },
                                        child: Padding(
                                          padding: EdgeInsets.all(12),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              if (_selectedImage != null) ...[
                                                Icon(Icons.check_circle, color: Colors.teal),
                                                SizedBox(width: 8),
                                                Text(
                                                  "تم اختيار الصورة",
                                                  style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                                                ),
                                              ] else ...[
                                                Icon(Icons.image, color: Color(0xFF42A5F5)),
                                                SizedBox(width: 8),
                                                Text(
                                                  "إضافة صورة للصنف",
                                                  style: TextStyle(color: Color(0xFF42A5F5), fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  // Only "سعر البيع" field
                                  _buildAmountField("المبلغ الكلي", icon: Icons.attach_money),
                                  SizedBox(height: 12),
                                  // Only "التسديد الشهري" field
                                  _buildAmountField("التسديد الشهري", icon: Icons.calendar_today, readOnly: true),
                                  SizedBox(height: 12),
                                  _buildAmountField("الباقي", icon: Icons.money_off, readOnly: true),
                                  SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDateField2("تاريخ القسط", saleDate,
                                                (date) => localSetState(() => saleDate = date),
                                            icon: Icons.date_range),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: _buildDateField2("الاستحقاق", dueDate,
                                                (date) => localSetState(() => dueDate = date),
                                            icon: Icons.event_available),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // Navigation buttons
                        Container(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (currentStep > 0)
                                ElevatedButton(
                                  onPressed: () => localSetState(() => currentStep--),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[200],
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text("رجوع", style: TextStyle(color: Colors.blueGrey[800])),
                                )
                              else
                                SizedBox(width: 80),
                              ElevatedButton(
                                onPressed: isNextEnabled && !_isSaving
                                    ? () async {
                                  if (currentStep == 0) {
                                    localSetState(() => currentStep = 1);
                                  } else {
                                    localSetState(() => _isSaving = true);
                                    await _saveInstallment();
                                    localSetState(() => _isSaving = false);
                                  }
                                }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isNextEnabled ? Colors.deepPurple: Colors.grey[700],
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  minimumSize: Size(160, 48),
                                ),
                                child: _isSaving
                                    ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    strokeWidth: 2,
                                  ),
                                )
                                    : Text(
                                  currentStep == 0 ? "التالي" : "حفظ القسط",
                                  style: TextStyle(color: Colors.white, fontSize: 18),
                                ),
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
          ),
        );
      },
    );
  }
  Future<XFile?> _showImagePickerBottomSheet(BuildContext context) async {
    return await showModalBottomSheet<XFile?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 5,
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.camera_alt, color: Colors.blueAccent),
                  title: Text("التقاط صورة بالكاميرا"),
                  onTap: () async {
                    final image = await _picker.pickImage(source: ImageSource.camera);
                    Navigator.pop(context, image);
                  },
                ),
                Divider(),
                ListTile(
                  leading: Icon(Icons.photo, color: Colors.blueAccent),
                  title: Text("اختيار من الاستوديو"),
                  onTap: () async {
                    final image = await _picker.pickImage(source: ImageSource.gallery);
                    Navigator.pop(context, image);
                  },
                ),
                Divider(),
                ListTile(
                  leading: Icon(Icons.delete, color: Color(0xFFCF274F)),
                  title: Text("مسح الصورة المختارة", style: TextStyle(color: Color(0xFFCF274F))),
                  onTap: () {
                    Navigator.pop(context, null); // فقط أرجع null
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField(String label, {IconData? icon, int maxLines = 1, TextEditingController? controller}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blueAccent),
        ),
        prefixIcon: icon != null ? Icon(icon, color: Colors.blueAccent) : null,
        filled: true,
        fillColor: Colors.grey[50],
      ),
      maxLines: maxLines,
    );
  }

  void _validateSalePrice() {
    final salePriceText = _salePriceController.text.replaceAll(',', '');

    final salePrice = int.tryParse(salePriceText) ?? 0;

  }

  Widget _buildAmountField(String label, {IconData? icon, bool readOnly = false}) {
    TextEditingController controller;

    if (label == "المبلغ الكلي") {
      controller = _salePriceController;
      return ValueListenableBuilder<bool>(
        valueListenable: isSalePriceValid,
        builder: (context, isValid, child) {
          return TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              ThousandsSeparatorInputFormatter(),
            ],
            onChanged: (_) {
              _validateSalePrice();
              final salePrice = int.tryParse(controller.text.replaceAll(',', '')) ?? 0;
              _remainingAmountController.text = intl.NumberFormat.decimalPattern().format(salePrice);
            },
            decoration: InputDecoration(
              labelText: "المبلغ الكلي",
              labelStyle: TextStyle(color: isValid ? Colors.black : Color(0xFFCF274F)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isValid ? Colors.grey[300]! : Color(0xFFCF274F)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isValid ? Colors.grey[300]! : Color(0xFFCF274F)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isValid ? Colors.blueAccent : Color(0xFFCF274F)),
              ),
              prefixIcon: Icon(Icons.attach_money, color: isValid ? Colors.blueAccent : Color(0xFFCF274F)),
              suffixText: "د.ع",
              suffixStyle: TextStyle(color: isValid ? Colors.blueAccent : Color(0xFFCF274F)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          );
        },
      );
    } else if (label == "الباقي") {
      controller = _remainingAmountController;
    } else if (label == "التسديد الشهري") {
      controller = _monthlyPaymentController;
      return TextFormField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          ThousandsSeparatorInputFormatter(),
        ],
        onChanged: (value) {
          final monthly = int.tryParse(value.replaceAll(',', '')) ?? 0;
          final salePrice = int.tryParse(_salePriceController.text.replaceAll(',', '')) ?? 0;

          if (monthly > salePrice) {
            // إذا تجاوز المبلغ الكلي، نرجع القيمة القديمة
            final corrected = salePrice;
            controller.text = intl.NumberFormat.decimalPattern().format(corrected);
            controller.selection = TextSelection.collapsed(offset: controller.text.length);

          }
        },
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          suffixText: "د.ع",
          filled: true,
          fillColor: Colors.grey[50],
        ),
      );
    } else {
      controller = TextEditingController();
    }

    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        ThousandsSeparatorInputFormatter(),
      ],
      onChanged: readOnly
          ? null
          : (_) {
        if (label == "المبلغ الكلي") _validateSalePrice();
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: label == "المبلغ الكلي" && !isSalePriceValid.value
            ? TextStyle(color: Color(0xFFCF274F))
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: label == "المبلغ الكلي" && !isSalePriceValid.value ? Color(0xFFCF274F): Colors.grey[300]!,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: label == "المبلغ الكلي" && !isSalePriceValid.value ? Color(0xFFCF274F) : Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: label == "المبلغ الكلي" && !isSalePriceValid.value? Color(0xFFCF274F): Colors.blueAccent,
          ),
        ),
        prefixIcon: icon != null
            ? Icon(icon, color: label == "المبلغ الكلي" && !isSalePriceValid.value ? Color(0xFFCF274F): Colors.blueAccent)
            : null,
        suffixText: label == "عدد الأشهر" ? null : "د.ع",
        suffixStyle: TextStyle(
          color: label == "المبلغ الكلي" && !isSalePriceValid.value
              ? Color(0xFFCF274F)
              : Colors.blueAccent,
        ),
        filled: true,
        fillColor: readOnly ? Colors.grey[200] : Colors.grey[50],
      ),
    );
  }

  Widget _buildDateField2(String label, DateTime? date, Function(DateTime?) onChanged, {IconData? icon}) {
    return TextFormField(
      readOnly: true,
      controller: TextEditingController(
        text: date != null ? intl.DateFormat('yyyy-MM-dd').format(date) : '',
      ),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blueAccent),
        ),
        prefixIcon: icon != null ? Icon(icon, color: Colors.blueAccent) : null,
        filled: true,
        fillColor: Colors.grey[50],
      ),
      onTap: () async {
        final selectedDate = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (selectedDate != null) {
          onChanged(selectedDate);
        }
      },
    );
  }
  Widget _buildGuarantorFieldWithGroupDropdown() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Expanded(
              flex: 4, // 👈 حجم أصغر للكفيل
              child: TextField(
                controller: _guarantorController,
                decoration: const InputDecoration(
                  labelText: "اسم الكفيل",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 6), // 👈 تقليل المسافة قليلاً
            Expanded(
              flex: 5,
              child: Directionality( // 👈 يؤثر على الحقل المختار أيضًا
                textDirection: TextDirection.rtl, // 👈 من اليسار إلى اليمين
                child: DropdownButtonFormField<String>(
                  value: selectedGroup,
                  decoration: const InputDecoration(
                    labelText: "المجموعة",
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text("بدون مجموعة", style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                    ...userGroups.map((group) {
                      return DropdownMenuItem<String>(
                        value: group,
                        child: Align(
                          alignment: Alignment.centerRight, // 👈 لجعل النص يبدأ من اليسار
                          child: Text(
                            group,
                            textDirection: TextDirection.ltr,
                          ),
                        ),                      );
                    }).toList(),
                  ],





                  onChanged: (value) {
                    setState(() {
                      selectedGroup = value;
                    });
                  },
                ),
              ),
            ),


          ],
        );
      },
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
              child: _buildInstallmentsList(),
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

            // Search row (ينزلق ثانياً)
            FadeInDown(
              from: 20,
              delay: const Duration(milliseconds: 100),
              child: _buildSearchRow(),
            ),

            const SizedBox(height: 8),


            if (searchType == 'group_id')
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _loadUserGroups(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return CircularProgressIndicator()
                          .animate()
                          .scale(duration: 500.ms)
                          .shimmer(delay: 200.ms);
                    }

                    final groups = snapshot.data!;

                    return Animate(
                      effects: [
                        FadeEffect(duration: 500.ms),
                        ScaleEffect(begin: Offset(0.95, 0.95), end: Offset(1, 1)),
                      ],
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'اختر المجموعة',
                          labelStyle: TextStyle(
                            fontFamily: 'Tajawal', // ← تحديد نوع الخط يدويًا

                            color: Colors.deepPurple,
                            fontWeight: FontWeight.bold,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          prefixIcon: Icon(Icons.group, color: Colors.deepPurple),
                        ),
                        value: selectedGroup,
                        onChanged: (val) {
                          setState(() {
                            selectedGroup = val!;
                            searchQuery = ''; // avoid showing the UUID
                          });
                          _loadInstallments();
                        },
                        items: [
                          DropdownMenuItem<String>(
                            value: 'none',
                            child: Text(
                              'لا توجد مجموعة',  style: const TextStyle(fontFamily: 'Tajawal',color: Colors.grey),

                            ),
                          ),
                          ...groups.map((g) {
                            return DropdownMenuItem<String>(
                              value: g['id'].toString(),
                              child: Text(
                                g['group_name'],
                                style: const TextStyle(fontFamily: 'Tajawal'),
                              ),
                            );
                          }).toList(),
                        ],
                        icon: Icon(Icons.arrow_drop_down_circle, color: Colors.deepPurple),
                        elevation: 8,
                        borderRadius: BorderRadius.circular(12),
                        style: TextStyle(
                          color: Colors.deepPurple[800],
                          fontSize: 16,
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),

            // Action buttons (ينزلق آخراً)
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

  Widget _buildSearchRow() {
    return Row(
      children: [
        Expanded(
          child: FadeInDown(  // استبدل ScaleTransition بـ FadeInDown
            duration: Duration(milliseconds: 800),
            child: TextField(
              controller: _searchController,
              textDirection: TextDirection.rtl,
              readOnly: searchType == 'group_id',
              style: TextStyle(
                fontSize: 15,
                color: searchType == 'group_id' ? Colors.grey : Colors.black,
              ),
              decoration: InputDecoration(
                hintText: 'بحث حسب $searchLabel',
                prefixIcon: const Icon(Icons.search, color: Colors.black),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: searchType == 'group_id' ? Colors.grey[200] : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
              onChanged: (query) {
                if (searchType != 'group_id') {
                  setState(() {
                    searchQuery = query;
                  });
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        FadeIn(
          duration: Duration(milliseconds: 1000),
          child: _buildSearchTypeMenu(),
        ),
      ],
    );
  }

  Widget _buildSearchTypeMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.filter_alt, color: Colors.black),
      onSelected: (value) {
        HapticFeedback.lightImpact();
        setState(() {
          searchType = value;
          searchLabel = _getSearchLabel(value);
        });
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'cust_name',
          child: Text('بحث بالاسم'),
        ),
        const PopupMenuItem(
          value: 'item_type',
          child: Text('بحث بالصنف'),
        ),
        const PopupMenuItem(
          value: 'group_id',
          child: Text('بحث بالمجموعة'),
        ),
        const PopupMenuItem(
          value: 'sponsor_name',
          child: Text('بحث بالكفيل'),
        ),
        const PopupMenuItem(
          value: 'notes',
          child: Text('بحث بالملاحظات'),
        ),
      ],
    );
  }

  String _getSearchLabel(String value) {
    switch (value) {
      case 'cust_name':
        return 'اسم العميل';
      case 'item_type':
        return 'اسم الصنف';
      case 'sponsor_name':
        return 'اسم الكفيل';
      case 'group_id':
        return 'اسم المجموعة';
      case 'notes':
        return 'الملاحظات';
      default:
        return 'البحث';
    }
  }


  // بحث بالتاريخ مع فلترة المجموعة إذا لزم الأمر

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
  Widget _buildInstallmentsList() {
    final filteredInstallments = installments.where((i) {
      dynamic value;

      if (searchType == 'cust_name') {
        value = i['customers']?['cust_name'];
      } else {
        value = i[searchType];
      }

      bool matchesSearch;
      if (searchType == 'group_id') {
        if (selectedGroup == 'none') {
          matchesSearch = i['group_id'] == null || i['group_id'].toString().isEmpty;
        } else {
          matchesSearch = i['group_id'].toString() == selectedGroup;
        }
      } else {
        matchesSearch = value != null &&
            value.toString().toLowerCase().contains(searchQuery.toLowerCase());
      }
      final remaining = double.tryParse(i['remaining_amount'].toString()) ?? 0;
      final months = int.tryParse(i['months'].toString()) ?? 0;
      final paidMonths = int.tryParse(i['paid_months']?.toString() ?? '0') ?? 0;

      bool matchesFilter = true;

      if (selectedFilter == 1) {
        final dueDate = DateTime.tryParse(i['due_date'] ?? '');
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        matchesFilter = dueDate != null && remaining > 0 && !dueDate.isAfter(today);
      } else if (selectedFilter == 2) {
        matchesFilter = remaining <= 0 || paidMonths >= months;
      }
      // مستحقين اليوم
      else if (selectedFilter == 3) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final dueDate = DateTime.tryParse(i['due_date'] ?? '');
        matchesFilter = dueDate != null &&
            DateTime(dueDate.year, dueDate.month, dueDate.day).isAtSameMomentAs(today);
      }

      return matchesSearch && matchesFilter;
    }).toList();

    // إضافة الترتيب حسب الفلتر المختار
    if (selectedFilter == 4) {
      filteredInstallments.sort((a, b) =>
          (a['customers']?['cust_name'] ?? '').toString().compareTo(
              (b['customers']?['cust_name'] ?? '').toString()));
    } else if (selectedFilter == 5) {
      filteredInstallments.sort((a, b) =>
          (b['customers']?['cust_name'] ?? '').toString().compareTo(
              (a['customers']?['cust_name'] ?? '').toString()));
    } else if (selectedFilter == 6) {
      filteredInstallments.sort((a, b) {
        final dateA = DateTime.tryParse(a['due_date'] ?? '') ?? DateTime(2100);
        final dateB = DateTime.tryParse(b['due_date'] ?? '') ?? DateTime(2100);
        return dateA.compareTo(dateB);
      });
    } else if (selectedFilter == 7) {
      filteredInstallments.sort((a, b) {
        final dateA = DateTime.tryParse(a['due_date'] ?? '') ?? DateTime(2100);
        final dateB = DateTime.tryParse(b['due_date'] ?? '') ?? DateTime(2100);
        return dateB.compareTo(dateA);
      });
    }

    if (filteredInstallments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/Animation/Animationempty.json',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            Text(
              'لا توجد نتائج في الوقت الحالي ',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: filteredInstallments.length,
      itemBuilder: (context, index) {
        final item = filteredInstallments[index];
        final cardId = item['id'];

        return Slidable(
          key: ValueKey(cardId),
          endActionPane: ActionPane(
            motion: const StretchMotion(),
            extentRatio: 0.6,
            children: [
              CustomSlidableAction(
                onPressed: (_) => _showReceiveInstallmentSheet(item),
                backgroundColor: Colors.teal,
                padding: EdgeInsets.zero,
                foregroundColor: Colors.white,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.monetization_on_outlined, color: Colors.white, size: 20),
                    SizedBox(height: 6),
                    Text(
                      'استلام قسط',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              SizedBox(width: 8),
              CustomSlidableAction(
                onPressed: (_) async {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ShowDetiles(installment: item),
                    ),
                  );
                },
                backgroundColor: Colors.blue.shade700,
                padding: EdgeInsets.zero,
                foregroundColor: Colors.white,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.open_in_new, color: Colors.white, size: 20),
                    SizedBox(height: 6),
                    Text(
                      'تفاصيل',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),            ],
          ),
          startActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.25,
            children: [
              CustomSlidableAction(
                onPressed: (_) async {
                  final remaining = double.tryParse(item['remaining_amount'].toString()) ?? 0;

                  if (remaining > 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('❌ لا يمكن حذف هذا القسط لأنه يحتوي على مبلغ متبقي.')),
                    );
                    return;
                  }

                  _showPasswordVerificationDialog(context, () async {
                    final confirm = await _showDeleteConfirmationDialog(context);
                    if (!confirm) return;

                    final prefs = await SharedPreferences.getInstance();
                    final userId = prefs.getString('UserID');
                    final installmentId = item['id'];
                    if (userId == null) return;

                    try {
                      // 1. نسخ الدفعات إلى جدول السلة
                      final payments = await Supabase.instance.client
                          .from('payments')
                          .select()
                          .eq('installment_id', installmentId)
                          .eq('user_id', userId);

                      for (var payment in payments) {
                        await Supabase.instance.client.from('payments_delete').insert({
                          'id': payment['id'],
                          'customer_name': item['customers']?['cust_name'],
                          'item_type': item['item_type'],
                          'payment_date': payment['payment_date'],
                          'amount_paid': payment['amount_paid'],
                          'notes': payment['notes'],
                          'user_id': userId,
                          'created_at': payment['created_at'],
                          'group_name': item['groups']?['group_name'],
                          'delegate_id': payment['delegate_id'],
                          'date_delete': DateTime.now().toIso8601String(),
                          'type': 'حذف القسط بالكامل',
                        });
                      }

                      // 2. حذف الدفعات الأصلية
                      await Supabase.instance.client
                          .from('payments')
                          .delete()
                          .eq('installment_id', installmentId)
                          .eq('user_id', userId);

                      // 3. جلب صورة القسط
                      final imageResult = await Supabase.instance.client
                          .from('installments')
                          .select('image_base64')
                          .eq('id', installmentId)
                          .eq('user_id', userId)
                          .maybeSingle();

                      final imageBase64 = imageResult?['image_base64'];

                      // 4. نسخ القسط إلى جدول الحذف
                      await Supabase.instance.client.from('installments_delete').insert({
                        'id': item['id'],
                        'customer_name': item['customers']?['cust_name'],
                        'sponsor_name': item['sponsor_name'],
                        'group_name': item['groups']?['group_name'],
                        'item_type': item['item_type'],
                        'notes': item['notes'],
                        'sale_price': item['sale_price'],
                        'monthly_payment': item['monthly_payment'],
                        'remaining_amount': item['remaining_amount'],
                        'start_date': item['start_date'],
                        'due_date': item['due_date'],
                        'user_id': userId,
                        'created_at': item['created_at'],
                        'image_base64': imageBase64,
                        'date_delete': DateTime.now().toIso8601String(),
                      });

                      // 5. حذف القسط من الجدول الأصلي
                      await Supabase.instance.client
                          .from('installments')
                          .delete()
                          .match({'id': installmentId, 'user_id': userId});

                      await _loadInstallments();

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم حذف القسط وكل دفعاته بنجاح'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      print('❌ فشل في حذف القسط: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('فشل في حذف القسط: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  });
                },
                backgroundColor: Color(0xFFCF274F),
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.delete, color: Colors.white, size: 20),
                    SizedBox(height: 6),
                    Text(
                      'حذف',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ],
          ),
          child: _buildInstallmentCard(item, cardId),
        );
      },
    );
  }}
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final intl.NumberFormat _formatter = intl.NumberFormat.decimalPattern();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // إزالة جميع الأحرف غير الرقمية
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // تنسيق الرقم
    String formatted = _formatter.format(int.parse(digitsOnly));

    // حساب موقع المؤشر الجديد
    int selectionIndex = formatted.length;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
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
                  const Text('أدخل كلمة مرور حسابك لتعديل القسط'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                          final userId = prefs.getString('UserID');
                          if (userId == null) return;

                          final password = passwordController.text.trim();
                          final digest = sha256.convert(utf8.encode(password)).toString();

                          final user = await Supabase.instance.client
                              .from('users_full_profile')
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