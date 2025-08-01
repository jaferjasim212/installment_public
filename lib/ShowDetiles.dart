import 'dart:io';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:installment/print_bottom_sheet.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/animation.dart';
import 'package:shimmer/shimmer.dart';
import 'package:crypto/crypto.dart';


class ShowDetiles extends StatefulWidget {
  final Map<String, dynamic> installment;

  const ShowDetiles({super.key, required this.installment});

  @override
  State<ShowDetiles> createState() => _ShowDetilesState();
}

class _ShowDetilesState extends State<ShowDetiles> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> payments = [];
  bool isLoading = true;
  String? imageBase64;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isCheckingImage = true;
  double _totalPaid = 0;
  bool isSaving = false;
  late String _lastPaidAmount = '0';
  late String _lastPaymentDate = 'لا توجد تسديدات';
  final salePriceController = TextEditingController();
  final interestRateController = TextEditingController();
  final totalWithInterestController = TextEditingController();
  final remainingAmountController = TextEditingController();



  @override
  void initState() {
    super.initState();
    _fetchPayments();
    _fetchInstallmentImage();

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }


  Future<void> _fetchInstallmentImage() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');
    if (userId == null) return;

    setState(() {
      _isCheckingImage = true;
    });

    final data = await Supabase.instance.client
        .from('installments')
        .select('image_base64')
        .eq('id', widget.installment['id'])
        .eq('user_id', userId)
        .maybeSingle();

    setState(() {
      imageBase64 = data?['image_base64'];
      _isCheckingImage = false;
    });
  }

  Future<void> _fetchPayments() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');
    if (userId == null) return;

    final data = await Supabase.instance.client
        .from('payments')
        .select()
        .eq('installment_id', widget.installment['id'])
        .eq('user_id', userId);

    double totalPaid = 0;
    for (var p in data) {
      totalPaid += double.tryParse(p['amount_paid'].toString()) ?? 0;
    }

    // ✅ ترتيب حسب created_at بشكل تنازلي للحصول على أحدث دفعة
    data.sort((a, b) {
      final aDate = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1900);
      final bDate = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1900);
      return bDate.compareTo(aDate);
    });

    // ✅ استخراج آخر دفعة حسب created_at
    final lastPayment = data.isNotEmpty ? data.first : null;
    final lastPaidAmount = double.tryParse(lastPayment?['amount_paid'].toString() ?? '')?.toStringAsFixed(2) ?? '0.00';
    final lastPaymentDate = lastPayment?['payment_date'] ?? 'لا توجد تسديدات';

    setState(() {
      payments = List<Map<String, dynamic>>.from(data);
      isLoading = false;
      _totalPaid = totalPaid;
      _lastPaidAmount = lastPaidAmount;
      _lastPaymentDate = lastPaymentDate;
    });
  }


  void _showEditInstallmentDialog(BuildContext context) {
    final installment = widget.installment;
    final theme = Theme.of(context);

    // Controllers
    final formatter = NumberFormat('#,##0.##', 'ar');


    TextEditingController itemTypeController = TextEditingController(text: installment['item_type']);
    TextEditingController sponsorNameController = TextEditingController(text: installment['sponsor_name']);

    TextEditingController salePriceController = TextEditingController(
      text: formatter.format(installment['sale_price'] ?? 0),
    );
    TextEditingController interestRateController = TextEditingController(
      text: (installment['interest_rate'] ?? 0).toString(),
    );
    TextEditingController totalWithInterestController = TextEditingController(
      text: formatter.format(installment['total_with_interest'] ?? 0),
    );
    TextEditingController monthlyPaymentController = TextEditingController(
      text: formatter.format(installment['monthly_payment'] ?? 0),
    );
    TextEditingController notesController = TextEditingController(text: installment['notes'] ?? '');
    TextEditingController startDateController = TextEditingController(text: installment['start_date']);
    TextEditingController dueDateController = TextEditingController(text: installment['due_date']);
    TextEditingController remainingAmountController = TextEditingController(
      text: NumberFormat('#,##0.##', 'ar').format(installment['remaining_amount'] ?? 0),
    );

    String? selectedGroupId = installment['group_id'];
    String? selectedGroupName = installment['groups']?['group_name'];

    void _updateTotalWithInterest() {
      final salePrice = double.tryParse(salePriceController.text.replaceAll(',', '')) ?? 0.0;
      final interest = double.tryParse(interestRateController.text) ?? 0.0;

      final totalWithInterest = salePrice + (salePrice * interest / 100);
      final remainingAmount = totalWithInterest - _totalPaid;

      totalWithInterestController.text = NumberFormat('#,##0.##', 'ar').format(totalWithInterest);
      remainingAmountController.text = NumberFormat('#,##0.##', 'ar').format(remainingAmount);
    }


    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width,
          padding: EdgeInsets.all(16),
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: ModalRoute.of(context)!.animation!,
              curve: Curves.fastOutSlowIn,
            ),
            child: FadeTransition(
              opacity: ModalRoute.of(context)!.animation!,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(Icons.edit, color: theme.primaryColor),
                      SizedBox(width: 10),
                      Text(
                        'تعديل بيانات القسط',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: theme.primaryColorDark,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      child: FutureBuilder(
                        future: Supabase.instance.client.from('groups').select(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Center(child: CircularProgressIndicator());
                          }
                          List groups = snapshot.data as List;
                          return StatefulBuilder(
                            builder: (context, setState) => Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Image Picker
                                GestureDetector(
                                  onTap: () async {
                                    final picker = ImagePicker();
                                    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                                    if (pickedFile != null) {
                                      final bytes = await File(pickedFile.path).readAsBytes();
                                      final base64Image = base64Encode(bytes);
                                      setState(() {
                                        imageBase64 = base64Image;
                                      });
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('لم يتم اختيار صورة'),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration: Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    height: 160,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 6,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                      image: imageBase64 != null
                                          ? DecorationImage(
                                        image: MemoryImage(base64Decode(imageBase64!)),
                                        fit: BoxFit.cover,
                                      )
                                          : null,
                                    ),
                                    child: imageBase64 == null
                                        ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.camera_alt,
                                          size: 40,
                                          color: Colors.grey[600],
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'إضافة صورة',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    )
                                        : null,
                                  ),
                                ),
                                SizedBox(height: 16),

                                // Form Fields
                                _buildAnimatedFormField(
                                  context,
                                  controller: itemTypeController,
                                  label: 'اسم الصنف',
                                  icon: Icons.category,
                                ),

                                _buildAnimatedFormField(
                                  context,
                                  controller: sponsorNameController,
                                  label: 'اسم الكفيل',
                                  icon: Icons.person,
                                ),

                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: DropdownButtonFormField(
                                    value: selectedGroupId,
                                    decoration: InputDecoration(
                                      labelText: 'اسم المجموعة',
                                      prefixIcon: Icon(Icons.group),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: null,
                                        child: Text('لا توجد مجموعة',
                                            style: TextStyle(color: Colors.grey)),
                                      ),
                                      ...groups.map((g) => DropdownMenuItem(
                                        value: g['id'],
                                        child: Text(g['group_name']),
                                      )),
                                    ],
                                    onChanged: (val) {
                                      setState(() => selectedGroupId = val as String?);
                                    },
                                  ),
                                ),

                                _buildAnimatedFormField(
                                  context,
                                  controller: salePriceController,
                                  label: 'سعر الشراء',
                                  icon: Icons.attach_money,
                                  keyboardType: TextInputType.number,
                                  onChanged: (val) => setState(() => _updateTotalWithInterest()),
                                ),

                                _buildAnimatedFormField(
                                  context,
                                  controller: interestRateController,
                                  label: 'نسبة الفائدة (%)',
                                  icon: Icons.percent,
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (val) => setState(() => _updateTotalWithInterest()),
                                ),

                                _buildAnimatedFormField(
                                  context,
                                  controller: totalWithInterestController,
                                  label: 'المبلغ بعد الفائدة',
                                  icon: Icons.attach_money,
                                  readOnly: true,
                                ),

                                _buildAnimatedFormField(
                                  context,
                                  controller: remainingAmountController,
                                  label: 'المبلغ المتبقي',
                                  icon: Icons.money_off,
                                  readOnly: true,
                                ),

                                _buildAnimatedFormField(
                                  context,
                                  controller: TextEditingController(
                                    text: NumberFormat('#,##0.##', 'ar').format(_totalPaid),
                                  ),
                                  label: 'المبالغ المسددة',
                                  icon: Icons.payment,
                                  readOnly: true,
                                ),

                                _buildAnimatedFormField(
                                  context,
                                  controller: monthlyPaymentController,
                                  label: 'القسط الشهري',
                                  icon: Icons.calendar_today,
                                  keyboardType: TextInputType.number,
                                ),

                                _buildAnimatedFormField(
                                  context,
                                  controller: startDateController,
                                  label: 'تاريخ البدء',
                                  icon: Icons.date_range,
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (date != null) {
                                      startDateController.text = DateFormat('yyyy-MM-dd').format(date);
                                    }
                                  },
                                ),

                                _buildAnimatedFormField(
                                  context,
                                  controller: dueDateController,
                                  label: 'تاريخ الاستحقاق',
                                  icon: Icons.event_available,
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (date != null) {
                                      dueDateController.text = DateFormat('yyyy-MM-dd').format(date);
                                    }
                                  },
                                ),

                                _buildAnimatedFormField(
                                  context,
                                  controller: notesController,
                                  label: 'الملاحظات',
                                  icon: Icons.note,
                                  maxLines: 3,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Actions
                  Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            backgroundColor: Colors.grey[200],
                          ),
                          child: Text(
                            'إلغاء',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        StatefulBuilder(
                          builder: (context, setState) => ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                              setState(() => isSaving = true);

                              final prefs = await SharedPreferences.getInstance();
                              final userId = prefs.getString('UserID');
                              if (userId == null) return;

                              final newSalePrice = double.tryParse(
                                  salePriceController.text.replaceAll(',', '')) ??
                                  0;
                              final newRemainingAmount = double.tryParse(
                                  remainingAmountController.text.replaceAll(',', '')) ??
                              0;


                              if (newRemainingAmount < 0) {
                                setState(() => isSaving = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('لا يمكن أن يكون المبلغ المتبقي أقل من صفر'),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                                return;
                              }

                              final updateData = {
                                'item_type': itemTypeController.text.trim(),
                                'sponsor_name': sponsorNameController.text.trim(),
                                'group_id': selectedGroupId,
                                'sale_price': newSalePrice,
                                'interest_rate': double.tryParse(interestRateController.text.replaceAll(',', '')) ?? 0,

                               'total_with_interest': double.tryParse(
                                    totalWithInterestController.text.replaceAll(',', '')) ??
                                    0,
                                'monthly_payment': double.tryParse(
                                    monthlyPaymentController.text.replaceAll(',', '')) ??
                                    0,
                                'start_date': startDateController.text,
                                'due_date': dueDateController.text,
                                'notes': notesController.text.trim(),
                                'remaining_amount': newRemainingAmount,
                              };

                              if (imageBase64 != null && imageBase64!.isNotEmpty) {
                                updateData['image_base64'] = imageBase64;
                              }

                              final oldInstallment = await Supabase.instance.client
                                  .from('installments')
                                  .select()
                                  .eq('id', installment['id'])
                                  .eq('user_id', userId)
                                  .single();

                              await Supabase.instance.client
                                  .from('installments_edit_log')
                                  .insert({
                                'installment_id': installment['id'],
                                'user_id': userId,
                                'before_data': oldInstallment,
                                'after_data': updateData,
                                'edited_at': DateTime.now().toIso8601String(),
                              });

                              await Supabase.instance.client
                                  .from('installments')
                                  .update(updateData)
                                  .match({
                                'id': installment['id'],
                                'user_id': userId,
                              });

                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('تم تعديل البيانات بنجاح'),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );

                              await _fetchPayments();
                              setState(() {
                                isSaving = false;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              backgroundColor: theme.primaryColor,
                              elevation: 3,
                            ),
                            child: isSaving
                                ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.save, size: 20,color: Colors.white,),
                                SizedBox(width: 8),
                                Text('حفظ التعديلات',style: TextStyle(color: Colors.white),),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedFormField(
      BuildContext context, {
        required TextEditingController controller,
        required String label,
        required IconData icon,
        TextInputType? keyboardType,
        bool readOnly = false,
        int? maxLines = 1,
        VoidCallback? onTap,
        ValueChanged<String>? onChanged,
      }) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(0.5, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: ModalRoute.of(context)!.animation!,
        curve: Curves.easeOut,
      )),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          maxLines: maxLines,
          onTap: onTap,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            filled: true,
            fillColor: readOnly ? Colors.grey[400] : Colors.grey[50], // ✅ التغيير هنا
          ),
        ),
      ),
    );
  }


  void _showPasswordVerificationDialog(BuildContext context) {
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
                          label: Text('تحقق',style: TextStyle(color: Colors.white,fontSize: 16),),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            setState(() => isChecking = true);

                            final prefs = await SharedPreferences.getInstance();
                            final userId = prefs.getString('UserID');
                            if (userId == null) return;

                            // تشفير كلمة المرور باستخدام SHA256
                            final password = passwordController.text.trim();
                            final bytes = utf8.encode(password);
                            final digest = sha256.convert(bytes).toString();

                            final user = await Supabase.instance.client
                                .from('users_full_profile')
                                .select()
                                .eq('id', userId)
                                .eq('password_hash', digest)
                                .maybeSingle();

                            setState(() => isChecking = false);

                            if (user != null) {
                              Navigator.of(context).pop(); // إغلاق نافذة التحقق
                              _showEditInstallmentDialog(context); // فتح نافذة التعديل
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('كلمة المرور غير صحيحة')),
                              );
                            }
                          },
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('إلغاء',style: TextStyle(color: Colors.white,fontSize: 16),),
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

  String _formatNumber(dynamic number) {
    final formatter = NumberFormat('#,##0', 'en'); // ← مع فاصل عشري
    return formatter.format(double.tryParse(number.toString()) ?? 0.0);
  }
  @override
  Widget build(BuildContext context) {
    final installment = widget.installment;
    final formatter = DateFormat('yyyy-MM-dd');
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('تفاصيل القسط', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: isLoading
              ? _buildShimmerLoading()
              : CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Image Section
                      if (_isCheckingImage)
                        Shimmer.fromColors(
                          baseColor: Colors.grey.shade300,
                          highlightColor: Colors.grey.shade100,
                          child: Container(
                            height: 220,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        )
                      else if (imageBase64 != null)
                        GestureDetector(
                          onTap: () => _showFullImage(context),
                          child: Hero(
                            tag: 'installment-image-${installment['id']}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.memory(
                                base64Decode(imageBase64!),
                                height: 220,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        )
                      else
                        SizedBox.shrink(), // لا يعرض أي شيء إذا لم توجد صورة

                      SizedBox(height: 24),

                      // Installment Details Card
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'معلومات القسط',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              SizedBox(height: 8),
                              _buildModernDetailRow(Icons.person, 'اسم العميل', installment['customers']?['cust_name']),
                              _buildModernDetailRow(Icons.category, 'الصنف', installment['item_type']),
                              _buildModernDetailRow(
                                  Icons.contact_page,
                                  'اسم الكفيل',
                                  installment['sponsor_name'] == null || installment['sponsor_name'].isEmpty
                                      ? 'لا يوجد كفيل'
                                      : installment['sponsor_name']
                              ),
                              _buildModernDetailRow(Icons.category_outlined, 'اسم المجموعة', installment['groups']?['group_name'] ?? 'لا توجد مجموعة'),
                              _buildDoubleDetailRow(
                                Icons.attach_money,
                                'سعر الشراء',
                                NumberFormat('#,##0.##', 'ar').format(installment['sale_price'] ?? 0),
                                'المبلغ المتبقي',
                                NumberFormat('#,##0.##', 'ar').format(installment['remaining_amount'] ?? 0),
                              ),
                              _buildModernDetailRow(
                                Icons.percent,
                                'نسبة الربح',
                                '${NumberFormat('#,##0.##', 'ar').format(installment['interest_rate'] ?? 0)}%',
                              ),
                              _buildModernDetailRow(Icons.payments_outlined, 'المبلغ الكلي مع الفائدة', NumberFormat('#,##0.##', 'ar').format(installment['total_with_interest'] ?? 0)),

                              _buildModernDetailRow(Icons.payment, 'القسط الشهري', NumberFormat('#,##0.##', 'ar').format(installment['monthly_payment'] ?? 0)),
                              _buildDoubleDetailRow(
                                Icons.calendar_today,
                                'تاريخ البدء',
                                installment['start_date'],
                                'تاريخ الاستحقاق',
                                installment['due_date'],
                              ),
                              _buildModernDetailRow(
                                  Icons.note_alt_rounded,
                                  'الملاحظات',
                                  installment['notes'] == null || installment['notes'].isEmpty
                                      ? 'لا توجد ملاحظات'
                                      : installment['notes']
                              ),

                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Payments Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'التسديدات السابقة',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ),

              if (payments.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        'لا توجد تسديدات بعد',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final payment = payments[index];
                      return AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {},
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.payment, color: Colors.green),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${NumberFormat('#,##0.##', 'ar').format(payment['amount_paid'] ?? 0)} د.ع',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          '${payment['payment_date']}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (payment['notes'] != null && payment['notes'].isNotEmpty)
                                    Tooltip(
                                      message: payment['notes'],
                                      child: Icon(Icons.info_outline, color: Colors.blue),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: payments.length,
                  ),
                ),

              // Buttons Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      SizedBox(height: 16),
                      _buildAnimatedButton(
                        context,
                        icon: Icons.print,
                        label: 'طباعة وصل التسديد الاخبر',
                        color: Colors.teal,
                        onPressed: () async {
                          await _fetchPayments(); // تنتظر تحميل بيانات التسديدات

                          final formattedPaidAmount = _formatNumber(_lastPaidAmount);

                          print('🟢 بيانات الطباعة:');
                          print('ID: ${installment['customer_id']}');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PrintBottomSheet(
                                id: installment['customer_id'].toString(), // ✅ هنا تنقل الـ ID
                                customerName: installment['customers']?['cust_name'] ?? 'غير معروف',
                                itemName: installment['item_type'] ?? '',
                                totalAmount: installment['sale_price'].toString(),
                                remainingAmount: installment['remaining_amount'].toString(),
                                paidAmount: formattedPaidAmount,
                                paymentDate: _lastPaymentDate,
                                dueDate: installment['due_date'] ?? '',
                              ),
                            ),
                          );
                        },
                      ),


                      SizedBox(height: 12),
                      _buildAnimatedButton(
                        context,
                        icon: Icons.edit,
                        label: 'تعديل القسط',
                        color: Colors.orange,
                        onPressed: () {
                          _showPasswordVerificationDialog(context);
                        },
                      ),
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

  Widget _buildModernDetailRow(IconData icon, String title, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blue.shade600),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value ?? 'غير متوفر',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedButton(
      BuildContext context, {
        required IconData icon,
        required String label,
        required Color color,
        required VoidCallback onPressed,
      }) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
// أضف هذه الدالة الجديدة لإنشاء صف مزدوج
  Widget _buildDoubleDetailRow(IconData icon, String title1, String? value1, String title2, String? value2) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blue.shade600),
          SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title1,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        value1 ?? 'غير متوفر',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title2,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        value2 ?? 'غير متوفر',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            SizedBox(height: 24),
            ...List.generate(8, (index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Hero(
            tag: 'installment-image-${widget.installment['id']}',
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.memory(
                base64Decode(imageBase64!),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    ));
  }
}