import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Picks a photo from the gallery and walks the user through a circular
/// crop, returning the cropped PNG bytes — or null if they cancelled at
/// any point. Shared between the profile avatar picker and the group
/// image picker so the crop UI only exists once.
Future<Uint8List?> pickAndCropCircularImage(BuildContext context) async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    // No maxWidth/maxHeight here — the crop step needs the original
    // resolution to crop from; downscaling happens after, on the
    // already-cropped result.
    imageQuality: 90,
  );
  if (picked == null || !context.mounted) return null;

  final originalBytes = await picked.readAsBytes();
  if (!context.mounted) return null;

  return Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(
      builder: (_) => _CropCircleScreen(imageBytes: originalBytes),
      fullscreenDialog: true,
    ),
  );
}

class _CropCircleScreen extends StatefulWidget {
  const _CropCircleScreen({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<_CropCircleScreen> createState() => _CropCircleScreenState();
}

class _CropCircleScreenState extends State<_CropCircleScreen> {
  final _controller = CropController();
  bool _cropping = false;

  void _onCropped(CropResult result) {
    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.of(context).pop(croppedImage);
      case CropFailure():
        setState(() => _cropping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not crop that photo — try again.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Crop photo'),
        actions: [
          TextButton(
            onPressed: _cropping
                ? null
                : () {
                    setState(() => _cropping = true);
                    _controller.cropCircle();
                  },
            child: const Text(
              'Done',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Crop(
            image: widget.imageBytes,
            controller: _controller,
            withCircleUi: true,
            baseColor: Colors.black,
            maskColor: Colors.black.withValues(alpha: 0.75),
            onCropped: _onCropped,
          ),
          if (_cropping)
            const ColoredBox(
              color: Colors.black38,
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }
}
