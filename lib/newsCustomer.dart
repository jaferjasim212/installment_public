import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class newscustomerpage extends StatefulWidget {
  const newscustomerpage({Key? key}) : super(key: key);

  @override
  State<newscustomerpage> createState() => _newscustomerpageState();
}

class _newscustomerpageState extends State<newscustomerpage> {
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  bool isPublic = true;
  String? selectedUserId;
  List<Map<String, dynamic>> users = [];
  File? selectedImage;
  String? uploadedImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final response = await Supabase.instance.client
        .from('customers')
        .select('id, cust_name');
    setState(() {
      users = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final fileName = pickedFile.name;
      final fileBytes = await file.readAsBytes();

      try {
        await Supabase.instance.client.storage
            .from('newsimages')
            .uploadBinary('public/$fileName', fileBytes);

        final publicUrl = Supabase.instance.client.storage
            .from('newsimages')
            .getPublicUrl('public/$fileName');

        setState(() {
          uploadedImageUrl = publicUrl;
          selectedImage = file;
        });
      } catch (e) {
        print('❌ خطأ في رفع الصورة: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل في رفع الصورة.')),
        );
      }
    }
  }

  Future<void> _submit() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || titleController.text.isEmpty || contentController.text.isEmpty) return;

    await Supabase.instance.client.from('newsCustomer').insert({
      'title': titleController.text,
      'content': contentController.text,
      'is_public': isPublic,
      'target_user_id': isPublic ? null : selectedUserId,
      'image_url': uploadedImageUrl,
      'created_at': DateTime.now().toIso8601String(),
    });

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة خبر')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'عنوان الخبر'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(labelText: 'تفاصيل الخبر'),
              maxLines: 5,
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image),
              label: Text(selectedImage != null ? 'تم اختيار صورة' : 'رفع صورة'),
            ),
            if (selectedImage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  selectedImage!.path.split('/').last,
                  style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Checkbox(value: isPublic, onChanged: (val) => setState(() => isPublic = val!)),
                const Text('خبر عام'),
              ],
            ),
            if (!isPublic)
              DropdownButtonFormField<String>(
                value: selectedUserId,
                items: users.map<DropdownMenuItem<String>>((user) {
                  return DropdownMenuItem<String>(
                    value: user['id'].toString(),
                    child: Text(user['cust_name']),
                  );
                }).toList(),
                onChanged: (val) => setState(() => selectedUserId = val),
                decoration: const InputDecoration(labelText: 'اختر المستخدم'),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('نشر الخبر'),
            ),
          ],
        ),
      ),
    );
  }
}
