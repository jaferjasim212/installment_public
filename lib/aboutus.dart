import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutUsPage extends StatefulWidget {
  const AboutUsPage({super.key});

  @override
  State<AboutUsPage> createState() => _AboutUsPageState();
}

class _AboutUsPageState extends State<AboutUsPage> {
  late VideoPlayerController _controller;
  String _appVersion = "";

  final List<Map<String, dynamic>> _features = [
    {
      'icon': Icons.payment,
      'title': 'إدارة الأقساط',
      'description': 'تتبع أقساطك بسهولة وإرسال إشعارات للعملاء عند الاستحقاق.',
      'color': Colors.blueAccent
    },
    {
      'icon': Icons.people,
      'title': 'إدارة العملاء',
      'description': 'تنظيم بيانات العملاء والمندوبين بكفاءة',
      'color': Colors.green
    },
    {
      'icon': Icons.monetization_on,
      'title': 'إدارة أموالك',
      'description': 'قم بأدارة أموالك من اي مكان وأعرف مدفوعاتك اليومية',
      'color': Colors.orange
    },
    {
      'icon': Icons.print,
      'title': 'طباعة الكشوفات',
      'description': 'إمكانية طباعة الكشوفات بكل مرونة',
      'color': Colors.grey
    },
    {
      'icon': Icons.settings,
      'title': 'إعدادات مخصصة',
      'description': 'تخصيص التطبيق حسب احتياجاتك',
      'color': Colors.purple
    },
  ];

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset("assets/Icon/splash.mp4")
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
        _controller.setLooping(false); // جعل الفيديو يعيد التشغيل تلقائياً
      });
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = info.version; // مثال: 1.0.2
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $urlString';
    }
  }

  Widget _buildFeatureCard(Map<String, dynamic> feature, int index) {
    return FadeInRight(
      delay: Duration(milliseconds: 200 * index),

      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        margin: const EdgeInsets.only(bottom: 15), // المسافة بين الكاردات

        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                feature['color'].withOpacity(0.7),
                feature['color'].withOpacity(0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(15),
          ),

          child: Row(
            children: [
              Icon(feature['icon'], size: 40, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature['title'],
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      feature['description'],
                      style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard(String title, String value, IconData icon, Color color, String url) {
    return Bounce(
      delay: const Duration(milliseconds: 500),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(title),
          subtitle: Text(value),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _launchURL(url),
        ),
      ),
    );
  }

  Widget _buildSocialButton(String imagePath, String url) {
    return ElasticIn(
      delay: const Duration(milliseconds: 700),
      child: InkWell(
        onTap: () => _launchURL(url),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Image.asset(imagePath, height: 40),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 330,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // فيديو مع نسبة عرض إلى ارتفاع ثابتة
                  if (_controller.value.isInitialized)
                    AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  else
                    const Center(child: CircularProgressIndicator()),

                  // طبقة تدرج لوني شفافة


                  // طبقة سوداء شفافة لتخفيف الإضاءة إذا لزم الأمر
                  Container(color: Colors.black.withOpacity(0.1)),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  FadeInUp(
                    child: const Text(
                      "إدارة الأقساط بكل سهولة واحترافية",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeInUp(
                    delay: const Duration(milliseconds: 200),
                    child: const Text(
                      "تطبيق متكامل لإدارة عمليات البيع بالتقسيط، يوفر لك الوقت والجهد مع واجهة سهلة الاستخدام وإمكانيات متقدمة.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  FadeInUp(
                    delay: const Duration(milliseconds: 300),
                    child: const Text(
                      "مميزات التطبيق",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  ..._features.asMap().entries.map((entry) =>
                      _buildFeatureCard(entry.value, entry.key)),
                  const SizedBox(height: 30),
                  FadeInUp(
                    delay: const Duration(milliseconds: 400),
                    child: const Text(
                      "تواصل معنا",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildContactCard(
                      "للتواصل مع المبرمج",
                      "07739090603",
                      Icons.phone,
                      Colors.blue,
                      "tel:07739090603"
                  ),
                  _buildContactCard(
                      "للتواصل مع الدعم",
                      "07700007732",
                      Icons.support_agent,
                      Colors.green,
                      "tel:07700007732"
                  ),
                  _buildContactCard(
                      "زيارة الموقع الإلكتروني",
                      "www.aksat-ms.com",
                      Icons.language,
                      Colors.orange,
                      "https://www.aksat-ms.com"
                  ),
                  const SizedBox(height: 20),
                  FadeInUp(
                    delay: const Duration(milliseconds: 500),
                    child: const Text(
                      "تابعنا على",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSocialButton(
                          'assets/images/facebook.png',
                          'https://www.facebook.com/share/1AwxRPxJyb/'
                      ),
                      const SizedBox(width: 20),
                      _buildSocialButton(
                          'assets/images/instagram.png',
                          'https://www.instagram.com/update__it?igsh=ZHZ0azVlZzFuYWd2'
                      ),
                      const SizedBox(width: 20),
                      _buildSocialButton(
                          'assets/images/whatsapp.png',
                          'https://whatsapp.com/channel/0029VbA7RYM3rZZbgWyLiT2V'
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  FadeInUp(
                    delay: const Duration(milliseconds: 600),
                    child: Text(
                      " الإصدار  $_appVersion ",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeInUp(
                    delay: const Duration(milliseconds: 700),
                    child: const Text(
                      "جميع الحقوق محفوظة © 2025\nفريق Update لتقنية المعلومات",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}