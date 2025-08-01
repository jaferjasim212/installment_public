import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;

class TodayPaymentsDialog extends StatefulWidget {
  const TodayPaymentsDialog({super.key});

  @override
  State<TodayPaymentsDialog> createState() => _TodayPaymentsDialogState();
}

class _TodayPaymentsDialogState extends State<TodayPaymentsDialog>
    with SingleTickerProviderStateMixin {
  List<dynamic> selectedIds = [];
  bool isLoading = true;
  bool isPrinting = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  List<Map<String, dynamic>> todayPayments = [];
  double totalPaidToday = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();
    _loadTodayPayments();
  }


  Future<void> _loadTodayPayments() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');
    if (userId == null) return;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(Duration(days: 1));

    final response = await Supabase.instance.client
        .from('payments')
        .select('''
      id,
      amount_paid,
      payment_date,
      notes,
      customers(cust_name),
      installments(item_type)
    ''')
        .eq('user_id', userId)
        .gte('payment_date', todayStart.toIso8601String())
        .lt('payment_date', tomorrowStart.toIso8601String());

    if (!mounted) return;

    setState(() {
      todayPayments = List<Map<String, dynamic>>.from(response);
      totalPaidToday = todayPayments.fold(0.0, (sum, item) {
        final value = double.tryParse(item['amount_paid'].toString()) ?? 0.0;
        return sum + value;
      });
      isLoading = false;
    });

    print('✅ Payments Loaded: ${todayPayments.length}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, _) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, controller) => Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 140),
                        child: CustomScrollView(
                          controller: controller,
                          slivers: [
                            SliverToBoxAdapter(
                              child: Column(
                                children: [
                                  const SizedBox(height: 12),
                                  Center(
                                    child: Container(
                                      width: 60,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: theme.dividerColor,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // العنوان في الوسط
                                  Center(
                                    child: Text(
                                      'تسديدات العملاء اليوم',
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // زر تحديد الكل على اليمين
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      children: [
                                        _buildSelectAllButton(),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),

                            if (isLoading)
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                      (context, index) => _buildShimmerCard(),
                                  childCount: 6,
                                ),
                              )
                            else if (todayPayments.isEmpty)
                              SliverFillRemaining(
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.assignment_turned_in_outlined,
                                        size: 60,
                                        color: theme.disabledColor,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'لا توجد تسديدات اليوم',
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          color: theme.disabledColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                    final i = todayPayments[index];
                                    final cardId = i['id'];
                                    final isSelected = selectedIds.contains(cardId);
                                    final dueDate = DateTime.tryParse(i['payment_date'] ?? '');
                                    final today = DateTime.now();
                                    final diff = dueDate != null
                                        ? dueDate.difference(DateTime(today.year, today.month, today.day)).inDays
                                        : 0;
                                    final statusText = diff < 0 ? 'متأخر ${-diff} يوم' : 'تسديد اليوم';
                                    final statusColor = diff < 0 ? colorScheme.error : theme.disabledColor;

                                    return _buildCustomerCard(
                                      i,
                                      cardId,
                                      isSelected,
                                      statusText,
                                      statusColor,
                                    );
                                  },
                                  childCount: todayPayments.length,
                                ),
                              ),

                            // عرض جدول التسديدات اليوم
                            if (todayPayments.isNotEmpty)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Divider(),
                                      Text(
                                        'التسديدات المسددة اليوم:',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      ...todayPayments.map((p) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(p['customers']?['cust_name'] ?? 'غير معروف'),
                                              Text(
                                                _formatCurrency(p['amount_paid']),
                                                style: theme.textTheme.bodyMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      const Divider(),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'المجموع:',
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            _formatCurrency(totalPaidToday),
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
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

                  // الأزرار في الأسفل
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 5,
                          ),
                        ],
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Column(
                        children: [
                          _buildPrintButton(),

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
    );
  }

  Widget _buildSelectAllButton() {
    return InkWell(
      onTap: () {
        setState(() {
          final selectAll = selectedIds.length != todayPayments.length;
          selectedIds = selectAll
              ? todayPayments.map((e) => e['id']).toList()
              : [];
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selectedIds.length == todayPayments.length && todayPayments.isNotEmpty
              ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
              : Theme.of(context).dividerColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selectedIds.length == todayPayments.length && todayPayments.isNotEmpty
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              'تحديد الكل',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard(
      Map<String, dynamic> installment,
      dynamic cardId,
      bool isSelected,
      String statusText,
      Color statusColor,
      ) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary.withOpacity(0.05)
            : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.3)
              : theme.dividerColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            if (isSelected) {
              selectedIds.remove(cardId);
            } else {
              selectedIds.add(cardId);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedCheckbox(
                    isSelected: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedIds.add(cardId);
                        } else {
                          selectedIds.remove(cardId);
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      installment['customers']?['cust_name'] ?? 'غير معروف',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // نوع الصنف - يعرض النص الطويل بشكل سطرين أو أكثر
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.category, size: 18, color: theme.iconTheme.color),
                  const SizedBox(width: 12),
                  Text(
                    'نوع الصنف:',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      installment['installments']?['item_type']?.toString() ?? 'غير محدد',
                      style: theme.textTheme.bodyMedium,
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),

                  ),
                ],
              ),

              const SizedBox(height: 15),
              if (installment['amount_paid'] != null) ...[
                _buildInfoRow(
                  Icons.attach_money,
                  'المبلغ المسدد:',
                  _formatCurrency(installment['amount_paid']),
                ),
              ],

            ],
          ),
        ),
      ),
    );
  }
  String _formatCurrency(dynamic amount) {
    final formatter = intl.NumberFormat('#,##0', 'ar');
    final value = double.tryParse(amount.toString()) ?? 0.0;
    return formatter.format(value);
  }

  Widget _buildInfoRow(IconData icon, String label, String? value) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 18, color: theme.hintColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.hintColor,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value ?? 'غير محدد',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPrintButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: selectedIds.isEmpty || isPrinting
            ? []
            : [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: selectedIds.isEmpty || isPrinting
            ? Theme.of(context).disabledColor
            : Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: selectedIds.isEmpty || isPrinting
              ? null
              : () async {
            setState(() => isPrinting = true);
            await _printSelectedLateInstallments();
            setState(() => isPrinting = false);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isPrinting)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                          Theme.of(context).colorScheme.onPrimary),
                    ),
                  )
                else
                  Icon(Icons.print,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 20),
                const SizedBox(width: 8),
                Text(
                  isPrinting ? 'جاري الطباعة...' : 'طباعة (${selectedIds.length})',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).dividerColor,
      highlightColor: Theme.of(context).highlightColor,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                    width: 24,
                    height: 24,
                    color: Colors.white,
                    margin: const EdgeInsets.only(right: 12)),
                Container(width: 150, height: 18, color: Colors.white),
                const Spacer(),
                Container(width: 80, height: 24, color: Colors.white),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(width: 18, height: 18, color: Colors.white),
                const SizedBox(width: 8),
                Container(width: 80, height: 14, color: Colors.white),
                const SizedBox(width: 8),
                Container(width: 150, height: 14, color: Colors.white),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(width: 18, height: 18, color: Colors.white),
                const SizedBox(width: 8),
                Container(width: 80, height: 14, color: Colors.white),
                const SizedBox(width: 8),
                Container(width: 150, height: 14, color: Colors.white),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // دالة الطباعة (كما هي بدون تغيير)
  Future<void> _printSelectedLateInstallments() async {
    if (selectedIds.isEmpty) return;

    String truncateWithEllipsis(int cutoff, String text) {
      return (text.length <= cutoff) ? text : '${text.substring(0, cutoff)}...';
    }

    final fontData = await rootBundle.load('assets/fonts/TajawalRegular.ttf');
    final ttf = pw.Font.ttf(fontData);

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');
    if (userId == null) return;

    final selectedInstallments = todayPayments
        .where((i) => selectedIds.contains(i['id']))
        .toList();

    final pdf = pw.Document();
    final now = DateTime.now();
    final formattedDateTime =
    intl.DateFormat(' yyyy/MM/dd - hh:mm a ', 'en').format(now);
    final formatCurrency = intl.NumberFormat("#,##0", "ar");

    // حساب المجموع الكلي
    final totalPaid = selectedInstallments.fold<double>(
      0,
          (sum, i) => sum + (double.tryParse(i['amount_paid']?.toString() ?? '0') ?? 0),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('© جميع الحقوق محفوظة برمجة بواسطة جعفر جاسم',
                  style: pw.TextStyle(font: ttf, fontSize: 10)),
              pw.SizedBox(height: 5),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('Update for Software Solution',
                    style: pw.TextStyle(font: ttf, fontSize: 10)),
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'تقرير  بالتسديدات اليومية',
              style: pw.TextStyle(
                font: ttf,
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 25),
          pw.Text('تاريخ ووقت الطباعة: $formattedDateTime',
              style: pw.TextStyle(font: ttf, fontSize: 12)),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey),
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  for (final header
                  in ['تاريخ الدفع', 'المسددة', 'الصنف', 'اسم العميل'])
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        header,
                        style: pw.TextStyle(
                            font: ttf, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                ],
              ),
              ...selectedInstallments.map((installment) {
                final paid = double.tryParse(
                    installment['amount_paid']?.toString() ?? '0') ??
                    0;
                final itemName =
                    installment['installments']?['item_type']?.toString() ??
                        'غير محدد';
                final shortItemName = truncateWithEllipsis(40, itemName);
                final customerName =
                    installment['customers']?['cust_name'] ?? 'غير معروف';
                final paymentDate =
                    installment['payment_date']?.toString() ?? '-';

                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(paymentDate,
                          style: pw.TextStyle(font: ttf),
                          textAlign: pw.TextAlign.center),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(formatCurrency.format(paid),
                          style: pw.TextStyle(font: ttf),
                          textAlign: pw.TextAlign.center),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        shortItemName,
                        style: pw.TextStyle(font: ttf),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(customerName,
                          style: pw.TextStyle(font: ttf),
                          textAlign: pw.TextAlign.center),
                    ),
                  ],
                );
              }).toList(),
              // صف الإجمالي
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(''),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      formatCurrency.format(totalPaid),
                      style: pw.TextStyle(
                        font: ttf,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),

                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(''),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

class AnimatedCheckbox extends StatefulWidget {
  final bool isSelected;
  final ValueChanged<bool> onChanged;

  const AnimatedCheckbox({
    required this.isSelected,
    required this.onChanged,
  });

  @override
  _AnimatedCheckboxState createState() => _AnimatedCheckboxState();
}

class _AnimatedCheckboxState extends State<AnimatedCheckbox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    if (widget.isSelected) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(AnimatedCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onChanged(!widget.isSelected),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).dividerColor,
              width: 2,
            ),
          ),
          child: widget.isSelected
              ? Icon(Icons.check, size: 16, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}


