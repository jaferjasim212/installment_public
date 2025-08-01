import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrintkashefAccount extends StatefulWidget {
  final String customerName;
  final String itemName;
  final String totalAmount;
  final String remainingAmount;
  final String paymentDate;
  final String dueDate;

  const PrintkashefAccount({
    super.key,
    required this.customerName,
    required this.itemName,
    required this.totalAmount,
    required this.remainingAmount,
    required this.paymentDate,
    required this.dueDate,
  });

  @override
  State<PrintkashefAccount> createState() => _PrintkashefAccountState();
}

class _PrintkashefAccountState extends State<PrintkashefAccount> {

  Map<String, dynamic>? printSettings;
  final GlobalKey previewKey = GlobalKey();
  bool isPrinting = false;
  String status = 'جاري التحضير للطباعة...';

  @override
  void initState() {
    super.initState();
    _prepareBluetooth();
    _loadPrintSettings().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startPrintProcess());
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
    });

    try {
      final imageBytes = await _captureWidgetAsImage(previewKey);
      final escPosData = await _convertImageToEscPos(imageBytes);

      List<ScanResult> results = [];

      FlutterBluePlus.scanResults.listen((r) {
        results = r;
      });

      await FlutterBluePlus.startScan();
      await Future.delayed(const Duration(seconds: 4));
      await FlutterBluePlus.stopScan();

      final devices = results.map((r) => r.device).toList();

      if (!context.mounted) return;
      final device = await showDialog<BluetoothDevice>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text("اختر الطابعة"),
          children: devices.map((d) {
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(context, d),
              child: Row(
                children: [
                  const Icon(Icons.print, color: Colors.black54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      d.name.isNotEmpty ? d.name : '(بدون اسم) - ${d.id}',
                      style: const TextStyle(color: Colors.black),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      );

      if (device == null) return;

      setState(() => status = 'جاري الاتصال بالطابعة...');
      await device.connect();

      final services = await device.discoverServices();
      final characteristic = services
          .expand((s) => s.characteristics)
          .firstWhere((c) => c.properties.write, orElse: () => throw 'لا يوجد خاصية كتابة');

      const chunkSize = 500;
      for (int i = 0; i < escPosData.length; i += chunkSize) {
        final chunk = escPosData.sublist(
          i,
          i + chunkSize > escPosData.length ? escPosData.length : i + chunkSize,
        );
        await characteristic.write(chunk, withoutResponse: true);
        await Future.delayed(const Duration(milliseconds: 20)); // إعطاء مهلة للطابعة
      }      await device.disconnect();

      if (context.mounted) {
        setState(() => status = '✅ تم إرسال الطباعة بنجاح');
      }
    } catch (e) {
      setState(() => status = '❌ فشلت عملية الطباعة: $e');print('❌ فشلت عملية الطباعة: $e');
    } finally {
      setState(() => isPrinting = false);
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

    // إذا كان هناك صورة base64 من إعدادات الطباعة
    final base64Image = printSettings?['report_image_url'];
    if (base64Image != null) {
      try {
        final decoded = base64Decode(base64Image);
        final headerImage = img.decodeImage(decoded);
        if (headerImage != null) {
          final resizedHeader = img.copyResize(headerImage, width: 384);
          bytesList.addAll(generator.imageRaster(resizedHeader, align: PosAlign.center));
          bytesList.addAll(generator.feed(1));
        }
      } catch (_) {
        // تجاهل الأخطاء إذا كانت الصورة غير صالحة
      }
    }

    // صورة الوصل الملتقطة من الواجهة
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
    final formattedDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // استخدم الإعدادات المحمّلة من Supabase أو افتراضي فارغ
    final Map<String, dynamic> settings = printSettings ?? {};

    final base64Image = settings['report_image_url'];
    final storeName = settings['store_name'] ?? '';
    final phone1 = settings['phone1'] ?? '';
    final phone2 = settings['phone2'] ?? '';
    final notes = settings['notes'] ?? '';

    final image = base64Image != null
        ? Image.memory(
      Uint8List.fromList(base64Decode(base64Image)),
      width: 150,
      height: 100,
      fit: BoxFit.contain,
    )
        : const SizedBox();

    Widget borderedBox(String label, String value) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black),
            ),
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Container(
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
            ),
            child: Text(value, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 8),
        ],
      );
    }

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
          const SizedBox(height: 4),
          Text(
            formattedDate,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          borderedBox('اسم العميل', widget.customerName),
          borderedBox('الصنف', widget.itemName),
          _buildInfoRow('المبلغ الكلي:', '${widget.totalAmount} د.ع'),
          _buildInfoRow('المبلغ المتبقي:', '${widget.remainingAmount} د.ع'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: borderedBox('الاستحقاق القادم', widget.dueDate)),
            ],
          ),
          const Divider(thickness: 1.5),
          Text('📞 $phone1'),
          Text('📞 $phone2'),
          const SizedBox(height: 4),
          Text(notes, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          const Text('© تم تطوير التطبيق بواسطة فريق Update Software', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
          const SizedBox(height: 30),
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
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 18))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            key: previewKey,
            child: _buildReceiptWidget(),
          ),
          const SizedBox(height: 20),
          isPrinting
              ? const CircularProgressIndicator()
              : const Icon(Icons.check_circle, color: Colors.green, size: 48),
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
                onPressed: () {
                  _startPrintProcess(); // إعادة محاولة البحث والطباعة
                },
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
          )
        ],
      ),
    );
  }
}