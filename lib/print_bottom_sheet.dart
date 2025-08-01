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
import 'package:intl/intl.dart' as intl;
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';


class PrintBottomSheet extends StatefulWidget {
  final String customerName;
  final String itemName;
  final String totalAmount;
  final String remainingAmount;
  final String paidAmount;
  final String paymentDate;
  final String dueDate;
  final String id;


  const PrintBottomSheet({
    super.key,
    required this.customerName,
    required this.itemName,
    required this.totalAmount,
    required this.remainingAmount,
    required this.paidAmount,
    required this.paymentDate,
    required this.dueDate,
    required this.id,

  });

  @override
  State<PrintBottomSheet> createState() => _PrintBottomSheetState();
}

class _PrintBottomSheetState extends State<PrintBottomSheet> {

  Map<String, dynamic>? printSettings;
  final GlobalKey previewKey = GlobalKey();
  bool isPrinting = false;
  String status = 'جاري التحضير للطباعة...';
  bool isSliding = false;
  bool useWithoutResponse = false;
  @override
  void initState() {
    super.initState();
    _prepareBluetooth();
    _loadPrintSettings().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _waitForPreviewReady(); // ← انتظر اكتمال الرسم
        if (mounted) _startPrintProcess();
      });    });
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
      status = 'جاري البحث عن الطابعات...';
    });

    try {
      final imageBytes = await _captureWidgetAsImage(previewKey);
      final escPosData = await _convertImageToEscPos(imageBytes);

      List<BluetoothDevice> devices = [];

      final btState = await FlutterBluePlus.state.first;
      print('🔍 Bluetooth state: $btState');
      if (btState != BluetoothAdapterState.on) {
        print('❌ البلوتوث غير مفعل');
        setState(() {
          status = '❌ الرجاء تفعيل البلوتوث أولاً.';
        });
        return;
      }

      if (Platform.isAndroid) {
        print('🔐 طلب صلاحيات Bluetooth Scan/Connect وLocation...');
        await Permission.bluetoothScan.request();
        await Permission.bluetoothConnect.request();
        await Permission.location.request();
      }

      final subscription = FlutterBluePlus.scanResults.listen((results) {
        for (var r in results) {
          devices.add(r.device);
        }
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
      await Future.delayed(const Duration(seconds: 4));
      await FlutterBluePlus.stopScan();
      await subscription.cancel();

      final connected = await FlutterBluePlus.connectedDevices;
      devices.addAll(connected);
      devices = devices.toSet().toList();

      if (devices.isEmpty) {
        setState(() {
          status = '❌ لم يتم العثور على أي أجهزة بلوتوث.';
        });
        return;
      }

      if (!context.mounted) return;

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

      if (device == null) return;

      setState(() => status = '🔌 جاري الاتصال بالطابعة...');
      await device.connect(autoConnect: false);
      setState(() => isSliding = true);

      final services = await device.discoverServices();
      print('🔍 تم اكتشاف ${services.length} خدمة');

      BluetoothCharacteristic? selectedChar;
      for (var service in services) {
        for (var char in service.characteristics) {
          if (char.properties.write || char.properties.writeWithoutResponse) {
            try {
              await char.write([0x0A], withoutResponse: false);
              selectedChar = char;
              useWithoutResponse = false;
              print('✅ الكتابة ناجحة بـ withoutResponse: false — ${char.uuid}');
              break;
            } catch (_) {
              try {
                await char.write([0x0A], withoutResponse: true);
                selectedChar = char;
                useWithoutResponse = true;
                print('✅ الكتابة ناجحة بـ withoutResponse: true — ${char.uuid}');
                break;
              } catch (_) {
                print('❌ خاصية فاشلة: ${char.uuid}');
                continue;
              }

            }
          }
        }
        if (selectedChar != null) break;
      }

      if (selectedChar == null) {
        throw 'لا يوجد خاصية كتابة متوافقة';
      }

      const chunkSize = 180;
      final totalChunks = (escPosData.length / chunkSize).ceil();
      for (int i = 0; i < escPosData.length; i += chunkSize) {
        final chunk = escPosData.sublist(
          i,
          i + chunkSize > escPosData.length ? escPosData.length : i + chunkSize,
        );
        await selectedChar.write(chunk, withoutResponse: useWithoutResponse);      }

      await device.disconnect();
      setState(() => status = '✅ تم إرسال الطباعة بنجاح');
    } catch (e, st) {
      final errorMessage = '''
❌ حدث خطأ أثناء الطباعة:
- الرسالة: $e
- النوع: ${e.runtimeType}
- التفاصيل: ${st.toString().split('\n').take(3).join('\n')}
''';

      print(errorMessage);

      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('❌ خطأ أثناء الطباعة'),
            content: SingleChildScrollView(
              child: Text(errorMessage, style: const TextStyle(fontSize: 13)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('موافق'),
              ),
            ],
          ),
        );
      }

      setState(() {
        status = '❌ فشلت عملية الطباعة. يرجى المحاولة مرة أخرى.';
      });
    } finally {
      setState(() {
        isPrinting = false;
        isSliding = false;
      });
    }
  }
  Future<void> _waitForPreviewReady() async {
    bool isReady = false;
    while (!isReady) {
      await Future.delayed(const Duration(milliseconds: 100));
      final boundary = previewKey.currentContext?.findRenderObject();
      if (boundary is RenderRepaintBoundary && !boundary.debugNeedsPaint) {
        isReady = true;
      }
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

  String cleanText(String input) {
    return input
        .replaceAll(RegExp(r'[\u200e\u200f\u202a-\u202e]'), '') // حذف الرموز المخفية
        .replaceAll('\n', '')
        .trim();
  }

  Widget _buildReceiptWidget() {
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd hh:mm a').format(now);
    // استخدم الإعدادات المحمّلة من Supabase أو افتراضي فارغ
    final Map<String, dynamic> settings = printSettings ?? {};

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
        height: 180, // ← 🔺 زِد هذه القيمة حسب ما تريد
        fit: BoxFit.fill, // ← لملء العرض والطول الجديد
      ),
    )
        : const SizedBox();


    final currencyFormatter = NumberFormat('#,##0', 'ar');
    double cleanAmount(dynamic value) {
      try {
        return double.parse(value.toString().replaceAll(',', ''));
      } catch (_) {
        return 0.0;
      }
    }

    final paidAmount = cleanAmount(widget.paidAmount);
    final remainingAmount = cleanAmount(widget.remainingAmount);
    final totalBeforePayment = paidAmount + remainingAmount;

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          image,
          const SizedBox(height: 22),
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

          // 🔵 اسم العميل
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey,
              border: Border.all(color: Colors.black, width: 1), // ✅ حافة سوداء
            ),
            child: const Text(
              'اسم العميل',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
            ),
          ),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black),
            ),
            child: Text(
              cleanText(widget.customerName), // ✅ تنظيف النص هنا
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none, // ⛔ منع الخطوط الزائدة
                color: Colors.black,
              ),
            ),
          ),

          const SizedBox(height: 22),

          // 🟢 الصنف
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey,
              border: Border.all(color: Colors.black, width: 1), // ✅ حافة سوداء
            ),
            child: const Text(
              'اسم الصنف',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black),
            ),
            child: Text(
              widget.itemName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 15),
          // 💰 معلومات القسط
          _buildInfoRow(' الباقي قبل الدفع:', '${currencyFormatter.format(totalBeforePayment)} د.ع'),
          const SizedBox(height: 8),

          _buildInfoRow('الدفعة المسددة:', '${widget.paidAmount} د.ع'),
          const SizedBox(height: 8),

          _buildInfoRow('المبلغ المتبقي:', '${currencyFormatter.format(remainingAmount)} د.ع'),
          const SizedBox(height: 25),

          // 📅 التواريخ
          Row(
            children: [
              // 🟥 تاريخ التسديد
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        border: Border.all(color: Colors.black, width: 1), // ✅ حافة سوداء
                      ),
                      child: const Text(
                        'تاريخ التسديد',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black),
                      ),
                      child: Text(
                        widget.paymentDate,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // 🟦 الاستحقاق القادم
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        border: Border.all(color: Colors.black, width: 1), // ✅ حافة سوداء
                      ),
                      child: const Text(
                        'تاريخ الاستحقاق',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black),
                      ),
                      child: Text(
                        widget.dueDate,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),


          const Divider(thickness: 1.5),

          Text(
            '📞 $phone1',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            '📞 $phone2',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 4),

          Text(
            notes,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),


          const SizedBox(height: 30), // ← مسافة قبل النهاية

          Center(
            child: Text(
              '© تم تطوير التطبيق بواسطة فريق Update Software',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16, // 🔺 أكبر
                fontWeight: FontWeight.w600, // 🔺 أكثر وضوحًا
                color: Colors.black87,
              ),
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 19, // 🔺 أكبر من السابق
                fontWeight: FontWeight.w900, // 🔺 بولد جداً
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }






  Future<void> shareReceiptViaWhatsApp() async {
    try {
      // 1. التقط صورة للوصل باستخدام RepaintBoundary
      RenderRepaintBoundary boundary = previewKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // 2. احفظها مؤقتًا
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.png').create();
      await file.writeAsBytes(pngBytes);

      // 3. شاركها عبر واتساب أو مشاركة عامة

      final now = DateTime.now();
      final formattedDate = DateFormat('yyyy/MM/dd – hh:mm a').format(now); // مثل: 2025/07/05 – 03:45 PM
      final message = '📄 وصل دفع العميل ${widget.customerName} من تطبيق أقساط في تاريخ $formattedDate';

      await Share.shareXFiles(
        [XFile(file.path)],
        text: message,
      );
      print('✅ تمت المشاركة عبر واتساب');
    } catch (e) {
      print("❌ فشل مشاركة الصورة: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // ✅ القسم المتحرك للوصل مع Scroll
                AnimatedSlide(
                  offset: isSliding ? const Offset(0, -4.2) : Offset.zero,
                  duration: isSliding
                      ? const Duration(seconds: 4)
                      : const Duration(milliseconds: 800),
                  curve: Curves.easeInOut, // ✅ هذا هو السر في النعومة

                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 20, bottom: 200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [

                        // 🟢 صف الأزرار: مشاركة وواتساب
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween, // ← توزيع على الطرفين
                            children: [

                              // زر المشاركة - على اليسار
                              ElevatedButton.icon(
                                onPressed: shareReceiptViaWhatsApp,
                                icon: const Icon(Icons.share, color: Colors.white),
                                label: const Text(
                                  'مشاركة',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(20),
                                      bottomLeft: Radius.circular(20),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Align(
                          alignment: Alignment.topCenter,
                          child: RepaintBoundary(
                            key: previewKey,
                            child: _buildReceiptWidget(), // الوصل
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ✅ القسم السفلي الثابت
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: MediaQuery.of(context).padding.bottom + 20, // ⬅️ هذا هو التعديل
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blueGrey,
                          Colors.teal.shade600,
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          spreadRadius: 3,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: isPrinting
                              ? const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          )
                              : const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 40,
                            key: ValueKey('check_icon'),
                          ),
                        ),
                        const SizedBox(height: 15),
                        AnimatedOpacity(
                          opacity: 1.0,
                          duration: const Duration(milliseconds: 500),
                          child: Text(
                            status,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton(
                              onPressed: _startPrintProcess,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.teal.shade700,
                                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 5,
                                shadowColor: Colors.black.withOpacity(0.3),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.search, size: 20),
                                  SizedBox(width: 8),
                                  Text('إعادة البحث', style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 5,
                                shadowColor: Colors.black.withOpacity(0.3),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.close, size: 20),
                                  SizedBox(width: 8),
                                  Text('إغلاق', style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}