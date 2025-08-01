import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateScreen extends StatelessWidget {
  final String changelog;
  final String updateUrl;

  const UpdateScreen({required this.changelog, required this.updateUrl, super.key});

  static Future<void> checkAndShowUpdate(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version;

    final response = await Supabase.instance.client
        .from('app_updates')
        .select()
        .eq('platform', 'android')
        .maybeSingle();

    final latestVersion = response?['latest_version'];
    final changelog = response?['changelog'] ?? '';
    final updateUrl = response?['play_store_url'];

    if (latestVersion != null && latestVersion != currentVersion && updateUrl != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => UpdateScreen(changelog: changelog, updateUrl: updateUrl),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset('assets/Animation/Animationupdate.json', width: 150, repeat: true),
            const SizedBox(height: 20),
            const Text(
              'تحديث جديد متاح 🎉',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
            ),
            const SizedBox(height: 15),
            SizedBox(
              height: 200, // يمكنك تعديل الارتفاع حسب الحاجة
              child: SingleChildScrollView(
                child: Text(
                  changelog,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 25),
            Directionality(
              textDirection: TextDirection.rtl,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (await canLaunchUrl(Uri.parse(updateUrl))) {
                    launchUrl(Uri.parse(updateUrl), mode: LaunchMode.externalApplication);
                  }
                },
                label: const Text('تحديث الآن', style: TextStyle(color: Colors.white,fontSize: 16,fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}