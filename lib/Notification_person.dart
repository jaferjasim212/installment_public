import 'package:flutter/material.dart';

class Notification_person extends StatefulWidget {
  const Notification_person({super.key});

  @override
  _Notification_person createState() => _Notification_person();
}

class _Notification_person extends State<Notification_person> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification_person'),
      ),
      body: const Center(
        child: Text(
          'Notification_person Screen',
          style: TextStyle(fontSize: 40),
        ),
      ),
    );
  }
}
