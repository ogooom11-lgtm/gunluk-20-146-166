import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../core/l10n/app_strings.dart';
import '../app_scope.dart';

/// مسح الوجه بكاميرا التطبيق (بلا إنترنت): يعرض الكاميرا الأمامية داخل حلقة
/// مسح متحرّكة، ويقبل عندما يكتشف وجهًا واضحًا في المنتصف.
///
/// تُستخدم لفتح تفاصيل المنبّه بدل التعرّف على الوجه من نظام الجهاز.
class FaceScanScreen extends StatefulWidget {
  const FaceScanScreen({super.key});

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen> with SingleTickerProviderStateMixin {
  CameraController? _camera;
  late final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableContours: false,
      enableLandmarks: true,
      enableClassification: false,
      minFaceSize: 0.18,
    ),
  );

  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat();

  String? _error;
  bool _busy = false;
  bool _done = false;
  int _hits = 0;
  DateTime _startedAt = DateTime.now();
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    _boot();
    // لا نُبقي المستخدم محبوسًا: بعد ٢٥ ثانية نُغلق بالنتيجة السالبة.
    _timeout = Timer(const Duration(seconds: 25), () {
      if (mounted && !_done) _finish(false);
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _scan.dispose();
    _camera?.dispose();
    _detector.close();
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _error = context.tr('face.noCamera'));
        return;
      }
      final CameraDescription front = cameras.firstWhere(
        (CameraDescription c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final CameraController controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _camera = controller);
      _startedAt = DateTime.now();
      await controller.startImageStream(_onFrame);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.code == 'CameraAccessDenied'
            ? context.tr('face.permissionDenied')
            : context.tr('face.cameraError');
      });
    } catch (_) {
      if (mounted) setState(() => _error = context.tr('face.cameraError'));
    }
  }

  /// كل إطار: نبحث عن وجه واضح في وسط الصورة. ثلاث إطارات متتالية = نجاح.
  Future<void> _onFrame(CameraImage image) async {
    if (_busy || _done) return;
    _busy = true;
    try {
      final InputImage? input = _toInputImage(image);
      if (input != null) {
        final List<Face> faces = await _detector.processImage(input);
        final bool ok = faces.any((Face f) {
          final double width = f.boundingBox.width / image.width;
          final double height = f.boundingBox.height / image.height;
          return width > 0.25 && height > 0.25;
        });
        if (ok) {
          _hits++;
          if (_hits >= 3 && !_done) {
            HapticFeedback.mediumImpact();
            await _finish(true);
          }
        } else {
          _hits = 0;
        }
      }
    } catch (_) {
      // إطار غير صالح — نكمل بدون إسقاط الشاشة.
    } finally {
      _busy = false;
    }
  }

  /// تحويل إطار الكاميرا إلى صيغة يفهمها كاشف الوجوه.
  InputImage? _toInputImage(CameraImage image) {
    final CameraController? controller = _camera;
    if (controller == null) return null;
    final CameraDescription description = controller.description;
    final InputImageRotation rotation = _rotationFor(description.sensorOrientation);
    final InputImageFormat format = switch (image.format.group) {
      ImageFormatGroup.nv21 => InputImageFormat.nv21,
      ImageFormatGroup.yuv420 => InputImageFormat.yuv420,
      ImageFormatGroup.bgra8888 => InputImageFormat.bgra8888,
      _ => InputImageFormat.nv21,
    };
    if (format == InputImageFormat.nv21 && image.planes.length != 1) return null;
    if (format == InputImageFormat.yuv420 && image.planes.length < 3) return null;

    final InputImageMetadata metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );
    try {
      return InputImage.fromBytes(
        bytes: image.planes.length == 1
            ? image.planes.first.bytes
            : _concatenate(image),
        metadata: metadata,
      );
    } catch (_) {
      return null;
    }
  }

  static Uint8List _concatenate(CameraImage image) {
    final BytesBuilder builder = BytesBuilder(copy: false);
    for (final Plane plane in image.planes) {
      builder.add(plane.bytes);
    }
    return builder.takeBytes();
  }

  static InputImageRotation _rotationFor(int sensorOrientation) {
    switch (sensorOrientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Future<void> _finish(bool ok) async {
    if (_done) return;
    _done = true;
    _timeout?.cancel();
    try {
      await _camera?.stopImageStream();
    } catch (_) {
      // نُكمل الإغلاق.
    }
    if (!mounted) return;
    Navigator.of(context).pop(ok);
  }

  @override
  Widget build(BuildContext context) {
    final CameraController? controller = _camera;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (controller != null && controller.value.isInitialized)
            Center(child: CameraPreview(controller))
          else
            const ColoredBox(color: Colors.black),
          // تعتيم مع فتحة بيضاوية على الوجه.
          const _OvalMask(),
          // حلقة المسح المتحرّكة.
          AnimatedBuilder(
            animation: _scan,
            builder: (BuildContext context, Widget? _) {
              return CustomPaint(
                painter: _ScannerPainter(
                  progress: _scan.value,
                  color: _hits > 0 ? const Color(0xFF2FA86A) : context.palette.seed,
                  hits: _hits,
                  startedAt: _startedAt,
                  now: DateTime.now(),
                ),
              );
            },
          ),
          SafeArea(
            child: Column(
              children: <Widget>[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: IconButton(
                    onPressed: () => _finish(false),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    tooltip: context.tr('common.cancel'),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: <Widget>[
                      Text(
                        _error ?? context.tr('face.hint'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      if (_error == null)
                        Text(
                          _hits > 0 ? context.tr('face.almost') : context.tr('face.center'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                      const SizedBox(height: 18),
                      if (_error != null)
                        FilledButton(
                          onPressed: () => _finish(false),
                          child: Text(context.tr('common.close')),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// تعتيم كل الشاشة مع فتحة بيضاوية شفافة على الوجه.
class _OvalMask extends StatelessWidget {
  const _OvalMask();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _MaskPainter()),
    );
  }
}

class _MaskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Path oval = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.42),
        width: size.width * 0.7,
        height: size.width * 0.92,
      ));
    final Path all = Path()..addRect(Offset.zero & size);
    canvas.drawPath(
      Path.combine(PathOperation.difference, all, oval),
      Paint()..color = Colors.black.withAlpha(150),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// حلقة المسح: قوس يلتف حول الوجه + تقدّم زمني + وميض أخضر عند النجاح.
class _ScannerPainter extends CustomPainter {
  _ScannerPainter({
    required this.progress,
    required this.color,
    required this.hits,
    required this.startedAt,
    required this.now,
  });

  final double progress;
  final Color color;
  final int hits;
  final DateTime startedAt;
  final DateTime now;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: size.width * 0.7,
      height: size.width * 0.92,
    );
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: <Color>[color.withAlpha(30), color, color.withAlpha(30)],
        stops: const <double>[0.0, 0.5, 1.0],
        transform: GradientRotation(progress * 6.2831853),
      ).createShader(rect);
    canvas.drawArc(rect, 0, 6.2831853, false, ring);

    // مؤشّر «كم بقي» على شكل نقطة صغيرة أسفل الحلقة.
    final double t = (now.difference(startedAt).inMilliseconds / 25000).clamp(0, 1).toDouble();
    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.white24;
    canvas.drawArc(rect.inflate(10), 1.5707963, 6.2831853 * (1 - t), false, track);
  }

  @override
  bool shouldRepaint(covariant _ScannerPainter old) =>
      old.progress != progress || old.hits != hits || old.color != color;
}
