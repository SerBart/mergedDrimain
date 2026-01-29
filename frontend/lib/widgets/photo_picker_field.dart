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
        Text(
          widget.label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        // Nowoczesny design - Card z gradient background
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.withOpacity(0.08),
                Colors.purple.withOpacity(0.08),
              ],
            ),
            border: Border.all(
              color: Colors.blue.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Preview section
                if (img != null)
                  Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                img,
                                width: 140,
                                height: 140,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: -8,
                            right: -8,
                            child: GestureDetector(
                              onTap: _remove,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade400,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.shade400.withOpacity(0.4),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  )
                else
                  Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                            width: 2,
                            strokeAlign: BorderSide.strokeAlignOutside,
                          ),
                        ),
                        child: Icon(
                          Icons.image_outlined,
                          size: 48,
                          color: Colors.blue.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Brak wybranego zdjęcia',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Galeria button
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _pick,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(img == null ? 'Wybierz zdjęcie' : 'Zmień'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    if (!kIsWeb) ...[
                      const SizedBox(width: 12),
                      // Aparat button
                      Expanded(
                        child: FilledButton.icon(
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
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.purple,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (img != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: 18, color: Colors.green.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Zdjęcie zostało wybrane',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}