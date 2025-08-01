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
import 'package:url_launcher/url_launcher.dart';



class LateInstallmentsDialog extends StatefulWidget {
  const LateInstallmentsDialog({super.key});

  @override
  State<LateInstallmentsDialog> createState() => _LateInstallmentsDialogState();
}

class _LateInstallmentsDialogState extends State<LateInstallmentsDialog>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> lateInstallments = [];
  List<dynamic> selectedIds = [];
  bool isLoading = true;
  bool isPrinting = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  double _progress = 0.0;
  bool _isSending = false;

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
    _loadLateInstallments();
  }

  Future<void> _loadLateInstallments() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');
    if (userId == null) return;

    final today = DateTime.now();
    final response = await Supabase.instance.client
        .from('installments')
        .select('''
      id, customer_id, sponsor_name, group_id, item_type, 
      notes, remaining_amount,monthly_payment, due_date, 
      customers(id, cust_name, cust_phone)
    ''')
        .eq('user_id', userId)
        .gt('remaining_amount', 0)
        .lt('due_date', today.toIso8601String())
        .order('due_date');
    setState(() {
      lateInstallments = List<Map<String, dynamic>>.from(response);
      isLoading = false;
    });
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
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Center(
                                      child: Text(
                                        'العملاء المتأخرين عن الدفع',
                                        style: theme.textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 15),

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
                            else if (lateInstallments.isEmpty)
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
                                        'لا يوجد عملاء متأخرين',
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
                                    final i = lateInstallments[index];
                                    final cardId = i['id'];
                                    final isSelected = selectedIds.contains(cardId);
                                    final dueDate = DateTime.tryParse(i['due_date'] ?? '');
                                    final today = DateTime.now();
                                    final diff = dueDate != null
                                        ? dueDate.difference(DateTime(today.year, today.month, today.day)).inDays
                                        : 0;
                                    final statusText = diff < 0 ? 'متأخر ${-diff} يوم' : 'غير متأخر';
                                    final statusColor = diff < 0 ? colorScheme.error : theme.disabledColor;

                                    return _buildCustomerCard(
                                      i,
                                      cardId,
                                      isSelected,
                                      statusText,
                                      statusColor,
                                    );
                                  },
                                  childCount: lateInstallments.length,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom buttons
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
                          const SizedBox(height: 12),
                          _buildNotificationButton(),
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
          final selectAll = selectedIds.length != lateInstallments.length;
          selectedIds = selectAll
              ? lateInstallments.map((e) => e['id']).toList()
              : [];
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selectedIds.length == lateInstallments.length && lateInstallments.isNotEmpty
              ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
              : Theme.of(context).dividerColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selectedIds.length == lateInstallments.length && lateInstallments.isNotEmpty
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

    return Dismissible(
      key: Key(cardId.toString()),
      direction: DismissDirection.endToStart, // ✅ السحب من اليمين لليسار
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.teal,
          borderRadius: BorderRadius.circular(1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Image.asset(
              'assets/images/whatsapp_app.png',
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 8),
            const Text('رسالة ', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('تأكيد الإرسال'),
            content: Text(
                'هل تريد إرسال رسالة استحقاق إلى ${installment['customers']?['cust_name'] ?? 'العميل'}؟'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('إلغاء')),
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('نعم')),
            ],
          ),
        );

        if (confirm == true) {
          // ✅ هنا يتم إرسال الرسالة قبل الحذف
          await _sendDueMessage(installment);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم إرسال رسالة استحقاق إلى ${installment['customers']?['cust_name'] ?? 'العميل'}'),
            ),
          );

          // ✅ إذا أردت حذف الكارد فعليًا بعد الإرسال:
          return true;

          // ❌ وإذا كنت لا تريد الحذف بل فقط الإرسال:
          // return false;
        }

        return false;
      },

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withOpacity(0.05) : theme.cardColor,
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
                        installment['item_type']?.toString() ?? '',
                        style: theme.textTheme.bodyMedium,
                        softWrap: true,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                _buildInfoRow(Icons.calendar_today, 'تاريخ الاستحقاق:', installment['due_date']),
                if (installment['remaining_amount'] != null) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.attach_money,
                    'المبلغ المستحق:',
                    _formatCurrency(installment['monthly_payment']),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.attach_money,
                    'المبلغ المتبقي:',
                    _formatCurrency(installment['remaining_amount']),
                  ),
                ],
              ],
            ),
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

  Widget _buildNotificationButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: selectedIds.isEmpty
            ? []
            : [
          BoxShadow(
            color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: selectedIds.isEmpty
            ? Theme.of(context).disabledColor
            : Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: selectedIds.isEmpty || _isSending
              ? null
              : () async {
            setState(() {
              _isSending = true;
              _progress = 0;
            });

            final total = selectedIds.length;
            int sent = 0;

            for (var installment in lateInstallments) {
              if (selectedIds.contains(installment['id'])) {
                final response = await Supabase.instance.client
                    .from('customer_links')
                    .select('customer_profile_id')
                    .eq('customer_table_id', installment['customer_id'])
                    .maybeSingle();

                if (response != null && response['customer_profile_id'] != null) {
                  final userId = response['customer_profile_id'];
                  final formatter = intl.NumberFormat('#,###');
                  final itemType = installment['item_type'] ?? 'المنتج';
                  final remaining = double.tryParse(installment['monthly_payment'].toString()) ?? 0;
                  final remainingFormatted = formatter.format(remaining);

                  final message = '''
لديك قسط متأخر عن الدفع للمنتج "$itemType" 🧾
المبلغ المطلوب تسديده: ${remainingFormatted} د.ع 💰
نرجو التسديد في أقرب وقت، شكراً لك.📱
''';

                  await Supabase.instance.client.functions.invoke(
                    'send_notification',
                    body: {
                      'user_id': userId,
                      'title': 'تذكير بقسط متأخر ⏰',
                      'message': message,
                    },
                  );

                  await Future.delayed(const Duration(milliseconds: 400));
                }

                sent++;
                setState(() {
                  _progress = sent / total;
                });
              }
            }

            setState(() {
              _isSending = false;
              _progress = 0;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ تم إرسال الإشعارات إلى $sent عميل'),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_active,
                    color: Theme.of(context).colorScheme.onSecondary,
                    size: 20),
                const SizedBox(width: 8),
                _isSending
                    ? Text(
                  '${(_progress * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                )
                    : Text(
                  'إرسال إشعار (${selectedIds.length})',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondary,
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

    final selectedInstallments = lateInstallments
        .where((i) => selectedIds.contains(i['id']))
        .toList();

    final pdf = pw.Document();
    final now = DateTime.now();
    final formattedDateTime =
    intl.DateFormat(' yyyy/MM/dd - hh:mm a ', 'en').format(now);
    final formatCurrency = intl.NumberFormat("#,##0", "ar");

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
              'تقرير بالأقساط المتأخرة',
              style: pw.TextStyle(
                font: ttf,
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),

          pw.SizedBox(height: 10),
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
                  in ['تاريخ الاستحقاق', 'المتبقي', 'الصنف', 'اسم العميل'])
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
                final remaining = double.tryParse(
                    installment['remaining_amount']?.toString() ?? '0') ??
                    0;
                final itemName =
                    installment['item_type']?.toString() ?? 'الصنف';
                final shortItemName = truncateWithEllipsis(40, itemName);
                final customerName =
                    installment['customers']?['cust_name'] ?? 'غير معروف';
                final dueDate = installment['due_date']?.toString() ?? '-';

                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(dueDate,
                          style: pw.TextStyle(font: ttf),
                          textAlign: pw.TextAlign.center),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(formatCurrency.format(remaining),
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
            ],
          )
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

Future<void> _sendDueMessage(Map<String, dynamic> installment) async {
  final supabase = Supabase.instance.client;

  print('🚀 بدأ تنفيذ دالة _sendDueMessage');

  // 1. استخراج البيانات من القسط
  final customerMap = installment['customers'];
  print('📦 قيمة customers: $customerMap');

  final String customerId = customerMap?['id'] ?? '';
  final String dueDate = installment['due_date'] ?? '';
  final String amount = installment['remaining_amount']?.toString() ?? '0';
  final double amountValue = double.tryParse(amount) ?? 0.0;
  final String formattedAmount = intl.NumberFormat("#,##0", "en_US").format(amountValue);

  final String itemType = installment['item_type']?.toString() ?? 'بدون صنف';

  print('🧾 customerId: $customerId');
  print('📅 dueDate: $dueDate');
  print('💰 amount: $formattedAmount');
  print('📦 itemType: $itemType');

  if (customerId.isEmpty) {
    print('❌ customerId فارغ! لا يمكن تنفيذ الاستعلام');
    return;
  }

  // 2. جلب اسم العميل ورقم الهاتف من جدول customers
  final customerData = await supabase
      .from('customers')
      .select('cust_name, cust_phone')
      .eq('id', customerId)
      .maybeSingle();

  print('📥 customerData من Supabase: $customerData');

  final String name = customerData?['cust_name'] ?? 'العميل';
  final String phone = customerData?['cust_phone'] ?? '';

  if (phone.isEmpty) {
    print('❌ رقم الهاتف غير موجود');
    return;
  }

  // 3. جلب user_id من SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final String? userId = prefs.getString('UserID');
  print('✅ فحص UserID من SharedPreferences: $userId');

  if (userId == null || userId.trim().isEmpty) {
    print('❌ لا يمكن تنفيذ العملية لأن user_id غير متوفر');
    return;
  }

  // 4. جلب الرسالة المخصصة
  final result = await supabase
      .from('WhatsappMesseges')
      .select('messege')
      .eq('user_id', userId)
      .maybeSingle();

  String customMessage = result?['messege'] ?? '';

  if (customMessage.trim().isEmpty) {
    print('⚠️ لا توجد رسالة مخصصة، سيتم استخدام رسالة افتراضية');
    customMessage =
    "أهلاً بالعميل المحترم: @اسم العميل\nيرجى تسديد ما بذمتكم من ديون ..\nالصنف: @الصنف\nالمبلغ المتبقي: @المبلغ المتبقي\nتاريخ الاستحقاق: @تاريخ الاستحقاق";
  }

  // 5. استبدال الرموز
  customMessage = customMessage
      .replaceAll('@اسم العميل', name)
      .replaceAll('@تاريخ الاستحقاق', dueDate)
      .replaceAll('@المبلغ المتبقي', formattedAmount)
      .replaceAll('@الصنف', itemType);

  // 6. توليد رابط واتساب
  final phoneWithCountryCode = '964${phone.replaceAll(RegExp(r'^0+'), '')}';
  final url = 'https://wa.me/$phoneWithCountryCode?text=${Uri.encodeComponent(customMessage)}';

  // 7. استخدام دالة الإطلاق المخصصة
  try {
    await launchCustomUrl(url);
  } catch (e) {
    print('❌ خطأ في فتح واتساب: $e');
  }
}

Future<void> launchCustomUrl(String urlString) async {
  final Uri url = Uri.parse(urlString);
  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
    throw '❌ تعذر فتح الرابط: $urlString';
  }
}
