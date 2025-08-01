import 'dart:convert';
import 'dart:io';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:ui' as ui;
import 'DelegatesPaymentsScreen.dart';
import 'print_bottom_sheet.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:crypto/crypto.dart';

class MonyTasded extends StatefulWidget {
  const MonyTasded({super.key});

  @override
  _MonyTasded createState() => _MonyTasded();
}

class _MonyTasded extends State<MonyTasded> with SingleTickerProviderStateMixin {

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
  bool isDeleting = false;
  bool isRestoring = false;

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
    // Set initial filter to "عرض تسديدات اليوم فقط"
    selectedFilter = 1;
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


  Future<void> _loadPaymentofdate() async {
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
        final response = await Supabase.instance.client
            .from('payments')
            .select('*, customers(cust_name), installments(item_type, sponsor_name, interest_rate), groups(group_name)')            .eq('user_id', userId)
            .eq('payment_date', todayStr)
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
        final response = await Supabase.instance.client
            .from('payments')
            .select('*, customers(cust_name), installments(item_type, sponsor_name, interest_rate), groups(group_name)')            .eq('user_id', userId)
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
    } catch (e) {
      print('❌ خطأ في تحميل الدفعات: $e');
      setState(() => loading = false);
    }
  }


  void _showdeletediloge(Map<String, dynamic> payment) async {
    final installmentId = payment['installment_id'];
    final paymentId = payment['id'];

    final response = await Supabase.instance.client
        .from('installments')
        .select('remaining_amount')
        .eq('id', installmentId)
        .maybeSingle();

    final remainingAmount = response?['remaining_amount'] ?? 0;

    bool isDeleting = false;
    bool isRestoring = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
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
                      'assets/Animation/AnimationDeletecust.json',
                      height: 120,
                      repeat: false,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'هل انت متأكد من عملية الحذف',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'يمكنك الضغط على حذف لتنقل الدفعة الى سلة المهملات.. أو اختيار الحذف والاسترجاع لحذف الدفعة وإرجاع المبلغ للعميل.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          onPressed: isDeleting
                              ? null
                              : () async {
                            setState(() => isDeleting = true);
                            if (remainingAmount <= 0) {
                              try {
                                final prefs = await SharedPreferences.getInstance();
                                final userId = prefs.getString('UserID');

                                final cleanedPayment = {
                                  'id': payment['id'],
                                  'customer_name': payment['customers']?['cust_name'] ?? '',
                                  'item_type': payment['installments']?['item_type'] ?? '',
                                  'payment_date': payment['payment_date'],
                                  'amount_paid': payment['amount_paid'],
                                  'notes': payment['notes'],
                                  'user_id': userId,
                                  'created_at': payment['created_at'],
                                  'group_name': payment['groups']?['group_name'],
                                  'type': 'حذف الدفعة',
                                };

                                await Supabase.instance.client
                                    .from('payments_delete')
                                    .insert(cleanedPayment);

                                await Supabase.instance.client
                                    .from('payments')
                                    .delete()
                                    .eq('id', payment['id'])
                                    .eq('user_id', userId!);

                                await _loadPaymentofdate();
                                Navigator.of(context).pop();

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('تم نقل الدفعة إلى سلة المهملات'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } catch (e) {
                                print("❌ حدث خطأ أثناء عملية الحذف: $e");
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('حدث خطأ أثناء الحذف: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              } finally {
                                setState(() => isDeleting = false);
                              }
                            } else {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('لا يمكن حذف الدفعة لأن هناك مبلغًا متبقيًا'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              setState(() => isDeleting = false);
                            }
                          },
                          icon: isDeleting
                              ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Icon(Icons.delete, color: Colors.white),
                          label: isDeleting
                              ? const Text(
                            'جاري الحذف...',
                            style: TextStyle(color: Colors.white),
                          )
                              : const Text(
                            'حذف الدفعة!',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: isRestoring
                              ? null
                              : () async {
                            setState(() => isRestoring = true);
                            try {
                              final prefs = await SharedPreferences.getInstance();
                              final userId = prefs.getString('UserID');
                              final amountPaid = double.tryParse(payment['amount_paid'].toString()) ?? 0;
                              final installmentId = payment['installment_id'];
                              final paymentId = payment['id'];

                              final installment = await Supabase.instance.client
                                  .from('installments')
                                  .select('remaining_amount')
                                  .eq('id', installmentId)
                                  .maybeSingle();

                              final currentRemaining = double.tryParse(installment?['remaining_amount'].toString() ?? '0') ?? 0;

                              await Supabase.instance.client
                                  .from('installments')
                                  .update({
                                'remaining_amount': currentRemaining + amountPaid,
                              })
                                  .eq('id', installmentId)
                                  .eq('user_id', userId!);

                              final cleanedPayment = {
                                'id': payment['id'],
                                'customer_name': payment['customers']?['cust_name'] ?? '',
                                'item_type': payment['installments']?['item_type'] ?? '',
                                'payment_date': payment['payment_date'],
                                'amount_paid': payment['amount_paid'],
                                'notes': payment['notes'],
                                'user_id': userId,
                                'created_at': payment['created_at'],
                                'group_name': payment['groups']?['group_name'],
                                'type': 'حذف مع استرجاع المبلغ',
                              };

                              await Supabase.instance.client
                                  .from('payments_delete')
                                  .insert(cleanedPayment);

                              await Supabase.instance.client
                                  .from('payments')
                                  .delete()
                                  .eq('id', paymentId)
                                  .eq('user_id', userId);

                              await _loadPaymentofdate();
                              Navigator.of(context).pop();

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('تم حذف الدفعة واسترجاع المبلغ بنجاح'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              print("❌ خطأ في حذف واسترجاع المبلغ: $e");
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('حدث خطأ أثناء العملية'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } finally {
                              setState(() => isRestoring = false);
                            }
                          },
                          icon: isRestoring
                              ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Icon(Icons.assignment_return_outlined, color: Colors.white),
                          label: isRestoring
                              ? const Text(
                            'جاري الاسترجاع...',
                            style: TextStyle(color: Colors.white),
                          )
                              : const Text(
                            'حذف و أسترجاع المبلغ!',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFCF274F),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'اغلاق النافذة',
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
      },
    );
  }


  Future<Uint8List> _generateAllInstallmentsPdf(
      pw.Font ttf,
      List<Map<String, dynamic>> installments,
      List<Map<String, dynamic>> allPayments,
      String customerName,
      String userId,
      ) async
  {
    final pdf = pw.Document();

    final now = DateTime.now();
    final formattedDateTime = intl.DateFormat(' yyyy/MM/dd - hh:mm a ', 'en').format(now);
    final formatCurrency = intl.NumberFormat("#,##0", "ar");

    for (final installment in installments) {
      final installmentId = installment['id'];

      final payments = await Supabase.instance.client
          .from('payments')
          .select()
          .eq('installment_id', installmentId)
          .eq('user_id', userId)
          .order('payment_date');

      final salePrice = double.tryParse(installment['sale_price']?.toString() ?? '0') ?? 0;
      final remaining = double.tryParse(installment['remaining_amount']?.toString() ?? '0') ?? 0;
      final paid = payments.fold<double>(0.0, (sum, p) => sum + (double.tryParse(p['amount_paid'].toString()) ?? 0));
      final itemName = installment['item_type']?.toString() ?? 'الصنف';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          footer: (context) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(top: 10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    '© جميع الحقوق محفوظة برمجة بواسطة جعفر جاسم',
                    style: pw.TextStyle(font: ttf, fontSize: 10),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(
                      'Update for Software Solution',
                      style: pw.TextStyle(font: ttf, fontSize: 10),
                    ),
                  ),
                ],
              ),
            );
          },
          build: (context) => [
            pw.Text('اسم الزبون: $customerName', style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Text('نوع البضاعة: $itemName', style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Text('تاريخ ووقت الطباعة: $formattedDateTime', style: pw.TextStyle(font: ttf, fontSize: 14)),
            pw.SizedBox(height: 15),

            pw.Text('تفاصيل التسديدات:', style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),

            pw.Table.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey),
              headerStyle: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
              cellStyle: pw.TextStyle(font: ttf, fontSize: 12),
              cellAlignment: pw.Alignment.center,
              headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
              headers: ['الحالة', 'التاريخ', 'المبلغ', 'القسط', '#'],
              data: List.generate(payments.length, (index) {
                final p = payments[index];
                final paidAmount = formatCurrency.format(double.tryParse(p['amount_paid'].toString()) ?? 0);
                final paymentDate = p['payment_date']?.toString() ?? '-';
                return [
                  'مسدد',
                  paymentDate,
                  paidAmount,
                  'القسط ${index + 1}',
                  '${index + 1}',
                ];
              }),
            ),

            pw.SizedBox(height: 25),
            pw.Text('الإجماليات:', style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),

            pw.Table.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey),
              headerStyle: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
              cellStyle: pw.TextStyle(font: ttf),
              cellAlignment: pw.Alignment.center,
              headers: ['المتبقي', 'المبلغ المسدد', 'المبلغ الكلي'],
              data: [
                [
                  formatCurrency.format(remaining),
                  formatCurrency.format(paid),
                  formatCurrency.format(salePrice),
                ]
              ],
            ),
          ],
        ),
      );
    }

    return pdf.save();
  }







  Future<Uint8List> _generatePdf(
      pw.Font ttf,
      List<Map<String, dynamic>> payments,
      Map<String, dynamic> payment,
      ) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final formattedDateTime = intl.DateFormat(' yyyy/MM/dd'+' - '+' a hh:mm ', 'en').format(now);

    final customerId = payment['customer_id'];
    final installmentId = payment['installment_id'];
    final userId = payment['user_id'];


    final data = await Supabase.instance.client
        .from('payments')
        .select('*, installments(id, item_type, sale_price, remaining_amount), customers(cust_name)')
        .eq('customer_id', customerId)
        .eq('installment_id', installmentId)
        .eq('user_id', userId);

    if (data.isEmpty) {
      throw Exception('لا توجد بيانات للعميل أو القسط المحدد.');
    }

    final updatedPayment = data.first;

    final rawSalePrice = updatedPayment['installments']?['sale_price'];
    final totalAmount = double.tryParse(rawSalePrice?.toString() ?? '0') ?? 0;

    final totalRemaining = double.tryParse(
      updatedPayment['installments']?['remaining_amount']?.toString() ?? '0',
    ) ?? 0;

    final customerName = updatedPayment['customers']?['cust_name']?.toString() ?? 'العميل';
    final itemName = updatedPayment['installments']?['item_type']?.toString() ?? 'الصنف';

    final totalPaid = payments.fold<double>(
      0.0,
          (sum, p) => sum + (double.tryParse(p['amount_paid']?.toString() ?? '0') ?? 0),
    );

    final formatCurrency = intl.NumberFormat("#,##0", "ar");

    print('\n📦 DEBUGGING بيانات العميل:');
    print(updatedPayment['customers'] ?? 'لا توجد بيانات عميل');

    print('\n📦 DEBUGGING بيانات القسط:');
    print(updatedPayment['installments'] ?? 'لا توجد بيانات قسط');

    print('\n🧮 إجماليات الحساب:');
    print('  - totalPaid: $totalPaid');
    print('  - totalRemaining: $totalRemaining');
    print('  - totalAmount: $totalAmount');
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
          footer: (context) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(top: 10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end, // محاذاة النصوص لليمين
                children: [
                  pw.Text(
                    '© جميع الحقوق محفوظة برمجة بواسطة جعفر جاسم',
                    style: pw.TextStyle(font: ttf, fontSize: 10),
                  ),
                  pw.SizedBox(height: 5),

                  pw.Align(
                    alignment: pw.Alignment.centerLeft, // نجعله يبدأ من نفس مكان الأول
                    child: pw.Text(
                      'Update for Software Solution',
                      style: pw.TextStyle(font: ttf, fontSize: 10),
                    ),
                  ),
                ],
              ),
            );
          },

          build: (context) => [

          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('اسم الزبون: $customerName',
                  style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),

              pw.Text('نوع البضاعة: $itemName',
                  style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),

              pw.Text('تاريخ ووقت الطباعة: $formattedDateTime',
                  style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
            ],
          ),


          pw.SizedBox(height: 20),

          pw.Text('تفاصيل التسديدات:',
              style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),

          pw.Table.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey),
            headerStyle: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
            cellStyle: pw.TextStyle(font: ttf, fontSize: 12),
            cellAlignment: pw.Alignment.center,
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
            headers: ['الحالة', 'التاريخ', 'المبلغ', 'القسط', '#'], // حذف "الخصم"
            data: List.generate(payments.length, (index) {
              final p = payments[index];
              final paidAmount = formatCurrency.format(
                double.tryParse(p['amount_paid'].toString()) ?? 0,
              );
              final paymentDate = p['payment_date']?.toString() ?? '-';
              return [
                'مسدد',
                paymentDate,
                paidAmount,
                'القسط ${index + 1}',
                '${index + 1}',
              ]; // حذف عمود "الخصم" من الصف
            }),
          ),



          pw.SizedBox(height: 25),

          /// 🟨 جدول الإجماليات
          pw.Text('الإجماليات:',
              style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey),
            headerStyle: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
            cellStyle: pw.TextStyle(font: ttf),
            cellAlignment: pw.Alignment.center, // ← تمركز جميع النصوص في وسط الخلية

            headers: ['المتبقي', 'المبلغ المسدد', 'المبلغ الكلي'], // ← بالعكس
            data: [
              [
                formatCurrency.format(totalRemaining),
                formatCurrency.format(totalPaid),
                formatCurrency.format(totalAmount),
              ]
            ],
          ),

        ],

          ),
    );

    return pdf.save();
  }


  void _showprintiloge(Map<String, dynamic> payment) async {
    bool isLoadingOne = false;
    bool isLoadingAll = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
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
                      'طباعة بيانات العميل',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // زر طباعة قسط واحد
                        ElevatedButton.icon(
                          onPressed: isLoadingOne
                              ? null
                              : () async {
                            setState(() => isLoadingOne = true);

                            final prefs = await SharedPreferences.getInstance();
                            final userId = prefs.getString('UserID');
                            final customerId = payment['customer_id'];
                            final itemId = payment['installment_id'];

                            final payments = await Supabase.instance.client
                                .from('payments')
                                .select()
                                .eq('customer_id', customerId)
                                .eq('installment_id', itemId)
                                .eq('user_id', userId!);

                            if (payments.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('لا توجد بيانات لعرضها')),
                              );
                              setState(() => isLoadingOne = false);
                              return;
                            }

                            final fontData = await rootBundle.load('assets/fonts/TajawalRegular.ttf');
                            final ttf = pw.Font.ttf(fontData);

                            setState(() => isLoadingOne = false);

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(
                                    centerTitle: true,
                                    title: const Text(
                                      'معاينة قبل الطباعة',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  body: PdfPreview(
                                    build: (format) => _generatePdf(ttf, payments, payment),
                                  ),
                                ),
                              ),
                            );
                          },
                          icon: isLoadingOne
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Icon(Icons.print_outlined, color: Colors.white),
                          label: Text(
                            isLoadingOne ? 'جاري التحميل...' : 'طباعة بيانات القسط المحدد',
                            style: const TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // زر طباعة جميع الأقساط
                        ElevatedButton.icon(
                          onPressed: isLoadingAll
                              ? null
                              : () async {
                            setState(() => isLoadingAll = true);

                            final prefs = await SharedPreferences.getInstance();
                            final userId = prefs.getString('UserID');
                            final customerId = payment['customer_id'];

                            final installments = await Supabase.instance.client
                                .from('installments')
                                .select('*, customers(cust_name)')
                                .eq('customer_id', customerId)
                                .eq('user_id', userId!);

                            if (installments.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('لا توجد أقساط للعميل')),
                              );
                              setState(() => isLoadingAll = false);
                              return;
                            }

                            final payments = await Supabase.instance.client
                                .from('payments')
                                .select()
                                .eq('customer_id', customerId)
                                .eq('user_id', userId);

                            final fontData = await rootBundle.load('assets/fonts/TajawalRegular.ttf');
                            final ttf = pw.Font.ttf(fontData);

                            setState(() => isLoadingAll = false);

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(
                                    centerTitle: true,
                                    title: const Text(
                                      'معاينة قبل الطباعة',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  body: PdfPreview(
                                    build: (format) => _generateAllInstallmentsPdf(
                                      ttf,
                                      installments,
                                      payments,
                                      payment['customers']?['cust_name'] ?? 'العميل',
                                      userId,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          icon: isLoadingAll
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Icon(Icons.print, color: Colors.white),
                          label: Text(
                            isLoadingAll ? 'جاري التحميل...' : 'طباعة جميع اقساط العميل',
                            style: const TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFCF274F),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'اغلاق النافذة',
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
    final interestRate = double.tryParse(i['installments']?['interest_rate']?.toString() ?? '0') ?? 0.0;
    final profit = paidAmount * interestRate / 100;
    final principal = paidAmount - profit;

    final paymentDate = i['payment_date'] ?? '';
    final formatter = intl.DateFormat('yyyy-MM-dd');

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
                      _buildRow('المبلغ المسدد :', '${formatCurrency(paidAmount)} د.ع'),
                      _buildRow('تاريخ الدفع :', formatter.format(DateTime.parse(paymentDate))),
                      _buildRow('الصنف :', i['installments']?['item_type']),

                      if (isExpanded) ...[
                        const Divider(height: 20),
                        _buildRow('نسبة الفائدة :', '${interestRate.toStringAsFixed(2)} ٪'),
                        _buildRow('ربح الدفعة :', '${formatCurrency(profit)} د.ع'),
                        _buildRow('رأس مال الدفعة :', '${formatCurrency(principal)} د.ع'),
                        const Divider(height: 20),

                        _buildRow(  'الملاحظات :',
                            i['sponsor_name'] == null || i['sponsor_name'].isEmpty
                                ? 'لا توجد ملاحظات'
                                : i['sponsor_name']
                        ),


                        _buildRow(  'اسم الكفيل :',
                            i['sponsor_name'] == null || i['sponsor_name'].isEmpty
                                ? 'لا يوجد كفيل'
                                : i['sponsor_name']
                        ),
                        _buildRow('اسم المجموعة :', i['groups']?['group_name'] ?? 'لا توجد مجموعة'),
                        _buildRow(
                          'تاريخ الإدخال :',
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

                      // خيارات التصفية
                      ScaleTransition(
                        scale: CurvedAnimation(
                          parent: ModalRoute.of(context)!.animation!,
                          curve: Curves.easeOutBack,
                        ),
                        child: _buildFilterOption(
                          title: 'عرض جميع التسديدات ',
                          value: 0,
                          icon: Icons.list,
                        ),
                      ),
                      const SizedBox(height: 8),

                      ScaleTransition(
                        scale: CurvedAnimation(
                          parent: ModalRoute.of(context)!.animation!,
                          curve: Interval(0.2, 1.0, curve: Curves.easeOutBack),
                        ),
                        child: _buildFilterOption(
                          title: 'عرض تسديدات اليوم فقط ($dueCount)',
                          value: 1,
                          icon: Icons.warning_amber_rounded,
                        ),
                      ),
                      const SizedBox(height: 8),

                      ScaleTransition(
                        scale: CurvedAnimation(
                          parent: ModalRoute.of(context)!.animation!,
                          curve: Interval(0.4, 1.0, curve: Curves.easeOutBack),
                        ),
                        child: _buildFilterOption(
                          title: 'عرض تسدادت الشهر الحالي فقط ($completedCount)',
                          value: 2,
                          icon: Icons.check_circle_outline,
                        ),
                      ),
                      const SizedBox(height: 25),
                      // تمت إزالة زر التأكيد هنا
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

  Widget _buildFilterOption({required String title, required int value, required IconData icon}) {
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
            });
            Navigator.of(context).pop();

            if (value == 0) {
              _loadPayment(); // عرض الجميع
            } else if (value == 1) {
              _loadPaymentofdate(); // تسديدات اليوم فقط
            } else if (value == 2) {
              _loadPayment(); // تسديدات الشهر الحالي ← تعتمد على selectedFilter داخل _buildInstallmentsList
            }
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
                    HapticFeedback.lightImpact();
                    setState(() {
                      selectedFilter = val!;
                    });
                    Navigator.of(context).pop();

                    if (val == 0) {
                      _loadPayment();
                    } else if (val == 1) {
                      _loadPaymentofdate();
                    } else if (val == 2) {
                      _loadPayment(); // الشهر الحالي
                    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
        title: const Text(
          'نافذة التسديدات',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () async {
                HapticFeedback.lightImpact();
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DelegatesPaymentsScreen()),
                );
              },
              icon: const Icon(Icons.mobile_friendly, size: 18, color: Colors.white),
              label: const Text(
                'تسديدات المندوبين',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFe6a82b),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
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
      ),

      body: _buildMainContent(),
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
                            color: Colors.black,
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
                          _loadPayment();
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
        const SizedBox(width: 8),
        Expanded(
          child: FadeIn(
            delay: const Duration(milliseconds: 300),
            child: ElevatedButton.icon(
              onPressed: () {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final startOfMonth = DateTime(now.year, now.month, 1);
                final endOfMonth = DateTime(now.year, now.month + 1, 0);

                final allCount = installments.length;
                final dueCount = installments.where((i) {
                  final paymentDate = DateTime.tryParse(i['payment_date'] ?? '');
                  return paymentDate != null &&
                      DateTime(paymentDate.year, paymentDate.month, paymentDate.day).isAtSameMomentAs(today);
                }).length;

                final completedCount = installments.where((i) {
                  final paymentDate = DateTime.tryParse(i['payment_date'] ?? '');
                  return paymentDate != null &&
                      paymentDate.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
                      paymentDate.isBefore(endOfMonth.add(const Duration(days: 1)));
                }).length;

                _showFilterDialog(allCount, dueCount, completedCount);
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
  Widget _buildInstallmentsList() {
    // تصفية القائمة
    final filteredPayments = installments.where((i) {
      dynamic value;
      // البحث حسب نوع الحقل
      if (searchType == 'cust_name') {
        value = i['customers']?['cust_name'];
      } else if (searchType == 'item_type' || searchType == 'sponsor_name') {
        value = i['installments']?[searchType];
      } else if (searchType == 'group_id') {
        value = i['groups']?['group_name'];
      } else if (searchType == 'notes') {
        value = i['notes'];
      } else {
        value = i[searchType];
      }

      bool matchesSearch;
      if (searchType == 'group_id') {
        if (selectedGroup == 'none') {
          matchesSearch = i['group_id'] == null || i['group_id'].toString().isEmpty;
        } else {
          matchesSearch = i['group_id']?.toString().trim() == selectedGroup?.trim();
        }
      } else {
        matchesSearch = value != null &&
            value.toString().toLowerCase().contains(searchQuery.toLowerCase());
      }

      // فلترة حسب التاريخ (تسديدات اليوم أو الشهر الحالي)
      bool matchesFilter = true;
      final paymentDate = DateTime.tryParse(i['payment_date'] ?? '');
      final now = DateTime.now();
      if (selectedFilter == 1) {
        // تسديدات اليوم
        final today = DateTime(now.year, now.month, now.day);
        matchesFilter = paymentDate != null &&
            DateTime(paymentDate.year, paymentDate.month, paymentDate.day)
                .isAtSameMomentAs(today);
      } else if (selectedFilter == 2) {
        // تسديدات الشهر الحالي
        matchesFilter = paymentDate != null &&
            paymentDate.year == now.year &&
            paymentDate.month == now.month;
      }

      return matchesSearch && matchesFilter;
    }).toList();

    // الترتيب حسب payment_date فقط (تصاعدي)
    filteredPayments.sort((a, b) {
      final dateA = DateTime.tryParse(a['payment_date'] ?? '') ?? DateTime(2100);
      final dateB = DateTime.tryParse(b['payment_date'] ?? '') ?? DateTime(2100);
      return dateA.compareTo(dateB);
    });


    double totalPaidAmount = 0.0;
    double totalProfit = 0.0;
    double totalPrincipal = 0.0;

    for (var item in filteredPayments) {
      final paid = double.tryParse(item['amount_paid'].toString()) ?? 0;
      final interest = double.tryParse(item['installments']!['interest_rate'].toString()) ?? 0;

      final profit = paid * interest / 100;
      final principal = paid - profit;

      totalPaidAmount += paid;
      totalProfit += profit;
      totalPrincipal += principal;
    }
    if (filteredPayments.isEmpty) {
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

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: filteredPayments.length,
            itemBuilder: (context, index) {
              final item = filteredPayments[index];
              final cardId = item['id'];
              return Slidable(
                key: ValueKey(cardId),
                endActionPane: ActionPane(
                  motion: const StretchMotion(),
                  extentRatio: 0.3,
                  children: [
                    CustomSlidableAction(
                      onPressed: (_) => _showprintiloge(item),
                      backgroundColor: Colors.teal,
                      padding: EdgeInsets.zero,
                      foregroundColor: Colors.white,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.print, color: Colors.white, size: 20),
                          SizedBox(height: 6),
                          Text(
                            'الطباعة',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),

                  ],
                ),
                startActionPane: ActionPane(
                  motion: const StretchMotion(),
                  extentRatio: 0.3,
                  children: [
                    CustomSlidableAction(
                      onPressed: (_) {
                        _showPasswordVerificationDialog(context, () {
                          _showdeletediloge(item); // نفذ الحذف بعد التحقق
                        });
                      },
                      backgroundColor: const Color(0xFFCF274F),
                      padding: EdgeInsets.zero,
                      foregroundColor: Colors.white,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.delete_forever, color: Colors.white, size: 20),
                          SizedBox(height: 6),
                          Text(
                            'حذف القسط',
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
                        topLeft: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                      ),
                    ),
                  ],
                ),
                child: _buildInstallmentCard(item, cardId),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(0),
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
                    const Text('أدخل كلمة مرور حسابك لتأكيد الحذف'),
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
                            ? const CircularProgressIndicator()
                            : ElevatedButton.icon(
                          icon: const Icon(Icons.security),
                          label: const Text('تحقق', style: TextStyle(color: Colors.white, fontSize: 16)),
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
                              Navigator.of(context).pop(); // أغلق النافذة
                              onVerified(); // نفذ العملية المطلوبة (مثلاً الحذف)
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('كلمة المرور غير صحيحة')),
                              );
                            }
                          },
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('إلغاء', style: TextStyle(color: Colors.white, fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFCF274F),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
}