import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:permission_handler/permission_handler.dart';

import '../services/live_room_service.dart';
import '../widgets/gpu_image_filter.dart';
import 'live_room_screen.dart';

/// Bigo-style Go Live setup: full-bleed camera, title above Go LIVE,
/// Beauty / Seats as icon dropdowns.
class CreateLiveRoomScreen extends StatefulWidget {
  const CreateLiveRoomScreen({super.key});

  @override
  State<CreateLiveRoomScreen> createState() => _CreateLiveRoomScreenState();
}

class _CreateLiveRoomScreenState extends State<CreateLiveRoomScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _liveRoomService = LiveRoomService();
  final _roomNameController = TextEditingController();

  CameraController? _cameraController;
  bool _isCameraInitializing = true;
  bool _cameraPermissionDenied = false;
  String? _cameraError;
  bool _isSubmitting = false;

  /// Once Go Live starts we must never re-open the preview camera — otherwise
  /// a lifecycle `resumed` after dispose steals the device from LiveKit.
  bool _isHandingOffToLive = false;

  /// True while closing via X / system back — blocks camera re-init and
  /// ensures the preview session is released before leaving.
  bool _isClosing = false;

  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;

  /// Cover thumb in the title card (host profile photo — not a name row).
  String? _coverPhotoUrl;

  String _selectedFilterName = 'Soft Skin';
  int _selectedSlotCount = 6;

  /// GPU beauty (skin smooth + whitening) on the create-room camera preview.
  bool _beautyEnabled = true;
  double _beautyIntensity = 0.55;

  /// Web browsers often block getUserMedia until a tap — show a CTA then.
  bool _webCameraNeedsTap = false;

  static const _slotOptions = [3, 6, 9];

  /// Backend only accepts Natural / Smooth / Bright / Vivid / Cool.
  String get _apiFilterName {
    switch (_selectedFilterName) {
      case 'None':
      case 'Natural':
        return 'Natural';
      case 'Soft Skin':
      case 'Smooth':
        return 'Smooth';
      case 'Soft Glow':
      case 'Bright':
        return 'Bright';
      case 'Vivid':
        return 'Vivid';
      case 'Cool':
        return 'Cool';
      default:
        return 'Natural';
    }
  }

  bool get _isCameraReady =>
      !_isHandingOffToLive &&
      _cameraController != null &&
      _cameraController!.value.isInitialized &&
      !_cameraPermissionDenied;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadCoverPhoto());
    // Defer so the first frame paints; on web, also avoid racing plugin ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_initCamera());
    });
  }

  Future<void> _loadCoverPhoto() async {
    try {
      final profile = await _liveRoomService.getMyProfile();
      final photo = profile['photo'] as String?;
      if (!mounted) return;
      if (photo != null && photo.trim().isNotEmpty) {
        setState(() => _coverPhotoUrl = photo.trim());
      }
    } catch (_) {
      // Cover stays as placeholder.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _roomNameController.dispose();
    // Best-effort if close didn't await (e.g. route replaced).
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      unawaited(controller.dispose());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isHandingOffToLive || _isClosing) return;

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      if (state == AppLifecycleState.resumed) {
        _initCamera();
      }
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_disposeCamera());
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _disposeCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    if (mounted) {
      setState(() {
        _isCameraInitializing = false;
      });
    }
    if (controller == null) return;
    try {
      // Stop capture before dispose so the OS camera indicator clears.
      if (controller.value.isInitialized) {
        await controller.pausePreview();
      }
    } catch (e) {
      debugPrint('Camera pausePreview failed: $e');
    }
    try {
      await controller.dispose();
    } catch (e) {
      debugPrint('Camera dispose failed: $e');
    }
  }

  /// Release camera fully, then leave — used by X and system back.
  Future<void> _closeScreen() async {
    if (_isClosing || _isSubmitting || _isHandingOffToLive) return;
    _isClosing = true;
    // Block lifecycle / init from opening the camera again while leaving.
    _isHandingOffToLive = true;
    await _disposeCamera();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _initCamera() async {
    if (!mounted || _isHandingOffToLive || _isClosing) return;
    setState(() {
      _isCameraInitializing = true;
      _cameraPermissionDenied = false;
      _cameraError = null;
      _webCameraNeedsTap = false;
    });

    if (!kIsWeb) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (!mounted) return;
        setState(() {
          _isCameraInitializing = false;
          _cameraPermissionDenied = true;
        });
        return;
      }
    }

    try {
      final cameras = await availableCameras();
      if (!mounted || _isHandingOffToLive) return;
      if (cameras.isEmpty) {
        setState(() {
          _isCameraInitializing = false;
          _cameraError = 'No camera found on this device.';
          _webCameraNeedsTap = kIsWeb;
        });
        return;
      }

      _cameras = cameras;
      final frontIndex = cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      _cameraIndex = frontIndex >= 0 ? frontIndex : 0;

      await _disposeCamera();
      if (!mounted || _isHandingOffToLive) return;

      // Web: medium + default format. jpeg group breaks some Chrome builds.
      final controller = CameraController(
        cameras[_cameraIndex],
        kIsWeb ? ResolutionPreset.medium : ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: kIsWeb ? null : ImageFormatGroup.jpeg,
      );
      await controller.initialize();

      if (!mounted || _isHandingOffToLive) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _isCameraInitializing = false;
        _webCameraNeedsTap = false;
      });
    } on CameraException catch (e) {
      if (_isHandingOffToLive) return;
      if (!mounted) return;
      final denied = e.code == 'CameraAccessDenied' ||
          e.code == 'CameraAccessDeniedWithoutPrompt' ||
          e.code == 'cameraPermission' ||
          e.code == 'PermissionDenied' ||
          (e.description?.toLowerCase().contains('permission') ?? false) ||
          (e.description?.toLowerCase().contains('notallowed') ?? false);
      setState(() {
        _isCameraInitializing = false;
        _cameraPermissionDenied = denied;
        _webCameraNeedsTap = kIsWeb;
        _cameraError = denied
            ? null
            : (e.description ?? 'Could not start the camera.');
      });
    } on MissingPluginException catch (e) {
      if (!mounted) return;
      setState(() {
        _isCameraInitializing = false;
        _webCameraNeedsTap = kIsWeb;
        _cameraError = kIsWeb
            ? 'Camera plugin not ready. Tap Enable Camera to retry.'
            : 'Camera plugin not available. Fully restart the app.';
      });
      debugPrint('Camera MissingPluginException: $e');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCameraInitializing = false;
        _webCameraNeedsTap = kIsWeb;
        _cameraError = 'Could not start the camera.';
      });
      debugPrint('Camera init failed: $e');
    }
  }

  Future<void> _flipCamera() async {
    if (_isSubmitting || _cameras.length < 2 || _isHandingOffToLive) return;
    final next = (_cameraIndex + 1) % _cameras.length;
    setState(() {
      _isCameraInitializing = true;
      _cameraIndex = next;
    });
    await _disposeCamera();
    if (!mounted || _isHandingOffToLive) return;

    try {
      final controller = CameraController(
        _cameras[_cameraIndex],
        kIsWeb ? ResolutionPreset.medium : ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: kIsWeb ? null : ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted || _isHandingOffToLive) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _isCameraInitializing = false;
      });
    } catch (e) {
      debugPrint('Flip camera failed: $e');
      if (mounted) {
        setState(() => _isCameraInitializing = false);
        unawaited(_initCamera());
      }
    }
  }

  Future<void> _handleGoLive() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _isHandingOffToLive = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    final roomName = _roomNameController.text.trim();
    final filterName = _apiFilterName;
    final slotCount = _selectedSlotCount;

    try {
      await _disposeCamera();
      // Short release beat so LiveKit can claim the camera without a long wait.
      await Future<void>.delayed(const Duration(milliseconds: 120));

      final room = await _liveRoomService.createRoom(
        roomName: roomName,
        filterName: filterName,
        slotCount: slotCount,
      );
      await _liveRoomService.goLive(room.id);

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LiveRoomScreen(
            roomName: room.id,
            role: LiveRoomRole.host,
            initialFilterName: room.filterName,
            initialSlotCount: room.slotCount,
          ),
        ),
      );
    } on LiveRoomException catch (e) {
      _isHandingOffToLive = false;
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _isSubmitting = false);
      unawaited(_initCamera());
    } catch (e) {
      _isHandingOffToLive = false;
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not go live: $e')),
      );
      setState(() => _isSubmitting = false);
      unawaited(_initCamera());
    }
  }

  Future<void> _pickBeautyFilter() async {
    if (_isSubmitting) return;

    final gpu = await showGpuBeautyControls(
      context: context,
      enabled: _beautyEnabled,
      intensity: _beautyIntensity,
    );
    if (gpu == null || !mounted) return;

    setState(() {
      _beautyEnabled = gpu.enabled;
      _beautyIntensity = gpu.intensity;
      // Named preset seeds LiveRoomScreen after Go Live.
      if (!gpu.enabled) {
        _selectedFilterName = 'None';
      } else if (gpu.intensity < 0.25) {
        _selectedFilterName = 'Natural';
      } else if (gpu.intensity < 0.55) {
        _selectedFilterName = 'Soft Skin';
      } else {
        _selectedFilterName = 'Soft Glow';
      }
    });
  }

  Future<void> _pickSeatSlots() async {
    if (_isSubmitting) return;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Seat slots',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            ..._slotOptions.map((count) {
              final selected = count == _selectedSlotCount;
              return ListTile(
                leading: const Icon(Icons.grid_view_rounded, color: Colors.white70),
                title: Text(
                  '$count seats',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: selected
                    ? const Icon(Icons.check, color: Color(0xFF00D4C8))
                    : null,
                onTap: () => Navigator.pop(ctx, count),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedSlotCount = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _closeScreen();
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraBackground(),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  Colors.transparent,
                  Colors.transparent,
                  Color(0xCC000000),
                ],
                stops: [0.0, 0.22, 0.55, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 8, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildTitleCard()),
                        IconButton(
                          onPressed: (_isSubmitting || _isClosing)
                              ? null
                              : () => unawaited(_closeScreen()),
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _buildToolRow(),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: _buildGoLiveButton(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildToolRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _toolIcon(
            icon: Icons.cameraswitch_outlined,
            label: 'Flip',
            onTap: _flipCamera,
          ),
          _toolIcon(
            icon: Icons.face_retouching_natural,
            label: 'Beauty',
            subtitle: _beautyEnabled
                ? '${(_beautyIntensity * 100).round()}%'
                : 'Off',
            onTap: _pickBeautyFilter,
          ),
          _toolIcon(
            icon: Icons.grid_view_rounded,
            label: 'Seats',
            subtitle: '$_selectedSlotCount',
            onTap: _pickSeatSlots,
          ),
        ],
      ),
    );
  }

  Widget _toolIcon({
    required IconData icon,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isSubmitting ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white60, fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }

  /// Bigo-style title card: cover thumb + title only (seats live in tool row).
  Widget _buildTitleCard() {
    final hasCover = _coverPhotoUrl != null && _coverPhotoUrl!.isNotEmpty;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: hasCover
                      ? CachedNetworkImage(
                          imageUrl: _coverPhotoUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => _coverPlaceholder(),
                        )
                      : _coverPlaceholder(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _roomNameController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                  cursorColor: Colors.white,
                  textInputAction: TextInputAction.done,
                  maxLines: 2,
                  minLines: 1,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Live room name',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    errorStyle: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 10,
                      height: 1,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a live room name';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coverPlaceholder() {
    return ColoredBox(
      color: const Color(0xFF3A2C5C),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: Colors.white.withValues(alpha: 0.5),
          size: 22,
        ),
      ),
    );
  }

  Widget _buildGoLiveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: _isSubmitting ? null : _handleGoLive,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF00C2FF),
          disabledBackgroundColor: const Color(0xFF00C2FF).withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Go LIVE',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
      ),
    );
  }

  Widget _buildCameraBackground() {
    if (_isCameraReady) {
      final preview = _cameraController!.value.previewSize;
      final previewW = preview?.height ?? MediaQuery.sizeOf(context).width;
      final previewH = preview?.width ?? MediaQuery.sizeOf(context).height;

      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: previewW,
            height: previewH,
            child: GpuImageFilter(
              enabled: _beautyEnabled,
              intensity: _beautyIntensity,
              child: CameraPreview(_cameraController!),
            ),
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFF120A24),
      child: Center(
        child: _isCameraInitializing
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white70),
                  SizedBox(height: 16),
                  Text(
                    'Starting camera...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              )
            : _buildCameraFallback(),
      ),
    );
  }

  Widget _buildCameraFallback() {
    final message = _webCameraNeedsTap
        ? 'Tap below to allow camera access for your preview.'
        : _cameraPermissionDenied
            ? 'Camera access is required to preview your stream.\nEnable it in Settings to continue.'
            : (_cameraError ?? 'Camera unavailable.');

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _webCameraNeedsTap
                ? Icons.videocam_outlined
                : _cameraPermissionDenied
                    ? Icons.no_photography_outlined
                    : Icons.videocam_off_outlined,
            color: Colors.white54,
            size: 48,
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: _cameraPermissionDenied && !kIsWeb
                ? openAppSettings
                : _initCamera,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            child: Text(
              _webCameraNeedsTap
                  ? 'Enable Camera'
                  : _cameraPermissionDenied && !kIsWeb
                      ? 'Open Settings'
                      : 'Retry',
            ),
          ),
        ],
      ),
    );
  }
}
