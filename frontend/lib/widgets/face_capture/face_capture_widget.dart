import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:face_reg_app/widgets/face_capture/face_oval_painter.dart';

enum CaptureMode { enroll, login }

class FaceCaptureWidget extends StatefulWidget {
  const FaceCaptureWidget({
    super.key,
    required this.mode,
    required this.onCaptureDone,
    this.onCancel,
  });

  final CaptureMode mode;
  final ValueChanged<List<File>> onCaptureDone;
  final VoidCallback? onCancel;

  @override
  State<FaceCaptureWidget> createState() => _FaceCaptureWidgetState();
}

class _FaceCaptureWidgetState extends State<FaceCaptureWidget>
    with TickerProviderStateMixin {
  CameraController? _controller;
  bool _initialised = false;
  bool _capturing = false;
  double _progress = 0.0;

  late AnimationController _pulseCtrl;
  late AnimationController _scanCtrl;
  late Animation<double> _pulseAnim;
  double _scanY = 0.0;

  static const _accent = Color(0xFF6C63FF);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _scanCtrl.addListener(() => setState(() => _scanY = _scanCtrl.value));

    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _controller = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller!.initialize();
    if (mounted) setState(() => _initialised = true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _scanCtrl.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _startCapture() async {
    if (_capturing || _controller == null) return;
    setState(() {
      _capturing = true;
      _progress = 0;
    });

    // Single best-effort frame for enrollment
    await Future.delayed(const Duration(milliseconds: 200));
    final xf = await _controller!.takePicture();
    setState(() => _progress = 1.0);
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) widget.onCaptureDone([File(xf.path)]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_initialised && _controller != null)
                  CameraPreview(_controller!)
                else
                  Container(
                    color: const Color(0xFF1E1E2E),
                    child: const Center(
                      child: CircularProgressIndicator(color: _accent),
                    ),
                  ),
                if (_initialised)
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, __) => CustomPaint(
                      painter: FaceOvalPainter(
                        progress: _progress,
                        color: _progress == 1.0 ? Colors.greenAccent : _accent,
                        scanLineY: _scanY,
                        showScanLine: _capturing,
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(153),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _capturing
                          ? '✅ Done!'
                          : 'Position your face in the oval\nthen tap Capture',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Gap(20),
        if (_capturing && _progress < 1.0)
          Column(
            children: [
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation(_accent),
                borderRadius: BorderRadius.circular(4),
              ),
              const Gap(8),
            ],
          ),
        Row(
          children: [
            if (widget.onCancel != null)
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancel'),
                ),
              ),
            if (widget.onCancel != null) const Gap(12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: (_initialised && !_capturing) ? _startCapture : null,
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Capture'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
