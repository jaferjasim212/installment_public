import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:installment/NoInternetScreen.dart';

class ConnectionWatcher {
  static StreamSubscription<ConnectivityResult>? _subscription;
  static bool _dialogShown = false;

  static void startMonitoring(BuildContext context) {
    _subscription ??= Connectivity().onConnectivityChanged.listen((result) async {
      if (result == ConnectivityResult.none && !_dialogShown) {
        _dialogShown = true;

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const NoInternetScreen(),
        );

        _dialogShown = false;
      }
    });
  }

  static void stopMonitoring() {
    _subscription?.cancel();
    _subscription = null;
    _dialogShown = false;
  }
}