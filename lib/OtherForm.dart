import 'dart:convert';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image/image.dart' as img;

class Otherform extends StatefulWidget {
  const Otherform({super.key});

  @override
  _Otherform createState() => _Otherform();
}

class _Otherform extends State<Otherform> {
  int? loadingIndex;

  final List<Map<String, dynamic>> items = [
    {
      'title': 'المندوبين',
      'subtitle':'يمكنك اضافة المندوبين لأستحصال أموالك من اي مكان ..',
      'icon': Icons.account_circle,
      'color': Color(0xFF6A8CAF),
      'darkColor': Color(0xFF4A6B8A)
    },
    {
      'title': 'المجموعات',
      'subtitle':'المجموعات هي دليلك السريع للوصول الى عملائك ..',

      'icon': Icons.group_work,
      'color': Color(0xFF42A5F5),
      'darkColor': Color(0xFF42A5F5)
    },
    {
      'title': 'إعدادات الطباعة',
      'subtitle':'قم بتغيير شعار نشاطك التجاري و الاسم و ارقام الهاتف .',

      'icon': Icons.print,
      'color': Colors.deepPurple,
      'darkColor': Colors.deepPurple
    },
    {
      'title': 'رسالة واتس اب مخصصة للمستحقين',
      'subtitle':'يمكنك انشاء رسالة واتس اب مخصصة بنفسك لكي ترسل الى العملاء المستحقين و المتأخرين..',

      'icon': Icons.message,
      'color': Colors.teal,
      'darkColor': Colors.teal
    },
    {
      'title': 'رسالة واتس اب مخصصة للتسديدات',
      'subtitle':'يمكنك انشاء رسالة واتس اب مخصصة لكي ترسل الى العملاء اثناء التسديد..',

      'icon': Icons.message,
      'color': Colors.teal.shade600,
      'darkColor': Colors.teal.shade600
    },
    {
      'title': 'سلة مهملات المبالغ المتبقية',
      'subtitle':'عرض الاقساط التي تم حذفها ..',

      'icon': Icons.delete_forever,
      'color': Color(0xFFEF476F),
      'darkColor': Color(0xFFCF274F)
    },
    {
      'title': 'سلة مهملات المبالغ المسددة',
      'subtitle':'عرض المدفوعات التي تم حذفها ..',

      'icon': Icons.delete_sweep,
      'color': Color(0xFFEF476F),
      'darkColor': Color(0xFFCF274F)
    },
  ];

  // متغير لتتبع العنصر المضغوط عليه
  int? _pressedIndex;


  Future<void> _showCustomDialog(BuildContext context, Map<String, dynamic> item) async {
    // عرض مؤشر التحميل
    bool needsLoading = [
      'سلة مهملات المبالغ المتبقية',
      'سلة مهملات المبالغ المسددة',
      'رسالة واتس اب مخصصة للمستحقين',
      'رسالة واتس اب مخصصة للتسديدات',
      'المندوبين',
      'المجموعات',
      'إعدادات الطباعة',
    ].contains(item['title']);


    if (item['title'] == 'المجموعات') {
      await _showGroupsDialog(context, item['color']);
    } else if (item['title'] == 'إعدادات الطباعة') {
      await _showUserprinterDialog(context, item['color']);
    } else if (item['title'] == 'المندوبين') {
      await _showUserDelegatesDialog(context, item['color']);
    } else if (item['title'] == 'رسالة واتس اب مخصصة للمستحقين') {
      await _showCustomWhatsAppMessageDialog(context, item['color']);
    }
    else if (item['title'] == 'رسالة واتس اب مخصصة للتسديدات') {
      await _showCustomWhatsAppMessageDialogtsded(context, item['color']);
    } else if (item['title'] == 'سلة مهملات المبالغ المتبقية') {
      await _showCustomWdeletemonybakyDialog(context, item['color']);
    } else if (item['title'] == 'سلة مهملات المبالغ المسددة') {
      await _showCustomWdeletemonytasdedDialog(context, item['color']);
    } else {
      // في حال لم تكن ضمن الحالات السابقة
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: '',
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (ctx, anim1, anim2) => Container(),
        transitionBuilder: (ctx, anim1, anim2, child) {
          final curvedValue = Curves.easeInOutBack.transform(anim1.value);
          return Transform.scale(
            scale: curvedValue,
            child: Opacity(
              opacity: anim1.value,
              child: AlertDialog(
                // ... محتوى الرسالة العامة
                title: Text(item['title'], style: TextStyle(color: item['color'])),
                content: const Text('سيتم فتح هذه الوظيفة قريباً'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('تم'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }



  void _showUserSettingsDialog(BuildContext context, Color color) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');
    if (userId == null) return;

    final settings = await Supabase.instance.client
        .from('user_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    final settingsData = settings ?? {
      'no_duplicate_installments': false,
      'no_past_due_date': false,
      'no_zero_amount': false,
      'send_due_notifications': false,
      'hide_today_received': false,
      'hide_installments_count': false,
      'hide_total_debts': false,
    };

    Map<String, bool> localSettings = settingsData.map((key, value) {
      if (value is bool) return MapEntry(key, value);
      if (value is String) return MapEntry(key, value.toLowerCase() == 'true');
      return MapEntry(key, false);
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) {
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'الإعدادات العامة',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  Expanded(
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        return ListView(
                          controller: controller,
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          children: localSettings.entries
                              .where((entry) => entry.key != 'id' && entry.key != 'user_id')
                              .map((entry) {
                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              margin: EdgeInsets.symmetric(vertical: 8),
                              elevation: 3,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      _getArabicSettingLabel(entry.key),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Align(
                                      alignment: Alignment.center,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            localSettings[entry.key] = !localSettings[entry.key]!;
                                          });
                                        },
                                        child: AnimatedContainer(
                                          duration: Duration(milliseconds: 200),
                                          width: 60,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(16),
                                            color: localSettings[entry.key]!
                                                ? Colors.green.withOpacity(0.2)
                                                : Colors.red.withOpacity(0.2),
                                          ),
                                          child: Stack(
                                            children: [
                                              AnimatedPositioned(
                                                duration: Duration(milliseconds: 200),
                                                left: localSettings[entry.key]! ? 30 : 0,
                                                right: localSettings[entry.key]! ? 0 : 30,
                                                top: 0,
                                                bottom: 0,
                                                child: Container(
                                                  width: 30,
                                                  height: 30,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: localSettings[entry.key]!
                                                        ? Colors.green
                                                        : Colors.red,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black.withOpacity(0.1),
                                                        blurRadius: 4,
                                                        offset: Offset(0, 2),
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
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          final cleanSettings = Map<String, dynamic>.from(localSettings)
                            ..remove('id')
                            ..remove('created_at');

                          await Supabase.instance.client
                              .from('user_settings')
                              .upsert(
                                {
                                  ...cleanSettings,
                                  'user_id': userId,
                                },
                                onConflict: 'user_id',
                              );

                          Navigator.of(ctx).pop();

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('تم حفظ الإعدادات بنجاح'),
                                ],
                              ),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              margin: EdgeInsets.all(16),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.error, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('فشل حفظ الإعدادات'),
                                ],
                              ),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              margin: EdgeInsets.all(16),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: Text(
                        'حفظ التغييرات',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  String _getArabicSettingLabel(String key) {
    switch (key) {
      case 'no_duplicate_installments':
        return 'منع الأقساط المكررة لنفس العميل';
      case 'no_past_due_date':
        return 'منع استلام مبالغ بتواريخ قديمة';
      case 'no_zero_amount':
        return 'منع استلام مبلغ بقيمة صفر';
      case 'send_due_notifications':
        return 'إرسال تنبيهات الاستحقاق الى العملاء';
      case 'hide_today_received':
        return 'إخفاء المبالغ المسددة اليوم في الصفحة الرئيسية';
      case 'hide_installments_count':
        return ' إخفاء عدد الأقساط في الصفحة الرئيسية';
      case 'hide_total_debts':
        return 'إخفاء إجمالي الديون في الصفحة الرئيسية';
      default:
        return key;
    }
  }

  Future<void> _showGroupsDialog(BuildContext context, Color color) async {
    TextEditingController _groupController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5, // حجم ابتدائي مناسب
        minChildSize: 0.4,    // أصغر حجم ممكن
        maxChildSize: 0.9,    // أكبر حجم ممكن
        expand: false,
        builder: (_, controller) {
          return StatefulBuilder(
            builder: (context, setState) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                    left: 16,
                    right: 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle indicator
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 8),
                        child: Container(
                          width: 60,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),

                      // Title
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'إدارة المجموعات',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),

                      // Input field
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _groupController,
                          maxLength: 16,
                          decoration: InputDecoration(
                            labelText: 'اسم المجموعة',
                            labelStyle: TextStyle(color: Colors.grey[600]),
                            floatingLabelStyle: TextStyle(color: color),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: color, width: 2),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),

                      SizedBox(height: 16),

                      // Save button
                      ElevatedButton.icon(
                        onPressed: () async {
                          final name = _groupController.text.trim();
                          if (name.isEmpty || name.length > 16) return;

                          setState(() {});

                          final prefs = await SharedPreferences.getInstance();
                          final userId = prefs.getString('UserID');
                          if (userId == null) return;

                          await Supabase.instance.client
                              .from('groups')
                              .insert({'group_name': name, 'user_id': userId});

                          _groupController.clear();
                          setState(() {});
                        },
                        icon: Icon(Icons.save_alt_rounded, size: 24, color: Colors.white),
                        label: Text(
                          'حفظ المجموعة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                          backgroundColor: Colors.teal,
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          shadowColor: Colors.teal.withOpacity(0.4),
                        ),
                      ),

                      SizedBox(height: 16),

                      // Groups list
                      Expanded(
                        child: FutureBuilder<List<Map<String, dynamic>>>(
                          future: _fetchGroups(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(color),
                                ),
                              );
                            }

                            final groups = snapshot.data!;
                            if (groups.isEmpty) {
                              return Center(
                                child: Text(
                                  'لا توجد مجموعات مسجلة',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              );
                            }

                            return ListView.builder(
                              controller: controller,
                              shrinkWrap: true,
                              physics: BouncingScrollPhysics(),
                              itemCount: groups.length,
                              itemBuilder: (ctx, index) {
                                final group = groups[index];
                                return Dismissible(
                                  key: ValueKey(group['id']),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: EdgeInsets.only(right: 24),
                                    decoration: BoxDecoration(
                                      color: Colors.red[400],
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Icon(Icons.delete, color: Colors.white),
                                        SizedBox(width: 8),
                                        Text(
                                          'حذف',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                      ],
                                    ),
                                  ),
                                  confirmDismiss: (_) async {
                                    final used = await Supabase.instance.client
                                        .from('installments')
                                        .select()
                                        .eq('group_id', group['id']);

                                    if (used.isNotEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('لا يمكن حذف مجموعة مرتبطة بأقساط'),
                                          backgroundColor: Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          margin: EdgeInsets.all(16),
                                        ),
                                      );
                                      return false;
                                    }

                                    final prefs = await SharedPreferences.getInstance();
                                    final userId = prefs.getString('UserID');

                                    if (userId == null || userId.isEmpty) {
                                      print('❌ userId غير موجود أو فارغ!');
                                      return false;
                                    }

                                    // محاولة الحذف
                                    final response = await Supabase.instance.client
                                        .from('groups')
                                        .delete()
                                        .match({'id': group['id'], 'user_id': userId});

                                    print('🗑️ حذف المجموعة response: $response');
                                    print('🔎 محاولة حذف المجموعة: id=${group['id']} - user_id=$userId');
                                    // إعادة تحميل البيانات بشكل صريح
                                    setState(() {
                                      // سيقوم FutureBuilder بإعادة جلب البيانات من جديد تلقائيًا
                                    });

                                    return true;
                                  },
                                  child: Card(
                                    margin: EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: ListTile(
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      title: Text(
                                        group['group_name'],
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      trailing: Icon(
                                        Icons.drag_handle,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
  Future<List<Map<String, dynamic>>> _fetchGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');
    if (userId == null) return [];
    final response = await Supabase.instance.client
        .from('groups')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }




  Future<void> _showCustomWhatsAppMessageDialog(BuildContext context, Color color) async {
    final supabase = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID') ?? '';

    // تحميل الرسالة القديمة قبل فتح الدايلوك
    final result = await supabase
        .from('WhatsappMesseges')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    final String oldMessage = result != null ? result['messege'] ?? '' : '';

    TextEditingController messageController = TextEditingController(text: oldMessage);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: SingleChildScrollView(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 60,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'رسالة مخصصة للمستحقين',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _insertVariableButton('@اسم العميل', messageController, setState),
                            _insertVariableButton('@تاريخ الاستحقاق', messageController, setState),
                            _insertVariableButton('@المبلغ المتبقي', messageController, setState),
                            _insertVariableButton('@الصنف', messageController, setState),

                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: messageController,
                          maxLines: 6,
                          textDirection: TextDirection.rtl,
                          decoration: InputDecoration(
                            labelText: 'نص الرسالة',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final message = messageController.text.trim();
                            if (message.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('يرجى كتابة نص الرسالة')),
                              );
                              return;
                            }

                            final existing = await supabase
                                .from('WhatsappMesseges')
                                .select()
                                .eq('user_id', userId)
                                .maybeSingle();

                            if (existing != null) {
                              await supabase
                                  .from('WhatsappMesseges')
                                  .update({'messege': message})
                                  .eq('user_id', userId);
                            } else {
                              await supabase.from('WhatsappMesseges').insert({
                                'user_id': userId,
                                'messege': message,
                                'created_at': DateTime.now().toIso8601String(),
                              });
                            }

                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text('تم حفظ رسالة الواتس اب المخصصة'),
                                  ],
                                ),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                margin: EdgeInsets.all(16),
                              ),
                            );
                          },
                          icon: Icon(Icons.save, size: 24, color: Colors.white),
                          label: Text(
                            'حفظ الرسالة المخصصة',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                            backgroundColor: color,
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            shadowColor: color.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }


  Future<void> _showCustomWhatsAppMessageDialogtsded(BuildContext context, Color color) async {
    final supabase = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID') ?? '';

    // تحميل الرسالة القديمة قبل فتح الدايلوك
    final result = await supabase
        .from('WhatsappMesseges_tasded')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    final String oldMessage = result != null ? result['messege'] ?? '' : '';

    TextEditingController messageController = TextEditingController(text: oldMessage);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: SingleChildScrollView(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 60,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'رسالة مخصصة للتسديدات',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _insertVariableButton('@اسم العميل', messageController, setState),
                            _insertVariableButton('@تاريخ الاستحقاق', messageController, setState),
                            _insertVariableButton('@المبلغ المتبقي', messageController, setState),
                            _insertVariableButton('@الصنف', messageController, setState),
                            _insertVariableButton('@تاريخ التسديد', messageController, setState),  // ✅ جديد
                            _insertVariableButton('@المبلغ المدفوع', messageController, setState),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: messageController,
                          maxLines: 6,
                          textDirection: TextDirection.rtl,
                          decoration: InputDecoration(
                            labelText: 'نص الرسالة',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final message = messageController.text.trim();
                            if (message.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('يرجى كتابة نص الرسالة')),
                              );
                              return;
                            }

                            final existing = await supabase
                                .from('WhatsappMesseges_tasded')
                                .select()
                                .eq('user_id', userId)
                                .maybeSingle();

                            if (existing != null) {
                              await supabase
                                  .from('WhatsappMesseges_tasded')
                                  .update({'messege': message})
                                  .eq('user_id', userId);
                            } else {
                              await supabase.from('WhatsappMesseges_tasded').insert({
                                'user_id': userId,
                                'messege': message,
                                'created_at': DateTime.now().toIso8601String(),
                              });
                            }

                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text('تم حفظ رسالة الواتس اب المخصصة'),
                                  ],
                                ),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                margin: EdgeInsets.all(16),
                              ),
                            );
                          },
                          icon: Icon(Icons.save, size: 24, color: Colors.white),
                          label: Text(
                            'حفظ رسالة التسديد',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                            backgroundColor: color,
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            shadowColor: color.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }






  Widget _insertVariableButton(String label, TextEditingController controller, void Function(void Function()) setState) {
    return OutlinedButton(
      onPressed: () {
        final text = controller.text;
        final selection = controller.selection;
        final newText = text.replaceRange(
          selection.start,
          selection.end,
          label,
        );
        setState(() {
          controller.text = newText;
          controller.selection = TextSelection.collapsed(offset: selection.start + label.length);
        });
      },
      child: Text(label),
    );
  }

  // Dialog for managing delegates (مندوبين) - modern design, similar to groups dialog
  Future<void> _showUserDelegatesDialog(BuildContext context, Color color) async {
    TextEditingController usernameController = TextEditingController();
    TextEditingController passwordController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 60,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'إدارة المندوبين',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: usernameController,
                          decoration: InputDecoration(
                            labelText: 'اسم المستخدم',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                            onPressed: () async {
                              final rawUsername = usernameController.text.trim();
                              final password = passwordController.text.trim();

                              if (rawUsername.isEmpty || password.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('الرجاء ملء جميع الحقول')),
                                );
                                return;
                              }

                              if (rawUsername.length < 6) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('اسم المستخدم يجب أن لا يقل عن 6 أحرف')),
                                );
                                return;
                              }

                              if (RegExp(r'[\u0600-\u06FF]').hasMatch(rawUsername)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('اسم المستخدم يجب أن يكون باللغة الإنجليزية فقط')),
                                );
                                return;
                              }

                              final username = rawUsername;

                              final prefs = await SharedPreferences.getInstance();
                              final userId = prefs.getString('UserID');
                              if (userId == null) return;

                              // التحقق من التكرار
                              final existing = await Supabase.instance.client
                                  .from('delegates')
                                  .select('id')
                                  .eq('username', username)
                                  .eq('user_id', userId)
                                  .maybeSingle();

                              if (existing != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('⚠️ اسم المستخدم مستخدم مسبقًا')),
                                );
                                return;
                              }

                              final result = await Supabase.instance.client.from('delegates').insert({
                                'username': username,
                                'password': password,
                                'user_id': userId,
                              }).select().maybeSingle();
                              print('✅ Delegate added: $result');

                              usernameController.clear();
                              passwordController.clear();

                              setState(() {});

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('✅ تم إضافة المندوب بنجاح')),
                              );
                            },
                            icon: Icon(Icons.save_alt_rounded, size: 24, color: Colors.white),
                          label: Text(
                            'إضافة مندوب',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                            backgroundColor: color,
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            shadowColor: color.withOpacity(0.4),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 300,
                          child: FutureBuilder<List<Map<String, dynamic>>>(
                            future: _fetchDelegates(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(color),
                                  ),
                                );
                              }

                              final delegates = snapshot.data!;
                              if (delegates.isEmpty) {
                                return Center(
                                  child: Text(
                                    'لا يوجد مندوبون مسجلون',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                );
                              }

                              return ListView.builder(
                                itemCount: delegates.length,
                                itemBuilder: (ctx, index) {
                                  final delegate = delegates[index];
                                  return Dismissible(
                                    key: ValueKey(delegate['id']),
                                    direction: DismissDirection.horizontal, // يسمح بالسحب لليمين واليسار
                                    background: Container(
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.only(right: 22),
                                      decoration: BoxDecoration(
                                        color: Colors.red[400],
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        children: const [
                                          Icon(Icons.delete, color: Colors.white),
                                          SizedBox(width: 8),
                                          Text('حذف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),

                                    secondaryBackground: Container(
                                      alignment: Alignment.centerLeft,
                                      decoration: BoxDecoration(
                                        color: Colors.blueAccent,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 22), // ← المسافة من الحافة اليمنى
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(Icons.edit, color: Colors.white),
                                            SizedBox(width: 8),
                                            Text('تعديل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    confirmDismiss: (direction) async {
                                      final prefs = await SharedPreferences.getInstance();
                                      final userId = prefs.getString('UserID');

                                      if (direction == DismissDirection.endToStart) {
                                        // تعديل
                                        final nameController = TextEditingController(text: delegate['username']);
                                        final passwordController = TextEditingController(text: delegate['password']);

                                        await showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            title: const Text('تعديل المندوب'),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                TextField(
                                                  controller: nameController,
                                                  decoration: const InputDecoration(labelText: 'اسم المستخدم'),
                                                ),
                                                const SizedBox(height: 10),
                                                TextField(
                                                  controller: passwordController,
                                                  decoration: const InputDecoration(labelText: 'كلمة المرور'),
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx),
                                                child: const Text('إلغاء'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () async {
                                                  if (userId == null) return;
                                                  await Supabase.instance.client.from('delegates').update({
                                                    'username': nameController.text.trim(),
                                                    'password': passwordController.text.trim(),
                                                  }).match({
                                                    'id': delegate['id'],
                                                    'user_id': userId,
                                                  });
                                                  Navigator.pop(ctx);
                                                  setState(() {});
                                                },
                                                child: const Text('تعديل'),
                                              ),
                                            ],
                                          ),
                                        );
                                        return false; // لا نحذف العنصر
                                      } else if (direction == DismissDirection.startToEnd) {
                                        // حذف
                                        if (userId == null || userId.isEmpty) return false;

                                        final payments = await Supabase.instance.client
                                            .from('payments')
                                            .select('id')
                                            .eq('delegate_id', delegate['id']);

                                        if (payments.isNotEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('لا يمكن حذف هذا المندوب لأنه مرتبط بعمليات تسديد')),
                                          );
                                          return false;
                                        }

                                        await Supabase.instance.client
                                            .from('delegates')
                                            .delete()
                                            .match({'id': delegate['id'], 'user_id': userId});

                                        setState(() {});
                                        return true;
                                      }
                                      return false;
                                    },
                                    child: Card(
                                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        title: Text(
                                          delegate['username'].startsWith('@') ? delegate['username'] : '@${delegate['username']}',
                                          textDirection: TextDirection.ltr,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Text(
                                          delegate['password'] ?? '',
                                          textDirection: TextDirection.ltr,
                                          style: const TextStyle(color: Colors.grey),
                                        ),
                                        trailing: Icon(Icons.person_outline, color: Colors.grey[400]),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
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
  Future<List<Map<String, dynamic>>> _fetchDelegates() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');
    if (userId == null) return [];
    final response = await Supabase.instance.client
        .from('delegates')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
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
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        title: const Text(
          'نوافذ إضافية',
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
              onPressed: () => _showUserSettingsDialog(context, Color(0xFFD48241)),
              icon: const Icon(Icons.settings, size: 18, color: Colors.white),
              label: const Text(
                'الإعدادات العامة',
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
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: items.length,

        itemBuilder: (context, index) {
          final item = items[index];

          if (loadingIndex == index) {
            return _buildLoadingCard(item['color']); // كارد مؤقت فيه مؤشر تحميل
          }

          return _buildOptionCard(
            icon: item['icon'],
            title: item['title'],
            subtitle: item['subtitle'], // يمكنك إضافة وصف لاحقاً إذا أردت
            color: item['color'],
            onTap: () async {
              setState(() => loadingIndex = index);

              await Future.delayed(const Duration(milliseconds: 300));
              await _showCustomDialog(context, item);

              setState(() => loadingIndex = null);
            },
          );
        },

      ),

    );
  }
  Widget _buildLoadingCard(Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withOpacity(0.05),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: const Center(
        child: SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.15),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_left_rounded, color: color),
          ],
        ),
      ),
    );
  }

}
Widget _buildLoadingCard(Color color) {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.symmetric(vertical: 20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      color: color.withOpacity(0.05),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: const Center(
      child: SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
    ),
  );
}

Future<void> _showUserprinterDialog(BuildContext context, Color color) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');
    if (userId == null) return;

    TextEditingController storeNameController = TextEditingController();
    TextEditingController phone1Controller = TextEditingController();
    TextEditingController phone2Controller = TextEditingController();
    TextEditingController notesController = TextEditingController();

    File? selectedImage;
    String? base64Image;
    final picker = ImagePicker();

    final existing = await Supabase.instance.client
        .from('print_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      storeNameController.text = existing['store_name'] ?? '';
      phone1Controller.text = existing['phone1'] ?? '';
      phone2Controller.text = existing['phone2'] ?? '';
      notesController.text = existing['notes'] ?? '';

      if (existing['report_image_url'] != null) {
        final bytes = base64Decode(existing['report_image_url']);
        final tempDir = await getTemporaryDirectory();
        final tempFile = await File('${tempDir.path}/report_image.png').writeAsBytes(bytes);
        selectedImage = tempFile;
        base64Image = existing['report_image_url'];
      }
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) {
            return StatefulBuilder(
              builder: (context, setState) {
                return Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                      left: 16,
                      right: 16,
                      top: 16,
                    ),
                    child: SingleChildScrollView(
                      controller: controller,
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 60,
                              height: 5,
                              margin: EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          Center(
                            child: Text(
                              'إعدادات الطباعة',
                              style: TextStyle(
                                color: color,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(height: 20),
                          // صورة يمكن اختيارها
                          GestureDetector(
                            onTap: () async {
                              try {
                                final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                                if (pickedFile == null) return;

                                final imageFile = File(pickedFile.path);
                                final bytes = await imageFile.readAsBytes();

                                // تحقق من الحجم
                                if (bytes.length > 2 * 1024 * 1024) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('⚠️ الصورة كبيرة جدًا، الحد الأقصى 2MB'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                // ✅ قص الصورة إلى الحجم المطلوب
                                final decodedImage = img.decodeImage(bytes);
                                if (decodedImage == null) throw Exception("فشل في قراءة الصورة");

                                final croppedImage = img.copyResize(decodedImage, width: 1513, height: 648);                                final resized = img.copyResize(croppedImage, width: 1513, height: 648);

                                final resizedBytes = img.encodePng(resized);
                                final base64 = base64Encode(resizedBytes);

                                setState(() {
                                  selectedImage = imageFile;
                                  base64Image = base64;
                                });
                              } catch (e) {
                                print('❌ خطأ في اختيار أو معالجة الصورة: $e');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('فشل في تحميل الصورة'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            child: Container(
                              height: 140,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(12),
                                image: selectedImage != null
                                    ? DecorationImage(
                                  image: FileImage(selectedImage!)..evict(),
                                  fit: BoxFit.cover,
                                )
                                    : null,
                              ),
                              child: selectedImage == null
                                  ? Center(
                                      child: Icon(Icons.image, size: 50, color: Colors.grey[400]),
                                    )
                                  : null,
                            ),
                          ),
                          SizedBox(height: 20),
                          // Store name
                          TextField(
                            controller: storeNameController,
                            decoration: InputDecoration(
                              labelText: 'اسم المحل',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          SizedBox(height: 16),
                          // Phone 1
                          TextField(
                            controller: phone1Controller,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'رقم الهاتف الأول',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          SizedBox(height: 16),
                          // Phone 2
                          TextField(
                            controller: phone2Controller,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'رقم الهاتف الثاني',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          SizedBox(height: 16),
                          // Notes
                          TextField(
                            controller: notesController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'ملاحظات',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          SizedBox(height: 24),
                          Center(
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final prefs = await SharedPreferences.getInstance();
                                  final userId = prefs.getString('UserID');
                                  if (userId == null) return;

                                  final dataToUpdate = {
                                    'store_name': storeNameController.text.trim(),
                                    'phone1': phone1Controller.text.trim(),
                                    'phone2': phone2Controller.text.trim(),
                                    'notes': notesController.text.trim(),
                                    'user_id': userId,
                                    'report_image_url': base64Image,
                                  };

                                  // إزالة null حتى لا تُحدث حقول غير مرغوبة
                                  dataToUpdate.removeWhere((key, value) => value == null);

                                  try {
                                    final response = await Supabase.instance.client
                                        .from('print_settings')
                                        .upsert(dataToUpdate, onConflict: 'user_id')
                                        .select()
                                        .maybeSingle();

                                    setState(() {});

                                    // --- تحميل الصورة المحدثة من قاعدة البيانات بعد حفظها ---
                                    final refreshed = await Supabase.instance.client
                                        .from('print_settings')
                                        .select()
                                        .eq('user_id', userId)
                                        .maybeSingle();

                                    if (refreshed != null && refreshed['report_image_url'] != null) {
                                      final refreshedBytes = base64Decode(refreshed['report_image_url']);
                                      final refreshedTempDir = await getTemporaryDirectory();
                                      final uniqueFileName = 'report_image_${DateTime.now().millisecondsSinceEpoch}.png';
                                      final refreshedFile = await File('${refreshedTempDir.path}/$uniqueFileName').writeAsBytes(refreshedBytes);
                                      selectedImage = refreshedFile;
                                      base64Image = refreshed['report_image_url'];
                                      setState(() {});
                                    }
                                    // -------------------------------------------------------

                                    setState(() {});
                                    Navigator.of(ctx).pop();

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            Icon(Icons.check_circle, color: Colors.white),
                                            SizedBox(width: 8),
                                            Text('تم حفظ إعدادات الطباعة'),
                                          ],
                                        ),
                                        backgroundColor: Colors.green,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        margin: EdgeInsets.all(16),
                                      ),
                                    );
                                  } catch (e) {
                                    print('خطأ أثناء حفظ إعدادات الطباعة: $e');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            Icon(Icons.error, color: Colors.white),
                                            SizedBox(width: 8),
                                            Text('فشل حفظ الإعدادات'),
                                          ],
                                        ),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        margin: EdgeInsets.all(16),
                                      ),
                                    );
                                  }
                                },
                                icon: Icon(Icons.save_alt_rounded, color: Colors.white),
                                label: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    'حفظ الإعدادات',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: color,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 5,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
Future<void> _showCustomWdeletemonybakyDialog(BuildContext context, Color color) async {
  final supabase = Supabase.instance.client;
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('UserID')?.trim() ?? '';

  final response = await supabase
      .from('installments_delete')
      .select()
      .eq('user_id', userId)
      .order('date_delete', ascending: false);

  final List<Map<String, dynamic>> deletedList = List<Map<String, dynamic>>.from(response);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'سلة مهملات الأقساط',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (deletedList.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('لا توجد سجلات محذوفة'),
              )
            else
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.65,
                child: ListView.builder(
                  itemCount: deletedList.length,
                  itemBuilder: (context, index) {
                    final item = deletedList[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('العميل: ${item['customer_name'] ?? '---'}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('الصنف: ${item['item_type'] ?? '---'}'),
                            Text('تاريخ الحذف: ${_formatDate(item['date_delete'])}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      );
    },
  );
}


String _formatAmount(dynamic value) {
  final double amount = double.tryParse(value.toString()) ?? 0.0;
  return intl.NumberFormat("#,##0.00", "en_US").format(amount);
}

String _formatDate(dynamic value) {
  if (value == null) return '---';
  final date = DateTime.tryParse(value.toString());
  return date != null ? intl.DateFormat('yyyy-MM-dd').format(date) : '---';
}
Future<void> _showCustomWdeletemonytasdedDialog(BuildContext context, Color color) async {
  final supabase = Supabase.instance.client;
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('UserID')?.trim();

  if (userId == null || userId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User ID غير متوفر')));
    return;
  }

  final response = await supabase
      .from('payments_delete')
      .select()
      .eq('user_id', userId)
      .order('date_delete', ascending: false);

  final List<Map<String, dynamic>> deletedPayments = List<Map<String, dynamic>>.from(response);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'سلة مهملات المبالغ المسددة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (deletedPayments.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('لا توجد سجلات محذوفة'),
              )
            else
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.65,
                child: ListView.builder(
                  itemCount: deletedPayments.length,
                  itemBuilder: (context, index) {
                    final item = deletedPayments[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('العميل: ${item['customer_name'] ?? '---'}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('الصنف: ${item['item_type'] ?? '---'}'),
                            Text('المبلغ المسدد: ${_formatAmount(item['amount_paid'])}'),
                            Text('تاريخ التسديد: ${_formatDate(item['payment_date'])}'),
                            Text('تاريخ الحذف: ${_formatDate(item['date_delete'])}'),
                            Text('النوع: ${item['type'] ?? '---'}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      );
    },
  );

}

