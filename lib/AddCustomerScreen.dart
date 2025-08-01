import 'dart:convert';
import 'dart:io';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class AddCustomerScreen extends StatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen>
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
  final FlutterNativeContactPicker _contactPicker = FlutterNativeContactPicker();

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
    'bigner_balance': TextEditingController(),
  };

  bool _saving = false;
  String _type = '';

  @override
  void initState() {
    super.initState();

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
  bool _isPickingContact = false;

  Future<void> _pickPhoneNumberFromContacts() async {
    if (_isPickingContact) return;
    _isPickingContact = true;

    try {
      final status = await Permission.contacts.status;

      if (!status.isGranted) {
        final result = await Permission.contacts.request();

        if (result.isGranted) {
          await _openContactPicker(); // انتظر الإنهاء
        } else if (result.isPermanentlyDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('تم رفض إذن الوصول إلى جهات الاتصال بشكل دائم.\nيرجى تفعيله من إعدادات التطبيق.'),
              action: SnackBarAction(
                label: 'الإعدادات',
                onPressed: () {
                  openAppSettings();
                },
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('يجب منح إذن الوصول إلى جهات الاتصال للاستمرار')),
          );
        }
      } else {
        await _openContactPicker();
      }
    } catch (e) {
      debugPrint('❌ خطأ أثناء طلب الإذن: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء الوصول إلى جهات الاتصال')),
      );
    } finally {
      _isPickingContact = false;
    }
  }

  Future<void> _openContactPicker() async {
    try {
      final contact = await _contactPicker.selectPhoneNumber();

      if (contact != null && contact.selectedPhoneNumber != null) {
        String selectedNumber = contact.selectedPhoneNumber!;

        // 🔧 تنظيف الرقم
        selectedNumber = selectedNumber
            .replaceAll(' ', '')
            .replaceAll('-', '')
            .replaceAll('(', '')
            .replaceAll(')', '');

        if (selectedNumber.startsWith('+964')) {
          selectedNumber = selectedNumber.substring(4);
        } else if (selectedNumber.startsWith('00964')) {
          selectedNumber = selectedNumber.substring(5);
        }

        // ✅ تحديث الحقل
        setState(() {
          _controllers['cust_phone']?.text = selectedNumber;
        });
      }
    } catch (e) {
      debugPrint('❌ فشل في اختيار جهة الاتصال: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: FadeTransition(
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
                    Row(
                      children: [
                        Expanded(
                          child: _buildAnimatedTextField('cust_phone', Icons.phone_android_outlined),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.contacts, size: 28, color: Colors.teal),
                          onPressed: _pickPhoneNumberFromContacts,
                          tooltip: 'اختر من جهات الاتصال',
                        ),
                      ],
                    ),
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
                      onPressed: () {
                        if (_attachmentsSaved) {
                          // إعادة فتح المرفقات لعرضها أو تعديلها
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
                                  });
                                },
                                initialImages: _customerImages,
                              );
                            },
                          );
                        } else {
                          // أول مرة يفتح الإضافة
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
                                    if (_customerImages.isNotEmpty) {
                                      _attachmentsSaved = true;
                                    }
                                  });
                                },
                                initialImages: [],
                              );
                            },
                          );
                        }
                      },
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
          onTap: _saving ? null : _saveCustomer,
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
                  'حفظ البيانات',
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
      case 'bigner_balance':
        return 'الرصيد الافتتاحي';
      default:
        return key;
    }
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');
    if (userId == null) return;

    try {
      setState(() => _saving = true);

      // تجهيز البيانات الأساسية
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
        'user_id': userId,
        'type': _type,
        'created_at': DateTime.now().toIso8601String(),
      };

      // ✅ إضافة الصور على شكل Base64 إلى الحقول image1 → image9
      for (int i = 0; i < _customerImages.length && i < 9; i++) {
        final file = File(_customerImages[i].path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final base64 = base64Encode(bytes);
          data['image${i + 1}'] = base64;
        }
      }



      // ✅ تنفيذ الإضافة إلى Supabase
      await Supabase.instance.client.from('customers').insert(data);

      Navigator.pop(context);
    } catch (e) {
      print('❌ فشل في حفظ العميل: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في حفظ البيانات: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Colors.red[400],
        ),
      );
    } finally {
      setState(() => _saving = false);
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
    final source = await showModalBottomSheet<ImageSource>(
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
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('اختيار من المعرض'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('إلغاء'),
                onTap: () => Navigator.pop(context, null),
              ),
            ],
          ),
        );
      },
    );

    if (source != null) {
      final picked = await _picker.pickImage(source: source);
      if (picked != null) {
        return picked;
      }
    }

    return null;
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