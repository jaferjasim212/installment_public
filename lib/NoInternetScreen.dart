import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NoInternetScreen extends StatefulWidget {
  const NoInternetScreen({super.key});

  @override
  State<NoInternetScreen> createState() => _NoInternetScreenState();

  static Future<void> checkConnectionAndShow(BuildContext context) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const NoInternetScreen(),
      );
    }
  }
}

class _NoInternetScreenState extends State<NoInternetScreen> {
  late StreamSubscription<ConnectivityResult> _subscription;

  @override
  void initState() {
    super.initState();

    // ✅ راقب الإنترنت وأغلق النافذة تلقائيًا عند العودة
    _subscription = Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel(); // ✅ أوقف الاستماع عند الخروج
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // منع الرجوع
      child: Dialog(
        insetPadding: const EdgeInsets.all(20),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset('assets/Animation/Animationconnection.json', width: 180),
              const SizedBox(height: 20),
              const Text(
                'لا يوجد اتصال بالإنترنت',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
              ),
              const SizedBox(height: 15),
              const Text(
                'يرجى التأكد من اتصالك بالإنترنت لاستخدام التطبيق.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 25),
              ElevatedButton.icon(
                onPressed: () async {
                  final conn = await Connectivity().checkConnectivity();
                  if (conn != ConnectivityResult.none) {
                    if (Navigator.canPop(context)) Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text(
                  "إعادة المحاولة",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFD48241),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}