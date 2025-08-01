import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class EditProfileData extends StatefulWidget {
  const EditProfileData({super.key});

  @override
  State<EditProfileData> createState() => _EditProfileDataState();
}

class _EditProfileDataState extends State<EditProfileData> with SingleTickerProviderStateMixin {
  String? activeSection;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleSection(String section) {
    if (activeSection == section) {
      _animationController.reverse();
      Future.delayed(const Duration(milliseconds: 300), () {
        setState(() => activeSection = null);
      });
    } else {
      setState(() => activeSection = section);
      _animationController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _getBackgroundColor(context),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
        child: Scaffold(
          backgroundColor: _getBackgroundColor(context),
          appBar: AppBar(
            title: const Text('إدارة الحساب', style: TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(22),

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 13),

                    _buildOptionCard(
                      icon: Icons.lock_outline_rounded,
                      title: 'تعديل معلومات الدخول',
                      subtitle: 'البريد الإلكتروني وكلمة المرور',
                      color: Colors.blueAccent,
                      onTap: () => _toggleSection('login'),
                    ),
                    const SizedBox(height: 25),
                    _buildOptionCard(
                      icon: Icons.person_outline_rounded,
                      title: 'تعديل البيانات الشخصية',
                      subtitle: 'الاسم، رقم الهاتف، العنوان، الصورة...',
                      color: Colors.teal,
                      onTap: () => _toggleSection('profile'),
                    ),
                  ],
                ),
              ),

              // لوحة التعديل
              if (activeSection != null) ...[
                GestureDetector(
                  onTap: () => _toggleSection(activeSection!),
                  behavior: HitTestBehavior.opaque,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(color: Colors.black.withOpacity(0.4)),
                  ),
                ),

                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutQuint,
                    height: MediaQuery.of(context).size.height * 0.7,
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: activeSection == 'login'
                            ? _LoginSection(onClose: () => _toggleSection(activeSection!))
                            : _ProfileSection(onClose: () => _toggleSection(activeSection!)),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[900]!
        : Colors.grey[50]!;
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  )),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  )),
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

class _LoginSection extends StatefulWidget {
  final VoidCallback onClose;

  const _LoginSection({required this.onClose});

  @override
  State<_LoginSection> createState() => _LoginSectionState();
}

class _LoginSectionState extends State<_LoginSection> {
  final oldPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final newEmailController = TextEditingController();
  final currentEmailController = TextEditingController();

  bool isLoading = true;
  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentEmail();
  }

  Future<void> _loadCurrentEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('UserID');

    final response = await Supabase.instance.client
        .from('users_full_profile')
        .select('email')
        .eq('id', userId!)
        .maybeSingle();

    setState(() {
      currentEmailController.text = response?['email'] ?? '';
      isLoading = false;
    });
  }

  Future<void> _saveChanges() async {
    final oldPass = oldPasswordController.text.trim();
    final newPass = newPasswordController.text.trim();
    final confirmPass = confirmPasswordController.text.trim();
    final newEmail = newEmailController.text.trim();

    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      _showErrorSnackbar('يرجى ملء جميع الحقول');
      return;
    }

    if (newPass != confirmPass) {
      _showErrorSnackbar('كلمة المرور الجديدة غير متطابقة');
      return;
    }

    try {
      final emailUsed = currentEmailController.text.trim();
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) throw Exception('المستخدم غير مسجل دخول');

      // تسجيل الدخول للتحقق من كلمة المرور القديمة
      await Supabase.instance.client.auth.signInWithPassword(
        email: emailUsed,
        password: oldPass,
      );

      // تحديث البريد أو كلمة المرور
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          password: newPass,
          email: newEmail.isNotEmpty ? newEmail : null,
        ),
      );

      // تشفير كلمة المرور الجديدة
      final bytes = utf8.encode(newPass);
      final shaPassword = sha256.convert(bytes).toString();

      // تحديث في جدول users_full_profile
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('UserID');
      if (userId == null) throw Exception('لم يتم العثور على UserID');

      await Supabase.instance.client
          .from('users_full_profile')
          .update({
        'password_hash': shaPassword,
        if (newEmail.isNotEmpty) 'email': newEmail,
      })
          .eq('id', userId);

      _showSuccessSnackbar('تم تحديث معلومات الدخول بنجاح');
      widget.onClose();
    } catch (e) {
      _showErrorSnackbar('حدث خطأ: ${e.toString()}');
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('تعديل معلومات الدخول',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: widget.onClose,
            ),
          ],
        ),
        const SizedBox(height: 24),

        _buildReadOnlyField(
          label: 'البريد الإلكتروني الحالي',
          controller: currentEmailController,
          icon: Icons.email_rounded,
        ),
        const SizedBox(height: 16),

        _buildPasswordField(
          controller: oldPasswordController,
          label: 'كلمة المرور الحالية',
          obscureText: _obscureOldPassword,
          onToggle: () => setState(() => _obscureOldPassword = !_obscureOldPassword),
        ),
        const SizedBox(height: 16),

        _buildPasswordField(
          controller: newPasswordController,
          label: 'كلمة المرور الجديدة',
          obscureText: _obscureNewPassword,
          onToggle: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
        ),
        const SizedBox(height: 16),

        _buildPasswordField(
          controller: confirmPasswordController,
          label: 'تأكيد كلمة المرور الجديدة',
          obscureText: _obscureConfirmPassword,
          onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
        ),
        const SizedBox(height: 8),
        Text('يجب أن تحتوي كلمة المرور على 8 أحرف على الأقل',
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),

        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _saveChanges,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal, // ✅ الخلفية
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'حفظ التغييرات',
            style: TextStyle(fontSize: 16, color: Colors.white,fontWeight: FontWeight.bold), // ✅ لون النص أبيض للوضوح
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        filled: true,
        fillColor: Colors.grey[100],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _ProfileSection extends StatefulWidget {
  final VoidCallback onClose;

  const _ProfileSection({required this.onClose});

  @override
  State<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController districtController = TextEditingController();
  String? base64Image;
  String? userId;
  bool isLoading = true;
  String? selectedGender;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('UserID');
    if (userId == null) {
      _showErrorSnackbar('لم يتم العثور على المستخدم');
      return;
    }

    final data = await Supabase.instance.client
        .from('users_full_profile')
        .select()
        .eq('id', userId!)
        .maybeSingle();

    if (data != null) {
      nameController.text = data['display_name'] ?? '';
      phoneController.text = data['phone'] ?? '';
      cityController.text = data['city'] ?? '';
      districtController.text = data['district'] ?? '';
      base64Image = data['profile_image_base64'];
      selectedGender = data['gender'];
    }

    setState(() => isLoading = false);
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 800,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() => base64Image = base64Encode(bytes));
    }
  }

  Future<void> _saveChanges() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final city = cityController.text.trim();
    final district = districtController.text.trim();

    if (name.isEmpty || phone.isEmpty || city.isEmpty || district.isEmpty) {
      _showErrorSnackbar('يرجى ملء جميع الحقول المطلوبة');
      return;
    }

    setState(() => _isUpdating = true);

    try {
      await Supabase.instance.client
          .from('users_full_profile')
          .update({
        'display_name': name,
        'phone': phone,
        'city': city,
        'district': district,
        'gender': selectedGender,
        if (base64Image != null) 'profile_image_base64': base64Image,
      })
          .eq('id', userId!);

      _showSuccessSnackbar('تم تحديث الملف الشخصي بنجاح');
      widget.onClose();
    } catch (e) {
      _showErrorSnackbar('حدث خطأ أثناء الحفظ: $e');
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('تعديل الملف الشخصي',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
              ),
            ],
          ),
          const SizedBox(height: 24),

          Center(
            child: Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blueAccent, width: 2),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: base64Image != null
                        ? Image.memory(
                      base64Decode(base64Image!),
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    )
                        : Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.person, size: 60, color: Colors.grey),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildTextField(
            controller: nameController,
            label: 'الاسم الكامل',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: phoneController,
            label: 'رقم الهاتف',
            icon: Icons.phone_rounded,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),

          _buildDropdownField(
            value: selectedGender,
            label: 'الجنس',
            icon: Icons.transgender_rounded,
            items: const ['ذكر', 'أنثى'],
            onChanged: (value) => setState(() => selectedGender = value),
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: cityController,
            label: 'المدينة',
            icon: Icons.location_city_rounded,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: districtController,
            label: 'المنطقة',
            icon: Icons.map_rounded,
          ),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _isUpdating ? null : _saveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal, // ✅ الخلفية

              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isUpdating
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Text('حفظ التغييرات', style: TextStyle(fontSize: 16,color: Colors.white,fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: const Text('اختر الجنس'),
          items: items.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}