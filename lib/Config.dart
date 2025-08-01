import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSecureConfig {
  static Future<void> initializeSupabase() async {
    const String edgeFunctionUrl = '----';
    const String secretToken = '***';

    final response = await http.get(
      Uri.parse(edgeFunctionUrl),
      headers: {
        'Authorization': 'Bearer $secretToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception("❌ فشل في جلب بيانات الاتصال من Edge Function");
    }

    final data = jsonDecode(response.body);
    final supabaseUrl = data['url'];
    final supabaseAnonKey = data['key'];

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
}