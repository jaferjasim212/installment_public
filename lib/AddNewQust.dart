import 'package:flutter/material.dart';

class AddNewQust extends StatefulWidget {
  const AddNewQust({super.key});

  @override
  _AddNewQust createState() => _AddNewQust();
}

class _AddNewQust extends State<AddNewQust> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('_AddNewQust'),
      ),
      body: const Center(
        child: Text(
          '_AddNewQust',
          style: TextStyle(fontSize: 40),
        ),
      ),
    );
  }
}
