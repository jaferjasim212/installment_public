import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';


class Editecustomerscreen extends StatefulWidget {
  final String customerId;

  const Editecustomerscreen({super.key, required this.customerId});

  @override
  State<Editecustomerscreen> createState() => _EditecustomerscreenState();
}

class _EditecustomerscreenState extends State<Editecustomerscreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool hasOpeningBalance = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late AnimationController _selectionAnimationController;
  late Animation<Color?> _colorAnimation;
  late AnimationController _choiceAnimationController;
  late Animation<double> _choiceScaleAnimation;
  late Animation<double> _selectionScaleAnimation;
  List<XFile> _customerImages = [];
  bool _attachmentsSaved = false;
  bool _isLoading = true;

  final Map<String, TextEditingController> _controllers = {
    'cust_name': TextEditingController(),
    'cust_phone': TextEditingController(),
    'cust_age': TextEditingController(),
    'cust_address': TextEditingController(),
    'cust_card_number': TextEditingController(),
    'cust_note': TextEditingController(),
    'spon_name': TextEditingController(),
    'spon_phone': TextEditingController(),
    'spon_address': TextEditingController(),
    'spon_kinship': TextEditingController(),
    'spon_card_number': TextEditingController(),
  };

  bool _saving = false;
  String _type = '';

  @override
  void initState() {
    super.initState();
    _fetchFullCustomerData();
    // باقي تهيئة الأنيميشن كما هو
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
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
    _selectionAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _selectionScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _selectionAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _colorAnimation = ColorTween(
      begin: Colors.grey.shade50,
      end: Colors.teal.shade50,
    ).animate(_selectionAnimationController);
    _animationController.forward();
    _choiceAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _choiceScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _choiceAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _selectionAnimationController.dispose();
    super.dispose();
  }

  Future<void> _fetchFullCustomerData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('customers')
          .select()
          .eq('user_id', userId)
          .eq('id', widget.customerId)
          .single();

      if (response == null) return;

      // تعبئة البيانات
      _controllers['cust_name']!.text = response['cust_name'] ?? '';
      _controllers['cust_phone']!.text = response['cust_phone'] ?? '';
      _controllers['cust_age']!.text = response['cust_age'] ?? '';
      _controllers['cust_address']!.text = response['cust_address'] ?? '';
      _controllers['cust_card_number']!.text = response['cust_card_number'] ?? '';
      _controllers['cust_note']!.text = response['cust_note'] ?? '';
      _controllers['spon_name']!.text = response['spon_name'] ?? '';
      _controllers['spon_phone']!.text = response['spon_phone'] ?? '';
      _controllers['spon_address']!.text = response['spon_address'] ?? '';
      _controllers['spon_kinship']!.text = response['spon_kinship'] ?? '';
      _controllers['spon_card_number']!.text = response['spon_card_number'] ?? '';
      _type = response['type'] ?? '';

      await _loadCustomerImagesFromMap(response);
    } catch (e) {
      debugPrint("❌ فشل في جلب بيانات العميل: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCustomerImagesFromMap(Map<String, dynamic> data) async {
    final tempDir = await getTemporaryDirectory();
    final uuid = Uuid();

    for (int i = 1; i <= 9; i++) {
      final base64String = data['image$i'];
      if (base64String != null && base64String.isNotEmpty) {
        final bytes = base64Decode(base64String);
        final file = File('${tempDir.path}/${uuid.v4()}_image_$i.png');
        await file.writeAsBytes(bytes);
        _customerImages.add(XFile(file.path));
      }
    }

    if (_customerImages.isNotEmpty) {
      setState(() => _attachmentsSaved = true);
    }
  }
  Future<void> _updateCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');
    if (userId == null) return;

    final String customerId = widget.customerId;

    try {
      setState(() => _saving = true);

      final data = <String, dynamic>{
        'cust_name': _controllers['cust_name']!.text.trim(),
        'cust_phone': _controllers['cust_phone']!.text.trim(),
        'cust_age': _controllers['cust_age']!.text.trim(),
        'cust_address': _controllers['cust_address']!.text.trim(),
        'cust_card_number': _controllers['cust_card_number']!.text.trim(),
        'cust_note': _controllers['cust_note']!.text.trim(),
        'spon_name': _controllers['spon_name']!.text.trim(),
        'spon_phone': _controllers['spon_phone']!.text.trim(),
        'spon_address': _controllers['spon_address']!.text.trim(),
        'spon_kinship': _controllers['spon_kinship']!.text.trim(),
        'spon_card_number': _controllers['spon_card_number']!.text.trim(),
        'type': _type,
      };

      // ✅ تحويل الصور إلى base64
      final imageFutures = <Future<void>>[];
      for (int i = 0; i < _customerImages.length && i < 9; i++) {
        final file = File(_customerImages[i].path);
        imageFutures.add(file.readAsBytes().then((bytes) {
          final base64 = base64Encode(bytes);
          data['image${i + 1}'] = base64;
        }));
      }
      await Future.wait(imageFutures);

      // ✅ تنفيذ التحديث
      await Supabase.instance.client
          .from('customers')
          .update(data)
          .eq('id', customerId)
          .eq('user_id', userId);

      Navigator.pop(context, true);
    } catch (e) {
      print('❌ فشل في تحديث العميل: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في تحديث البيانات: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Colors.red[400],
        ),
      );
    } finally {
      setState(() => _saving = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl, // 👈 النصوص RTL
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.grey[50],
          elevation: 0,
          centerTitle: true,
          title: const Text('تعديل بيانات العميل'),
          automaticallyImplyLeading: false, // ⛔ يمنع السهم الافتراضي
          actions: [
            Padding(
              padding: const EdgeInsets.only(left: 12), // ⬅️ يتحكم بموقع السهم يساراً
              child: IconButton(
                icon: const Icon(Icons.arrow_forward, color: Colors.black),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
        body: _isLoading
            ? _buildShimmerLoader()
            : FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAccountTypeSection(),
                    const SizedBox(height: 30),
                    _buildSectionHeader('معلومات العميل الأساسية'),
                    _buildAnimatedTextField('cust_name', Icons.person_outline),
                    _buildAnimatedTextField('cust_phone', Icons.phone_android_outlined),
                    _buildAnimatedTextField('cust_age', Icons.cake_outlined),
                    _buildAnimatedTextField('cust_address', Icons.location_on_outlined),
                    _buildAnimatedTextField('cust_card_number', Icons.credit_card_outlined),
                    _buildAnimatedTextField('cust_note', Icons.note_add_outlined),
                    _buildSectionHeader('معلومات الكفيل'),
                    _buildAnimatedTextField('spon_name', Icons.person_outline),
                    _buildAnimatedTextField('spon_phone', Icons.phone_android_outlined),
                    _buildAnimatedTextField('spon_address', Icons.location_on_outlined),
                    _buildAnimatedTextField('spon_kinship', Icons.family_restroom_outlined),
                    _buildAnimatedTextField('spon_card_number', Icons.credit_card_outlined),
                    ElevatedButton.icon(
                      onPressed: _handleAttachmentPress,
                      icon: Icon(
                        _attachmentsSaved ? Icons.check_circle_outline : Icons.image_outlined,
                        color: _attachmentsSaved ? Colors.green.shade800 : Colors.blue.shade800,
                      ),
                      label: Text(
                        _attachmentsSaved ? 'تمت إضافة المرفقات' : 'إضافة مرفقات للعميل',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _attachmentsSaved ? Colors.green.shade800 : Colors.blue.shade800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _attachmentsSaved ? Colors.green.shade100 : Colors.blue.shade100,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 30),
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  void _handleAttachmentPress() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return CustomerImageGrid(
          onImagesUpdated: (selectedImages) {
            setState(() {
              _customerImages = selectedImages;
              _attachmentsSaved = _customerImages.isNotEmpty;
            });
          },
          initialImages: _attachmentsSaved ? _customerImages : [],
        );
      },
    );
  }

  Widget _buildShimmerLoader() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // نوع الحساب
          _buildShimmerText(width: 100, height: 16),
          const SizedBox(height: 12),
          _buildShimmerTextField(),
          const SizedBox(height: 30),

          // عنوان القسم الأول
          _buildShimmerText(width: 200),
          const SizedBox(height: 20),

          for (int i = 0; i < 6; i++) ...[
            _buildShimmerTextField(),
            const SizedBox(height: 16),
          ],

          // عنوان القسم الثاني
          _buildShimmerText(width: 200),
          const SizedBox(height: 20),

          for (int i = 0; i < 5; i++) ...[
            _buildShimmerTextField(),
            const SizedBox(height: 16),
          ],

          // زر المرفقات
          _buildShimmerButton(height: 55),
          const SizedBox(height: 30),

          // زر الحفظ
          _buildShimmerButton(height: 50),
        ],
      ),
    );
  }

  Widget _buildShimmerText({double width = 100, double height = 16}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  Widget _buildShimmerTextField() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: 55,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerButton({double height = 50}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
  Widget _buildAccountTypeSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "نوع الحساب",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildAccountTypeChoice('حساب عميل', 0),
                  const SizedBox(width: 20),
                  _buildAccountTypeChoice('حساب مورد', 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountTypeChoice(String title, int index) {
    bool isSelected = _type == title;

    return GestureDetector(
      onTap: () {
        setState(() {
          _type = title;
        });
        _choiceAnimationController.forward().then((_) {
          _choiceAnimationController.reverse();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.teal.shade800 : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: Colors.teal.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            )
          ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.teal.shade800 : Colors.grey.shade700,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              ScaleTransition(
                scale: _choiceScaleAnimation,
                child: Icon(
                  Icons.check_circle,
                  color: Colors.teal.shade800,
                  size: 20,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Container(
            height: 24,
            width: 4,
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedTextField(String key, IconData icon) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: (key == 'bigner_balance' && !hasOpeningBalance)
          ? const SizedBox.shrink()
          : Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          controller: _controllers[key],
          keyboardType: (key.contains('phone') || key.contains('age') || key == 'bigner_balance')
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          inputFormatters: key == 'bigner_balance'
              ? [
            ThousandsSeparatorInputFormatter(),

          ]
              : null,

          decoration: InputDecoration(
            labelText: _getArabicLabel(key),
            prefixIcon: Icon(icon, color: Colors.teal.shade600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
          ),
          validator: (value) {
            if (key == 'cust_name' && (value == null || value.isEmpty)) {
              return 'الرجاء إدخال الاسم';
            }
            if (key == 'bigner_balance' && hasOpeningBalance && (value == null || value.isEmpty)) {
              return 'يرجى إدخال الرصيد الافتتاحي';
            }
            return null;
          },
        ),
      ),
    );
  }


  Widget _buildSaveButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            Colors.teal.shade700,
            Colors.teal.shade600,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.shade200,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _saving ? null : _updateCustomer,
          child: Center(
            child: _saving
                ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            )
                : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'تعديل البيانات',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.save_alt_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getArabicLabel(String key) {
    switch (key) {
      case 'cust_name':
        return 'الاسم الثلاثي';
      case 'cust_phone':
        return 'رقم الهاتف';
      case 'cust_age':
        return 'العمر';
      case 'cust_address':
        return 'العنوان';
      case 'cust_card_number':
        return 'رقم البطاقة الشخصية';
      case 'cust_note':
        return 'الملاحظات';
      case 'spon_name':
        return 'اسم الكفيل';
      case 'spon_phone':
        return 'هاتف الكفيل';
      case 'spon_address':
        return 'عنوان الكفيل';
      case 'spon_kinship':
        return 'صلة القرابة';
      case 'spon_card_number':
        return 'رقم بطاقة الكفيل';

      default:
        return key;
    }
  }
}class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final intl.NumberFormat _formatter = intl.NumberFormat("#,##0.##", "en_US");

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String newText = newValue.text.replaceAll(',', '');
    if (newText.isEmpty) return newValue;

    double? value = double.tryParse(newText);
    if (value == null) return oldValue;

    String formatted = _formatter.format(value);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class CustomerImageGrid extends StatefulWidget {
  final void Function(List<XFile>) onImagesUpdated;
  final List<XFile> initialImages;

  const CustomerImageGrid({
    super.key,
    required this.onImagesUpdated,
    this.initialImages = const [],
  });

  @override
  State<CustomerImageGrid> createState() => _CustomerImageGridState();
}
class _CustomerImageGridState extends State<CustomerImageGrid> {
  final ImagePicker _picker = ImagePicker();
  late List<XFile> _images;

  @override
  void initState() {
    super.initState();
    _images = List<XFile>.from(widget.initialImages);
  }

  Future<XFile?> _showImageSourceDialog() async {
    return showModalBottomSheet<XFile>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('التقاط صورة'),
                onTap: () async {
                  final picked = await _picker.pickImage(source: ImageSource.camera);
                  Navigator.pop(context, picked);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('اختيار من المعرض'),
                onTap: () async {
                  final picked = await _picker.pickImage(source: ImageSource.gallery);
                  Navigator.pop(context, picked);
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('إلغاء'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('تحميل المرفقات للعميل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 9,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                if (index < _images.length) {
                  return Stack(
                    children: [
                      InkWell(
                        onTap: () async {
                          if (_images.length >= 9) return;
                          final picked = await _showImageSourceDialog();
                          if (picked != null) {
                            setState(() {
                              _images.add(picked);
                            });
                            widget.onImagesUpdated(_images);
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_images[index].path),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        left: 4,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _images.removeAt(index);
                            });
                            widget.onImagesUpdated(_images);
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(Icons.close, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  return InkWell(
                    onTap: () async {
                      if (_images.length >= 9) return;
                      final picked = await _showImageSourceDialog();
                      if (picked != null) {
                        setState(() {
                          _images.add(picked);
                        });
                        widget.onImagesUpdated(_images);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.camera_alt_outlined, color: Colors.grey, size: 40),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حفظ المرفقات',style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold),),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}