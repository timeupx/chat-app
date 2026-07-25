import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/live_room_service.dart';
import 'live_room_detail_screen.dart';

/// Form for setting up a new live room/channel: name and image only.
/// On submit, uploads the picked image, creates the `LiveRoom` row on the
/// backend, then hands off to [LiveRoomDetailScreen] where the host can
/// actually go live.
class CreateLiveRoomScreen extends StatefulWidget {
  const CreateLiveRoomScreen({super.key});

  @override
  State<CreateLiveRoomScreen> createState() => _CreateLiveRoomScreenState();
}

class _CreateLiveRoomScreenState extends State<CreateLiveRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _liveRoomService = LiveRoomService();
  final _picker = ImagePicker();

  final _roomNameController = TextEditingController();

  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _roomNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final image = await _picker.pickImage(source: source, imageQuality: 85);
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedImage = image;
      _pickedImageBytes = bytes;
    });
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCreateRoom() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pickedImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a room image.')));
      return;
    }

    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final imageUrl = await _liveRoomService.uploadImage(_pickedImage!);

      final room = await _liveRoomService.createRoom(
        roomName: _roomNameController.text.trim(),
        roomImage: imageUrl,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => LiveRoomDetailScreen(roomId: room.id)),
      );
    } on LiveRoomException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradientColors = [
      theme.colorScheme.primary,
      theme.colorScheme.tertiary,
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Set Up Your Room'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _buildImagePicker(theme),
                const SizedBox(height: 28),
                _buildGlassField(
                  child: TextFormField(
                    controller: _roomNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _fieldDecoration(
                      label: 'Room Name',
                      hint: 'e.g. Friday Night Karaoke',
                      icon: Icons.videocam_outlined,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Room name is required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 32),
                _buildCreateButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker(ThemeData theme) {
    return GestureDetector(
      onTap: _isSubmitting ? null : _showImageSourceSheet,
      child: Container(
        height: 190,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withValues(alpha: 0.12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
          image: _pickedImageBytes != null
              ? DecorationImage(image: MemoryImage(_pickedImageBytes!), fit: BoxFit.cover)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: _pickedImageBytes == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 44, color: Colors.white),
                  SizedBox(height: 10),
                  Text(
                    'Tap to select a room image',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ],
              )
            : Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                      onPressed: _showImageSourceSheet,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  /// Frosted-glass style container used behind form fields so text stays
  /// readable against the gradient background.
  Widget _buildGlassField({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: child,
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.white70),
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white38),
      border: InputBorder.none,
    );
  }

  Widget _buildCreateButton() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(colors: [Color(0xFFFF5F6D), Color(0xFFFFC371)]),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: _isSubmitting ? null : _handleCreateRoom,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: _isSubmitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text(
                      'Create Room',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
