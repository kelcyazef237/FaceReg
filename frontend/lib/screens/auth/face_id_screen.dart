import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:face_reg_app/core/constants.dart';
import 'package:face_reg_app/services/auth_provider.dart';
import 'package:face_reg_app/screens/home/home_screen.dart';

/// Apple Face ID–style auto-scan screen.
/// No oval, no button — camera starts, captures automatically, verifies.
class FaceIdScreen extends StatefulWidget {
  final String name;
  final bool isReauth;

  const FaceIdScreen({
    required this.name,
    this.isReauth = false,
    super.key,
  });

  @override
  State<FaceIdScreen> createState() => _FaceIdScreenState();
}

enum _ScanState { initialising, scanning, verifying, success, failed }

class _FaceIdScreenState extends State<FaceIdScreen>
    with TickerProviderStateMixin {
  CameraController? _camera;
  _ScanState _state = _ScanState.initialising;
  String _statusText = 'Preparing camera…';
  String? _errorDetail;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _camera = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _camera!.initialize();
      if (!mounted) return;
      setState(() {
        _state = _ScanState.scanning;
        _statusText = 'Look at the camera';
      });
      // Auto-start scan after a short delay so the user can position their face
      await Future.delayed(AppConstants.faceIdStartDelay);
      if (mounted) _scan();
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _ScanState.failed;
          _statusText = 'Camera error';
          _errorDetail = e.toString();
        });
      }
    }
  }

  Future<void> _scan() async {
    if (_camera == null || !_camera!.value.isInitialized) return;

    setState(() {
      _state = _ScanState.scanning;
      _statusText = 'Scanning…';
    });

    final frames = <File>[];
    try {
      for (int i = 0; i < AppConstants.livenessFrameCount; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        final xf = await _camera!.takePicture();
        frames.add(File(xf.path));
        if (i < AppConstants.livenessFrameCount - 1) {
          await Future.delayed(AppConstants.captureInterval);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _ScanState.failed;
          _statusText = 'Capture error';
          _errorDetail = e.toString();
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _state = _ScanState.verifying;
      _statusText = 'Verifying…';
    });

    final auth = context.read<AuthProvider>();
    final ok = await auth.loginFace(name: widget.name, frames: frames);

    if (!mounted) return;
    if (ok) {
      _pulseCtrl.stop();
      setState(() {
        _state = _ScanState.success;
        _statusText = 'Verified';
      });
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) {
        Navigator.pushReplacementNamed(context, HomeScreen.route);
      }
    } else {
      setState(() {
        _state = _ScanState.failed;
        _statusText = 'Verification failed';
        _errorDetail = auth.error;
      });
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _camera?.dispose();
    super.dispose();
  }

  Color get _stateColor => switch (_state) {
        _ScanState.success => Colors.greenAccent,
        _ScanState.failed => Colors.redAccent,
        _ => const Color(0xFF6C63FF),
      };

  IconData get _stateIcon => switch (_state) {
        _ScanState.success => Icons.check_rounded,
        _ScanState.failed => Icons.close_rounded,
        _ => Icons.face_retouching_natural_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview (background)
          if (_camera != null && _camera!.value.isInitialized)
            Opacity(
              opacity: 0.4,
              child: CameraPreview(_camera!),
            ),

          // Dark gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [
                  Colors.black.withAlpha(100),
                  Colors.black.withAlpha(220),
                ],
              ),
            ),
          ),

          // Center content
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),

                // Animated indicator
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) {
                    final isActive = _state == _ScanState.scanning ||
                        _state == _ScanState.verifying;
                    final scale = isActive ? _pulseAnim.value : 1.0;
                    final glowOpacity = isActive ? _pulseAnim.value * 0.4 : 0.0;

                    return Transform.scale(
                      scale: 0.9 + scale * 0.1,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _stateColor, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: _stateColor.withAlpha(
                                (glowOpacity * 255).toInt(),
                              ),
                              blurRadius: 30,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        child: Icon(_stateIcon, size: 56, color: _stateColor),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Status text
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _statusText,
                    key: ValueKey(_statusText),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                if (_errorDetail != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      _errorDetail!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withAlpha(160),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],

                const Spacer(flex: 2),

                // Buttons (only on failure)
                if (_state == _ScanState.failed) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _state = _ScanState.scanning;
                          _statusText = 'Look at the camera';
                          _errorDetail = null;
                        });
                        _pulseCtrl.repeat(reverse: true);
                        Future.delayed(
                          AppConstants.faceIdStartDelay,
                          () { if (mounted) _scan(); },
                        );
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try Again'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      final auth = context.read<AuthProvider>();
                      auth.clearSavedUser();
                    },
                    child: const Text(
                      'Use a different account',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],

                // Name display
                const Spacer(),
                Text(
                  widget.name,
                  style: TextStyle(
                    color: Colors.white.withAlpha(120),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
