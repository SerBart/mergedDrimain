import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PhotoPickerField extends StatefulWidget {
  final String? initialBase64;
  final ValueChanged<String?> onChanged;
  final double previewSize;
  final String label;

  const PhotoPickerField({
    super.key,
    required this.onChanged,
    this.initialBase64,
    this.previewSize = 80,
    this.label = 'Zdjęcie',
  });

  @override
  State<PhotoPickerField> createState() => _PhotoPickerFieldState();
}

class _PhotoPickerFieldState extends State<PhotoPickerField> {
  String? _base64;

  @override
  void initState() {
    super.initState();
    _base64 = widget.initialBase64;
  }

  Future<void> _pick() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      setState(() => _base64 = b64);
      widget.onChanged(b64);
    }
  }

  void _remove() {
    setState(() => _base64 = null);
    widget.onChanged(null);
  }

  Uint8List? _decode() {
    if (_base64 == null) return null;
    try {
      return base64Decode(_base64!);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final img = _decode();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                )),
        const SizedBox(height: 8),
        Row(
          children: [
            if (img != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      img,
                      width: widget.previewSize,
                      height: widget.previewSize,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: InkWell(
                      onTap: _remove,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.close,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  )
                ],
              )
            else
              Container(
                width: widget.previewSize,
                height: widget.previewSize,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.image, color: Colors.white54),
              ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(img == null ? 'Wybierz zdjęcie' : 'Zmień'),
            ),
            if (!kIsWeb) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final picker = ImagePicker();
                  final XFile? shot = await picker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 1600,
                    imageQuality: 80,
                  );
                  if (shot != null) {
                    final bytes = await shot.readAsBytes();
                    final b64 = base64Encode(bytes);
                    setState(() => _base64 = b64);
                    widget.onChanged(b64);
                  }
                },
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Aparat'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}