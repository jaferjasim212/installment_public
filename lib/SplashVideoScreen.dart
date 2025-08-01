import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';

class SplashVideoScreen extends StatefulWidget {
  final Future<Widget> nextScreen;

  const SplashVideoScreen({super.key, required this.nextScreen});

  @override
  State<SplashVideoScreen> createState() => _SplashVideoScreenState();
}

class _SplashVideoScreenState extends State<SplashVideoScreen>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _showCopyright = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeVideo();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _showCopyright = true);
      }
    });
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.asset('assets/Icon/splash.mp4');
    await _controller.initialize();

    if (mounted) {
      _animationController.forward();
      setState(() {});
    }

    _controller.play();
    _controller.setLooping(false);

    _controller.addListener(() async {
      if (_controller.value.position >= _controller.value.duration &&
          !_controller.value.isPlaying) {
        _controller.removeListener(() {});

        await _animationController.reverse();

        if (mounted) {
          final nextScreenWidget = await widget.nextScreen;
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => nextScreenWidget,
              transitionsBuilder: (_, a, __, c) =>
                  FadeTransition(opacity: a, child: c),
              transitionDuration: const Duration(milliseconds: 800),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Colors.white,
                ],
              ),
            ),
          ),

          Center(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: child,
                  ),
                );
              },
              child: _controller.value.isInitialized
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              )
                  : const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ),
          ),

          // حقوق النشر
          if (_showCopyright)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _showCopyright ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 1000),
                child: const Column(
                  children: [
                    Text(
                      'Copyright © DESIGN BY',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Jafer Jasim',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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