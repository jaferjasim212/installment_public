import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';

class CustomerAttachmentsScreen extends StatefulWidget {
  final String customerId;
  final String userId;

  const CustomerAttachmentsScreen({
    super.key,
    required this.customerId,
    required this.userId,
  });

  @override
  State<CustomerAttachmentsScreen> createState() => _CustomerAttachmentsScreenState();
}

class _CustomerAttachmentsScreenState extends State<CustomerAttachmentsScreen> {
  List<String> _attachments = [];
  bool _loading = true;
  String _customerName = '';

  @override
  void initState() {
    super.initState();
    _fetchAttachments();
  }

  Future<void> _fetchAttachments() async {
    try {
      final response = await Supabase.instance.client
          .from('customers')
          .select('cust_name, image1, image2, image3, image4, image5, image6, image7, image8, image9')
          .eq('id', widget.customerId)
          .eq('user_id', widget.userId)
          .single();

      final images = <String>[];
      for (int i = 1; i <= 9; i++) {
        final img = response['image$i'];
        if (img != null && img.toString().isNotEmpty) {
          images.add(img);
        }
      }

      setState(() {
        _attachments = images;
        _customerName = response['cust_name'] ?? 'بدون اسم';
        _loading = false;
      });
    } catch (e) {
      debugPrint("❌ خطأ في تحميل المرفقات: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل في تحميل المرفقات')),
      );
      setState(() => _loading = false);
    }
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      itemCount: 9,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentsGrid() {
    return GridView.builder(
      itemCount: 9, // دائمًا 9 خانات
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        if (index < _attachments.length) {
          final imageBytes = base64Decode(_attachments[index]);
          return InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => Dialog(
                  backgroundColor: Colors.transparent,
                  child: InteractiveViewer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(imageBytes),
                    ),
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(imageBytes, fit: BoxFit.cover),
            ),
          );
        } else {
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Center(
              child: Icon(Icons.image_not_supported, color: Colors.grey),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 2,
        backgroundColor: Colors.teal,
        title: Text(
          ' مرفقات العميل ($_customerName)',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading ? _buildShimmerGrid() : _buildAttachmentsGrid(),
      ),
    );
  }
}