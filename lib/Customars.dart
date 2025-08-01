import 'dart:convert';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart'  as intl;
import 'AddCustomerScreen.dart';
import 'CustomerAttachmentsScreen.dart';
import 'EditeCustomerScreen.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'dart:ui';

class Customars extends StatefulWidget {
  const Customars({super.key});

  @override
  _Customars createState() => _Customars();
}

class _Customars extends State<Customars> with SingleTickerProviderStateMixin {  List<Map<String, dynamic>> customers = [];
  bool loading = true;
  String selectedType = 'حساب عميل';
  String searchQuery = '';
  Map<String, int> customerInstallmentCounts = {};
  int customerCount = 0;
  int supplierCount = 0;
  late AnimationController _controller;
  late Animation<double> _animation;
bool _loadingAttachments = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
    final String id = item['customer_id'];
    customerInstallmentCounts[id] = (customerInstallmentCounts[id] ?? 0) + 1;
  }
}
  Future<void> _loadCustomers() async {
    setState(() => loading = true);
    await _loadInstallmentCounts();

    SharedPreferences prefs = await SharedPreferences.getInstance();
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
            .select('id, cust_name, cust_phone, cust_age, cust_address, cust_card_number, cust_note, spon_name, spon_phone, spon_address, spon_kinship, spon_card_number, created_at, type')
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

      // ✅ احسب العدد بشكل صحيح
      customerCount = allCustomers.where((c) => c['type'] == 'حساب عميل').length;
      supplierCount = allCustomers.where((c) => c['type'] == 'حساب مورد').length;

      // ✅ فلترة العملاء المعروضين فقط بناءً على selectedType
      customers = allCustomers
          .where((cust) =>
      (cust['cust_name']?.toString().contains(searchQuery) ?? true) &&
          cust['type'] == selectedType)
          .toList();

      setState(() => loading = false);
    } catch (e) {
      print('❌ فشل في تحميل العملاء: $e');
      setState(() => loading = false);
    }
  }

  Future<bool> _showDeleteConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
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
                    color:  Colors.teal,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'سيتم حذف هذا الحساب نهائيًا إذا لم يكن مرتبطًا بأقساط.\n\nهل ترغب في المتابعة؟',
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
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFCF274F),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          'نعم، احذف',
                          style: TextStyle(
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
    ) ?? false;
  }

  void _onSearchChanged(String value) {
    setState(() {
      searchQuery = value;
    });
    _loadCustomers();
  }


Future<void> _showBottomSheetCreateAccount(BuildContext context, String customerId) async {
  final _usernameController = TextEditingController();
  bool isActive = false;
  final ValueNotifier<Map<String, dynamic>?> matchedCustomer = ValueNotifier(null);
  final ValueNotifier<bool> isLoading = ValueNotifier(false);

  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('UserID');
  if (userId == null) return;

  // تحقق من الربط المسبق بين العميل والمستخدم
  final existingLink = await Supabase.instance.client
      .from('customer_links')
      .select('customer_profile_id, Customer_full_profile(display_name, phone, email)')
      .eq('customer_table_id', customerId)
      .eq('user_id', userId)
      .maybeSingle();

  if (existingLink != null) {
    final profile = existingLink['Customer_full_profile'];
    matchedCustomer.value = {
      'id': existingLink['customer_profile_id'],
      'display_name': profile['display_name'],
      'phone': profile['phone'],
      'email': profile['email'],
      'alreadyLinked': true,
    };
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    transitionAnimationController: AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: Navigator.of(context),
    ),
    builder: (context) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: AnimatedPadding(
            padding: MediaQuery.of(context).viewInsets,
            duration: const Duration(milliseconds: 100),
            child: Container(
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    const Text(
                      'ربط الحساب للعميل',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: 'البريد الإلكتروني',
                              prefixIcon: Icon(Icons.email, color: Colors.teal),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ValueListenableBuilder<bool>(
                          valueListenable: isLoading,
                          builder: (_, loading, __) {
                            return loading
                                ? CircularProgressIndicator()
                                : IconButton(
                              icon: Icon(Icons.search, color: Colors.teal),
                              onPressed: () async {
                                final email = _usernameController.text.trim();
                                if (email.isEmpty) return;
                                isLoading.value = true;
                                try {
                                  final response = await Supabase.instance.client
                                      .from('Customer_full_profile')
                                      .select('id, display_name, phone, email')
                                      .eq('email', email)
                                      .maybeSingle();

                                  if (response != null) {
                                    final link = await Supabase.instance.client
                                        .from('customer_links')
                                        .select()
                                        .eq('customer_table_id', customerId)
                                        .eq('customer_profile_id', response['id'])
                                        .maybeSingle();

                                    matchedCustomer.value = {
                                      ...response,
                                      'alreadyLinked': link != null,
                                    };
                                  } else {
                                    matchedCustomer.value = null;
                                  }
                                } catch (e) {
                                  matchedCustomer.value = null;
                                  print('❌ خطأ في البحث: $e');
                                } finally {
                                  isLoading.value = false;
                                }
                              },
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    ValueListenableBuilder<Map<String, dynamic>?>(
                      valueListenable: matchedCustomer,
                      builder: (_, customer, __) {
                        if (customer == null) return const SizedBox();
                        return Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.teal),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('الاسم: ${customer['display_name'] ?? ''}', style: TextStyle(fontSize: 16)),
                              const SizedBox(height: 5),
                              Text('الهاتف: ${customer['phone'] ?? ''}', style: TextStyle(fontSize: 16)),
                              const SizedBox(height: 10),
                              if (customer['alreadyLinked'] == true)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '⚠️ هذا الحساب مرتبط مسبقًا.',
                                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 10),
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('تأكيد الحذف'),
                                            content: const Text('هل أنت متأكد من رغبتك في إزالة الربط مع هذا الحساب؟'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: const Text('إلغاء'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                child: const Text('حذف'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm == true) {
                                          await Supabase.instance.client
                                              .from('customer_links')
                                              .delete()
                                              .eq('customer_table_id', customerId)
                                              .eq('customer_profile_id', customer['id'])
                                              .eq('user_id', userId);

                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Text('تم إزالة الربط بنجاح'),
                                              backgroundColor: Colors.red,
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.delete_forever,color: Colors.white,),
                                      label: const Text('إزالة الربط',style: TextStyle(color: Colors.white,fontSize: 14,fontWeight: FontWeight.bold),),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    await Supabase.instance.client.from('customer_links').insert({
                                      'customer_table_id': customerId,
                                      'customer_profile_id': customer['id'],
                                      'user_id': userId,
                                      'is_active': isActive,
                                    });

                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('تم ربط الحساب بنجاح'),
                                        backgroundColor: Colors.teal,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.link),
                                  label: const Text('ربط الحساب'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                        shadowColor: Colors.teal.withOpacity(0.4),
                      ),
                      child: const Text(
                        'إغلاق',
                        style: TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
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
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        title: FadeIn(
          child: Text(
            'إدارة ${selectedType == 'حساب عميل' ? 'العملاء' : 'الموردين'}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Colors.white,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(
                        backgroundColor: Colors.white,
                        elevation: 1,
                        centerTitle: true,
                        leading: const BackButton(color: Colors.black),
                        title: const Text("فتح حساب جديد", style: TextStyle(color: Colors.black)),
                      ),
                      body: const AddCustomerScreen(),
                    ),
                  ),
                );
                _loadCustomers();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFe6a82b),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                elevation: 2,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text('فتح حساب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: FadeInDown(
              delay: const Duration(milliseconds: 100),
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'بحث بالاسم',
                  labelStyle: TextStyle(color:  Colors.black),
                  prefixIcon: Icon(Icons.search, color: Colors.black),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.teal, width: 1.5),
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FadeIn(
              delay: const Duration(milliseconds: 200),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: Text('حسابات العملاء ($customerCount)'),
                        selected: selectedType == 'حساب عميل',
                        selectedColor: Colors.teal,
                        labelStyle: TextStyle(
                          color: selectedType == 'حساب عميل' ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold, fontSize: 12,
                        ),
                        onSelected: (value) {
                          if (value) {
                            setState(() => selectedType = 'حساب عميل');
                            _loadCustomers();
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text('حسابات الموردين ($supplierCount)'),
                        selected: selectedType == 'حساب مورد',
                        selectedColor: Colors.teal,
                        labelStyle: TextStyle(
                          color: selectedType == 'حساب مورد' ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold, fontSize: 12,
                        ),
                        onSelected: (value) {
                          if (value) {
                            setState(() => selectedType = 'حساب مورد');
                            _loadCustomers();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: loading
                ? Center(
              child: SingleChildScrollView( // ✅ أضف هذا
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Lottie.asset(
                      'assets/Animation/Animationserch.json',
                      width: 200,
                      height: 200,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'جاري تحميل البيانات...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.teal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            )
                : customers.isEmpty
                ? FadeIn(
              child: SingleChildScrollView(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset(
                        'assets/Animation/Animationempty.json',
                        width: 200,
                        height: 200,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'لا يوجد ${selectedType == 'حساب عميل' ? 'عملاء' : 'موردين'}',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'اضغط على زر "فتح حساب" لإنشاء حساب جديد',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
                : ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: customers.length,
              itemBuilder: (context, index) {
                final c = customers[index];
                final String id = c['id'];
                final int numInstallments = customerInstallmentCounts[id] ?? 0;
                final bool hasNoInstallments = numInstallments == 0;


                return Slidable(
                  key: Key('$id'),
                  // إعدادات للتمرير من اليمين
                  endActionPane: ActionPane(
                    motion: const StretchMotion(), // تأثير تمدد جميل
                    extentRatio: 0.6,
                    children: [
                      CustomSlidableAction(
                        onPressed: (_) {
                          _showBottomSheetCreateAccount(context, c['id']);
                        },
                        backgroundColor: Color(0xFF42A5F5),
                        autoClose: true,
                        borderRadius: BorderRadius.circular(12),
                        padding: EdgeInsets.zero,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.link, color: Colors.white, size: 20),
                            SizedBox(height: 4),
                            Text(
                              'ربط الحساب ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      // زر المحادثة


                      CustomSlidableAction(
                        onPressed: (_) async {
                          if (_loadingAttachments) return;

                          final prefs = await SharedPreferences.getInstance();
                          final userId = prefs.getString('UserID');
                          if (userId == null) return;

                          setState(() => _loadingAttachments = true);

                          // ✅ انتقال مباشر للصفحة
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CustomerAttachmentsScreen(
                                customerId: c['id'].toString(),
                                userId: userId,
                              ),
                            ),
                          );

                          setState(() => _loadingAttachments = false);
                        },
                        backgroundColor: Colors.teal,
                        autoClose: false,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        padding: EdgeInsets.zero,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _loadingAttachments
                                ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                                : const Icon(Icons.image_outlined, color: Colors.white, size: 20),
                            const SizedBox(height: 4),
                            const Text(
                              'عرض المرفقات',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // إعدادات للتمرير من اليسار
                  startActionPane: ActionPane(
                    motion: const DrawerMotion(), // تأثير يشبه فتح الدرج
                    extentRatio: 0.25,
                    children: [


                      CustomSlidableAction(
                        onPressed: (_) async {
                          if (numInstallments > 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('❌ لا يمكن حذف الحساب لأنه مرتبط بأقساط')),
                            );
                            return;
                          }
                          final confirmed = await _showDeleteConfirmationDialog(context);
                          if (confirmed == true) {
                            await Supabase.instance.client.from('customers').delete().eq('id', id);
                            setState(() => customers.removeAt(index));
                          }
                        },
                        backgroundColor: Color(0xFFCF274F),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                        autoClose: true,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.delete, color: Colors.white),
                            SizedBox(height: 4),
                            Text(
                              'حذف',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],

                  ),

                child: GestureDetector(
                onTapDown: (_) => _controller.forward(),
                onTapUp: (_) => _controller.reverse(),
                onTapCancel: () => _controller.reverse(),
                child: ScaleTransition(
                    scale: _animation, // سيتم شرحه لاحقاً
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 10,
                            spreadRadius: 2,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: hasNoInstallments ? Colors.red.shade100 : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => Editecustomerscreen(customerId: c['id']),
                              ),
                            );
                            if (result == true) {
                              _loadCustomers();
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // الصف الأول: الاسم
                                      Row(
                                        children: [
                                          Icon(Icons.person_outline,
                                              size: 18,
                                              color: Colors.teal),
                                          const SizedBox(width: 8),
                                          Text(
                                            c['cust_name'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      // الصف الثاني: الهاتف
                                      Row(
                                        children: [
                                          Icon(Icons.phone_android_outlined,
                                              size: 18,
                                              color: Colors.teal),
                                          const SizedBox(width: 8),
                                          Text(
                                            c['cust_phone'] ?? 'غير متوفر',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      // الصف الثالث: العنوان
                                      Row(
                                        children: [
                                          Icon(Icons.location_on_outlined,
                                              size: 18,
                                              color: Colors.teal),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              c['cust_address'] ?? 'غير متوفر',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // العمود الجانبي: عدد الأقساط ونوع الحساب
                                Column(
                                  children: [
                                    // عدد الأقساط
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: hasNoInstallments ? Color(0xFFCF274F) : Colors.teal,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (hasNoInstallments ? Color(0xFFCF274F): Colors.teal!)
                                                .withOpacity(0.3),
                                            blurRadius: 6,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            'الأقساط',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            '$numInstallments',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // نوع الحساب
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        c['type'] ?? '',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[800],
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
                    ),
                  ),
                ),);              },
            ),
          ),
        ],
      ),
    );
  }


}