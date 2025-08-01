import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrintKashef extends StatefulWidget {
  final String customerName;
  final String itemType;
  final double totalAmount;
  final double remainingAmount;
  final String dueDate;
  final List<Map<String, dynamic>> payments;

  const PrintKashef({
    super.key,
    required this.customerName,
    required this.itemType,
    required this.totalAmount,
    required this.remainingAmount,
    required this.dueDate,
    required this.payments,
  });

  @override
  State<PrintKashef> createState() => _PrintKashefState();
}



class _PrintKashefState extends State<PrintKashef> {
  Map<String, dynamic>? installmentDetails;
  List<Map<String, dynamic>> payments = [];
  Map<String, dynamic>? printSettings;
  final GlobalKey previewKey = GlobalKey();
  bool isPrinting = false;
  String status = 'جاري التحضير للطباعة...';

  @override
  void initState() {
    super.initState();

    _prepareBluetooth();

    _loadPrintSettings().then((_) {
      if (!mounted) return; // ✅ تحقق قبل البدء
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return; // ✅ تحقق قبل تشغيل الطباعة
        _startPrintProcess();
      });
    });
  }


  Future<void> _loadPrintSettings() async {
    final supabase = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');
    if (userId == null) return;
    final data = await supabase
        .from('print_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (data != null) {
      setState(() {
        printSettings = data;
      });
    }
  }

  Future<void> _prepareBluetooth() async {
    // التحقق من حالة البلوتوث
    final permission = await FlutterBluePlus.adapterState.first;
    if (permission != BluetoothAdapterState.on) {
      setState(() {
        status = '❌ الرجاء التأكد من أن البلوتوث مفعّل.';
      });
      return;
    }

    // طلب صلاحية الموقع
    final locationStatus = await Permission.location.status;
    if (!locationStatus.isGranted) {
      final granted = await Permission.location.request();
      if (!granted.isGranted) {
        setState(() {
          status = '❌ يتطلب التطبيق صلاحية الموقع للبحث عن الطابعات.';
        });
        return;
      }
    }

    // طلب صلاحيات الموقع والبلوتوث حسب النظام
    await FlutterBluePlus.turnOn();
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    List<BluetoothDevice> devices = [];

    await for (final r in FlutterBluePlus.scanResults) {
      devices = r.map((e) => e.device).toList();
      break;
    }
    FlutterBluePlus.stopScan();
  }

  Future<void> _startPrintProcess() async {
    setState(() {
      isPrinting = true;
      status = '🔄 جاري البحث عن الطابعات...';
    });

    try {
      // 1. التقط صورة الفاتورة وحولها إلى بيانات ESC/POS
      final imageBytes = await _captureWidgetAsImage(previewKey);
      final escPosData = await _convertImageToEscPos(imageBytes);

      List<BluetoothDevice> devices = [];

      // 2. تأكد من حالة البلوتوث
      final btState = await FlutterBluePlus.state.first;
      print('🔍 Bluetooth state: $btState');
      if (btState != BluetoothAdapterState.on) {
        print('❌ البلوتوث غير مفعل');
        setState(() {
          status = '❌ الرجاء تفعيل البلوتوث أولاً.';
        });
        return;
      }

      // 3. اطلب صلاحيات الأندرويد 12+ للمسح والاتصال
      if (Platform.isAndroid) {
        print('🔐 طلب صلاحيات Bluetooth Scan/Connect وLocation...');
        await Permission.bluetoothScan.request();
        await Permission.bluetoothConnect.request();
        await Permission.location.request();
        print('🔐 حالة صلاحيات Scan: ${await Permission.bluetoothScan.status}');
        print('🔐 حالة صلاحيات Connect: ${await Permission.bluetoothConnect.status}');
        print('🔐 حالة صلاحيات Location: ${await Permission.location.status}');
      }

      // 4. اشترك في نتائج المسح
      print('🔍 الاشتراك في نتائج المسح...');
      final subscription = FlutterBluePlus.scanResults.listen((results) {
        print('🔍 تحديث نتائج المسح: ${results.length} أجهزة');
        for (var r in results) {
          final name = r.device.name.isNotEmpty ? r.device.name : '(بدون اسم)';
          print(' • [Scan] $name — ${r.device.id}');
          devices.add(r.device);
        }
      });

      // 5. ابدأ المسح وأعطه 4 ثواني
      print('🔍 بدء المسح لمدة 4 ثوانٍ...');
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

      // 6. انتظر 4 ثواني حتى ينتهي المسح
      await Future.delayed(const Duration(seconds: 4));

      // 7. أوقف المسح وإلغاء الاشتراك
      print('⏹️ إيقاف المسح');
      await FlutterBluePlus.stopScan();
      await subscription.cancel();

      // 8. جلب الأجهزة المقترنة حالياً
      final connected = await FlutterBluePlus.connectedDevices;
      print('🔌 الأجهزة المرتبطة حالياً: ${connected.length}');
      for (var d in connected) {
        final name = d.name.isNotEmpty ? d.name : '(بدون اسم)';
        print(' • [Connected] $name — ${d.id}');
        devices.add(d);
      }

      // 9. إزالة التكرارات
      devices = devices.toSet().toList();
      print('✅ بعد إزالة التكرار: ${devices.length} جهاز إجمالي');

      // 10. تحقق من وجود أجهزة
      if (devices.isEmpty) {
        print('❌ لم يتم العثور على أي جهاز');
        setState(() {
          status = '❌ لم يتم العثور على أي أجهزة بلوتوث.';
        });
        return;
      }

      if (!context.mounted) return;

      // 11. عرض قائمة اختيار الطابعة
      final device = await showDialog<BluetoothDevice>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text("اختر الطابعة"),
          children: devices.map((d) => SimpleDialogOption(
            onPressed: () => Navigator.pop(context, d),
            child: Row(
              children: [
                const Icon(Icons.print, color: Colors.black54),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  d.name.isNotEmpty ? d.name : '(بدون اسم) - ${d.id}',
                  style: const TextStyle(color: Colors.black),
                )),
              ],
            ),
          )).toList(),
        ),
      );

      if (device == null) {
        print('❌ لم يختر المستخدم أي جهاز');
        return;
      }
      print('🖨️ جهاز مختار: ${device.name} — ${device.id}');

      setState(() => status = '🔌 جاري الاتصال بالطابعة...');
      print('🔗 محاولة الاتصال بـ ${device.id} ...');

      // 12. الاتصال بالجهاز
      await device.connect(autoConnect: false);
      print('✅ تم الاتصال');

      // 13. اكتشاف الخدمات
      final services = await device.discoverServices();
      print('🔍 تم اكتشاف ${services.length} خدمة');
      final characteristic = services
          .expand((s) => s.characteristics)
          .firstWhere(
            (c) => c.properties.write,
        orElse: () {
          print('❌ لا يوجد خاصية كتابة في هذه الطابعة');
          throw 'No writable characteristic';
        },
      );
      print('⚙️ خاصية الكتابة: ${characteristic.uuid}');

      // 14. إرسال البيانات على دفعات
      const chunkSize = 500;
      final totalChunks = (escPosData.length / chunkSize).ceil();
      for (int i = 0; i < escPosData.length; i += chunkSize) {
        final chunk = escPosData.sublist(
          i,
          i + chunkSize > escPosData.length ? escPosData.length : i + chunkSize,
        );
        final chunkIndex = (i / chunkSize).floor() + 1;
        print('📤 إرسال الدفعة $chunkIndex/$totalChunks (${chunk.length} bytes)');
        await characteristic.write(chunk, withoutResponse: true);
        await Future.delayed(const Duration(milliseconds: 20));
      }

      // 15. قطع الاتصال
      print('✂️ قطع الاتصال');
      await device.disconnect();
      print('✅ تم فصل الاتصال');

      if (context.mounted) {
        setState(() => status = '✅ تم إرسال الطباعة بنجاح');
      }
    } catch (e, st) {
      print('❌ خطأ في _startPrintProcess: $e');
      print(st);
      setState(() {
        status = '❌ فشلت عملية الطباعة: $e';
      });
    } finally {
      setState(() {
        isPrinting = false;
      });
    }
  }



  Future<Uint8List> _captureWidgetAsImage(GlobalKey key) async {
    RenderRepaintBoundary boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<List<int>> _convertImageToEscPos(Uint8List pngBytes) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final bytesList = <int>[];

    final base64Image = printSettings?['report_image_url'];
    if (base64Image != null) {
      try {
        final decoded = base64Decode(base64Image);
        final headerImage = img.decodeImage(decoded);
        if (headerImage != null) {
          // خلفية بيضاء بنفس حجم اللوغو
          final whiteBg = img.Image(
            width: headerImage.width,
            height: headerImage.height,
          );
          whiteBg.clear(img.ColorRgb8(255, 255, 255));
          img.compositeImage(whiteBg, headerImage);

          // إعادة تحجيم الصورة بعرض الورقة (384px)
          final resizedHeader = img.copyResize(whiteBg, width: 384);

          // padding علوي بسيط (20 بكسل) لمنع القص العلوي
          final paddedHeader = img.Image(
            width: 384,
            height: resizedHeader.height + 10, // تقليل الارتفاع العام
          );
          paddedHeader.clear(img.ColorRgb8(255, 255, 255));

          img.compositeImage(
            paddedHeader,
            resizedHeader,
            dstX: 0, // بدون إزاحة أفقية لأن العرض 384 كامل
            dstY: 10,
          );

          // طباعة اللوغو
          bytesList.addAll(generator.imageRaster(paddedHeader, align: PosAlign.center));
          bytesList.addAll(generator.feed(1));
        }
      } catch (e) {
        print('❌ خطأ في معالجة صورة الهيدر: $e');
      }
    }

    // طباعة صورة الوصل الملتقطة
    final mainImage = img.decodeImage(pngBytes);
    if (mainImage != null) {
      final resized = img.copyResize(mainImage, width: 384);
      bytesList.addAll(generator.imageRaster(resized, align: PosAlign.center));
    }

    bytesList.addAll(generator.feed(3));
    bytesList.addAll(generator.cut());

    return bytesList;
  }


  Widget _buildReceiptWidget() {
    final now = DateTime.now();
    final formattedDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final settings = printSettings ?? {};
    final base64Image = settings['report_image_url'];
    final storeName = settings['store_name'] ?? '';
    final phone1 = settings['phone1'] ?? '';
    final phone2 = settings['phone2'] ?? '';
    final notes = settings['notes'] ?? '';

    final image = base64Image != null
        ? Container(
      width: double.infinity,
      alignment: Alignment.center,
      child: Image.memory(
        Uint8List.fromList(base64Decode(base64Image)),
        width: 384,
        fit: BoxFit.fitWidth,
      ),
    )
        : const SizedBox();

    final currencyFormatter = NumberFormat('#,##0', 'ar');

    final customerName = widget.customerName;
    final itemName = widget.itemType;
    final totalAmount = widget.totalAmount;
    final remainingAmount = widget.remainingAmount;
    final dueDate = widget.dueDate;
    final payments = widget.payments;

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          image,
          const SizedBox(height: 8),
          Text(
            storeName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            formattedDate,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),

          // اسم العميل
          _buildTitleBox('اسم العميل'),
          _buildValueBox(customerName),
          const SizedBox(height: 22),

          // اسم الصنف
          _buildTitleBox('اسم الصنف'),
          _buildValueBox(itemName),
          const SizedBox(height: 15),

          // المبالغ
          _buildInfoRow('المبلغ الكلي:', '${currencyFormatter.format(totalAmount)} د.ع'),
          const SizedBox(height: 8),
          _buildInfoRow('المبلغ المتبقي:', '${currencyFormatter.format(remainingAmount)} د.ع'),
          const SizedBox(height: 15),

          // تاريخ الاستحقاق
          _buildTitleBox('تاريخ الاستحقاق'),
          _buildValueBox(dueDate),
          const SizedBox(height: 20),

          // جدول التسديدات
          if (payments.isNotEmpty)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1.2),
              ),
              child: Column(
                children: payments.map((payment) {
                  final date = payment['payment_date'] ?? '';
                  final amount = currencyFormatter.format(double.tryParse(payment['amount_paid'].toString()) ?? 0.0);
                  return Container(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.black)),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '💵 $amount د.ع',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          date,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            )
          else
            Text('لا توجد تسديدات.', style: TextStyle(fontSize: 16, color: Colors.grey)),

          const SizedBox(height: 20),
          const Divider(thickness: 1.5),
          Text(
            '📞 $phone1',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            '📞 $phone2',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            notes,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.bottomLeft,
            child: Text(
              '© تم تطوير التطبيق بواسطة فريق Update Software',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

// 🔷 مساعدات للعرض
  Widget _buildTitleBox(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey,
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
      ),
    );
  }

  Widget _buildValueBox(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
      ),
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontSize: 16)),
      ],
    );
  }



  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: RepaintBoundary(
                key: previewKey,
                child: _buildReceiptWidget(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (isPrinting)
            const CircularProgressIndicator()
          else
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
          const SizedBox(height: 10),
          Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                onPressed: () => _startPrintProcess(),
                icon: const Icon(Icons.search),
                label: const Text('إعادة البحث'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                label: const Text('إغلاق'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}